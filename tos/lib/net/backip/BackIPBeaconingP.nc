/**
 * This is an implementation of Backpressure based routing over BLIP,
 * based on the concepts in the Backpressure collection protocol
 *
 * @author Srikanth Nori <snori@usc.edu>
 */

#include <IPDispatch.h>
#include <lib6lowpan/lib6lowpan.h>
#include <lib6lowpan/ip.h>
#include <lib6lowpan/iovec.h>
#include <iprouting.h>
#include <limits.h>

#include "BackIP.h"
#include "BackIPShared.h"
#include "blip_printf.h"

module BackIPBeaconingP {
	provides {
		interface StdControl;
		interface RootControl;
		interface BackIPLinkResultInterface;
		interface PacketGen;
		interface BackIPStats;
	}
	uses {
		interface Timer<TMilli> as BeaconTimer;
		interface ForwardingTable;
		interface UDP as UDPBeacon;
		interface UDP as UDPNull;
		interface BeaconQueueInterface;
		interface ForwardingEvents;
		interface IPPacket;
		interface IPAddress;
		interface NeighborDiscovery as ND;
	}
} implementation {

	bool I_AM_ROOT = FALSE;

	command error_t RootControl.setRoot()
	{
		I_AM_ROOT = TRUE;
#if ADAPTIVE_BEACONING
		call BeaconTimer.startPeriodic(IDLE_BEACON_INTERVAL);
#endif
		return SUCCESS;
	}

	command error_t RootControl.unsetRoot()
	{
		I_AM_ROOT = FALSE;
		if(call BeaconTimer.isRunning()) {
			call BeaconTimer.stop();
		}
		return SUCCESS;
	}

	command bool RootControl.isRoot()
	{
		return I_AM_ROOT;
	}

	//bool first_run = FALSE;
	bool no_neighbours = FALSE;

	uint32_t best_bp_n = UINT_MAX;

	neighbour_table_t table;
	int nt_update_neighbour(ll_addr_t *ll_addr, uint16_t ETX, uint32_t backpressure);
	int nt_update_neighbour_backpressure(ll_addr_t *ll_addr, uint32_t backpressure);
	int nt_update_neighbour_ETX(ll_addr_t *ll_addr, uint16_t ETX);
	int nt_update_neighbour_tx_time(ll_addr_t *ll_addr, uint16_t tx_time);
	void nt_print();

	command error_t StdControl.start()
	{
		route_key_t new_key = ROUTE_INVAL_KEY;
		struct in6_addr def;
		dbg("BackIPBeaconing", "StdControl.start called\n");

		//first_run = TRUE;
		no_neighbours = TRUE;

		if(call UDPBeacon.bind((uint16_t)BACKIP_BEACON_PORT) != SUCCESS) {
			dbg("BackIPBeaconing", "Failed to bind to beaconing port\n");
			return FAIL;
		}

		if(call UDPNull.bind((uint16_t)BACKIP_NULPKT_PORT) != SUCCESS) {
			dbg("BackIPNull", "Failed to bind to null packet port\n");
			return FAIL;
		}

		inet_pton6("fe80::22:ff:fe00:1", &def);
		/* BLIP needs to have at least one route to start transmissions */
		new_key = call ForwardingTable.addRoute(NULL,
				0,
				&def,
				BACKIP_IFACE);

		if (new_key == ROUTE_INVAL_KEY) {
			dbg("BackIPBeaconing", "Adding default route failed\n");
			return FAIL;
		}
#if ADAPTIVE_BEACONING
		/* Send out a beacon to 'announce' your existence */
		if(!(call BeaconTimer.isRunning())) {
			call BeaconTimer.startOneShot(FAST_BEACON_INTERVAL);
		}
#else
		call BeaconTimer.startPeriodic(IDLE_BEACON_INTERVAL);
#endif

		return SUCCESS;
	}

	command error_t StdControl.stop()
	{
		dbg("BackIPBeaconing", "StdControl.stop called\n");

		if((call BeaconTimer.isRunning()))	{
			call BeaconTimer.stop();
		}

		return SUCCESS;
	}

	event void BeaconTimer.fired()
	{
		int ret;
		uint32_t backpressure_value;
		struct sockaddr_in6 dest;
		uint8_t beacon_pkt[MAX_BEACON_SIZE];

		//Construct Beacon Packet
		//<00 - 03 bytes>:: Beacon type
		//<04 - 07 bytes>:: Backpressure value

		backpressure_value = call BeaconQueueInterface.GetBackpressure();

		if(no_neighbours && ! I_AM_ROOT) {
			//printf("[%d] Generating req beacon\n", TOS_NODE_ID);printfflush();
			dbg("BackIPBeaconing", "Generating req beacon\n", TOS_NODE_ID);
			write_4B(beacon_pkt, BEACON_TYPE_REQ);
		} else {
			//printf("[%d] Generating normal beacon\n", TOS_NODE_ID);printfflush();
			dbg("BackIPBeaconing", "Generating normal beacon\n", TOS_NODE_ID);
			write_4B(beacon_pkt, BEACON_TYPE_NORM);
		}
		write_4B(beacon_pkt + 4, backpressure_value);

		//Send packet to LL-multicast address, will reach all immediate neighbors
		inet_pton6("ff02::1", &dest.sin6_addr);
		dest.sin6_port = htons((uint16_t)BACKIP_BEACON_PORT);

		atomic {
			call BeaconQueueInterface.SendingBeacon();
			ret = call UDPBeacon.sendto(&dest, beacon_pkt, MAX_BEACON_SIZE);
		}
		if(SUCCESS != (ret)) {
			dbg("BackIPBeaconing", "Beacon Send Failed %d\n", ret);
			//printf("[%d] Beacon send failed \n", TOS_NODE_ID); printfflush();
		} else {
			//printf("[%d] Beacon sent \n", TOS_NODE_ID); printfflush();
		}

		if(I_AM_ROOT) {
			//Root beacons periodically
			call BeaconTimer.startOneShot(IDLE_BEACON_INTERVAL);
		} else {
			// Other nodes: Send beacons fast till they have one neighbour at least
			if(no_neighbours) {
				call BeaconTimer.startOneShot(FAST_BEACON_INTERVAL);
			}
		}
	}

	event void UDPBeacon.recvfrom(struct sockaddr_in6 *from,
			void *data, uint16_t len, struct ip6_metadata *md)
	{
		uint32_t beacon_type;
		uint8_t *rpkt = data;
		ieee154_addr_t ll_addr;
		uint32_t r_backpressure_value;
#if TOSSIM
		char addr[46];
		inet_ntop6(&from->sin6_addr, addr, 46);
		dbg("BackIPBeaconing", "Received beacon from %s\n", addr);
#endif

		if (call ND.resolveAddress(&from->sin6_addr, &ll_addr) != SUCCESS) {
			dbg("BackIPBeaconing", "resolvAddress failed \n");
			return;
		}
		read_4B(&r_backpressure_value , rpkt + 4);
		nt_update_neighbour_backpressure(&ll_addr, r_backpressure_value);

		//I've got one neighbour at least so I can stop beaconing frantically
		no_neighbours = FALSE;

		//printf("[%d] Received beacon %d\n", TOS_NODE_ID, r_backpressure_value);
		//printfflush();


#if ADAPTIVE_BEACONING
		/* Check the beacon type */
		read_4B(&beacon_type, rpkt);

		dbg("BackIPBeaconing", "[%d] Received beacon type %d bp %d\n", TOS_NODE_ID, beacon_type, r_backpressure_value);
		//printf("[%d] Received beacon type %d bp %d\n", TOS_NODE_ID, beacon_type, r_backpressure_value);
		//printfflush();
		/* If a response has been requested, quickly send out a beacon */
		if(BEACON_TYPE_REQ == beacon_type) {
			//printf("[%d]  Received req beacon\n", TOS_NODE_ID);
			dbg("BackIPBeaconing", " Received req beacon\n", TOS_NODE_ID);
			printf("[%d] Received req beacon\n", TOS_NODE_ID);

			/* Override any other requests! We have a new friend!
			 * this is important, dammit */
			if(call BeaconTimer.isRunning()) {
				call BeaconTimer.stop();
			}
			call BeaconTimer.startOneShot(FAST_BEACON_INTERVAL);
		}
#endif
	}

	//add an IPv6 hop-by-hop options header ala
	// http://tools.ietf.org/html/rfc2460#section-4.3
	// to carry backpressure information.
	//
	// 'Downstream' nodes may modify this
	event bool ForwardingEvents.initiate(struct ip6_packet *ip_pkt,
			struct in6_addr *next_hop)
	{
		static backip_data_hdr_t data_hdr;
		static struct ip_iovec v;
		uint16_t len;

		//no Hop-by-hop headers on ICMP packets
		if (ip_pkt->ip6_hdr.ip6_nxt == IANA_ICMP)
			return TRUE;

		data_hdr.ip6_ext_outer.ip6e_nxt = ip_pkt->ip6_hdr.ip6_nxt;
		data_hdr.ip6_ext_outer.ip6e_len = 0;

		data_hdr.ip6_ext_inner.ip6e_nxt = BACKIP_HBH_OPT_TYPE;
		data_hdr.ip6_ext_inner.ip6e_len = sizeof(backip_data_hdr_t) -
			offsetof(backip_data_hdr_t, data);

		data_hdr.data = call BeaconQueueInterface.GetBackpressure() + 1;
		//+1 to include this packet in calculation

		ip_pkt->ip6_hdr.ip6_nxt = IPV6_HOP;
		len = ntohs(ip_pkt->ip6_hdr.ip6_plen);

		//add the header
		v.iov_base = (uint8_t *) &data_hdr;
		v.iov_len = sizeof(backip_data_hdr_t);
		v.iov_next = ip_pkt->ip6_data; //original data;

		/* increase length in ipv6 header and relocate beginning */
		ip_pkt->ip6_data = &v;
		len = len + v.iov_len;
		ip_pkt->ip6_hdr.ip6_plen = htons(len);
		return TRUE;
	}

	event bool ForwardingEvents.approve(struct ip6_packet *ip_pkt,
			struct in6_addr *next_hop)
	{
		backip_data_hdr_t data_hdr;
		uint8_t nxt_hdr = IPV6_HOP;
		int off;

		//dbg("BackIPFwdEvent", "+Approve %d\n", ip_pkt->ip6_hdr.ip6_nxt);

		/* is there a HBH header? */
		off = call IPPacket.findHeader(ip_pkt->ip6_data, ip_pkt->ip6_hdr.ip6_nxt, &nxt_hdr);
		if (off < 0) {
			dbg("BackIPFwdEvent", "Fail 1\n");
			return TRUE;
		}

		/* if there is, is there a BackIP TLV option in there? */
		off = call IPPacket.findTLV(ip_pkt->ip6_data, off, BACKIP_HBH_OPT_TYPE);
		if (off < 0) {
			dbg("BackIPFwdEvent", "Fail 2\n");
			return TRUE;
		}

		/* read out the backip option */
		if (iov_read(ip_pkt->ip6_data,
					off + sizeof(struct tlv_hdr),
					sizeof(backip_data_hdr_t) - offsetof(backip_data_hdr_t, data),
					(void *)&data_hdr.data) !=
				sizeof(backip_data_hdr_t) - offsetof(backip_data_hdr_t, data)) {
			dbg("BackIPFwdEvent", "Fail 3\n");
			return TRUE;
		}
		dbg("BackIPFwdEvent", "Approve: Neighbour backpressure is %d\n", data_hdr.data);
		//printf("Approve: Neighbour backpressure is %d\n", data_hdr.data);
		//printfflush();

		//Replace with our local backpressure
		data_hdr.data = call BeaconQueueInterface.GetBackpressure();
		iov_update(ip_pkt->ip6_data,
				off + sizeof(struct tlv_hdr),
				sizeof(backip_data_hdr_t) - offsetof(backip_data_hdr_t, data),
				(void *)&data_hdr.data);
		return TRUE;
	}

	event void ForwardingEvents.linkResult(struct in6_addr *node,
			struct send_info *info)
	{
		//dbg("BackIPFwdEvent", "linkResult %d\n", info->link_fragment_attempts);
		return;
	}

	command void BackIPLinkResultInterface.updateETX(ll_addr_t *ll_addr, uint16_t ETX)
	{
		dbg("BackIPFwdEvent", "updateETX: %d\n", ETX);
		nt_update_neighbour_ETX(ll_addr, ETX);
	}

	void print_ll_addr(ll_addr_t *addr)
	{
		int i = 0;
		for(i = 0; i < sizeof(ll_addr_t); i++) {
			printf("%02X", ((char *)addr)[i]);
		}
		printf("\n");
	}

	/* Find and set the current best neighbour. Return 0 on success */
	command int8_t BackIPLinkResultInterface.updateNeighbour()
	{
		uint8_t i, best_idx;
		int32_t max_weight = -1, curr_weight = 0;

		uint32_t BP, ETX, rate, myBP;

		//Check if there are any good neighbours at all
		if(table.num_curr_neighbours == 0) {
			return -1;
		}

		atomic {
			myBP = call BeaconQueueInterface.GetBackpressure();

			//Scan through the routing table and find neighbour with best weight
			for(i = 0; i < table.num_curr_neighbours; i++) {
				neighbour_table_entry_t *entry = &table.entry[i];
				BP = entry->backpressure;
				ETX = LINK_ETX_V * entry->ETX / 100;
				rate = 10000 / entry->tx_time;
				curr_weight = (myBP - BP - ETX) * rate;

				dbg("BackIPFwdEvent", "i: %d myBP: %d BP: %d ETX: %d(%d) rate:%d curr_weight: %d\n",
						i, myBP, BP, ETX, entry->ETX, rate, curr_weight);
				//printf("%3d %3d %3d %3d(%3d) %3d %3d\n", i, myBP, BP, ETX, entry->ETX, rate, curr_weight); printfflush();

				if(curr_weight > max_weight) {
					best_idx = i;
					max_weight = curr_weight;
				}
			}

			if(max_weight == -1) {
				//No neighbour is good right now
				//printf("No neighbour is good right now!\n"); printfflush();
				return -1;
			}	else {
#if PRINTFUART_ENABLED
				{
					neighbour_table_entry_t * entry = &table.entry[best_idx];
				//printf("Good neighbour:"); printf_ieee154addr(&entry->ll_addr); printf("\n"); printfflush();
				//printf(" myBP: %d BP: %d ETX: %d(%d) rate:%d curr_weight: %d\n", myBP, entry->backpressure, LINK_ETX_V*entry->ETX/100, entry->ETX, 10000/entry->tx_time, max_weight); printfflush();
				}
#endif
				call BeaconQueueInterface.setNeighbour(&table.entry[best_idx].ll_addr);
			}
		}
		return 0;
	}

	/* Calculate the current link rate */
	command void BackIPLinkResultInterface.updateLinkRate(
			ll_addr_t *ll_addr, uint16_t tx_time)
	{
		dbg("BackIPFwdEvent", "updateLinkRate: %u\n", tx_time);
		nt_update_neighbour_tx_time(ll_addr, tx_time);
	}

	/* Generate a beacon to tell your neighbours that your BP has changed */
	command void BackIPLinkResultInterface.drasticBackpressureChange()
	{
#if ADAPTIVE_BEACONING
		//printf("[%d] Drastic BP change!\n", TOS_NODE_ID);
		//printfflush();
		if(call BeaconTimer.isRunning()) {
			/* Beacon already scheduled, do nothing */
		} else {
			call BeaconTimer.startOneShot(FAST_BEACON_INTERVAL);
		}
#endif
	}

	bool _cmp_ll_addr(ll_addr_t *a1, ll_addr_t *a2)
	{
		if (a1->ieee_mode != a2->ieee_mode)
			return FALSE;
		switch(a1->ieee_mode) {
			case IEEE154_ADDR_SHORT:
				if(0 == memcmp(&a1->ieee_addr.saddr,
							&a2->ieee_addr.saddr,
							sizeof(ieee154_saddr_t))) {
					return TRUE;
				}
				return FALSE;
				break;
			case IEEE154_ADDR_EXT:
				if(0 == memcmp(&a1->ieee_addr.laddr,
							&a2->ieee_addr.laddr,
							sizeof(ieee154_laddr_t))) {
					return TRUE;
				}
				return FALSE;
				break;
			default:
				return FALSE;
				break;
		}
		return FALSE;
	}

	bool _get_neighbour_index(uint8_t *idx, ll_addr_t *ll_addr)
	{
		uint8_t i;
		bool found = FALSE;
		//printf("[%d] looking up neighbour\n", TOS_NODE_ID);

		for(i = 0; i < table.num_curr_neighbours; i++) {
			if(_cmp_ll_addr(ll_addr, &table.entry[i].ll_addr)) {
				//printf("[%d] found\n", TOS_NODE_ID);
				found = TRUE;
				break;
			}
		}

		if(found) {
			//printf("[%d] found\n", TOS_NODE_ID);
			*idx = i;
		} else {
			//printf("[%d] not found\n", TOS_NODE_ID);
			if(table.num_curr_neighbours == MAX_NEIGHBOURS) {
				printf("[%d] table size exceeded\n", TOS_NODE_ID);
				return FALSE;
			}

			//printf("[%d] creating new entry\n", TOS_NODE_ID);
			*idx = table.num_curr_neighbours;
			memcpy(&table.entry[*idx].ll_addr, ll_addr, sizeof(ll_addr_t));
			table.entry[*idx].ETX						= 100; //Initialize to amazing lossless link
			table.entry[*idx].backpressure	= 255; //Init to high
			table.entry[*idx].tx_time				= 1; //Init to 1ms
			table.num_curr_neighbours++;
		}
		return TRUE;
	}

	int nt_update_neighbour(ll_addr_t *ll_addr, uint16_t ETX, uint32_t backpressure)
	{
		uint8_t idx;
		bool found;
		atomic {
			found = _get_neighbour_index(&idx, ll_addr);
			if(found) {
				table.entry[idx].ETX = ETX;
				table.entry[idx].backpressure = backpressure;
			} else {
				return -1;
			}
			return 0;
		}
	}

	int nt_update_neighbour_ETX(ll_addr_t *ll_addr, uint16_t ETX)
	{
		uint8_t idx;
		bool found;
		uint32_t newETX;
		uint16_t oldETX;

		atomic {
			found = _get_neighbour_index(&idx, ll_addr);
			if(found) {
				oldETX = table.entry[idx].ETX;
				newETX = (oldETX * LINK_ETX_ALPHA) + (ETX * 100) * (100 - LINK_ETX_ALPHA);
				newETX /= 100;
				dbg("BackIPFwdEvent", "oldETX: %d input:%d newETX:%d\n", oldETX, ETX, newETX);
				table.entry[idx].ETX = newETX;
			} else {
				return -1;
			}
			return 0;
		}
	}

	int nt_update_neighbour_backpressure(ll_addr_t *ll_addr, uint32_t backpressure)
	{
		uint8_t idx;
		bool found;
		atomic {
			found = _get_neighbour_index(&idx, ll_addr);
			if(found) {
				table.entry[idx].backpressure = backpressure;
			} else {
				return -1;
			}
			return 0;
		}
	}

	int nt_update_neighbour_tx_time(ll_addr_t *ll_addr, uint16_t tx_time)
	{
		uint8_t idx;
		bool found;
		atomic {
			found = _get_neighbour_index(&idx, ll_addr);
			if(found) {
				uint16_t old_tx_time;
				uint16_t new_tx_time;
				if(tx_time == 0) {
					new_tx_time = 1;
				} else {
					new_tx_time = tx_time;
				}
				old_tx_time = table.entry[idx].tx_time;
				table.entry[idx].tx_time =
					((LINK_TX_TIME_ALPHA * (uint32_t)(old_tx_time)) +
					 ((10 - LINK_TX_TIME_ALPHA)*(uint32_t)new_tx_time)) / 10;

			} else {
				return -1;
			}
			return 0;
		}
	}

	void nt_print()
	{
		struct in6_addr local_addr;
		ll_addr_t local_ll;
		call IPAddress.getLLAddr(&local_addr);
		if (call ND.resolveAddress(&local_addr, &local_ll) != SUCCESS) {
			dbg("BackIPNT", "resolveAddress local failed \n");
			return;
		}
		atomic {
			int i;
			dbg("BackIPNT","------------------\n");
			dbg("BackIPNT","--Neighbour Table-\n");
			dbg("BackIPNT","-----%08X-----\n",
					(uint32_t)local_ll.ieee_addr.laddr.data);
			for(i = 0; i < table.num_curr_neighbours; i++) {
				neighbour_table_entry_t *entry = &table.entry[i];
				dbg("BackIPNT","%08X %04d %04d\n",
						(uint32_t)(entry->ll_addr.ieee_addr.laddr.data),
						entry->ETX, entry->backpressure);
			}
			dbg("BackIPNT","------------------\n\n");
		}
	}
	event void IPAddress.changed(bool global_valid) {}

	command void PacketGen.sendNull()
	{
		struct sockaddr_in6 dest;
		uint8_t null_pkt[MAX_NULPKT_SIZE];

		dbg("BackIPNull", "Sending NULL\n");

		//Send packet to default destination address
		inet_pton6(NULL_DEST_ADDR, &dest.sin6_addr);
		dest.sin6_port = htons((uint16_t)BACKIP_NULPKT_PORT);

		call UDPNull.sendto(&dest, null_pkt, MAX_NULPKT_SIZE);

	}

	event void UDPNull.recvfrom(struct sockaddr_in6 *from,
			void *data, uint16_t len, struct ip6_metadata *md)
	{
		dbg("BackIPNull", "Receiving NULL\n");
	}

	command void BackIPStats.getCurrStats(backip_stats_t *stats)
	{
		int i;
		struct in6_addr local_addr;
		call IPAddress.getLLAddr(&local_addr);

		//Fill in neighbor details
		atomic {
			stats->num_curr_neighbours = table.num_curr_neighbours;
			for(i = 0; i < table.num_curr_neighbours; i++) {
				memcpy(&stats->nb[i].ll_addr,
						&table.entry[i].ll_addr, sizeof(ll_addr_t));
				stats->nb[i].backpressure = table.entry[i].backpressure;
				stats->nb[i].ETX = table.entry[i].ETX;
				stats->nb[i].tx_time = table.entry[i].tx_time;
			}
		}

		//Fill in local details
		stats->backpressure = call BeaconQueueInterface.GetBackpressure();
		stats->last_backpressure = call BeaconQueueInterface.GetLastBackpressure();
		call BeaconQueueInterface.GetSendStats(&stats->send_stats);
		call ND.resolveAddress(&local_addr, &stats->ll_addr);
	}
}

