interface BackIPFlag {

	command void setFlag(uint32_t flag);
	command void clearFlag();
	event void flagPacket(uint32_t pkt_id);
}

