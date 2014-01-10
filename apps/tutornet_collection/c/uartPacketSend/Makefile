CC=gcc
SF=$(TOSROOT)/support/sdk/c/sf
CFLAG="-DTUTORNET"

all:
	$(CC) $(CFLAG) -c -I$(SF) ../UartPacket.c
	$(CC) $(CFLAG) -c -I$(SF) startExperiment.c
	$(CC) $(CFLAG) startExperiment.o UartPacket.o  $(SF)/serialpacket.o  $(SF)/message.o $(SF)/libmote.a -o startExperiment
	$(CC) $(CFLAG) -c -I$(SF) stopExperiment.c
	$(CC) $(CFLAG) stopExperiment.o UartPacket.o  $(SF)/serialpacket.o  $(SF)/message.o $(SF)/libmote.a -o stopExperiment
	$(CC) $(CFLAG) -c -I$(SF) resetExperiment.c	
	$(CC) $(CFLAG) resetExperiment.o UartPacket.o  $(SF)/serialpacket.o  $(SF)/message.o $(SF)/libmote.a -o resetExperiment
