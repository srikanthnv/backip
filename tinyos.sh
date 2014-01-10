#! /usr/bin/env bash
echo "Setting up for TinyOS 2.1.2"
export TOSROOT=
export TOSDIR=
export MAKERULES=

TOSROOT="/opt/tinyos-2.1.2"
TOSDIR="$TOSROOT/tos"
CLASSPATH=$CLASSPATH:$TOSROOT/support/sdk/java/tinyos.jar:$TOSROOT/apps/UDP_BCP_BLIP/commons-cli-1.2.jar
MAKERULES="$TOSROOT/support/make/Makerules"

export TOSROOT
export TOSDIR
export CLASSPATH
export MAKERULES

