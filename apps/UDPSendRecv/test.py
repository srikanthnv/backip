#! /usr/bin/python
from TOSSIM import *
import sys

numnodes = 7
t = Tossim([])
r = t.radio()
f = open("topo.txt", "r")

for line in f:
  s = line.split()
  if s:
    print " ", s[0], " ", s[1], " ", s[2];
    r.add(int(s[0]), int(s[1]), float(s[2]))

t.addChannel("Boot", sys.stdout);
#t.addChannel("LedsC", sys.stdout);
#t.addChannel("IPForwardingEngineP", sys.stdout);
#t.addChannel("IPProtocols", sys.stdout);
#t.addChannel("ForwardingTable", sys.stdout);
#t.addChannel("RPL", sys.stdout);
#t.addChannel("IPNeighborDiscoveryP", sys.stdout);
t.addChannel("UDPSendRecv", sys.stdout);
#t.addChannel("UDP", sys.stdout);
#t.addChannel("UniqueSend", sys.stdout);
#t.addChannel("UniqueReceive", sys.stdout);
#t.addChannel("Csma", sys.stdout);
#t.addChannel("Drops", sys.stdout);
#t.addChannel("SendTask", sys.stdout);
#t.addChannel("CC2420TinyosNetworkP", sys.stdout);
#t.addChannel("IPDispatch", sys.stdout);
#t.addChannel("ICMP", sys.stdout);
#t.addChannel("Bare", sys.stdout);
#t.addChannel("IPPacket", sys.stdout);
#t.addChannel("TossimPacketModelC", sys.stdout);
#t.addChannel("CpmModelC", sys.stdout);

noise = open(sys.argv[1], "r")
#noise = open("meyer-heavy.txt", "r")
for line in noise:
  str1 = line.strip()
  if str1:
    val = int(str1)
    for i in range(1, numnodes + 1):
      t.getNode(i).addNoiseTraceReading(val)

for i in range(1, numnodes + 1):
  print "Creating noise model for ",i;
  t.getNode(i).createNoiseModel()

start_time = t.time();
for i in range(1, numnodes + 1):
  print "Booting node i at ",start_time + i*100;
  t.getNode(i).bootAtTime(start_time + i*100);

print "Starting simulation";
#for i in range(10000):
while True:
 # print "Iter ",i;
 # print "Sim time ",t.timeStr();
  t.runNextEvent();

