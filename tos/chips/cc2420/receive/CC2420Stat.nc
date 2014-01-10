interface CC2420Stat {
	async command void incr_recv();
	async command void set_recv(uint32_t recv);
	command uint32_t get_recv();

	async command void incr_recv_done();
	async command void set_recv_done(uint32_t recv_done);
	command uint32_t get_recv_done();

	async command void incr_ack_sent();
	async command void set_ack_sent(uint32_t ack_sent);
	command uint32_t get_ack_sent();

	async command void incr_flush();
	async command void set_flush(uint32_t flush);
	command uint32_t get_flush();

	async command void incr_txfifo();
	async command void set_txfifo(uint32_t flush);
	command uint32_t get_txfifo();

	async command void incr_txsend();
	async command void set_txsend(uint32_t flush);
	command uint32_t get_txsend();
	/*async command void incr_recv();
	async command uint32_t get_recv();

	async command void incr_recv_done();
	async command uint32_t get_recv_done();

	async command void incr_ack_sent();
	async command uint32_t get_ack_sent();

	async command void incr_flush();
	async command uint32_t get_flush();*/

}
