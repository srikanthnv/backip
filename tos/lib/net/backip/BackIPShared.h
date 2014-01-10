#ifndef __BACKIPSHARED_H__
#define __BACKIPSHARED_H__
typedef struct {
	uint16_t stat_sent_total;
	uint16_t stat_sent_null;
	uint16_t stat_sent_success;
	uint16_t stat_dropped_q;
	uint16_t stat_dropped_fail;
	uint16_t stat_dropped_cond;
	uint16_t stat_recvd_total;
} send_stats_t;

#endif
