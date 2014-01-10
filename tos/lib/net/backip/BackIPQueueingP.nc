/**
 * This is an implementation of Backpressure based routing over BLIP,
 * based on the concepts in the Backpressure collection protocol
 *
 * @author Srikanth Nori <snori@usc.edu>
 */

#include "BackIPShared.h"
module BackIPQueueingP {
	provides {
		interface Send;
		interface Receive;
		interface BeaconQueueInterface;
		interface StdControl;
		interface BackIPFlag;
		interface PacketLink as FakePacketLink;
	}
	uses {
		interface Send as SubSend;
		interface Receive as SubReceive;
		interface Packet as SubPacket;
		interface Pool<message_t> as MessagePool;
		interface Pool<fe_queue_entry_t> as QEntryPool;
		interface Stack<fe_queue_entry_t *> as SendStack;
		interface Timer<TMilli> as txRetryTimer;
		interface Timer<TMilli> as PacketDelayTimer;
		interface BackIPLinkResultInterface;
		interface PacketGen;
		interface PacketLink;
		interface LocalTime <TMilli>;
	}
} implementation {

#if DELAY
#define DELAY_TABLE_SIZE (FORWARDING_QUEUE_SIZE + 2)
#define PER_HOP_DELAY 10 //ms
	struct {
		uint32_t seq;
		uint32_t time_in;
		uint32_t occupied;
	} delaytable[DELAY_TABLE_SIZE];
#endif

	/* Not configuration params */
	bool sending_beacon = FALSE;
	uint8_t sending_data = 0;
	bool radioBusy = FALSE;
	uint8_t suppress_sendDone = FALSE;
	send_stats_t send_stats = {0};

	/* The current 'good' backpressure neighbour */
	ll_addr_t curr_nb_ll_addr;

	/* Only one packet can be actively 'under send' at any time - this is that */
	fe_queue_entry_t *current_send_qe;

	/*  from BCP 'The virtual queue preserves backpressure values through
	 *  stack drop events.  This preserves performance of
	 *  BCP.  If a forwarding event occurs while the data stack
	 *  is empty, a null packet is generated from this virtual
	 *  queue backlog.'
	 */
	uint16_t virtualQueueSize = 0;

	/* Keep track of the last BP of mine that was signalled to neighbours */
	static int32_t my_last_bp = 0;

	command error_t StdControl.start()
	{
		radioBusy = FALSE;
		sending_beacon = FALSE;
		suppress_sendDone = FALSE;
		virtualQueueSize = 0;
		memset(&send_stats, 0, sizeof(send_stats));
#if DELAY
		memset(&delaytable, 0, sizeof(delaytable));
#endif
		return SUCCESS;
	}

	command error_t StdControl.stop()
	{
		radioBusy = FALSE;
		call txRetryTimer.stop();
		return SUCCESS;
	}

	/* Set the current neighbour */
	command void BeaconQueueInterface.setNeighbour(ll_addr_t *nb_ll)
	{
		atomic {
			memcpy(&curr_nb_ll_addr, nb_ll, sizeof(ll_addr_t));
		}
	}

	/* Rewrite address on outgoing packets */
	void rewrite_dst_ll_addr(message_t *msg)
	{
		uint8_t *buf;
		atomic {
			buf = call SubSend.getPayload(msg, 0);
			buf += IEEE154_MIN_HDR_SZ;
			if (curr_nb_ll_addr.ieee_mode == IEEE154_ADDR_SHORT) {
				uint16_t tmpval = (curr_nb_ll_addr.i_saddr);
				memcpy(buf, &tmpval, 2);
			} else {
				memcpy(buf, &(curr_nb_ll_addr.i_laddr), 8);
			}
		}
		//printf("Sending to: "); printf_ieee154addr(&curr_nb_ll_addr); printf("\n"); printfflush();
	}

	/* Make space in a full stack */
	void conditionalDiscard()
	{
		fe_queue_entry_t* discardQe;
		//uint8_t *pl = (uint8_t *)(discardQe->msg) + 27;
		//uint32_t tmp;
		//tmp = pl[0]<<24 | pl[1]<<16 | pl[2]<<8 | pl[3];
		atomic {
			while(call SendStack.size() >= call SendStack.maxSize()) {
				//printf("[%d] Popping stack\n", TOS_NODE_ID);
				dbg("DROP", "DROP>>Discard\n");
				discardQe = call SendStack.popBottom();
				if(discardQe == NULL) {
				}
				if((call MessagePool.put(discardQe->msg)!= SUCCESS )) {
				}
				if((call QEntryPool.put(discardQe)) != SUCCESS) {
				}
				send_stats.stat_dropped_cond++;
				virtualQueueSize++;
			}
		}
	}

	inline uint32_t _get_bp()
	{
		atomic {
			return call SendStack.size() + virtualQueueSize + sending_data;
		}
	}

	/* See if backpressure has varied significantly */
	void check_bp()
	{
		int now_bp = _get_bp();
		int diff = abs(now_bp - my_last_bp);
		//printf("[%d] BP Diff: last:%d now:%d diff:%d thresh:%d\n", TOS_NODE_ID,
		//my_last_bp, now_bp, diff, BP_DIFF_THRESH );
		dbg("BackIPQueueing", "BP Diff: %u %u %u %d\n",
				my_last_bp, now_bp, diff, BP_DIFF_THRESH );
		if(diff >= BP_DIFF_THRESH) {
			//printf("[%d] Signaling\n", TOS_NODE_ID);
			dbg("BackIPQueueing", "Signaling\n", TOS_NODE_ID);
			call BackIPLinkResultInterface.drasticBackpressureChange();
		}
	}

	/* Data sender */
	task void sendDataTask()
	{
		uint8_t len;
		int8_t retval;
		error_t err;

		dbg("BackIPQueueing", "sendDataTask fired\n");

		/* If I'm still sending the previous message, try again later */
		if(radioBusy) {
			dbg("BackIPQueueing", "radioBusy, trying later 1\n");
			call txRetryTimer.startOneShot(RETRY_INTERVAL);
			return;
		}

#if ADAPTIVE_BEACONING
		/* Check if a beacon has to be sent */
		check_bp();
#endif

		/* Nothing to send */
		if(call SendStack.empty() && virtualQueueSize <= 0 ) {
			dbg("BackIPQueueing", "sendDataTask nothing to send! Panic! This is impossible!\n");
			return;
		}

		/* Check if a good neighbour exists */
		atomic {
			retval = call BackIPLinkResultInterface.updateNeighbour();
		}

		if(0 != retval) {
			/* No good neighbour exists */
			call txRetryTimer.startOneShot(REROUTE_INTERVAL);
			dbg("BackIPQueueing", "sendDataTask: no good neighbour right now\n");
			//printf("[%d] sendDataTask: no good neighbour right now\n", TOS_NODE_ID); printfflush();
			return;
		}

		/* -- We definitely have something to send, and someone to send it to -- */

		/* Free up space in the queue if needed */
		conditionalDiscard();

		/* 'lock' the radio */
		radioBusy = TRUE;

		/*
		 * We have 2 options here:
		 *  - Send a data packet if it's available
		 *  - Send a null packet otherwise
		 */

		/* Data packets available */
		if(!(call SendStack.empty())) {
			/* Get a message from the top of the stack */
			atomic {
				current_send_qe = call SendStack.popTop();
			}
			len = call SubPacket.payloadLength(current_send_qe->msg);
			dbg("BackIPQueueing", ">>sendDataTask sending packet of size %d retx %d\n", len, current_send_qe->tx_count);

			/* Check if we've already sent this too many times */
			if(current_send_qe->tx_count >= MAX_RETX_ATTEMPTS)
			{
				dbg("BackIPQueueing", ">>sendDataTask: Too many retransmits\n");
				//printf("Too many retransmits, penalizing "); printf_ieee154addr(&curr_nb_ll_addr); printf("\n"); printfflush();

				send_stats.stat_dropped_fail++;

				/* Remove the 'under send' data packet from BP calculations */
				sending_data = 0;

				/* Penalize by 2X */
				call BackIPLinkResultInterface.updateETX(&curr_nb_ll_addr, 2*MAX_RETX_ATTEMPTS);

				//Push it back to the top of the stack and restart
				conditionalDiscard();
				current_send_qe->tx_count = 0;
				atomic {
					if((call SendStack.pushTop(current_send_qe)) != SUCCESS) {
						dbg("BackIPQueueing", ">>sendDataTask: failed to restore ETX-expired packet into queue\n");
					}
				}

				radioBusy = FALSE;

				/* Retry later */
				dbg("Debug", "retry giving up on packet\n");
				call txRetryTimer.startOneShot(REROUTE_INTERVAL);
				return;
			}

			/* Send out the message, but since this is data, no need to signal
			 * sendDone to the parent, that's already done
			 */
			suppress_sendDone = TRUE;

			/* Update this packet to send it to the current best neighbour */
			rewrite_dst_ll_addr(current_send_qe->msg);

			/* Increment tx_count for this packet */
			current_send_qe->tx_count++;

			/* So one packet is 'under send' right now. This should also count
			 * for backpressure calculation. So remember this fact! */
			sending_data = 1;

			/* Hand off packet to Bare for transmission */
			dbg("BackIPQueueing", ">>sending packet %X\n", current_send_qe->msg);
			call PacketLink.setRetries(current_send_qe->msg, 2);
			call PacketLink.setRetryDelay(current_send_qe->msg, 50);
#if DELAY
			atomic {
				uint32_t seq;
				uint8_t xlen;
				uint32_t time_spent = 0, time_diff = 0;
				uint8_t i;
				uint8_t *payload = call SubSend.getPayload(current_send_qe->msg, 0);
				xlen = call SubPacket.payloadLength(current_send_qe->msg);
				seq = ((uint32_t)(payload[xlen - 8]) << 24) | ((uint32_t)(payload[xlen - 7]) << 16) | 
					((uint32_t)(payload[xlen - 6]) << 8) | (payload[xlen - 5]);
				/*for(i = 0; i < xlen; i++) {
					printf("%02x", payload[i]);
				}
				printf("\n");*/
				printf("seq %d\n",seq);
				/*printf("addr1 %d\n",(uint32_t)payload);
				printf("addr2 %d\n",(uint32_t)payload + xlen - 8);*/
				//printf("Sending seq %u xlen %u ptr %x offset %x\n", seq, xlen, payload, payload + xlen - 4);
				for(i = 0; i < DELAY_TABLE_SIZE; i++) {
					if(delaytable[i].occupied && delaytable[i].seq == seq) {
						//printf("Found %d\n", seq);
						break;
					}
				}
				if(i < DELAY_TABLE_SIZE) {
					delaytable[i].occupied = FALSE;
					time_diff = (call LocalTime.get()) - delaytable[i].time_in;
					time_spent = ((uint32_t)(payload[xlen - 4]) << 24) | ((uint32_t)(payload[xlen - 3]) << 16) |
						((uint32_t)(payload[xlen - 2]) << 8) | (payload[xlen - 1]);
					printf("Spent: %u Diff %u\n", time_spent, time_diff);
					time_spent += time_diff;
				}
				time_spent += PER_HOP_DELAY;
				printf("New time %u\n", time_spent);
				//write_4B(payload + xlen - 4, time_spent);
				payload[xlen - 4] = ((time_spent & 0xff000000) >> 24);
				payload[xlen - 3] = ((time_spent & 0xff0000) >> 16);
				payload[xlen - 2] = ((time_spent & 0xff00) >> 8);
				payload[xlen - 1] = ((time_spent & 0xff));
				//printfflush();
			}

#endif
			err = call SubSend.send(current_send_qe->msg, len);
			if(err != SUCCESS) {
				//Send has failed - local sender is busy. Don't penalize the neighbor.
				//Also, retry immediately if possible.
				current_send_qe->tx_count--;
				atomic {
					if((call SendStack.pushTop(current_send_qe)) != SUCCESS) {
					}
				}
				sending_data = 0;

				radioBusy = FALSE;

				/* Retry soon */
				dbg("Debug", "retry local send failed\n");
				call txRetryTimer.startOneShot(RETRY_INTERVAL);
				return;
			}

			/* No data, only virtual */
		} else {
			virtualQueueSize--;
			radioBusy = FALSE;
			//Generate a null packet;
			call PacketGen.sendNull();
			send_stats.stat_sent_null++;
		}
	}

	event void PacketDelayTimer.fired() {}

	event void txRetryTimer.fired()
	{
		post sendDataTask();
	}

	message_t *m_msgp = 0;

	task void signalDone()
	{
		signal Send.sendDone(m_msgp, SUCCESS);
	}

	command error_t Send.send(message_t *msg, uint8_t len)
	{
		message_t *newMsg;
		int retVal;
		fe_queue_entry_t *ins;

		dbg("BackIPQueueing", "Sending %x\n", msg);
		dbg("BackIPQueueing", "old retries: %d\n",
				((tossim_metadata_t *)(msg->metadata))->maxRetries);

		/* Check if this message is a beacon (flag set by calling
		 * SendingBeacon(). Beacons have to bypass queues.
		 */
		if(sending_beacon) {
			int ret = 0;
			if(radioBusy) {
				dbg("BackIPQueueing", "radioBusy, try later 2\n");
				sending_beacon = FALSE;
				return ERETRY;
			}
			radioBusy = TRUE;
			sending_beacon = FALSE;
			dbg("BackIPQueueing", ">>Bypassing queues for beacon.\n");

			/* Send out the message but since this is a beacon,
			 * let the lower layer signal sendDone
			 */
			suppress_sendDone = FALSE;
			ret = call SubSend.send(msg, len);

			/* track the last known backpressure that I beaconed */
			my_last_bp =_get_bp();
			return ret;
		}

		send_stats.stat_sent_total++;

		/* Not a beacon, just regular data, put it into the queue */
		/* Free up space in the queue if needed */
		conditionalDiscard();

		dbg("BackIPQueueing", "Enqueueing packet of size %d.\n", len);
		call SubPacket.setPayloadLength(msg, len);
		printf("Setting size %u\n", len); printfflush();

		if(call MessagePool.empty()) {
			dbg("DROP", "DROP>>client cannot enqueue, message pool empty. SS: %d MP:%d/%d\n", call SendStack.size(), call MessagePool.size(), call MessagePool.maxSize());
			//printf("[%d] fail1 \n", TOS_NODE_ID); printfflush();
			send_stats.stat_dropped_q++;
			return ERETRY;
		}
		newMsg = call MessagePool.get();
		if(NULL == newMsg) {
			dbg("DROP", "DROP>>client cannot enqueue, message pool get failed.\n");
			//printf("[%d] fail2 \n", TOS_NODE_ID); printfflush();
			send_stats.stat_dropped_q++;
			return ERETRY;
		}

		ins = call QEntryPool.get();
		if(ins == NULL) {
			//printf("[%d] fail3 \n", TOS_NODE_ID); printfflush();
			call MessagePool.put(newMsg);
			send_stats.stat_dropped_q++;
			dbg("DROP", "DROP>>client cannot enqueue, qentrypool.get failed.\n");
			return ERETRY;
		}
		dbg("BackIPQueueing", "Copying %d bytes\n", sizeof(message_t));
		memcpy(newMsg, msg, sizeof(message_t));
		dbg("BackIPQueueing", "old retries: %d, new retries: %d\n",
				((tossim_metadata_t *)(msg->metadata))->maxRetries,
				((tossim_metadata_t *)(newMsg->metadata))->maxRetries);
		ins->msg = newMsg;
		ins->tx_count = 0;
		ins->first_tx_time = call PacketDelayTimer.getNow();
		retVal = call SendStack.pushTop(ins);

		if(retVal != SUCCESS) {
			dbg("DROP", "DROP>>client failed to push packet to sendStack.\n");
			//printf("[%d] fail4 \n", TOS_NODE_ID); printfflush();
			send_stats.stat_dropped_q++;
			return ERETRY;
		}
		dbg("BackIPQueueing", ">>client queued packet %X\n", ins->msg);
		m_msgp = msg;
		post signalDone();
		//signal Send.sendDone(msg, SUCCESS);

		/* Schedule for sending */
		dbg("Debug", "Sending new packet\n");
		post sendDataTask();
		return SUCCESS;
	}

	command error_t Send.cancel(message_t *msg)
	{
		return call SubSend.cancel(msg);
	}

	command uint8_t Send.maxPayloadLength()
	{
		return call SubSend.maxPayloadLength();
	}

	command void * Send.getPayload(message_t *msg, uint8_t len)
	{
		return call SubSend.getPayload(msg, len);
	}

	event void SubSend.sendDone(message_t *msg, error_t error)
	{
		int ret = 0;
		//radioBusy = FALSE;

		if(suppress_sendDone) {
			/* send done is suppressed for data packets */

			if(!(call PacketLink.wasDelivered(msg))) {
				//if(error != SUCCESS) {

				/* Transmission failed, must retry. */
				dbg("Debug", "Failed\n");
				sending_data = 0;

				dbg("BackIPQueueing", "Send failed, retrying\n");
				//printf("Send failed, retrying\n"); printfflush();
				/* Push message back to retransmit */
				atomic {
					if(SUCCESS != (ret = call SendStack.pushTop(current_send_qe))) {
						dbg("DROP", "DROP>> WTF %d\n", ret);
					}
				}

				/* Retry immediately */
				dbg("Debug", "Retrying after sned failure\n");
				radioBusy = FALSE;
				post sendDataTask();
				return;
			} else {
				/* Transmission was succesful */
				uint32_t now_time;
				uint16_t tx_time;

				send_stats.stat_sent_success++;
				printf("Send success\n"); printfflush();

				/* Remove the 'under send' data packet from BP calculations */
				sending_data = 0;

				/* Update transmission time */
				now_time = call PacketDelayTimer.getNow();
				if(now_time - current_send_qe->first_tx_time > 0xFFFF) {
					tx_time = 0xFFFF;
				} else {
					tx_time = (uint16_t)(now_time - current_send_qe->first_tx_time);
				}

				atomic {
					dbg("BackIPQueueing", "Send succeeded, update ETX\n");
					call BackIPLinkResultInterface.updateETX(&curr_nb_ll_addr,
							current_send_qe->tx_count);

					dbg("BackIPQueueing", "Send succeeded, update link rate\n");
					call BackIPLinkResultInterface.updateLinkRate(&curr_nb_ll_addr,
							tx_time);
				}
			}

			/* Return the message to the pool for reuse */
			call MessagePool.put(current_send_qe->msg);
			call QEntryPool.put(current_send_qe);

			//dbg("BackIPQueueing", ">>Suppressing sendDone\n");
			suppress_sendDone = FALSE;
			radioBusy = FALSE;
			} else {

				/* send done is not suppressed for beacons */
				//dbg("BackIPQueueing", ">>Releasing sendDone\n");
				signal Send.sendDone(msg, error);
				radioBusy = FALSE;
			}

			/* In either case, send data if it is available */
			if(call SendStack.size() > 0 || virtualQueueSize > 0) {
				dbg("Debug", "more data exists %d %d\n", call SendStack.size(), virtualQueueSize);
				post sendDataTask();
			}
			return;
		}


		bool is_flag_set = FALSE;
		uint32_t pkt_flag = 0;

		command void BackIPFlag.setFlag(uint32_t flag)
		{
			is_flag_set = TRUE;
			pkt_flag = flag;
		}

		command void BackIPFlag.clearFlag()
		{
			is_flag_set = FALSE;
		}

		event message_t *SubReceive.receive(message_t *msg, void *payload, uint8_t len)
		{
			dbg("BackIPQueueing", "Received at BackIPQueueing layer\n");
			send_stats.stat_recvd_total ++;
#if DELAY
			atomic {
				int i;
				uint8_t xlen = call SubPacket.payloadLength(msg);
				printf("Received pkt of len %d\n", xlen);

				if(xlen== 40) {
					//find free slot
					for(i = 0; i < DELAY_TABLE_SIZE; i++) {
						if(delaytable[i].occupied == FALSE)
							break;
					}
					//if found
					if(i < DELAY_TABLE_SIZE) {
						uint8_t *pl = payload;
						//read_4B(&(delaytable[i].seq), ((uint32_t)payload) + (xlen - 8));
						delaytable[i].seq = ((uint32_t)(pl[xlen - 8]) << 24) | ((uint32_t)(pl[xlen - 7]) << 16) |
							((uint32_t)(pl[xlen - 6]) << 8) | (pl[xlen - 5]);
						printf("Stored %d\n", delaytable[i].seq);
						delaytable[i].time_in = call LocalTime.get();
						delaytable[i].occupied = TRUE;
					}
				}
			}
#endif
			printf("Signaling\n");
			signal Receive.receive(msg, payload, len);
			return msg;
		}

		command void BeaconQueueInterface.SendingBeacon()
		{
			sending_beacon = TRUE;
		}

		command uint32_t BeaconQueueInterface.GetBackpressure()
		{
			return _get_bp();
		}

		command uint32_t BeaconQueueInterface.GetLastBackpressure()
		{
			return my_last_bp;
		}

		command uint32_t BeaconQueueInterface.GetSendStats(send_stats_t *st)
		{
			memcpy(st, &send_stats, sizeof(send_stats_t));
			return 0;
		}
		command void FakePacketLink.setRetries(message_t *msg, uint16_t maxRetries)
		{
			call PacketLink.setRetries(msg, maxRetries);
		}
		command void FakePacketLink.setRetryDelay(message_t *msg, uint16_t retryDelay)
		{
			call PacketLink.setRetryDelay(msg, retryDelay);
		}
		command uint16_t FakePacketLink.getRetries(message_t *msg)
		{
			return call PacketLink.getRetries(msg);
		}
		command uint16_t FakePacketLink.getRetryDelay(message_t *msg)
		{
			return call PacketLink.getRetryDelay(msg);
		}
		command bool FakePacketLink.wasDelivered(message_t *msg)
		{
			return TRUE;
		}

	}

