module CC2420ReceiveC
{
  provides interface Receive;
  
  uses {
    interface TossimPacketModel as Model;
    interface Packet;
  }
}

implementation
{
  event void Model.receive(message_t* msg)
  {
    /*cc2420_metadata_t* metadata = call CC2420PacketBody.getMetadata( msg );
    cc2420_header_t* header = call CC2420PacketBody.getHeader( msg );
    uint8_t length = header->length;
    uint8_t tmpLen __DEPUTY_UNUSED__ = sizeof(message_t) - (offsetof(message_t, data) - sizeof(cc2420_header_t));
    uint8_t* COUNT(tmpLen) buf = TCAST(uint8_t* COUNT(tmpLen), header);

    dbg("CC2420ReceiveP", "CC2420ReceiveP putting CRC %u\n", metadata->crc);
    metadata->crc = buf[ length ] >> 7;
    metadata->lqi = buf[ length ] & 0x7f;
    metadata->rssi = buf[ length - 1 ];*/

    uint8_t len = call Packet.payloadLength(msg);
    signal Receive.receive(msg, call Packet.getPayload(msg, len), len);
  }
}
