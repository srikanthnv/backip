/**
 * This is an implementation of Backpressure based routing over BLIP,
 * based on the concepts in the Backpressure collection protocol
 *
 * @author Srikanth Nori <snori@usc.edu>
 */

/* Top-level component to provide BackIP layers */

configuration BackIPRoutingC {
	provides {
		interface StdControl;
		interface RootControl;
		interface Send as DataSend;
		interface Receive as DataReceive;
		interface BackIPStats;
		interface BackIPFlag;
		interface PacketLink as FakePacketLink;
	}
} implementation {
	components BackIPBeaconingC as Beacon;
	components BackIPQueueingC as Queue;
	components IPStackC;

	StdControl = Beacon;
	RootControl = Beacon;
	BackIPStats = Beacon;
	BackIPFlag = Queue;
	FakePacketLink = Queue;
	DataSend = Queue.Send;
	DataReceive = Queue.Receive;
	Beacon.BeaconQueueInterface -> Queue.BeaconQueueInterface;
	Queue.BackIPLinkResultInterface -> Beacon.BackIPLinkResultInterface;
	Queue.PacketGen -> Beacon.PacketGen;

	IPStackC.RoutingControl -> Beacon.StdControl;
}
