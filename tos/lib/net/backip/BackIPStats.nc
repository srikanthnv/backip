/**
 * This is an implementation of Backpressure based routing over BLIP,
 * based on the concepts in the Backpressure collection protocol
 *
 * @author Srikanth Nori <snori@usc.edu>
 */

#include "BackIPShared.h"

typedef struct {
	uint32_t backpressure;
	uint32_t last_backpressure;
	ieee154_addr_t ll_addr;
	uint8_t num_curr_neighbours;
	send_stats_t send_stats;
	struct {
		ieee154_addr_t ll_addr;
		uint32_t backpressure;
		uint16_t ETX;
		uint16_t tx_time;
	} nb[0x30];
} backip_stats_t;

interface BackIPStats {

	command void getCurrStats(backip_stats_t *stats);
}

