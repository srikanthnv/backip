interface BackIPLinkResultInterface {

	/* Update current neighbour ETX value */
	command void updateETX(ll_addr_t *ll_addr, uint16_t ETX);

	/* Update current neighbour linkRate */
	command void updateLinkRate(ll_addr_t *ll_addr, uint16_t tx_time);

	/* Find best neighbour */
	command int8_t updateNeighbour();

	/* Signal large change in local Backpressure */
	command void drasticBackpressureChange();
}

