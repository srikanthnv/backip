#! /usr/bin/python
from TOSSIM import *
import sys

t = Tossim([])
r = t.radio()
f = open("topo.txt", "r")

for line in f:
  s = line.split()
  if s:
    print " ", s[0], " ", s[1], " ", s[2];
    r.add(int(s[0]), int(s[1]), float(s[2]))

t.addChannel("EasyCollection", sys.stdout)
#t.addChannel("Boot", sys.stdout)
#t.addChannel("Routing", sys.stdout)
#t.addChannel("Forwarder", sys.stdout)
#t.addChannel("ERROR",sys.stdout)

#t.addChannel("AMQueueEntryP",sys.stdout)
#t.addChannel("AMQueue",sys.stdout)
#t.addChannel("AMQueueImpl", sys.stdout)
#t.addChannel("AM",sys.stdout)
#t.addChannel("UniqueSend",sys.stdout)
#t.addChannel("Csma", sys.stdout)
#t.addChannel("Beacon", sys.stdout)
#t.addChannel("BCP", sys.stdout)

#t.addChannel("TossimPacketModelC", sys.stdout)
#t.addChannel("CC2420TinyosNetworkP", sys.stdout)

#t.addChannel("AM", sys.stdout)
#t.addChannel("UniqueSend", sys.stdout)
#t.addChannel("CC2420TinyosNetworkP", sys.stdout)
#t.addChannel("Csma", sys.stdout)
#t.addChannel("Lplc", sys.stdout)
#t.addChannel("PacketLink", sys.stdout)
#t.addChannel("CC2420PacketP", sys.stdout)
#t.addChannel("CC2420ReceiveP", sys.stdout)

noise = open("meyer-heavy.txt", "r")
for line in noise:
  str1 = line.strip()
  if str1:
    val = int(str1)
    for i in range(1, 5):
      t.getNode(i).addNoiseTraceReading(val)

for i in range(1, 5):
  print "Creating noise model for ",i;
  t.getNode(i).createNoiseModel()

for i in range(1, 5):
  print "Booting ", i, " at time ",(100000 + i*1000);
  t.getNode(i).bootAtTime(100000 + i*1000);

for i in range(10000000):
  t.runNextEvent()

