CC=gcc
SF=$(TOSROOT)/support/sdk/c/sf
CFLAG="-DTUTORNET"

all: 
		$(CC) $(CFLAG) -c -I$(SF) UartPacket.c
	        $(CC) $(CFLAG) -c -I$(SF) prettylisten.c
	    	$(CC) prettylisten.o UartPacket.o $(SF)/serialpacket.o  $(SF)/message.o $(SF)/libmote.a -o prettylisten
