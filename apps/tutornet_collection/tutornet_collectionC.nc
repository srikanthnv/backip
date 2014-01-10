#include "tutornet_collection.h"
#include "TimeSyncMsg.h"

# if PROTO_CTP

#include <CtpDebugMsg.h>

# endif

module tutornet_collectionC{

	uses interface Boot;
	uses interface SplitControl as RadioControl;

# ifdef LOW_POWER_LISTENING
# ifndef TOSSIM
  
	uses interface SplitControl as csmaControl;

# endif
# endif
	
	uses interface StdControl as ProtoControl;

	uses interface Leds;
	uses interface Timer<TMilli>;
	uses interface Timer<TMilli> as logTimer;
	// uses interface Timer<TMilli> as sinkTimer;
	uses interface RootControl;
	uses interface Receive;
	uses interface Send;
	uses interface Packet;


# ifndef TOSSIM

	uses interface CC2420Packet;

# endif


# if PROTO_BCP
	
	uses interface BcpPacket;

# else
	
	uses interface CtpPacket;
	uses interface Receive as DataSnoop;

# endif

# ifdef LOW_POWER_LISTENING
# ifndef TOSSIM
	
	uses interface LowPowerListening as LPL; 

# endif
# endif

	uses interface AMPacket;
	uses interface Random;
	uses interface SafeSerialSendIF;
	uses interface Receive as UartReceive;
	uses interface StdControl as SerialControl;


# if PROTO_BCP
	
	provides interface BcpDebugIF;
# else

	provides interface CollectionDebug;

# endif
}



