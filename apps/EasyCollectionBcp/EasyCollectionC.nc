#include <Timer.h>

#ifdef TOSSIM
#define printf(...)
#else
#include <printf.h>
#endif

module EasyCollectionC {

  provides interface BcpDebugIF;

  uses interface Boot;
  uses interface SplitControl as RadioControl;
  uses interface StdControl as RoutingControl;
  uses interface Send;
  uses interface Leds;
  uses interface Timer<TMilli>;
  uses interface RootControl;
  uses interface Receive;
}
implementation {

  message_t packet;
  uint16_t sendCounter;

  bool sendBusy = FALSE;

  typedef nx_struct EasyCollectionMsg {
    nx_uint16_t data;
    nx_uint16_t senderID;
  } EasyCollectionMsg;

  // --------------- Boot events ----------------------
  event void Boot.booted() {
    call RadioControl.start();
  }

  // --------------- RadioControl events ---------------------
  event void RadioControl.startDone(error_t err) {
    if (err != SUCCESS)
      call RadioControl.start();
    else
    {
      call RoutingControl.start();
      if (TOS_NODE_ID == 1)
	call RootControl.setRoot();
      else
	call Timer.startPeriodic(1000);
    }
  }


  event void RadioControl.stopDone(error_t err) {}

  // ------------------------- send message --------------------------
  void sendMessage() {

    EasyCollectionMsg* msg = (EasyCollectionMsg*)call Send.getPayload(&packet, sizeof(EasyCollectionMsg));

    dbg("EasyCollection","EasyCollection sendMessage() called\n");

    msg->data = sendCounter;

    sendCounter += 1;

    msg->senderID = TOS_NODE_ID;

//      call Leds.led0On();
    if (call Send.send(&packet, sizeof(EasyCollectionMsg)) != SUCCESS) 
    {
      dbg("EasyCollection","EasyCollection in sendMessage() Send.send called but failed\n");
    }
    else
    {
      sendBusy = TRUE;
      //dbg("EasyCollection","EasyCollection in sendMessage() Send.send called and succeeded, set sendBusy=TRUE\n");
    }

  }


  event void Timer.fired() {

    //dbg("EasyCollection","---------------------EasyCollection timer fired-----------------------------\n");

    //call Leds.led2Toggle();
    if (1)
    //if (!sendBusy)
    {
      //dbg("EasyCollection","EasyCollection not sendBusy, sendMessage() called\n");
      sendMessage();
    }
    else
    {
      //dbg("EasyCollection","EasyCollection sendBusy\n");
    }
  }


  event void Send.sendDone(message_t* m, error_t err) {
   //dbg("EasyCollection","EasyCollection sendDone\n");

   //call Leds.led0Off();
   if (err != SUCCESS)
   {
     //dbg("EasyCollection","EasyCollection sendDone, but err!=SUCCESS\n");
   }
   else
   {
     //dbg("EasyCollection","EasyCollection sendDone, and err==SUCCESS\n");
   }

   sendBusy = FALSE;
  }


  event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len) {

    EasyCollectionMsg *ecm = (EasyCollectionMsg *)payload;
    dbg("EasyCollection","EasyCollection received packet from %u counter %u\n", ecm->senderID, ecm->data);
    printf("EasyCollection received packet from %u counter %u\n", ecm->senderID, ecm->data);

    //call Leds.led1Toggle();
    return msg;
  }

   /*
   * Notifies upper layer of a change to the local
   *  backpressure level.
   */
  command void BcpDebugIF.reportBackpressure(uint32_t dataQueueSize_p, uint32_t virtualQueueSize_p, uint16_t localTXCount_p, uint8_t origin_p, uint8_t originSeqNo_p, uint8_t reportSource_p){
     //dbg("EasyCollection", "data %hhu %hhu %hhu %hhu %hhu %hhu\n", dataQueueSize_p, virtualQueueSize_p, localTXCount_p, origin_p, originSeqNo_p, reportSource_p);
   }

  /**
   * Notifies the application layer of an error
   */
  command void BcpDebugIF.reportError( uint8_t type_p ) { 
   /*call Leds.led0Off();
   call Leds.led1Off();
   call Leds.led2Off();
   if((type_p & 0xA0) == 0xA0)
   {
	if(type_p & 0x01)
		call Leds.led0On();
	if(type_p & 0x02)
		call Leds.led1On();
	if(type_p & 0x04)
		call Leds.led2On();
   }*/
   printf("%x\n", type_p);

  }

  /**
   * Notifies upper layer of an update to the estimated link transmission time
   */
  command void BcpDebugIF.reportLinkRate(uint8_t neighbor_p, uint16_t previousLinkPacketTxTime_p, 
                              uint16_t updateLinkPacketTxTime_p, uint16_t newLinkPacketTxTime,
                              uint16_t latestLinkPacktLossEst){}

  /**
   * Used to debug
   */
  command void BcpDebugIF.reportValues(uint32_t field1_p, uint32_t field2_p, uint32_t field3_p, uint16_t field4_p, 
                              uint16_t field5_p, uint16_t field6_p, uint8_t field7_p, uint8_t field8_p){}

}





