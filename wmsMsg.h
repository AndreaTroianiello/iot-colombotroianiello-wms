#ifndef WMSMSG_H
#define WMSMSG_H

/**
*Message used by the bin during the alert mode to communicate with the truck.
*Contains the type of the message, the id of the bin and its coordinates.
*/
typedef nx_struct alert_msg {
	nx_uint8_t msg_type; 
	nx_uint16_t node_id;
	nx_uint16_t node_x;
	nx_uint16_t node_y;
} alert_msg_t;

/**
*Message used by the truck to communicate its arrival to destination.
*If success is 1, the truck is arrived to the destination.
*/
typedef nx_struct truck_msg{
	nx_uint8_t msg_type;
	nx_uint8_t success;
} truck_msg_t;

/**
*Message used by the neighbour mode to handle the moving of the extra_trash.
*Contains the type of message, the id of the bin, its coordinates and the extra trash.
*The type can be MOVE,BINRES and MVTRASH.
*MOVE is used when the bin has extra trash and wants to send it to a neighbour.
*BINRES is used when the bin can accept other trash and commincates it to the neighbour.
*MVTRASH is used to move the extra trash between bins.
*/
typedef nx_struct move_msg{
	nx_uint8_t msg_type;
	nx_uint16_t node_id;
	nx_uint16_t node_x;
	nx_uint16_t node_y;
	nx_uint8_t trash;
} move_msg_t;

/**
*Message to communicate over the serial port.
*This message contains the information of the bin, its id, status and trash levels.
*/
typedef nx_struct serial_msg{
	nx_uint16_t node_id;
	nx_uint8_t trash_level;
	nx_uint8_t status;
	nx_uint8_t outside_trash;
} serial_msg_t;

/**
*Types of the packet used during the communication.
*/
#define ALERT 1
#define TRUCK 2
#define MOVE 3
#define BINRES 4
#define MVTRASH 5

/**
*The channels used to communicate on the radio.
*/
enum{
	//The channel used between bins.
	AM_BIN_CHANNEL = 6,
	//The channel used between truck and bin.
	AM_TRUCK_CHANNEL = 7,
};

/**
*The number port used to communicate between the bin and the terminal.
*/
enum {
AM_SERIAL_MSG = 0x89,
};

#endif