implementation{
	
	
		  message_t packet;
		  // BeaconMsg* beaconData;
		  stationDataMsg stationData;
		  uint32_t startTestTime = 0;
		  uint32_t radioOnDuration = 0;
		  uint32_t radioOffDuration = 0;
		  uint32_t lastRadioOnTime = 0;
		  uint32_t lastRadioOffTime = 0;
		  uint16_t sequence;
		  am_addr_t parent;
		  

		  // log file


		  uint8_t pktFlag[MAX_NODES+1][MAX_PKTFLAGS+1];
		  int logTotalPktNum[MAX_NODES+1];
		  int logPktNum[MAX_NODES+1];
		  int netPackRec,totalPackRec,logRound;
		  //uint8_t numberOfResets = 0;
		  uint32_t throught = 0;
		  uint32_t onTime = 0;
		  uint32_t offTime = 0;
		  uint32_t preTime = 0;
		  uint32_t nowTime = 0;
		  bool radioFlg = FALSE; 

		 
		  uint32_t count = 0;
		  am_addr_t parent;
		  uint8_t commandCount = 0;
		  uint8_t commandCountAckCount = 0;
		  uint16_t testTime = 0;
		  uint32_t lastReception = 0;
		  uint32_t firstReception = 0;
		  bool firstReception_flag = FALSE;

		  uint8_t quotient, remainder;
		  uint8_t mask;
		  uint8_t mask_temp;

///////////////// These values come from UART////////////////////

		  uint32_t send_period = 1000;
		  uint32_t num_nodes = 10;
		  uint32_t num_packets = 200;
		  uint32_t log_period = 100;

/////////////////////////////////////////////////////////////////
	
	

	// function declarations
	// uint16_t getRss(message_t* msg);
	void logRadio(uint32_t  onDur, uint32_t offDur);
	void logTH(uint32_t  throughput, uint32_t logperiod);
	void logPRR(uint32_t  ID, uint32_t PRR, uint32_t TPR);
	void bitWrite(uint32_t nodeID, uint32_t index);
	bool bitRead(uint32_t nodeID, uint32_t index);


	event void Boot.booted() {    
		    
		    sequence = 0;
		    call RadioControl.start();
		    call SerialControl.start();
		    // call Timer.startOneShot(10000);
		    // call sinkTimer.startPeriodic(1000);
		    // call logTimer.startPeriodic(LOG_PERIOD);
		   
		    if(TOS_NODE_ID == 18)
		    		call RootControl.setRoot();
		    else{
				call RootControl.unsetRoot();
		    }

	  }




/*	uint16_t getRss(message_t* msg){



# ifndef TOSSIM
		return (uint16_t)(call CC2420Packet.getRssi(msg));
#else
		return 0;
# endif
	}

*/
////////////////////This part deals with the flag for every packet we receive//////////////////////////

	void bitWrite(uint32_t nodeID, uint32_t index) {
		
				
		quotient = index/8;
		remainder = index % 8;
		mask_temp = 1;
		mask = mask_temp << remainder;
		pktFlag[nodeID][quotient] = pktFlag[nodeID][quotient]| mask;
	}

	bool bitRead(uint32_t nodeID, uint32_t index) {
		
		quotient = index/8;
		remainder = index % 8;
		mask_temp = 1;
		mask = mask_temp << remainder;
		if(pktFlag[nodeID][quotient] == (pktFlag[nodeID][quotient]|mask))
			return TRUE;
		else
			return FALSE;	
	}
////////////////////////////////////////////////////////////////////////////////////////////////////////


# ifndef TOSSIM


	void logRadio(uint32_t  onDur, uint32_t offDur) {
		
		
		message_t* messagePtr;
		UartPacket* uartPacketPtr;


		messagePtr = call SafeSerialSendIF.getMessageBuffer();
		if( messagePtr == 0 )
			return;


		uartPacketPtr = (UartPacket *) call SafeSerialSendIF.getPayload(messagePtr, sizeof(UartPacket));


		if( uartPacketPtr == NULL )
			dbg("Error", "%s:uartPacketPtr is NULL! Packet size error?\n",__FUNCTION__);

		uartPacketPtr->type = LOG_RADIO_TYPE; //radio log message
		uartPacketPtr->field1 = onDur; 
		uartPacketPtr->field2 = offDur;

		dbg("Serial","%s:generated a serial packet notifying of packet reception.\n", __FUNCTION__);
		call SafeSerialSendIF.queueMessageBuffer(messagePtr);
	}


# ifdef LOW_POWER_LISTENING
	
	event void csmaControl.startDone( error_t err ){
		
		uint32_t totalTime;
		call Leds.led0On();
		nowTime = call Timer.getNow();
		if(radioFlg==TRUE) {
			onTime += nowTime - preTime;
		}
		else{
			offTime += nowTime - preTime;
		}
		
		radioFlg = TRUE; //now is on
		preTime = nowTime;
		totalTime = onTime+offTime;
		
		if(totalTime>=3000){ //log it in to flash
			logRadio(onTime, offTime);  
			onTime=0;
			offTime = 0;
		}
	}



	event void csmaControl.stopDone( error_t err ){

		call Leds.led0Off();
		nowTime = call Timer.getNow();
		
		if(radioFlg==TRUE) {
			onTime += nowTime - preTime;
		}
		else{
			offTime += nowTime - preTime;
		}
		
		radioFlg = FALSE; //now is on
		preTime = nowTime;
	}


# endif


	void logTH(uint32_t  throughput, uint32_t logperiod) {
		
		message_t* messagePtr;
		UartPacket* uartPacketPtr;
		logRound ++;
		
		messagePtr = call SafeSerialSendIF.getMessageBuffer();
		
		if( messagePtr == 0 )
			return;

		uartPacketPtr = (UartPacket *) call SafeSerialSendIF.getPayload(messagePtr, sizeof(UartPacket));
		
		if( uartPacketPtr == NULL )
			
			dbg("Error", "%s:uartPacketPtr is NULL! Packet size error?\n",__FUNCTION__);
		
		uartPacketPtr->type = LOG_THROUGHPUT_TYPE; //th log message
		uartPacketPtr->field1 = throughput; //node ID,
		uartPacketPtr->field2 = logperiod; //node ID,
		uartPacketPtr->field3 = firstReception; //time when the first packet was received during this log time,
		uartPacketPtr->field4 = (uint16_t) netPackRec;//tells about the total throughput so far.
		uartPacketPtr->field5 = (uint16_t) totalPackRec;//tells about duplicate packets received.
		uartPacketPtr->field6 = (uint16_t)((num_nodes-1)*num_packets - netPackRec);// tells about the dropped packets.
		uartPacketPtr->field7 = (uint8_t) logRound;
		uartPacketPtr->time = lastReception; //time when the most recent packet was received,
		dbg("Serial","%s:generated a serial packet notifying of packet reception.\n", __FUNCTION__);
		call SafeSerialSendIF.queueMessageBuffer(messagePtr);
		
	}

	
	void logPRR(uint32_t  ID, uint32_t PRR, uint32_t TPR) {
		
		message_t* messagePtr;
		UartPacket* uartPacketPtr;

		// Send a serial packet notifying of packet arrival
		messagePtr = call SafeSerialSendIF.getMessageBuffer();
		
		if( messagePtr == 0 )
			return;
			
			uartPacketPtr = (UartPacket *) call SafeSerialSendIF.getPayload(messagePtr, sizeof(UartPacket));
		
		if( uartPacketPtr == NULL )
			dbg("Error", "%s:uartPacketPtr is NULL! Packet size error?\n",__FUNCTION__);
			
		uartPacketPtr->type = LOG_PRR_TYPE; //prr log message
		uartPacketPtr->field8 = ( uint8_t ) ID; //node ID,
		uartPacketPtr->field4 = ( uint16_t ) PRR; //node PRR,
		uartPacketPtr->field1 = TPR; //node TPR,
		uartPacketPtr->field5 = ( uint16_t ) logPktNum[ID +1]; //node PRR
		uartPacketPtr->field2 = logTotalPktNum[ID+1]; //node TPR
		uartPacketPtr->field6 = ( uint16_t ) logPktNum[ID+2]; //node PRR,
		uartPacketPtr->field3 = logTotalPktNum[ID+2]; //node TPR,
		// uartPacketPtr->field7 = numberOfResets;
		dbg("Serial","%s:generated a serial packet notifying of packet reception.\n", __FUNCTION__);
		call SafeSerialSendIF.queueMessageBuffer(messagePtr);
	}

	
# endif




	event void logTimer.fired(){
		
				
		int i;
		double th;
		th = throught;
		logTH(throught, log_period);
		throught = 0;

# ifdef TOSSIM

		if(TOS_NODE_ID==18)
		dbg("logfile","throughput at root is %f.\n", th*1000/);
# endif

		for(i=1;i<num_nodes+1;i=i+3) {
//			if(TOS_NODE_ID !=i){
//				if((logPktNum[i] != 0)||(logPktNum[i+1] != 0)||(logPktNum[i+2] != 0)){
					logPRR(i, logPktNum[i],logTotalPktNum[i]);
# ifdef TOSSIM
		
					if(TOS_NODE_ID==18)
						dbg("logfile","recv from %d total %d\n",i+1,logPktNum[i]);
# endif
//				}
//			}
		//	logPktNum[i] = 0;
		//	logPktNum[i+1] = 0;
		//	logPktNum[i+2] = 0;
		}
		firstReception_flag = FALSE;
		call logTimer.startOneShot(log_period);

	}


//////////////////////////////////////////////////////////////////////////////////////////////
	event void RadioControl.startDone(error_t err) {

		if (err != SUCCESS) {    
			call RadioControl.start();
		} 
		else {
			call ProtoControl.start();
		}

# ifdef LOW_POWER_LISTENING

		//  call LPL.setLocalSleepInterval(LPL_SLEEP_INTERVAL_MS);
		call LPL.setLocalWakeupInterval(LPL_SLEEP_INTERVAL_MS);
# endif
	}

	event void RadioControl.stopDone(error_t err) {
		// Radio has been shut down
		// not implemented
	}


////////////////////////////////////////////////////////////////////////////////////////////////////


	void sendMessage() {
	
		stationDataMsg * sendingData;
		error_t err;
		message_t* messagePtr;
		UartPacket* uartPacketPtr;

		// Send a packet to Bcp

		sendingData = call Packet.getPayload(&packet, sizeof(stationDataMsg));
		call Packet.setPayloadLength(&packet, sizeof(stationDataMsg));

# if PROTO_BCP
	
		call BcpPacket.setOrigin(&packet, call AMPacket.address());
# else

		call CtpPacket.setOrigin(&packet, call AMPacket.address());
# endif

		// populate packet fields
		// sendingData->stationID = stationData.stationID;
		// sendingData->beaconID = stationData.beaconID;
		// sendingData->sequence = stationData.sequence;
		// sendingData->RSSI = stationData.RSSI;

		sendingData->sourceID = TOS_NODE_ID;
		sendingData->sequenceID = sequence;
	//	sendingData->dispatchTime = lastReception;// call Timer.getNow();

//#if PROTO_CTP

# ifdef LOW_POWER_LISTENING
		
		// call LPL.setRxSleepInterval(&packet, LPL_SLEEP_INTERVAL_MS);
		call LPL.setRemoteWakeupInterval(&packet, LPL_SLEEP_INTERVAL_MS);
# endif

//  #endif
		err = call Send.send(&packet, sizeof(stationDataMsg)); 
		
		if(err == SUCCESS){
			call Leds.led1Toggle();
			sequence++;
		}
		else{
			// sequence++;
			messagePtr = call SafeSerialSendIF.getMessageBuffer();
			uartPacketPtr = (UartPacket *) call SafeSerialSendIF.getPayload(messagePtr, sizeof(UartPacket));
			uartPacketPtr->time = 0x00;
			uartPacketPtr->field1 = err;
			uartPacketPtr->field2 = ESIZE;
			uartPacketPtr->field3 = EBUSY;
			uartPacketPtr->field4 = EOFF;
			uartPacketPtr->field5 = FAIL;
			uartPacketPtr->field6 = sequence;
			uartPacketPtr->field7 = 0x00;
			uartPacketPtr->field8 = 0x00;
			uartPacketPtr->type = SEND_ERROR_TYPE;

			call SafeSerialSendIF.queueMessageBuffer(messagePtr);
		}
	}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


	event void Timer.fired() {


		if(TOS_NODE_ID != 18){ 
			if(sequence<num_packets){
				sendMessage();
				call Timer.startOneShot(send_period);
				
			}
		}
	}

//Only when you need a mobile Sink on a Testbed

/*	event void sinkTimer.fired(){
		if(TOS_NODE_ID == 18)
			call RootControl.setRoot();
		else{
			call RootControl.unsetRoot();
		}
	}

*/

	event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len) {

# ifdef REC_PAC		
		message_t *  messagePtr;
		UartPacket * uartPacketPtr;
# endif

		stationDataMsg * receivedData = (stationDataMsg*)(payload);

		// Book Keeping of the received packets.

		
		if(bitRead(receivedData->sourceID, receivedData->sequenceID) == FALSE){
			
			logPktNum[receivedData->sourceID]++;			
			throught+=1;
			bitWrite(receivedData->sourceID, receivedData->sequenceID);
			netPackRec+=1;
		}
		logTotalPktNum[receivedData->sourceID]++;
		totalPackRec+=1;
		

		lastReception = call logTimer.getNow();
		if(firstReception_flag == FALSE){
			firstReception = lastReception;
			firstReception_flag = TRUE;
		}
		//  call Leds.led1Toggle();

# ifdef REC_PAC
		

		messagePtr = call SafeSerialSendIF.getMessageBuffer();
		
		if( messagePtr == 0 ){
			return msg;
		}

		
		if( TOS_NODE_ID == 18 ){


			uartPacketPtr = (UartPacket *) call SafeSerialSendIF.getPayload(messagePtr, sizeof(UartPacket));
			
			// if(uartPacketPtr == NULL)
				// call Leds.led2On();

			uartPacketPtr->time = lastReception;
			uartPacketPtr->field1 = receivedData->sequenceID;
			uartPacketPtr->field2 = 0x00;
			uartPacketPtr->field3 = call Timer.getNow();

#ifdef PROTO_BCP
			uartPacketPtr->field4 = call BcpPacket.getTxCount(msg);
			uartPacketPtr->field5 = call BcpPacket.getHopCount(msg);
#else
			uartPacketPtr->field4 = call CtpPacket.getTxCount(msg);
			uartPacketPtr->field5 = call CtpPacket.getHopCount(msg);
#endif

			uartPacketPtr->field6 = 0x00;
			uartPacketPtr->field7 = receivedData->sourceID;
			uartPacketPtr->field8 = 0x00; //receivedData->beaconID;
			uartPacketPtr->type = SINK_RECEIVE_TYPE;
			call SafeSerialSendIF.queueMessageBuffer(messagePtr);

		}
# endif

		return msg;
	}

	
	event void Send.sendDone(message_t *msg, error_t error){
	
	// not implemented   
	
	}



	event message_t* UartReceive.receive(message_t* bufPtr_p, void* payload_p,uint8_t len_p) {

		
		message_t* messagePtr;
		UartPacket* uartPacketPtr;
		
		int i,j;

		if( len_p != sizeof(UartPacket) ) {return bufPtr_p;}
		
		uartPacketPtr = (UartPacket*)payload_p;
		
		if( uartPacketPtr->type == TYPE_START ){ 
		
			// Start packet received, begin the Timer (first time give us 10 seconds to start)
			//startTestTime = call Timer.getNow();
			send_period = uartPacketPtr->field1;
			num_nodes = uartPacketPtr->field2;
			num_packets = uartPacketPtr->field3;
			firstReception_flag = FALSE;
			netPackRec = 0;
			totalPackRec = 0;
			logRound = 0;
			sequence = 0;
			//numberOfResets = 0;
			for(i=0;i<num_nodes+1;i++) {
		    		logPktNum[i] = 0;
				logTotalPktNum[i] = 0;
				for(j=0;j<MAX_PKTFLAGS+1;j++){
					pktFlag[i][j] = 0;
				}
			}

			call Timer.startOneShot(10000); // Wait 10 seconds to start 
			// call sinkTimer.startPeriodic(1000); // Begin sink mobility recurring timer
			log_period = 10*send_period;
			call logTimer.startOneShot(10000 + log_period); //Begin logging Data
			
		}
		else if( uartPacketPtr->type == TYPE_SYNC ){
			// Stop time Sync
			//call TimeSyncMode.setMode(TS_USER_MODE);
		}
		else if( uartPacketPtr->type == TYPE_STOP ){
			// Stop traffic Timer and reset counter
			call Timer.stop();
			call logTimer.stop();
			count = 0;
			commandCount = 0;
			commandCountAckCount = 0;
		}
		else if( uartPacketPtr->type == TYPE_SYNC_SET ){
			// Start time Sync
			//call TimeSyncMode.setMode(TS_TIMER_MODE);
		}
		else if( uartPacketPtr->type == TYPE_RESET ){
			// reset experiment, set command count to zero
			//call TimeSyncMode.setMode(TS_TIMER_MODE);
			call Timer.stop();
			call logTimer.stop();
			commandCount = 0;
			commandCountAckCount = 0;
			count = 0;
		}


		
		// After receiving a UartPacket, update commandCount and send a response
		commandCount = uartPacketPtr->field8;

		messagePtr = call SafeSerialSendIF.getMessageBuffer();

		if( messagePtr == 0 )
			return bufPtr_p;
		
		uartPacketPtr = (UartPacket *) call SafeSerialSendIF.getPayload(messagePtr, sizeof(UartPacket));
			
		if( uartPacketPtr == NULL )
			dbg("Error", "%s:uartPacketPtr is NULL! Packet size error?\n",__FUNCTION__);
		
		uartPacketPtr->type = UART_ACK_TYPE;
		uartPacketPtr->field8 = commandCount;

		call SafeSerialSendIF.queueMessageBuffer(messagePtr);

		return bufPtr_p;
	}


