/*
 * Copyright (c) 2008-2010 The Regents of the University  of California.
 * All rights reserved."
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * - Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 * - Redistributions in binary form must reproduce the above copyright
 *   notice, this list of conditions and the following disclaimer in the
 *   documentation and/or other materials provided with the
 *   distribution.
 * - Neither the name of the copyright holders nor the names of
 *   its contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL
 * THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 * OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 */
#include <IPDispatch.h>
#include <lib6lowpan/lib6lowpan.h>
#include <lib6lowpan/ip.h>
#include <lib6lowpan/ip.h>

#include "UDPReport.h"
#include "blip_printf.h"

#define REPORT_PERIOD 10L

module UDPSendRecvP {
  uses {
    interface Boot;
    interface SplitControl as RadioControl;
    interface SplitControl as IPControl;

    interface UDP as Echo;
    interface UDP as Status;

    interface Leds;
    
    interface Timer<TMilli> as StatusTimer;
   
    interface BlipStatistics<ip_statistics_t> as IPStats;
    interface BlipStatistics<udp_statistics_t> as UDPStats;

    interface RootControl;
    interface ForwardingTable;

    interface Random;
  }

} implementation {

  bool timerStarted;
  nx_struct udp_report stats;
  struct sockaddr_in6 route_dest;
  uint8_t buf[30];
  uint32_t ctr;

  event void Boot.booted() {
    call RadioControl.start();
    call IPControl.start();
#ifdef RPL_ROUTING
    if(TOS_NODE_ID == 1)
    {
    	dbg("Boot", "Setting root\n");
        call RootControl.setRoot();
	call Leds.led2On();
    }
#endif


    timerStarted = FALSE;

    call IPStats.clear();

    call StatusTimer.startPeriodic(1000);
#if 0 //def REPORT_DEST
    route_dest.sin6_port = htons(7000);
    inet_pton6(REPORT_DEST, &route_dest.sin6_addr);
    call StatusTimer.startOneShot(call Random.rand16() % (1024 * REPORT_PERIOD));
#endif

    dbg("Boot", "booted: %i\n", TOS_NODE_ID);

    //call ForwardingTable.addRoute(NULL, 0, NULL, ROUTE_IFACE_154);
    call Echo.bind(7000);
    //call Status.bind(7001);

  }
#if 1
  event void RadioControl.startDone(error_t e) {
  }

  event void RadioControl.stopDone(error_t e) {

  }
  
  event void IPControl.startDone (error_t error) {
  }

  event void IPControl.stopDone (error_t error) { }


  event void Status.recvfrom(struct sockaddr_in6 *from, void *data, 
                             uint16_t len, struct ip6_metadata *meta) {

  }

  event void Echo.recvfrom(struct sockaddr_in6 *from, void *data, 
                           uint16_t len, struct ip6_metadata *meta) {
    char addr[30];
    uint32_t rec = 0;
    uint8_t *ptr = data;
#ifdef PRINTFUART_ENABLED
    int i;
    uint8_t *cur = data;
    //call Leds.led0Toggle();
    printf("Echo recv [%i]: ", len);
    for (i = 0; i < len; i++) {
      printf("%02x ", cur[i]);
    }
    printf("\n");
#endif
    rec = ((ptr[0] << 24) | (ptr[1] << 16) | (ptr[2] << 8) | ptr[3]);
    call Leds.led1Toggle();
    inet_ntop6(&from->sin6_addr, addr, 30);
    dbg("UDPSendRecv", "%i received a packet %u from %s\n", TOS_NODE_ID, rec, addr);
    printf("%i received a packet %u from %s\n", TOS_NODE_ID, rec, addr);
    //call Echo.sendto(from, data, len);
  }
#endif
  event void StatusTimer.fired() {
    //dbg("UDPSendRecv", "fired: %i\n", TOS_NODE_ID);
    if(TOS_NODE_ID != 1)
    {
      buf[0] = (ctr & 0xff000000) >> 24;
      buf[1] = (ctr & 0xff0000) >> 16;
      buf[2] = (ctr & 0xff00) >> 8;
      buf[3] = (ctr & 0xff);
      ctr++;

      route_dest.sin6_port = htons(7000);
      inet_pton6("fec0::1", &route_dest.sin6_addr);
      //inet_pton6("::1", &route_dest.sin6_addr);
      call Status.sendto(&route_dest, &buf, 4);
      printf("%i sent a packet [%u]\n", TOS_NODE_ID, ctr);
      dbg("UDPSendRecv", "%i sent a packet [%u]\n", TOS_NODE_ID, ctr);
      call Leds.led1Toggle();

    }
    else
    {
    	printf("%i did nothing\n", TOS_NODE_ID);
    }
    return;
#if 0
    if (!timerStarted) {
      call StatusTimer.startPeriodic(1024 * REPORT_PERIOD);
      timerStarted = TRUE;
    }

    stats.seqno++;
    stats.sender = TOS_NODE_ID;
    stats.interval = REPORT_PERIOD;

    call IPStats.get(&stats.ip);
    call UDPStats.get(&stats.udp);
    call Leds.led1Toggle();
    call Status.sendto(&route_dest, &stats, sizeof(stats));
#endif
  }
}
