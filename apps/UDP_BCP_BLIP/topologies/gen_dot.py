#! /usr/bin/python
import sys

try:
	f = open(sys.argv[1], "r")
	o = open(sys.argv[2], "w")
except:
	print "Usage:",sys.argv[0]," topofile dot_filename"
	sys.exit(-1)

o.write('graph graphname {\n')
for line in f:
	s = line.split()
	x = str((float(s[1]))*10)
	y = str((float(s[2]))*10)
	o.write('\t'+s[0] + '[shape=circle,pos="' + x + ',' + y + '",width=.7,penwidth=3,fontsize=20]\n');
	print s, "*";
o.write('}')