//////////////////////////////////////////////DE-BUG COMMANDS FOR BCP and CTP /////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////



# if PROTO_BCP

		command void BcpDebugIF.reportBackpressure(uint32_t dataQueueSize_p, uint32_t virtualQueueSize_p, uint16_t localTXCount_p, uint8_t origin_p,uint8_t originSeqNo_p, uint8_t reportSource_p){

# if DBG_NET

		message_t* messagePtr;
		UartPacket* uartPacketPtr;

		// Send a serial packet notifying of packet admission
		messagePtr = call SafeSerialSendIF.getMessageBuffer();

		if( messagePtr == 0 )
			return;

		uartPacketPtr = (UartPacket *) call SafeSerialSendIF.getPayload(messagePtr, sizeof(UartPacket));
	
		if( uartPacketPtr == NULL )
			dbg("Error", "%s:uartPacketPtr is NULL! Packet size error?\n",__FUNCTION__);

		uartPacketPtr->type = 0x03;
		uartPacketPtr->field1 = dataQueueSize_p;
		uartPacketPtr->field2 = virtualQueueSize_p;
		uartPacketPtr->field3 = localTXCount_p;
		uartPacketPtr->field6 = origin_p;
		uartPacketPtr->field7 = originSeqNo_p;
		uartPacketPtr->field8 = reportSource_p;
		uartPacketPtr->time = call Timer.getNow();

		call SafeSerialSendIF.queueMessageBuffer(messagePtr);

# endif
	}

	command void BcpDebugIF.reportError( uint8_t type_p ){
	
# if DBG_NET
	
		message_t* messagePtr;
		UartPacket* uartPacketPtr;

		// Send a serial packet notifying of packet admission
		messagePtr = call SafeSerialSendIF.getMessageBuffer();
		
		if( messagePtr == 0 )
			return;
	
		uartPacketPtr = (UartPacket *) call SafeSerialSendIF.getPayload(messagePtr, sizeof(UartPacket));
			
		if( uartPacketPtr == NULL )
			dbg("Error", "%s:uartPacketPtr is NULL! Packet size error?\n",__FUNCTION__);

		uartPacketPtr->type = 0x0F;
		uartPacketPtr->field8 = type_p; 
		uartPacketPtr->time = call Timer.getNow();

		call SafeSerialSendIF.queueMessageBuffer(messagePtr);

# endif
	}

	command void BcpDebugIF.reportLinkRate(uint8_t neighbor_p, uint16_t previousLinkPacketTxTime_p, 
				 uint16_t updateLinkPacketTxTime_p, uint16_t newLinkPacketTxTime_p,
				 uint16_t latestLinkPacktLossEst_p){

# if DBG_NET

		message_t* messagePtr;
		UartPacket* uartPacketPtr;

		// Send a serial packet notifying of packet admission
		messagePtr = call SafeSerialSendIF.getMessageBuffer();

		if( messagePtr == 0 )
			return;
		
		uartPacketPtr = (UartPacket *) call SafeSerialSendIF.getPayload(messagePtr, sizeof(UartPacket));
		
		if( uartPacketPtr == NULL )
			dbg("Error", "%s:uartPacketPtr is NULL! Packet size error?\n",__FUNCTION__);
		
		uartPacketPtr->type = 0x04;
		uartPacketPtr->field1 = latestLinkPacktLossEst_p;
		uartPacketPtr->field2 = 0x0000;
		uartPacketPtr->field3 = 0x0000;
		uartPacketPtr->field4 = previousLinkPacketTxTime_p;
		uartPacketPtr->field5 = updateLinkPacketTxTime_p;
		uartPacketPtr->field6 = newLinkPacketTxTime_p;
		uartPacketPtr->field7 = 0x00;
		uartPacketPtr->field8 = neighbor_p;
		uartPacketPtr->time = call Timer.getNow();

		call SafeSerialSendIF.queueMessageBuffer(messagePtr);

# endif

	}

	command void BcpDebugIF.reportValues(uint32_t field1_p, uint32_t field2_p, uint32_t field3_p, uint16_t field4_p,
		      uint16_t field5_p, uint16_t field6_p, uint8_t field7_p, uint8_t field8_p){

# if DBG_NET

		message_t* messagePtr;
		UartPacket* uartPacketPtr;

		messagePtr = call SafeSerialSendIF.getMessageBuffer();
		if( messagePtr == 0 )
			return;
		
		uartPacketPtr = (UartPacket *) call SafeSerialSendIF.getPayload(messagePtr, sizeof(UartPacket));
		if( uartPacketPtr == 0 )
			dbg("Error", "%s:uartPacketPtr is NULL! Packet size error?\n",__FUNCTION__);
	
		uartPacketPtr->type = 0x10;
		uartPacketPtr->field1 = field1_p;
		uartPacketPtr->field2 = field2_p;
		uartPacketPtr->field3 = field3_p;
		uartPacketPtr->field4 = field4_p;
		uartPacketPtr->field5 = field5_p;
		uartPacketPtr->field6 = field6_p;
		uartPacketPtr->field7 = field7_p;
		uartPacketPtr->field8 = field8_p;
		uartPacketPtr->time = call Timer.getNow();

		call SafeSerialSendIF.queueMessageBuffer(messagePtr);

# endif
	} 


