#include "tutornet_collection.h"

configuration tutornet_collectionAppC{
}

implementation{
	components tutornet_collectionC, MainC, LedsC, ActiveMessageC;

#ifdef LOW_POWER_LISTENING
#ifndef TOSSIM
	components CC2420CsmaC as CsmaC;
	components CC2420ActiveMessageC as RadioMsg;
#endif
#endif

#if PROTO_BCP
	components BcpC;
#else
	components CtpP;
	components new CollectionSenderC(0x0);
#endif
	components new exponentialRandomC(MEAN_PACKET_DELAY) as RandomC;
	components new TimerMilliC();
	components new TimerMilliC() as logTimer;
	components new TimerMilliC() as sinkTimer;
	components new SafeSerialSendC(UART_QUEUE_SIZE, AM_UARTPACKET) as SafeSerialSend;

#ifdef LOW_POWER_LISTENING
#ifndef TOSSIM
	components CC2420ActiveMessageC as LPLProvider;
#endif
#endif

	//  components new AMReceiverC(BEACON_PROTOCOL) as BeaconReceiver;

	tutornet_collectionC.Boot             -> MainC.Boot;
	tutornet_collectionC.RadioControl     -> ActiveMessageC.SplitControl;
	tutornet_collectionC.Leds             -> LedsC.Leds;
	tutornet_collectionC.Timer            -> TimerMilliC.Timer;
	//tutornet_collectionC.sinkTimer        -> sinkTimer.Timer;
	tutornet_collectionC.logTimer        -> logTimer.Timer;

#if PROTO_BCP
	BcpC.BcpDebugIF           -> tutornet_collectionC.BcpDebugIF;
	tutornet_collectionC.ProtoControl     -> BcpC.StdControl;
	tutornet_collectionC.RootControl      -> BcpC.RootControl;
	tutornet_collectionC.Receive          -> BcpC.Receive;
	//  tutornet_collectionC.BeaconReceive    -> BeaconReceiver;
	tutornet_collectionC.Send             -> BcpC.Send;

	// Packet formation interfaces
	tutornet_collectionC.Packet           -> BcpC.Packet;
	tutornet_collectionC.BcpPacket        -> BcpC.BcpPacket;
#else
	CtpP.CollectionDebug      -> tutornet_collectionC.CollectionDebug;

	tutornet_collectionC.ProtoControl     -> CtpP.StdControl;
	tutornet_collectionC.RootControl      -> CtpP.RootControl;
	tutornet_collectionC.Receive          -> CtpP.Receive[0x0];
	//  tutornet_collectionC.BeaconReceive    -> BeaconReceiver;
	tutornet_collectionC.Send             -> CollectionSenderC.Send;

	// Packet formation interfaces
	tutornet_collectionC.Packet           -> CollectionSenderC.Packet;
	tutornet_collectionC.CtpPacket        -> CtpP.CtpPacket;
	tutornet_collectionC.DataSnoop        -> CtpP.Snoop[0x0];
#endif

	tutornet_collectionC.Random           -> RandomC; 
	tutornet_collectionC.SafeSerialSendIF -> SafeSerialSend.SafeSerialSendIF;
	tutornet_collectionC.UartReceive      -> SafeSerialSend.UartReceive;
	tutornet_collectionC.SerialControl    -> SafeSerialSend.StdControl;
	tutornet_collectionC.AMPacket         -> ActiveMessageC.AMPacket;

#ifdef LOW_POWER_LISTENING
#ifndef TOSSIM
	tutornet_collectionC.LPL              -> LPLProvider;
	tutornet_collectionC.csmaControl      -> CsmaC;
#endif
	tutornet_collectionC                  -> RadioMsg.CC2420Packet;
#endif

}
