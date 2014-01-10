for mote in `motelist -c | awk -F',' '{print $2}'`
do
s="serial@"$mote":telosb"
l="log_"`basename $mote`
java net.tinyos.tools.PrintfClient -comm $s > $l &
done

