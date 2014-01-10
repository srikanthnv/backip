#include <stdio.h>
#include <stdlib.h>
#include <sys/time.h>

#include "sfsource.h"
#include "serialpacket.h"
#include "serialprotocol.h"

#include "../UartPacket.h"

const static uint8_t COMMAND_STOP_TIME =2;
const static uint8_t COMMAND_START_TIME=4;
const static uint8_t COMMAND_START     =1;
const static uint8_t COMMAND_STOP      =3;
const static uint8_t COMMAND_RESET     =5;


const static uint32_t SEND_PERIOD   = 12;
const static uint32_t NUM_NODES     = 2;
const static uint32_t NUM_PACKETS   = 200;

uint8_t nodeID_m;

void sendCommand( int type_p, int fd_p, uint8_t commandCount_p )
{
  fd_set serialFDSet;
  struct timeval timeout;
  uint8_t packet[40];
  tmsg_t *msg;
  int i, len;
  tmsg_t *msgUart;
  int success = 0;

  while( success == 0 )
  {
    msg = new_tmsg(packet+1, SPACKET_SIZE + UARTPACKET_SIZE);
    msgUart = new_tmsg(packet+1+SPACKET_SIZE, UARTPACKET_SIZE);
    if(!msg){fprintf(stderr, "ERROR- msg NULL\n");}
    if(!msgUart){fprintf(stderr, "ERROR- msgUart NULL\n");}
    // Set up the serial message
    spacket_header_dest_set(msg, 0xFFFF);
    spacket_header_src_set(msg, 0x0000);
    spacket_header_length_set(msg, UARTPACKET_SIZE);
    spacket_header_group_set(msg, 0);
    spacket_header_type_set(msg, UARTPACKET_AM_TYPE);
    // Set up UartPacket fields
    UartPacket_time_set(msgUart, 0);
    UartPacket_field1_set(msgUart, SEND_PERIOD); 
    UartPacket_field2_set(msgUart, NUM_NODES); 
    UartPacket_field3_set(msgUart, NUM_PACKETS); 
    UartPacket_field4_set(msgUart, 0); 
    UartPacket_field5_set(msgUart, 0); 
    UartPacket_field6_set(msgUart, 0); 
    UartPacket_field7_set(msgUart, 0); 
    UartPacket_field8_set(msgUart, commandCount_p); 
    UartPacket_type_set(msgUart, type_p);

    // First byte must be zero, not sure why =P
    packet[0] = SERIAL_TOS_SERIAL_ACTIVE_MESSAGE_ID;

    // (re)send the command packet
    for (i = 0; i < SPACKET_SIZE+UARTPACKET_SIZE+1; i++)
      fprintf(stderr, " %02x", packet[i]);
    if (write_sf_packet(fd_p, packet, SPACKET_SIZE+UARTPACKET_SIZE+1) == 0){
      printf("\n ack\n");
      success = 1;
    }
    else
      printf("\n noack\n");

    // Clean up the sent command packet
    free_tmsg(msgUart);
    free_tmsg(msg);
/*
    printf("Sending command packet <type,count>=<%u,%u>@%u\n", type_p, commandCount_p, nodeID_m); 

    // Give the node a chance to send a response packet with the correct commandCount
    timeout.tv_sec = 0;
    timeout.tv_usec = 300000;

    while( success == 0 && timeout.tv_usec != 0 )
    {
      // Add the fd to the serialFDSet;
      FD_ZERO(&serialFDSet);
      FD_SET(fd_p, &serialFDSet);
      if( select(FD_SETSIZE, &serialFDSet, (fd_set *) 0, (fd_set *) 0, &timeout) != 0 )
      {
        // Receive the packet, may be a commandCount update
        uint8_t *packet = read_sf_packet(fd_p, &len);

        if (!packet)
        {
          printf("read_sf_packet returned null packet data! Terminating.\n");
          exit(0);
        }
        if (len >= 1 + SPACKET_SIZE &&
            packet[0] == SERIAL_TOS_SERIAL_ACTIVE_MESSAGE_ID)
        {
          tmsg_t *msgUart = new_tmsg(packet + 1 + SPACKET_SIZE, len - 1 - SPACKET_SIZE);

	  if (!msg)
	    exit(0);

          printf("Packet commandCount is %u, type %u.\n", UartPacket_field8_get(msgUart), UartPacket_type_get(msgUart));

          if(UartPacket_field8_get(msgUart) == commandCount_p && 
             UartPacket_type_get(msgUart) == 0x05 )
          {
            success = 1;
          }
        }
      }
    }*/
  }
}

void hexprint(uint8_t *packet_p, int len_p, FILE* logFile_p)
{
  int i;

  for (i = 0; i < len_p; i++)
    fprintf(logFile_p, "%02x ", packet_p[i]);
}

int main(int argc, char **argv)
{
  int fd;
  char logFileName[20];
  int ret;
  FILE* logFile;
  fd_set serialFDSet;

  if (argc != 3)
    {
      fprintf(stderr, "Usage: %s <host> <port> - dump packets from a serial forwarder\n", argv[0]);
      exit(2);
    }

  nodeID_m = (atoi(argv[2]) - 10000);

  fprintf(stderr, "Openning serial forwarder at %s:%s\n",
      argv[1], argv[2]);
  fd = open_sf_source(argv[1], atoi(argv[2]));
  if (fd < 0)
  {
    fprintf(stderr, "Couldn't open serial forwarder at %s:%s\n", argv[1], argv[2]);
    exit(1);
  }


  sendCommand( COMMAND_RESET, fd, 0 );

}


