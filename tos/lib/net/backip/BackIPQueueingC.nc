/**
 * This is an implementation of Backpressure based routing over BLIP,
 * based on the concepts in the Backpressure collection protocol
 *
 * @author Srikanth Nori <snori@usc.edu>
 */

#include "BackIP.h"

configuration BackIPQueueingC {
	provides {
		interface Send;
		interface Receive;
		interface BeaconQueueInterface;
		interface BackIPFlag;
		interface PacketLink as FakePacketLink;
	}
	uses {
		interface BackIPLinkResultInterface;
		interface PacketGen;
	}
} implementation {
	components CC2420RadioC as MessageC;
	components BackIPQueueingP;
	components new PoolC(message_t, FORWARDING_QUEUE_SIZE) as MessagePoolP;
	components new PoolC(fe_queue_entry_t, FORWARDING_QUEUE_SIZE) as QEntryPoolP;
	components new StackC(fe_queue_entry_t *, FORWARDING_QUEUE_SIZE) as SendStackP;
	components new TimerMilliC() as txRetryTimer;
	components new TimerMilliC() as PacketDelayTimer;
	components IPStackC;

	BackIPQueueingP.txRetryTimer -> txRetryTimer;
	BackIPQueueingP.PacketDelayTimer -> PacketDelayTimer;
	Send = BackIPQueueingP;
	Receive = BackIPQueueingP;
	BeaconQueueInterface = BackIPQueueingP;
	BackIPFlag = BackIPQueueingP;
	BackIPLinkResultInterface = BackIPQueueingP;
	PacketGen = BackIPQueueingP;
	FakePacketLink = BackIPQueueingP;
	BackIPQueueingP.SubSend -> MessageC.BareSend;
	BackIPQueueingP.SubReceive -> MessageC.BareReceive;
	BackIPQueueingP.SubPacket -> MessageC.BarePacket;
	BackIPQueueingP.MessagePool -> MessagePoolP;
	BackIPQueueingP.QEntryPool -> QEntryPoolP;
	BackIPQueueingP.SendStack -> SendStackP;
	BackIPQueueingP.PacketLink -> MessageC;
	IPStackC.RoutingControl -> BackIPQueueingP.StdControl;

	components LocalTimeMilliC;
	BackIPQueueingP.LocalTime -> LocalTimeMilliC;
}
