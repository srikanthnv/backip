for i in {8..56}
do
port=$((10000+$i))
../uartPacketSend/startExperiment testbed.usc.edu $port &
done
