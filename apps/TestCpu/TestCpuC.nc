/**
 *
 * This application is used to test the basic functionality of the printf service.
 * Calls to the standard c-style printf command are made to print various strings
 * of text over the serial line.  Only upon calling printfflush() does the
 * data actually get sent out over the serial line.
 *
 * @author Kevin Klues (klueska@cs.wustl.edu)
 * @version $Revision: 1.11 $
 * @date $Date: 2010-06-29 22:07:25 $
 */

#include "printf.h"
#include "cmds.h"

module TestCpuC @safe() {
	uses {
		interface Boot;
		interface Timer<TMilli>;
		//interface Timer<TMilli> as Perf;
		interface SplitControl as Control;
		interface Receive;
		interface AMSend;
		interface Packet;
		interface Counter<TMilli, uint32_t>;
		interface Leds;

	}
}
implementation {

	uint8_t dummyVar1 = 123;
	uint16_t dummyVar2 = 12345;
	uint32_t dummyVar3 = 1234567890;

	event void Boot.booted() {
		call Control.start();
	}

	event void Control.startDone(error_t err) {
		call Timer.startPeriodic(1000);
		//call Perf.startPeriodic(1000);
	}

	async event void Counter.overflow() {}
	event void Control.stopDone(error_t err) {}

	//event void Perf.fired(){}

	task void PerfTask() {
		int i = 0, j = 0, k = 0;
		message_t pkt;
		msg_t *msg;
		msg = (msg_t *)(call Packet.getPayload(&pkt, sizeof(msg_t)));
		call Leds.led0Toggle();
		//msg->st = call Perf.getNow();
		msg->st = call Counter.get();
		for(i = 0; i < 100; i++)
			for(j = 0; j < 100; j++)
				for(k = 0; k < 100; k++)
					dummyVar3++;
		msg->ctr = dummyVar3;
		//msg->end = call Perf.getNow();
		msg->end = call Counter.get();
		msg->diff = msg->end - msg->st;
		call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(msg_t));
		//call Leds.led0Off();
		dummyVar3 = 0;
	}

	event void Timer.fired()
	{
		post PerfTask();
	}
	event void AMSend.sendDone(message_t *msg, error_t err) {}

	event message_t *Receive.receive(message_t *msg, void *payload, uint8_t len)
	{
		return msg;
	}
}
