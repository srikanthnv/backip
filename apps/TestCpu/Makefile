COMPONENT=TestCpuAppC
CFLAGS += -I$(TOSDIR)/lib/printf
CFLAGS += -DNEW_PRINTF_SEMANTICS -DPRINTFUART_ENABLED
#CFLAGS += -DFAST_SMCLK
CFLAGS += -DHAVE_ROSC_P2_5

BUILD_EXTRA_DEPS += Stats.class
CLEAN_EXTRA = *.class StatsMsg.java

Stats.class: $(wildcard *.java) StatsMsg.java
	javac -target 1.4 -source 1.4 *.java

StatsMsg.java:
	mig java -target=null $(CFLAGS) -java-classname=StatsMsg cmds.h msg_t -o $@

include $(MAKERULES)