# else


	/* Log the occurrence of an event of type type */
	command error_t CollectionDebug.logEvent(uint8_t type){

# if DBG_NET

		message_t* messagePtr;
		UartPacket* uartPacketPtr;
		
		if( type == NET_C_FE_SEND_QUEUE_FULL ){
			// Send a serial packet notifying of queue size
			messagePtr = call SafeSerialSendIF.getMessageBuffer();
			
			if( messagePtr == 0 )
				return FAIL;
			
			uartPacketPtr = (UartPacket *) call SafeSerialSendIF.getPayload(messagePtr, sizeof(UartPacket));
			
			if( uartPacketPtr == NULL )
				dbg("Error", "%s:uartPacketPtr is NULL! Packet size error?\n",__FUNCTION__);

			uartPacketPtr->type = 0x20;
			uartPacketPtr->field1 = 0x00000000;
			uartPacketPtr->field2 = 0x00000000;
			uartPacketPtr->field3 = 0x0000;
			uartPacketPtr->field4 = 0x0000;
			uartPacketPtr->field5 = 0x0000;
			uartPacketPtr->field6 = 0x00;
			uartPacketPtr->field7 = 0x00;
			uartPacketPtr->field8 = 0xD0;

			uartPacketPtr->time = call Timer.getNow();

			call SafeSerialSendIF.queueMessageBuffer(messagePtr);
		}

# endif
		return SUCCESS;
	}

	
	/* Log the occurrence of an event and a single parameter */
	command error_t CollectionDebug.logEventSimple(uint8_t type, uint16_t arg){
	
		return SUCCESS;
	}

	
	/* Log the occurrence of an event and 3 16bit parameters */
	command error_t CollectionDebug.logEventDbg(uint8_t type, uint16_t arg1, uint16_t arg2, uint16_t arg3){

# if DBG_NET
	
		message_t* messagePtr;
		UartPacket* uartPacketPtr;
		
		if( type == NET_C_Q_SIZE || type == NET_C_TXCOUNT || NET_C_TREE_NEW_PARENT){
			// Send a serial packet notifying of queue size
			messagePtr = call SafeSerialSendIF.getMessageBuffer();
			if( messagePtr == 0 )
				return FAIL;
			
			uartPacketPtr = (UartPacket *) call SafeSerialSendIF.getPayload(messagePtr, sizeof(UartPacket));
			if( uartPacketPtr == NULL )
				dbg("Error", "%s:uartPacketPtr is NULL! Packet size error?\n",__FUNCTION__);

			if( type == NET_C_Q_SIZE ){
				uartPacketPtr->type = 0x03;
			} 
			else if( type == NET_C_TREE_NEW_PARENT ){
				uartPacketPtr->type = 0x09;
			}
			else {
				uartPacketPtr->type = 0x07;
			} 
			
			uartPacketPtr->field1 = arg3;
			uartPacketPtr->field2 = arg2;
			uartPacketPtr->field3 = 0x0000;
			uartPacketPtr->field4 = 0x0000;
			uartPacketPtr->field5 = 0x0000;
			uartPacketPtr->field6 = 0x0000;
			uartPacketPtr->field7 = 0x0000;
			uartPacketPtr->field8 = 0x0000;
			uartPacketPtr->time = call Timer.getNow();

			call SafeSerialSendIF.queueMessageBuffer(messagePtr);

		}
		
# endif
		return SUCCESS;
	} 

	/* Log the occurrence of an event related to forwarding a message.
	* This is intended to allow following the same message as it goes from one
	* hop to the next
	*/
	
	command error_t CollectionDebug.logEventMsg(uint8_t type, uint16_t msg, am_addr_t origin, am_addr_t node){

# if DBG_NET

		message_t* messagePtr;
		UartPacket* uartPacketPtr;
		if( type == NET_C_FE_SENT_MSG || type == NET_C_FE_FWD_MSG ){
			// Send a serial packet notifying of packet admission
			messagePtr = call SafeSerialSendIF.getMessageBuffer();
		
			if( messagePtr == 0 )
				return FAIL;
			
			uartPacketPtr = (UartPacket *) call SafeSerialSendIF.getPayload(messagePtr, sizeof(UartPacket));
			
			if( uartPacketPtr == NULL )
				dbg("Error", "%s:uartPacketPtr is NULL! Packet size error?\n",__FUNCTION__);
			
			uartPacketPtr->type = 0x04;
			uartPacketPtr->field1 = 0x0000;
			uartPacketPtr->field2 = 0x0000;
			uartPacketPtr->field3 = 0x0000;
			uartPacketPtr->field4 = 0x0000;
			uartPacketPtr->field5 = msg;
			uartPacketPtr->field6 = origin;
			uartPacketPtr->field7 = 0x00;
			uartPacketPtr->field8 = node;
			uartPacketPtr->time = call Timer.getNow();

			call SafeSerialSendIF.queueMessageBuffer(messagePtr);

		}
# endif
		return SUCCESS;
	}

	/* Log the occurrence of an event related to a route update message,
	* such as a node receiving a route, updating its own route information,
	* or looking at a particular entry in its routing table.
	*/

	command error_t CollectionDebug.logEventRoute(uint8_t type, am_addr_t parent_p, uint8_t hopcount, uint16_t metric){

# if DBG_NET
	
		message_t* messagePtr;
		UartPacket* uartPacketPtr;

		if( type == NET_C_TREE_SENT_BEACON && call Timer.isRunning()){
		
			// Send a serial packet notifying of Beacon
			messagePtr = call SafeSerialSendIF.getMessageBuffer();
			if( messagePtr == 0 )
				return FAIL;
			
			uartPacketPtr = (UartPacket *) call SafeSerialSendIF.getPayload(messagePtr, sizeof(UartPacket));
			
			if( uartPacketPtr == NULL )
				dbg("Error", "%s:uartPacketPtr is NULL! Packet size error?\n",__FUNCTION__);
			
			uartPacketPtr->type = 0x20;
			uartPacketPtr->field1 = 0x0000;
			uartPacketPtr->field2 = 0x0000;
			uartPacketPtr->field3 = 0x0000;
			uartPacketPtr->field4 = 0x0000;
			uartPacketPtr->field5 = metric;
			uartPacketPtr->field6 = hopcount;
			uartPacketPtr->field7 = parent_p;
			uartPacketPtr->field8 = type;
			uartPacketPtr->time = call Timer.getNow();

			call SafeSerialSendIF.queueMessageBuffer(messagePtr);

		}
# endif
		return SUCCESS;
	}

	event message_t* DataSnoop.receive(message_t* msg, void *payload, uint8_t len){ 

# if DBG_NET

		uint16_t loopCount = 0;
		uint16_t loopSum = 0;

		// Checking to see whether CTP performance degrades under snoop usage.
		
		for( loopCount = 0; loopCount < 100; loopCount++ ){
			loopSum += loopCount;
		}

# endif
		return msg;
	}
 
# endif

}


