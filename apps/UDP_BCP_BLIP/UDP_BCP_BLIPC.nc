/**
 * This is an implementation of Backpressure based routing over BLIP,
 * based on the concepts in the Backpressure collection protocol
 *
 * @author Srikanth Nori <snori@usc.edu>
 */

#include <lib6lowpan/6lowpan.h>
#include "UDP_BCP_BLIP.h"
#include "backip_cmds.h"

configuration UDP_BCP_BLIPC {

} implementation {
	components MainC, LedsC;
	components UDP_BCP_BLIPP;

	UDP_BCP_BLIPP.Boot -> MainC;
	UDP_BCP_BLIPP.Leds -> LedsC;

	components new TimerMilliC() as SendT;
	UDP_BCP_BLIPP.SendTimer -> SendT;
	components IPStackC;

	UDP_BCP_BLIPP.RadioControl ->  IPStackC;
	components new UdpSocketC() as Echo,
						 new UdpSocketC() as Status;
	UDP_BCP_BLIPP.Echo -> Echo;

	UDP_BCP_BLIPP.Status -> Status;

	components new TimerMilliC() as PerfT;
	UDP_BCP_BLIPP.PerfTimer -> PerfT;

	components new exponentialRandomC(INTER_PKT_TIME) as RandomC;
	UDP_BCP_BLIPP.Random -> RandomC;

#ifdef RPL_ROUTING
	components RPLRoutingC;
	UDP_BCP_BLIPP.RootControl -> RPLRoutingC;
#endif

#ifdef BACKIP_ROUTING
	components BackIPRoutingC;
	UDP_BCP_BLIPP.RootControl -> BackIPRoutingC;
	UDP_BCP_BLIPP.BackIPStats -> BackIPRoutingC;
	UDP_BCP_BLIPP.BackIPFlag -> BackIPRoutingC;
#endif

#ifdef STATS
	components new TimerMilliC() as StatsT;
	UDP_BCP_BLIPP.StatsTimer -> StatsT;
	components SerialActiveMessageC as AM;
	UDP_BCP_BLIPP.Control -> AM;
	UDP_BCP_BLIPP.Receive -> AM.Receive[AM_BACKIP_MSG_T];
	UDP_BCP_BLIPP.AMSend  -> AM.AMSend[AM_BACKIP_MSG_T];
	UDP_BCP_BLIPP.Packet  -> AM;

	components new QueueC(backip_msg_t *, 10);
	UDP_BCP_BLIPP.SendQ -> QueueC.Queue;
	components new PoolC(backip_msg_t, 10);
	UDP_BCP_BLIPP.MsgPool -> PoolC.Pool;

	components LocalTimeMilliC;
	UDP_BCP_BLIPP.LocalTime -> LocalTimeMilliC;
#endif

	UDP_BCP_BLIPP.IPControl -> IPStackC;

#ifndef IN6_PREFIX
	components DhcpCmdC;
#endif

#ifdef PRINTFUART_ENABLED
	/* This component wires printf directly to the serial port, and does
	 * not use any framing.  You can view the output simply by tailing
	 * the serial device.  Unlike the old printfUART, this allows us to
	 * use PlatformSerialC to provide the serial driver.
	 *
	 * For instance:
	 * $ stty -F /dev/ttyUSB0 115200
	 * $ tail -f /dev/ttyUSB0
	 */
	//components SerialPrintfC;

	/* This is the alternative printf implementation which puts the
	 * output in framed tinyos serial messages.  This lets you operate
	 * alongside other users of the tinyos serial stack.
	 */
#if !TOSSIM
	components PrintfC;
	components SerialStartC;
#endif
#endif
}
