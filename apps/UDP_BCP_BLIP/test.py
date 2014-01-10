#! /usr/bin/python
from TOSSIM import *
import sys

numnodes = int(sys.argv[1])
t = Tossim([])
r = t.radio()
f = open(sys.argv[2], "r")

for line in f:
  s = line.split()
  print s, "*";
  if s and s[0] == 'gain':
    #print " ", s[1], " ", s[2], " ", s[3], "*";
		r.add(int(s[1]), int(s[2]), float(s[3]))
  elif s and s[0] != 'noise':
    r.add(int(s[0]), int(s[1]), float(s[2]))

t.addChannel("Boot", sys.stdout);
#t.addChannel("BackIPBeaconing", sys.stdout);
#t.addChannel("BackIPQueueing", sys.stdout);
#t.addChannel("BackIPNT", sys.stdout);
#t.addChannel("BackIPFwdEvent", sys.stdout);
#t.addChannel("BackIPNull", sys.stdout);
#t.addChannel("BackIPBytes", sys.stdout);
#t.addChannel("Debug", sys.stdout);
#t.addChannel("RPLRoutingEngine", sys.stdout);
#t.addChannel("LedsC", sys.stdout);
#t.addChannel("IPForwardingEngineP", sys.stdout);
#t.addChannel("IPProtocols", sys.stdout);
#t.addChannel("ForwardingTable", sys.stdout);
#t.addChannel("RPL", sys.stdout);
#t.addChannel("IPNeighborDiscoveryP", sys.stdout);
t.addChannel("UDP_BCP_BLIP", sys.stdout);
#t.addChannel("AM", sys.stdout);
#t.addChannel("UniqueReceive", sys.stdout);
#t.addChannel("UDP", sys.stdout);
#t.addChannel("UniqueSend", sys.stdout);
#t.addChannel("Csma", sys.stdout);
#t.addChannel("PacketLink", sys.stdout);
#t.addChannel("Drops", sys.stdout);
t.addChannel("DROP", sys.stdout);
#t.addChannel("SendTask", sys.stdout);
#t.addChannel("CC2420TinyosNetworkP", sys.stdout);
#t.addChannel("IPDispatch", sys.stdout);
#t.addChannel("IPLower", sys.stdout);
#t.addChannel("ICMP", sys.stdout);
#t.addChannel("Bare", sys.stdout);
#t.addChannel("IPPacket", sys.stdout);
#t.addChannel("PacketLink", sys.stdout);
#t.addChannel("TossimPacketModelC", sys.stdout);
#t.addChannel("CpmModelC", sys.stdout);
#t.addChannel("Acks", sys.stdout);
print "Adding noise traces", sys.argv[3]
noise = open(sys.argv[3], "r")
#noise = open("meyer-heavy.txt", "r")
for line in noise:
  str1 = line.strip()
  if str1:
    val = int(str1)
    for i in range(numnodes):
      t.getNode(i).addNoiseTraceReading(val)

for i in range(numnodes):
  print "Creating noise model for ",i;
  t.getNode(i).createNoiseModel()

start_time = t.time();
l = range(numnodes)
l.remove(1)
t.getNode(1).bootAtTime(start_time + 100);
start_time += 5*10*1000*1000*1000
#start_time += 5*10*1000*1000*1000
for i in l:
	s = start_time + i*100
	#s = start_time + i*2*10*1000*1000*1000
	print "Booting node",i,"at ",s;
	t.getNode(i).bootAtTime(s);

print "Starting simulation";
#for i in range(10000):
while True:
	t.runNextEvent();

