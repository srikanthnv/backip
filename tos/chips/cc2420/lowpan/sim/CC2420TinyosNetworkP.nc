/*
 * Copyright (c) 2005-2006 Rincon Research Corporation
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * - Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 * - Redistributions in binary form must reproduce the above copyright
 *   notice, this list of conditions and the following disclaimer in the
 *   documentation and/or other materials provided with the
 *   distribution.
 * - Neither the name of the Rincon Research Corporation nor the names of
 *   its contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE
 * RINCON RESEARCH OR ITS CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 * OF THE POSSIBILITY OF SUCH DAMAGE
 */

/**
 * Fills in the network ID byte for outgoing packets for compatibility with
 * other 6LowPAN networks.  Filters incoming packets that are not
 * TinyOS network compatible.  Provides the 6LowpanSnoop interface to
 * sniff for packets that were not originated from TinyOS.
 *
 * @author David Moss
 */

#include "CC2420.h"
#include "Ieee154.h"

module CC2420TinyosNetworkP @safe() {
  provides {

    interface Send as BareSend;
    interface Receive as BareReceive;

    interface Send as ActiveSend;
    interface Receive as ActiveReceive;

    interface Packet as BarePacket;
  }
  
  uses {
    interface Send as SubSend;
    interface Receive as SubReceive;
    interface CC2420Packet;
    interface CC2420PacketBody;
  }
}

implementation {

void print_bytes(uint8_t *ptr, uint8_t len)
{
  uint32_t i;
  char buf[300] = "", num[3];
  for(i = 0; i < len; i++) {
    sprintf(num, "%02x", ptr[i]);
    strcat(buf, num);
  }
  dbg("Debug", "%s\n", buf);
}
  enum {
    CLIENT_AM,
    CLIENT_BARE,
  } m_busy_client;

  command error_t ActiveSend.send(message_t* msg, uint8_t len) {
   call CC2420Packet.setNetwork(msg, TINYOS_6LOWPAN_NETWORK_ID);
    m_busy_client = CLIENT_AM;
    return call SubSend.send(msg, len);
  }

  command error_t ActiveSend.cancel(message_t* msg) {
    return call SubSend.cancel(msg);
  }

  command uint8_t ActiveSend.maxPayloadLength() {
    return call SubSend.maxPayloadLength();
  }

  command void* ActiveSend.getPayload(message_t* msg, uint8_t len) {
    if (len <= call ActiveSend.maxPayloadLength()) {
      return msg->data;
    } else {
      return NULL;
    }
  }
  /***************** BarePacket Commands ****************/
  command void BarePacket.clear(message_t *msg) {
    memset(msg, 0, sizeof(message_t));
  }

  command uint8_t BarePacket.payloadLength(message_t *msg) {
    tossim_header_t *hdr = call CC2420PacketBody.getHeader(msg);
    return hdr->length + 1 - MAC_FOOTER_SIZE;
  }

  command void BarePacket.setPayloadLength(message_t* msg, uint8_t len) {
    tossim_header_t *hdr = call CC2420PacketBody.getHeader(msg);
    hdr->length = len - 1 + MAC_FOOTER_SIZE;
  }

  command uint8_t BarePacket.maxPayloadLength() {
    return TOSH_DATA_LENGTH + sizeof(tossim_header_t);
  }

  command void* BarePacket.getPayload(message_t* msg, uint8_t len) {

  }

  /***************** Send Commands ****************/
  command error_t BareSend.send(message_t* msg, uint8_t len) {

	print_bytes(msg, len);
   call BarePacket.setPayloadLength(msg, len);
    m_busy_client = CLIENT_BARE;
    return call SubSend.send(msg, 0);
  }

  command error_t BareSend.cancel(message_t* msg) {
    return call SubSend.cancel(msg);
  }

  command uint8_t BareSend.maxPayloadLength() {
    return call BarePacket.maxPayloadLength();
  }

  command void* BareSend.getPayload(message_t* msg, uint8_t len) {
#ifndef TFRAMES_ENABLED                      
    tossim_header_t *hdr = call CC2420PacketBody.getHeader(msg);
    return hdr;
#else
    // you really can't use BareSend with TFRAMES
#endif
  }
  
  /***************** SubSend Events *****************/
  event void SubSend.sendDone(message_t* msg, error_t error) {
    dbg("CC2420TinyosNetworkP", "CC2420TinyosNetworkP sendDone\n");
    if (m_busy_client == CLIENT_AM) {
      signal ActiveSend.sendDone(msg, error);
    } else {
      signal BareSend.sendDone(msg, error);
    }
  }

  /***************** SubReceive Events ***************/
  event message_t *SubReceive.receive(message_t *msg, void *payload, uint8_t len) {
    uint8_t network = call CC2420Packet.getNetwork(msg);
    dbg("CC2420TinyosNetworkP", "CC2420TinyosNetworkP received\n");

#if !TOSSIM //TOSSIM doesn't seem to believe in CRCs
    if(!(call CC2420PacketBody.getMetadata(msg))->crc) {
    dbg("CC2420TinyosNetworkP", "1 %u\n", (call CC2420PacketBody.getMetadata(msg))->crc);
      return msg;
    }
#endif

#ifndef TFRAMES_ENABLED
    if (network == TINYOS_6LOWPAN_NETWORK_ID) {
    dbg("CC2420TinyosNetworkP", "2\n");
      return signal ActiveReceive.receive(msg, payload, len);
    } else {
    dbg("CC2420TinyosNetworkP", "3\n");
      dbg("Bare" , "Received:\n");
	print_bytes(msg, len-1);
      //((uint8_t *)msg)[5] = 0;
      return signal BareReceive.receive(msg, 
                                        call BareSend.getPayload(msg, len - 1), 
                                        len - 1);
                                        //len + sizeof(tossim_header_t));
    }
#else
    dbg("CC2420TinyosNetworkP", "4\n");
    return signal ActiveReceive.receive(msg, payload, len);
#endif
  }

  /***************** Defaults ****************/
  default event message_t *BareReceive.receive(message_t *msg, void *payload, uint8_t len) {
    return msg;
  }
  default event void BareSend.sendDone(message_t *msg, error_t error) {

  }
  default event message_t *ActiveReceive.receive(message_t *msg, void *payload, uint8_t len) {
    return msg;
  }
  default event void ActiveSend.sendDone(message_t *msg, error_t error) {

  }

}
