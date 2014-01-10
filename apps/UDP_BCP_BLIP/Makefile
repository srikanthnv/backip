COMPONENT=UDP_BCP_BLIPC
# uncomment this for network programming support
# BOOTLOADER=tosboot

# radio options
CFLAGS += -DCC2420_DEF_CHANNEL=26
# CFLAGS += -DRF230_DEF_CHANNEL=26
#CFLAGS += -DCC2420_DEF_RFPOWER=5
CFLAGS += -DCC2420_DEF_RFPOWER=3
#CFLAGS += -DCC2420_HW_ACKNOWLEDGEMENTS

# enable dma on the radio
# PFLAGS += -DENABLE_SPI0_DMA

# you can compile with or without a routing protocol... of course,
# without it, you will only be able to use link-local communication.
#PFLAGS += -DRPL_ROUTING -DRPL_STORING_MODE -I$(TOSDIR)/lib/net/rpl
#PFLAGS += -DRPL_OF_MRHOF
#PFLAGS += -DNEW_PRINTF_SEMANTICS -DPRINTFUART_ENABLED

PFLAGS += -DBACKIP_ROUTING -I$(TOSDIR)/lib/net/backip

PFLAGS += -DSTATS #Enable stats collection
#PFLAGS += -DMOTES #Enable autostart
PFLAGS += -DDELAY #Enable autostart

#Pick one of these three
#PFLAGS += -DSTATS_STOR #store stats onto flash
PFLAGS += -DSTATS_SFWD #stream stats live onto serial forwarder
#PFLAGS += -DSTATS_STOR_SFWD #send stored stats onto SF (STATS_STOR should be done first)

# tell the 6lowpan layer to not generate hc-compressed headers
# PFLAGS += -DLIB6LOWPAN_HC_VERSION=-1

# if this is set, motes will send debugging information to the address
# listed.  BLIP_STATS causes blip to record statistics.
# you can log this information using the util/Listener.py script
#PFLAGS += -DREPORT_DEST=\"fec0::100\" -DBLIP_STATS

# if you're using DHCP, set this to try and derive a 16-bit address
# from the IA received from the server.  This will work if the server
# gives out addresses from a /112 prefix.  If this is not set, blip
# will only use EUI64-based link addresses.  If not using DHCP, this
# causes blip to use TOS_NODE_ID as short address.  Otherwise the
# EUI will be used in either case.
PFLAGS += -DBLIP_DERIVE_SHORTADDRS
#PFLAGS += -DBLIP_STATS

# this disables dhcp and statically chooses a prefix.  the motes form
# their ipv6 address by combining this with TOS_NODE_ID
PFLAGS += -DIN6_PREFIX=\"fec0::\"

#Reading from serial forwarder
BUILD_EXTRA_DEPS += BackIPStats.class
CLEAN_EXTRA = *.class BackIPStatsMsg.java

BackIPStats.class: $(wildcard *.java) BackIPStatsMsg.java
	  javac -g -target 1.4 -source 1.4 *.java

BackIPStatsMsg.java:
	  mig java -target=null $(CFLAGS) -java-classname=BackIPStatsMsg backip_cmds.h backip_msg_t -o $@

include $(MAKERULES)

