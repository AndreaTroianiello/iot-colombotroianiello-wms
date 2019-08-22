#ifndef WMSMSG_H
#define WMSMSG_H

//payload of the msg
typedef nx_struct my_msg {
	nx_uint8_t msg_type; //request or response
	nx_uint16_t msg_id;
	nx_uint16_t value;
} my_msg_t;

#define REQ 1
#define RESP 2 

enum{
AM_MY_MSG = 6,
};

#endif