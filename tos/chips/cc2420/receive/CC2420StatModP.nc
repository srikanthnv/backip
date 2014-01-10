module CC2420StatModP {
	provides {
		interface CC2420Stat;
	}
}implementation {

	norace uint32_t recv = 0;
	norace uint32_t flush = 0;
	norace uint32_t recv_done = 0;
	norace uint32_t ack_sent = 0;
	norace uint32_t txfifo = 0;
	norace uint32_t txsend = 0;

//#define FN_INCR(FIELD) async command void CC2420Stat.incr_##FIELD() { ++FIELD; }
//#define FN_GET(FIELD) async command uint32_t CC2420Stat.get_##FIELD() { return FIELD; }
//#define FN_INCR(FIELD) async command void CC2420Stat.incr_##FIELD() { atomic {++FIELD; }}
//#define FN_GET(FIELD) async command uint32_t CC2420Stat.get_##FIELD() { atomic {return FIELD; }}
#define FN_INCR(FIELD) async command void CC2420Stat.incr_##FIELD() { ++FIELD; }
#define FN_SET(FIELD) async command void CC2420Stat.set_##FIELD(uint32_t x) {FIELD=x; }
#define FN_GET(FIELD) command uint32_t CC2420Stat.get_##FIELD() { return FIELD; }

	FN_INCR(recv);
	FN_INCR(flush);
	FN_INCR(recv_done);
	FN_INCR(ack_sent);
	FN_SET(recv);
	FN_SET(flush);
	FN_SET(recv_done);
	FN_SET(ack_sent);
	FN_GET(recv);
	FN_GET(flush);
	FN_GET(recv_done);
	FN_GET(ack_sent);

	FN_INCR(txfifo);
	FN_SET(txfifo);
	FN_GET(txfifo);
	FN_INCR(txsend);
	FN_SET(txsend);
	FN_GET(txsend);

}
