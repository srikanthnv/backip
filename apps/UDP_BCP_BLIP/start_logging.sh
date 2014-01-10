#!/bin/bash -ve

#Start the root
#java BackIPStats -comm sf@testbed.usc.edu:10008 -cmd 100 >& logs/mote8.log &
#
##wait for network to stabilize
#sleep 3
#
##Start senders
#leaf=()
#for i in {8..15}
#do
#if [ $i -ne 8 ]
#then
#leaf+=($i)
#fi
#done
#
##for i in {8..56}
#for i in "${leaf[@]}"
#do
#	x=$((10000+$i))
#	echo "Starting $x"
#	java BackIPStats -comm sf@testbed.usc.edu:$x -cmd 100 > logs/mote$i.log &
#	sleep 2
#done
#
#for i in {8..56}
#tmake -n -b 115200 -f ./main.ihex -a 10 10
#sleep 30

#for i in 8 9 11 12
#do
#tmake -n -b 115200 -f ./main.ihex -a $i $i
#sleep 1
#done

java BackIPStats -comm sf@testbed.usc.edu:10018 >& logs/mote18.log &
sleep 10
leaf=()

for i in {17..8}
do
leaf+=($i)
done

for i in {19..48}
do
if [ $i -ne 18 ]
then
leaf+=($i)
fi
done

for i in "${leaf[@]}"
do
x=$((10000+$i))
#echo "Starting $x"
java BackIPStats -comm sf@testbed.usc.edu:$x > logs/mote$i.log &
sleep 10
done

