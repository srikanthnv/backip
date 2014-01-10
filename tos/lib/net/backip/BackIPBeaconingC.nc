/**
 * This is an implementation of Backpressure based routing over BLIP,
 * based on the concepts in the Backpressure collection protocol
 *
 * @author Srikanth Nori <snori@usc.edu>
 */

#include "BackIP.h"

configuration BackIPBeaconingC{
  provides {
    interface StdControl;
    interface RootControl;
    interface PacketGen;
    interface BackIPStats;
	interface BackIPLinkResultInterface;
  } uses {
    interface BeaconQueueInterface;
  }
} implementation{
  components BackIPBeaconingP as Beaconing;
  components new TimerMilliC() as BeaconTimer;
  components IPStackC, IPPacketC, IPNeighborDiscoveryC as NdC, IPAddressC;
  components new UdpSocketC() as UDPBeacon;
  components new UdpSocketC() as UDPNull;

  StdControl = Beaconing;
  RootControl = Beaconing;
  PacketGen = Beaconing;
  BackIPStats = Beaconing;
  BeaconQueueInterface = Beaconing;
  BackIPLinkResultInterface = Beaconing;

  Beaconing.BeaconTimer -> BeaconTimer;
  Beaconing.ForwardingTable -> IPStackC;
  Beaconing.ForwardingEvents -> IPStackC.ForwardingEvents[BACKIP_IFACE];
  Beaconing.UDPBeacon -> UDPBeacon;
  Beaconing.UDPNull -> UDPNull;
  Beaconing.IPPacket -> IPPacketC;
	Beaconing.ND -> NdC.NeighborDiscovery;
	Beaconing.IPAddress -> IPAddressC;
}
