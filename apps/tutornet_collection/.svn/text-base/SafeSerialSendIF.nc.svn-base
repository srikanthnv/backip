interface SafeSerialSendIF{
  /*
   * getMessageBuffer
   *  Returns a pointer to an available message_t*
   *  If no pool space is available, will return a
   *  pointer to a useless message_t*, which will
   *  be discarded upon call of queueMessageBuffer()
   */
  command message_t* getMessageBuffer();
  
  /*
   * getPayload
   *  Returns a void pointer (to be casted) to a payload
   *  of size_p bytes from the message pointer passed.
   */
  command void * getPayload(message_t* msg_p, uint8_t size_p);
  
  /*
   * queueMessageBuffer
   *  Pushes the last returned message_t* onto
   *  the SendQueue.  If the message_t* was the
   *  overflow message_t, the message will be
   *  discarded.
   */
  command void    queueMessageBuffer(message_t* sendMsg_p);
  
  /*
   * Returns the number of dropped serial messages,
   *  a serial message is dropped when the message
   *  pool is full and getMessageBuffer() is called.
   */
  command uint8_t droppedMessageCount();
}
