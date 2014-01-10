#ifndef TUTORNET_COLLECTION_H
#define TUTORNET_COLLECTION_H

enum{
  UART_QUEUE_SIZE = 20,
  MEAN_PACKET_DELAY = 100,
  RSSI_OFFSET = 100,
  AM_UARTPACKET   = 0x89,
  BEACON_TYPE = 0xFF,
  STATION_RECEIVE_TYPE = 0x10,
 
  LOG_THROUGHPUT_TYPE = 0x61,
  LOG_PRR_TYPE = 0x62,
  LOG_RADIO_TYPE =0x63,
  SEND_ERROR_TYPE = 0xee,
  SINK_RECEIVE_TYPE = 0x11,
  UART_ACK_TYPE = 0x05,

  TYPE_START = 0x01,  // field1 = send_period; field2 = num_nodes; field3 = num_packets;
  TYPE_SYNC = 0x02,
  TYPE_STOP = 0x03,
  TYPE_SYNC_SET = 0x04,
  TYPE_RESET = 0x05
};

#define PROTO_BCP 1
//#define REC_PAC 1

//#define FLAG_LPL 1
//#define DBG_NET 1
//#define PROTO_CTP 1
//#define SEND_PERIOD 500
//#define LOG_PERIOD 3000

#define MAX_PKTNUM 500 //Has to be a multiple of 8
#define MAX_PKTFLAGS 6 //Has vale = MAX_NODES/8
#define MAX_NODES 48

/**
 *  the UartPacket struct is used for logging purposes.
 *  The eight fields (3x32, 3x16, 2x8) are indicated
 *  as valid or invalid per the type field.
 */

typedef nx_struct UartPacket {
  nx_uint32_t         time;
  nx_uint32_t         field1;
  nx_uint32_t         field2;
  nx_uint32_t         field3;
  nx_uint16_t         field4;
  nx_uint16_t         field5;
  nx_uint16_t         field6;
  nx_uint8_t          field7;
  nx_uint8_t          field8;
  nx_uint8_t          type;
} UartPacket;

typedef nx_struct stationDataMsg{
 nx_uint8_t sourceID;
 nx_uint16_t sequenceID;
 nx_uint16_t dispatchTime;
//  nx_uint16_t RSSI;
}stationDataMsg;


#endif
