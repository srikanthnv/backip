#!/bin/bash

java net.tinyos.sim.LinkLayerModel cfg_20random
./gen_dot.py topology.out topo.dot
dot -Kneato -n -Tpng topo.dot -o topo.png
