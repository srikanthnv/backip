x=8
for mote in `motelist -c | awk -F',' '{print $2}'`
do
make telosb blip reinstall.$x bsl,$mote 
x=$((x+1))
done
#make telosb blip reinstall.9 bsl,/dev/ttyUSB1 
#make telosb blip reinstall.10 bsl,/dev/ttyUSB2
