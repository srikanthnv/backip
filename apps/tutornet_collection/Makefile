COMPONENT=tutornet_collectionAppC
APPSDIR=$(TOSROOT)/apps
TOSDIR=$(TOSROOT)/tos
#CFLAGS += -I$(TOSDIR)/lib/net -I$(TOSDIR)/lib/net/4bitle -I../bcp_org \
#	-I$(TOSDIR)/lib/net/ctp -I$(TOSDIR)/lib/ftsp
CFLAGS += -I$(TOSDIR)/lib/net -I$(TOSDIR)/lib/net/4bitle -I$(TOSDIR)/lib/net/bcp \
	-I$(TOSDIR)/lib/net/ctp -I$(TOSDIR)/lib/ftsp
#CFLAGS += -I$(TOSDIR)/lib/net -I$(TOSDIR)/lib/net/4bitle -I../bcp \
#	-I$(TOSDIR)/lib/net/ctp -I$(TOSDIR)/lib/ftsp
CFLAGS +="-DCC2420_DEF_CHANNEL=26"
CFLAGS +="-DCC2420_DEF_RFPOWER=5"
# uncomment below for BCP
CFLAGS +="-DCC2420_NO_ADDRESS_RECOGNITION"
CFLAGS +="-DTOS_FOOTER_LEN=0"
CFLAGS +="-DVIRTQ"
CFLAGS +="-DLIFO"
#CFLAGS +="-DBEACON_ONLY"
#CFLAGS +="-DLOW_POWER_LISTENING"
#CFLAGS +="-DLPL_SLEEP_INTERVAL_MS=800"
#CFLAGS +="-DMEAN_ADMIT_TIME=666"

C_CODE = ./c

BUILD_EXTRA_DEPS = $(C_CODE)/UartPacket.h $(C_CODE)/uartPacketSend/UartPacket.h

CLEAN_EXTRA = $(BUILD_EXTRA_DEPS)

$(C_CODE)/UartPacket.h:tutornet_collection.h
	mig c -target=$(PLATFORM) $(CFLAGS) -c-prefix=UartPacket tutornet_collection.h UartPacket -o $@

$(C_CODE)/uartPacketSend/UartPacket.h:tutornet_collection.h
	mig c -target=$(PLATFORM) $(CFLAGS) -c-prefix=UartPacket tutornet_collection.h UartPacket -o $@

include $(MAKERULES)
