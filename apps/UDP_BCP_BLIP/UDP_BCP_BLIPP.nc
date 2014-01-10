/**
 * This is an implementation of Backpressure based routing over BLIP,
 * based on the concepts in the Backpressure collection protocol
 *
 * @author Srikanth Nori <snori@usc.edu>
 */

#include <IPDispatch.h>
#include <lib6lowpan/lib6lowpan.h>
#include <lib6lowpan/ip.h>
#include <lib6lowpan/ip.h>
#include <BlipStatistics.h>

#include "blip_printf.h"
#include "backip_cmds.h"

#if !TOSSIM
#define SENDER_EXPR (TOS_NODE_ID != 18)
#define DEST_NODE_ID 18
#define DEST_ADDR "fec0::12"
#else
#define SENDER_EXPR (TOS_NODE_ID != 1)
#define DEST_NODE_ID 1
#define DEST_ADDR "fec0::1"
#endif

#define REPORT_PERIOD 10L

module UDP_BCP_BLIPP {
	uses {
		interface Boot;
		interface SplitControl as RadioControl;
		interface SplitControl as IPControl;

		interface UDP as Echo;
		interface UDP as Status;
		interface Random;

		interface Leds;

		interface Timer<TMilli> as SendTimer;
		interface Timer<TMilli> as PerfTimer;

		interface RootControl;
#ifdef BACKIP_ROUTING
		interface BackIPStats;
		interface BackIPFlag;
#endif
#ifdef STATS
		interface Timer<TMilli> as StatsTimer;
		interface SplitControl as Control;
		interface Receive;
		interface AMSend;
		interface Packet;
		interface Queue<backip_msg_t *> as SendQ;
		interface Pool<backip_msg_t> as MsgPool;
		interface LocalTime <TMilli>;
#endif //STATS

	}

} implementation {

	struct sockaddr_in6 route_dest;
#if DELAY
#define BUFLEN 8
#else
#define BUFLEN 4
#endif
	uint8_t buf[BUFLEN];
	uint32_t ctr;

#ifdef STATS
	task void sendStatsTask();
#endif //STATS

	event void Boot.booted()
	{
		ctr = TOS_NODE_ID * 1000;

#ifdef STATS
		call Control.start();
#else
		call PerfTimer.startPeriodic(1000);
#endif //STATS
		call RadioControl.start();
		call IPControl.start();

		if(TOS_NODE_ID == DEST_NODE_ID)
		{
			dbg("Boot", "Setting root\n");
			call RootControl.setRoot();
			//call Leds.led2On();
		}
		dbg("Boot", "booted: %i\n", TOS_NODE_ID);

		call Echo.bind(7000);
	}

	event void RadioControl.startDone(error_t e) {
	}

	event void RadioControl.stopDone(error_t e) {

	}

	uint32_t now, t0, dt;
	bool first_timer = TRUE;
	event void IPControl.startDone (error_t error)
	{
		if(SENDER_EXPR) {
#if BACKIP_ROUTING
		call BackIPFlag.setFlag(0xffffffff);
#endif
#if TOSSIM || MOTES
#if POISSON
		call SendTimer.startOneShot(call Random.rand32());
#else
		now = call SendTimer.getNow();
		t0 = now + 5000;
		//t0 = INTER_PKT_TIME;
		dt = INTER_PKT_TIME;
		dbg("UDP_BCP_BLIP", "now: %u, t0: %u, dt: %u\n", now, t0, dt);
		call SendTimer.startOneShot(t0);
#endif
#endif
		}
	}

	event void IPControl.stopDone (error_t error) { }

	event void Status.recvfrom(struct sockaddr_in6 *from, void *data,
			uint16_t len, struct ip6_metadata *meta) {

	}

	uint32_t pkts_recvd = 0;
	event void Echo.recvfrom(struct sockaddr_in6 *from, void *data,
			uint16_t len, struct ip6_metadata *meta)
	{
		char addr[46];
		uint32_t rec = 0;
		uint8_t *ptr = data;
		rec = (((uint32_t)ptr[0] << 24) |
				((uint32_t)ptr[1] << 16) |
				((uint32_t)ptr[2] << 8) |
				(uint32_t)ptr[3]);
		call Leds.led1Toggle();
		inet_ntop6(&from->sin6_addr, addr, 46);
		printf("received %d\n", rec);
		dbg("UDP_BCP_BLIP", "%i received a packet %u from %s\n", TOS_NODE_ID, rec, addr);
		//call Echo.sendto(from, data, len);
		pkts_recvd ++;
#ifdef STATS
		if(TOS_NODE_ID == DEST_NODE_ID) {
			backip_msg_t *m = call MsgPool.get();
			if(m == NULL) {
				return;
			}
			m->sender = from->sin6_addr.in6_u.u6_addr8[15];
			m->ctr = rec;
			m->recv_time = call LocalTime.get();
#if DELAY
			m->delay = (((uint32_t)ptr[4] << 24) |
				((uint32_t)ptr[5] << 16) |
				((uint32_t)ptr[6] << 8) |
				(uint32_t)ptr[7]);
#endif
			atomic call SendQ.enqueue(m);
			post sendStatsTask();
		}
#endif //STATS
	}

#ifdef STATS
	bool sending_stats = FALSE;

	/* Takes care of 'gently' sending stats out over serial forwarder */
	/* or storing them to flash  */
	task void sendStatsTask()
	{
		message_t pkt;
		backip_msg_t *msg;
		backip_msg_t *qmsg;
		int ret;

		if(call SendQ.empty()) {
			return;
		}

		/* Check if prev send is done */
		if(sending_stats) {
			/* Busy? Try again later */
			call StatsTimer.startOneShot(10);
			return;
		}

		/* Start sending */
		sending_stats = TRUE;

		/* Pull out a message from queue */
		atomic {qmsg = call SendQ.head();}
		/* Acquire a packet to send */
		msg = (backip_msg_t *)(call Packet.getPayload(&pkt, sizeof(backip_msg_t)));
		if(call Packet.maxPayloadLength() < sizeof(backip_msg_t)) {
			printf("[%d] Send size exceeded: %d\n", TOS_NODE_ID, sizeof(backip_msg_t));
		}

		msg->sender = qmsg->sender;
		msg->ctr = qmsg->ctr;
		msg->recv_time = qmsg->recv_time;
		msg->delay = qmsg->delay;

		if((ret = call AMSend.send(AM_BROADCAST_ADDR, &pkt,
						sizeof(backip_msg_t))) != SUCCESS) {
			sending_stats = FALSE;
			call StatsTimer.startOneShot(10);
		}
	}

	event void StatsTimer.fired()
	{
		post sendStatsTask();
	}

	event void AMSend.sendDone(message_t *bufPtr, error_t error)
	{
		backip_msg_t *m;
		sending_stats = FALSE;
		if(error != SUCCESS) {
			call StatsTimer.startOneShot(10);
			return;
		}
		/* Done sending so get it out of the queue */
		m = call SendQ.dequeue();
		call MsgPool.put(m);

		if(!(call SendQ.empty())) {
			call StatsTimer.startOneShot(10);
		}
	}

	event message_t* Receive.receive(message_t* bufPtr,
			void* payload, uint8_t len)
	{
		if(SENDER_EXPR) {
#if POISSON
			call SendTimer.startOneShot(call Random.rand32());
#else
			call SendTimer.startPeriodic(INTER_PKT_TIME);
#endif
		}
		return bufPtr;
	}

	event void Control.startDone(error_t err)	{}
	event void Control.stopDone(error_t err) {}
#endif //STATS

	event void PerfTimer.fired() {
		printf("Recvd: %d\n", pkts_recvd);
		pkts_recvd = 0;
	}
	event void SendTimer.fired() {
		int ret;
		backip_msg_t *m;
		if(SENDER_EXPR) {
			/*if(ctr - (TOS_NODE_ID * 1000)> MAX_PKTS) {
				return;
			}*/
			//memset(buf, 0xfa, BUFLEN);
			buf[0] = (ctr & 0xff000000) >> 24;
			buf[1] = (ctr & 0xff0000) >> 16;
			buf[2] = (ctr & 0xff00) >> 8;
			buf[3] = (ctr & 0xff);

			route_dest.sin6_port = htons(7000);
			inet_pton6(DEST_ADDR, &route_dest.sin6_addr);
			dbg("UDP_BCP_BLIP", "%i sending a packet [%u] to %s\n", TOS_NODE_ID, ctr, DEST_ADDR);
			ctr++;
			printf("[%i] sending a packet [%u] to %s\n", TOS_NODE_ID, ctr, DEST_ADDR);

			while(1) {
				ret = call Status.sendto(&route_dest, &buf, BUFLEN);

				if(ret == SUCCESS) {
					dbg("UDP_BCP_BLIP", "Sending packet success\n");
					//call CC2420Stat.incr_txsend();
					break;
				} else if (ret == ERETRY) {
					dbg("UDP_BCP_BLIP", "retrying...\n");
					break; //continue;
				} else {
					dbg("UDP_BCP_BLIP", "DROP>>Sending packet failed\n");
					break;
				}
				//printfflush();

			}
			call Leds.led0Toggle();

#if POISSON
			call SendTimer.startOneShot(call Random.rand32());
#endif
#if TOSSIM || MOTES
			if(first_timer) {
				first_timer = FALSE;
				call SendTimer.stop();
				call SendTimer.startPeriodic(dt);
			}
#endif
#if STATS
			m = call MsgPool.get();
			if(m != NULL) {
				m->sender = TOS_NODE_ID;
				m->ctr = ctr - 1;
				atomic call SendQ.enqueue(m);
				post sendStatsTask();
			}
#endif
		}
		return;
	}

#if BACKIP_ROUTING
	event void BackIPFlag.flagPacket(uint32_t pkt_id)
	{
		dbg("UDP_BCP_BLIP", "Packet flagged %08x\n", pkt_id);
	}
#endif
}
