interface BeaconQueueInterface {

	/* Tell queueing component that a beacon is about to be sent */
	command void SendingBeacon();

	/* Return current backpressure value */
	command uint32_t GetBackpressure();

	/* Return last signaled backpressure value */
	command uint32_t GetLastBackpressure();

	/* Set current best neighbour */
	command void setNeighbour(ll_addr_t *nb_ll);

	/* Set current best neighbour */
	command uint32_t GetSendStats(send_stats_t *st);
}

