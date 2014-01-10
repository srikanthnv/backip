/**
 * This is an implementation of Backpressure based routing over BLIP,
 * based on the concepts in the Backpressure collection protocol
 *
 * @author Srikanth Nori <snori@usc.edu>
 */

#ifndef __BACKIP_H__
#define __BACKIP_H__

#include <iprouting.h>

/* Feature toggles */
#define ADAPTIVE_BEACONING 1

/* Constants/Magic numbers */
#define BACKIP_BEACON_PORT	56009L
#define BACKIP_NULPKT_PORT	56010L
#define BEACON_TYPE_NORM				100 //Normal beacon - just for info
#define BEACON_TYPE_REQ					200 //Request neighbours to respond

/* Can't change these */
#define BACKIP_IFACE		ROUTE_IFACE_154
#if TOSSIM
#define NULL_DEST_ADDR			"fec0::1"
#else
#define NULL_DEST_ADDR			"fec0::12"  //Sink address. TODO
#endif
#define MAX_BEACON_SIZE		8
#define MAX_NULPKT_SIZE		1
//http://tools.ietf.org/html/rfc4727
#define BACKIP_HBH_OPT_TYPE 0x7E

/* Tunable parameters */
#define FORWARDING_QUEUE_SIZE		10	//Num pkts to 'hold'
#define BP_DIFF_THRESH					2		//Send beacon if backpressure delta >= than this
#define IDLE_BEACON_INTERVAL		2000	//Frequency of beacons when there's no activity
#define FAST_BEACON_INTERVAL		100	//Quickly send Beacon at start
#define RETRY_INTERVAL					50	//if radio busy
#define REROUTE_INTERVAL				50	//if no good route exists
#define LINK_ETX_ALPHA					90	//LINK_LOSS_ALPHA in BCP
#define LINK_TX_TIME_ALPHA			9		//LINK_EST_ALPHA in BCP
#define LINK_ETX_V							2		//LINK_LOSS_V in BCP
#define MAX_RETX_ATTEMPTS				5		//Before 'giving up' on a link
#define MAX_NEIGHBOURS				0x30	//defines fwding table size

typedef ieee154_addr_t ll_addr_t;

typedef struct {
	ll_addr_t ll_addr;		//Neighbour's Link Layer address
	uint32_t backpressure;	//Neighbour's reported backpressure
	uint16_t ETX;			//EWMA in 100ths of expected transmissions
	uint16_t tx_time;		//EWMA in 100us units time to transmit a packet (incl RTT ACK)

} neighbour_table_entry_t;

typedef struct {
	neighbour_table_entry_t entry[MAX_NEIGHBOURS];
	uint8_t num_curr_neighbours;
} neighbour_table_t;

typedef struct {
	message_t * ONE_NOK msg;
	uint16_t tx_count;
	uint32_t first_tx_time;
} fe_queue_entry_t;

nx_struct nx_ip6_ext {
	nx_uint8_t ip6e_nxt;
	nx_uint8_t ip6e_len;
};

typedef nx_struct {
	nx_struct nx_ip6_ext ip6_ext_outer;
	nx_struct nx_ip6_ext ip6_ext_inner;
	nx_uint8_t data;
	nx_uint8_t pad0;
	nx_uint16_t pad1;
} __attribute__((packed)) backip_data_hdr_t;

void print_bytes(uint8_t *ptr, uint8_t len)
{
	uint32_t i;
	char buf[300] = "", num[3];
	for(i = 0; i < len; i++) {
		sprintf(num, "%02x", ptr[i]);
		strcat(buf, num);
	}
	dbg("BackIPBytes", "%s\n", buf);
}

void write_4B(uint8_t *buf, uint32_t data)
{
	uint32_t ndata = htonl(data);
	buf[0] = (ndata & 0xff000000) >> 24;
	buf[1] = (ndata & 0xff0000) >> 16;
	buf[2] = (ndata & 0xff00) >> 8;
	buf[3] = (ndata & 0xff);
}

void read_4B(uint32_t *data, uint8_t *buf)
{
	uint32_t ndata;
	ndata =  ((uint32_t)buf[0] << 24) & 0xff000000;
	ndata |= ((uint32_t)buf[1] << 16) & 0xff0000;
	ndata |= ((uint32_t)buf[2] << 8)  & 0xff00;
	ndata |= ((uint32_t)buf[3])       & 0xff;
	*data = ntohl(ndata);
}

#endif /* __BACKIP_H__ */
