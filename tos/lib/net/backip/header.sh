set -f
X="/**\n * This is an implementation of Backpressure based routing over BLIP,\n * based on the concepts in the Backpressure collection protocol\n *\n * @author Srikanth Nori <snori@usc.edu>\n */\n"
#echo $X
sed -i "1 i$X" $1
