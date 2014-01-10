generic configuration SafeSerialSendC(uint8_t QUEUE_SIZE, am_addr_t SERIAL_ADDR){
  provides interface SafeSerialSendIF;
  provides interface Receive as UartReceive;
  provides interface StdControl;
}
implementation{
  components SafeSerialSendM;
  components new QueueC(message_t*, QUEUE_SIZE);
  components new PoolC(message_t, QUEUE_SIZE);
  components SerialActiveMessageC as UartAM;

  SafeSerialSendM.UartSend      -> UartAM.AMSend[SERIAL_ADDR];
  SafeSerialSendM.UartPacket    -> UartAM.Packet;
  SafeSerialSendM.UartAMPacket  -> UartAM.AMPacket;
  SafeSerialSendM.SerialControl -> UartAM.SplitControl;
  SafeSerialSendM.SendQueue     -> QueueC.Queue;
  SafeSerialSendM.MessagePool   -> PoolC.Pool;

  SafeSerialSendM.SafeSerialSendIF = SafeSerialSendIF;
  UartAM.Receive[SERIAL_ADDR]      = UartReceive;
  SafeSerialSendM.StdControl       = StdControl;
}
