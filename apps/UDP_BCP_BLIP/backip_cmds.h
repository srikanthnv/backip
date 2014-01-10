#ifndef __BACKIP_CMDS_H__
#define __BACKIP_CMDS_H__

enum {
	AM_BACKIP_MSG_T = 0x89,
};

typedef struct backip_msg_t  {
	nx_uint8_t sender;
	nx_uint32_t ctr;
	nx_uint32_t recv_time;
	nx_uint32_t delay;
} __attribute__((packed)) backip_msg_t;

#endif __BACKIP_CMDS_H__
