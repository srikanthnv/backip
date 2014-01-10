COMPONENT=EasyCollectionAppC
CFLAGS += -DCC2420_NO_ADDRESS_RECOGNITION=1
CFLAGS += -I$(TOSDIR)/lib/net \
          -I$(TOSDIR)/lib/net/le \
          -I$(TOSDIR)/lib/net/bcp \
	-I$(TOSDIR)/lib/printf/ -DNEW_PRINTF_SEMANTICS

PFLAGS += -fnesc-separator=__ 
include $(MAKERULES)

