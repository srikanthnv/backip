#ifndef __BACKIP_CMDS_H__
#define __BACKIP_CMDS_H__

enum {
	AM_MSG_T = 0x89,
};

typedef struct msg_t  {
	nx_uint32_t st;
	nx_uint32_t end;
	nx_uint32_t diff;
	nx_uint32_t ctr;
} __attribute__((packed)) msg_t;

#endif __BACKIP_CMDS_H__
