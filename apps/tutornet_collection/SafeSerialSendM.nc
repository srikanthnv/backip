module SafeSerialSendM{
  uses interface AMSend as UartSend;
  uses interface Packet as UartPacket;
  uses interface AMPacket as UartAMPacket;
  uses interface SplitControl as SerialControl;
  
  uses interface Pool<message_t> as MessagePool;
  uses interface Queue<message_t*> as SendQueue;
  
  provides interface SafeSerialSendIF;
  provides interface StdControl;
}
implementation{
  /*
   * sending_m is used to indicate an outstanding send 
   *  request exists.  Once sendDone is called, sending_m
   *  will be set to false.
   */
  bool sending_m;
  
  /*
   * serialRunning_m is used to indicate whether the
   *  serialAM is up.
   */
  bool serialRunning_m;
  
  /*
   * Keeps count of the number of messages that were dropped
   */
  uint8_t overflowCount_m;
 
  task void sendTask(){
    message_t* newMsg;
    error_t retVal;
    newMsg = call SendQueue.head();

    if( sending_m )
      return;

    dbg("Serial","%s:calling UartSend.send\n", __FUNCTION__);
    retVal = call UartSend.send(AM_BROADCAST_ADDR, newMsg, call UartPacket.payloadLength(newMsg) ); 
    if( retVal == SUCCESS )
      sending_m = TRUE; 
    else
      dbg("Serial","%s:call to UartSend.send failed with code %u.\n", __FUNCTION__, retVal);
  }
 
  event void UartSend.sendDone(message_t *msg, error_t error){
    if( msg == call SendQueue.head() )
    {
      if (error != SUCCESS) {
        // Retry send
        sending_m = FALSE;
        post sendTask();
      }else{
      	/*
      	 * Successful UartSend, free the pool and dequeue,
      	 *  if this freed a pool slot then update nextMessage_m
      	 */
        call SendQueue.dequeue();
        if( call MessagePool.put(msg)!= SUCCESS ){
          dbg("ERROR", "%s: Memory leak, failed MessagePool.put().\n", __FUNCTION__);
        }
        
        sending_m = FALSE;
      
        if( !(call SendQueue.empty()) && serialRunning_m )
        {
          /*
           * Send the next message
           */
          post sendTask();
        }
      }
    }
  }
  
  event void SerialControl.startDone(error_t error){
    if (error != SUCCESS){
      //try restarting it
      call SerialControl.start();
    } else {
      serialRunning_m = TRUE;
    }
  }  
  
  event void SerialControl.stopDone(error_t error){
    serialRunning_m = FALSE;
  }
  
  command message_t * SafeSerialSendIF.getMessageBuffer(){
    message_t * retVal;

    if( !call MessagePool.empty() ){
      retVal = call MessagePool.get();
    } else {
      retVal = 0;
      overflowCount_m++;
    }

    return retVal;
  }
  
  command void * SafeSerialSendIF.getPayload(message_t * msg_p, uint8_t size_p){
    // Set the size for future use
    dbg("Serial","%s:getting payload of size %u\n",__FUNCTION__,size_p);
    call UartPacket.setPayloadLength(msg_p, size_p);
    return call UartPacket.getPayload(msg_p, size_p);
  }
  
  
  
  command void SafeSerialSendIF.queueMessageBuffer(message_t * sendMsg_p)
  {
    if( sendMsg_p == 0 || (call SendQueue.maxSize() == call SendQueue.size()) ){ return; }
    call SendQueue.enqueue(sendMsg_p);
    post sendTask();
  }
  
  command uint8_t SafeSerialSendIF.droppedMessageCount(){
    uint8_t retVal  = overflowCount_m;
    overflowCount_m = 0;
    return retVal;
  }
  

  command error_t StdControl.start(){
    sending_m               = FALSE;
    serialRunning_m         = FALSE;
    overflowCount_m         = 0;
    
    call SerialControl.start();
    return SUCCESS;
  }
  
 
  command error_t StdControl.stop(){
    serialRunning_m         = FALSE;
    call SerialControl.stop();
    return SUCCESS;
  } 
}
