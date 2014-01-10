#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "sfsource.h"
#include "serialpacket.h"
#include "serialprotocol.h"
#include "UartPacket.h"

enum{
LOG_THROUGHPUT_TYPE = 0x61,
LOG_PRR_TYPE = 0x62,
LOG_RADIO_TYPE =0x63,
SEND_ERROR_TYPE = 0xee,
SINK_RECEIVE_TYPE = 0x11
};

FILE *thFile;
FILE *radioFile;
FILE *prrFile;

void hexprint(uint8_t *packet, int len)
{
  int i;
   	 for (i = 0; i < len; i++)
    		printf("%02x ", packet[i]);
}


int main(int argc, char **argv)
{
  int fd;
  char  thFileName[20];
  char  radioFileName[20];
  char  prrFileName[20];

  if (argc != 5)
    {
      fprintf(stderr, "Usage: %s <host> <port>  <NUMNODES> <PACKET RATE>- dump packets from a serial forwarder\n", argv[0]);
      exit(2);
    }
  fd = open_sf_source(argv[1], atoi(argv[2]));
  if (fd < 0)
    {
      fprintf(stderr, "Couldn't open serial forwarder at %s:%s\n",
	      argv[1], argv[2]);
      exit(1);
    }
  strcpy(thFileName, "log_th_"); 
  strcat(thFileName, (const char *) argv[2]);
  strcat(thFileName, "_NUMNODES"); 
  strcat(thFileName, (const char *) argv[3]); 
  strcat(thFileName, "_PACRT");
  strcat(thFileName, (const char *) argv[4]); 
  strcat(thFileName, ".txt"); 
  thFile = fopen((const char *) thFileName, "w");

  strcpy(prrFileName, "log_prr_"); 
  strcat(prrFileName, (const char *) argv[2]);
  strcat(prrFileName, "_NUMNODES"); 
  strcat(prrFileName, (const char *) argv[3]); 
  strcat(prrFileName, "_PACRT");
  strcat(prrFileName, (const char *) argv[4]);  
  strcat(prrFileName, ".txt"); 
  prrFile = fopen((const char *)prrFileName, "w");

  strcpy(radioFileName, "log_radio_"); 
  strcat(radioFileName, (const char *) argv[2]);
  strcat(radioFileName, "_NUMNODES"); 
  strcat(radioFileName, (const char *) argv[3]); 
  strcat(radioFileName, "_PACRT");
  strcat(radioFileName, (const char *) argv[4]);  
  strcat(radioFileName, ".txt"); 
  radioFile = fopen((const char *)radioFileName, "w");

  for (;;)
    {
      int len, i;
      uint8_t *packet = read_sf_packet(fd, &len);

      if (!packet)
	exit(0);

      if (len >= 1 + SPACKET_SIZE &&
	  packet[0] == SERIAL_TOS_SERIAL_ACTIVE_MESSAGE_ID)
	{
	  tmsg_t *msg = new_tmsg(packet + 1, len - 1);
	  tmsg_t *data;
	  if (!msg)
	    exit(0);

/*	  printf("dest %u, src %u, length %u, group %u, type %u\n  ",
		 spacket_header_dest_get(msg),
		 spacket_header_src_get(msg),
		 spacket_header_length_get(msg),
		 spacket_header_group_get(msg),
		 spacket_header_type_get(msg));*/
	//  hexprint((uint8_t *)tmsg_data(msg) + spacket_data_offset(0),
	//	   tmsg_length(msg) - spacket_data_offset(0));

	data = new_tmsg(tmsg_data(msg) + spacket_data_offset(0), spacket_header_length_get(msg)); 

	uint8_t type = UartPacket_type_get(data);
        if(type==SINK_RECEIVE_TYPE){
      	   //uint8_t node = UartPacket_time_get(data);
	   uint32_t seq   = UartPacket_field1_get(data);
	   uint16_t txCnt = UartPacket_field4_get(data);
	   uint16_t hopCnt = UartPacket_field5_get(data);
	   uint8_t fromID = UartPacket_field7_get(data);
	   uint32_t time = UartPacket_time_get(data);


	   printf("TYPE:0x%x FID:%d SEQ:%d HOPCNT:%d  TXCNT:%d TIME:%d\n",
                   type, fromID, seq, hopCnt, txCnt, time);
        }else if(type==SEND_ERROR_TYPE){ //send fail
	   uint32_t errCode = UartPacket_field1_get(data);
	   uint16_t seq   = UartPacket_field6_get(data);



	   printf("TYPE:0x%x SEND ERROR!!  SEQ:%d CODE:%d\n",
                   type, seq, errCode);
        }else if(type==LOG_THROUGHPUT_TYPE){//get throughput
	  uint32_t throught =UartPacket_field1_get(data);
	  uint32_t period =UartPacket_field2_get(data);
	  uint32_t lastReception =UartPacket_time_get(data);
	  uint32_t firstReception =UartPacket_field3_get(data);
	  uint16_t netPackRec =UartPacket_field4_get(data);
	  uint16_t totalPackRec =UartPacket_field5_get(data);
	  uint16_t pacNotRec =UartPacket_field6_get(data);
	  uint8_t roundNum =UartPacket_field7_get(data);
	  printf("TYPE:%d TH:%d DUR:%d TH:%f FSTREC:%d LSTREC:%d\tNetRecPac:%d DuplicateRec:%d AwaitedPac:%d NetTH: %f\n",
                   type, throught, period, throught*1000.0/(double)period,firstReception, lastReception, netPackRec, totalPackRec - netPackRec, pacNotRec, netPackRec*1000.0/(double)(period*roundNum) );
	  fprintf(thFile,"TH: %d, DUR: %d, TH: %f FSTREC:%d LSTREC: %d\tNetRecPac:%d DuplicateRec:%d AwaitedPac:%d NetTH: %f\n",throught, period, throught*1000.0/(double)period,firstReception,lastReception, netPackRec, totalPackRec - netPackRec, pacNotRec, netPackRec*1000.0/(double)(period*roundNum));
        }else if(type==LOG_PRR_TYPE){//get prr
	  uint8_t ID =UartPacket_field8_get(data);
	  uint16_t PRR =UartPacket_field4_get(data);
	  uint32_t TPR =UartPacket_field1_get(data);
	  printf("TYPE:%d ID:%d PRR:%d TPR:%d\n", type, ID, PRR, TPR);
	  fprintf(prrFile,"ID: %d, PRR: %d, TPR: %d\n",ID, PRR, TPR);

	  PRR =UartPacket_field5_get(data);
	  TPR =UartPacket_field2_get(data);
	  printf("TYPE:%d ID:%d PRR:%d TPR:%d\n", type, ID+1, PRR, TPR);
	  fprintf(prrFile,"ID: %d, PRR: %d, TPR: %d\n",ID+1, PRR, TPR);

	  PRR =UartPacket_field6_get(data);
	  TPR =UartPacket_field3_get(data);
	  printf("TYPE:%d ID:%d PRR:%d TPR:%d\n", type, ID+2, PRR, TPR);
	  fprintf(prrFile,"ID: %d, PRR: %d, TPR: %d\n",ID+2, PRR, TPR);
        }else if(type==LOG_RADIO_TYPE){//get radio
	  uint32_t onTime =UartPacket_field1_get(data);
	  uint32_t offTime =UartPacket_field2_get(data);
          double onPer = (double)onTime/(double)(onTime+offTime);
	  printf("TYPE:%d ONTIME:%d OFFTIME:%d  \%%f\n",type, onTime, offTime, onPer);
	  fprintf(radioFile,"ONTIME: %d, OFFTIME: %d,  \%%f\n",onTime, offTime, onPer);
        }else if(type==0x40){//get radio
	  uint32_t onTime =UartPacket_field1_get(data);
	  uint32_t offTime =UartPacket_field2_get(data);
          double onPer = (double)onTime/(double)(onTime+offTime);
	  printf("******** Initialization *************\n");
        }else{
//           printf("TYPE:%x\n", type);

        }
          
        free(msg);
      }else{
	  printf("non-AM packet: ");
	  hexprint(packet, len);
	  printf("\n");
      }
     // putchar('\n');
      fflush(stdout);
      fflush(radioFile);
      fflush(prrFile);
      fflush(thFile);
      free((void *)packet);
    }
}
