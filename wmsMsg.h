#ifndef WMSMSG_H
#define WMSMSG_H


typedef nx_struct alert_msg {
	nx_uint8_t msg_type; 
	nx_uint16_t node_id;
	nx_uint16_t node_x;
	nx_uint16_t node_y;
} alert_msg_t;

typedef nx_struct truck_msg{
	nx_uint8_t msg_type;
	nx_uint8_t success;
} truck_msg_t;

typedef nx_struct move_msg{
	nx_uint8_t msg_type;
	nx_uint16_t node_id;
} move_msg_t;

typedef nx_struct binres_msg{
	nx_uint8_t msg_type;
	nx_uint16_t node_id;
	nx_uint16_t node_x;
	nx_uint16_t node_y;
} binres_msg_t;

typedef nx_struct move_act_msg{
	nx_uint8_t msg_type;
	nx_uint16_t node_id;
	nx_uint8_t trash;
} move_act_msg_t;




#define ALERT 1
#define TRUCK 2
#define MOVE 3
#define BINRES 4
#define MOVEACT 5;

enum{
	AM_BIN_CHANNEL = 6
};

#endif