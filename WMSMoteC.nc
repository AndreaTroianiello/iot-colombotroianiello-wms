#include "wmsMsg.h"

module WMSMoteC {

    uses {
	    interface Boot;    
	    interface Read<uint8_t>;
       	interface Random;
        interface Timer<TMilli> as TruckTimer;
        interface Timer<TMilli> as AlertTimer;
        interface Timer<TMilli> as MoveTrashTimer;
        
        interface SplitControl;    	
        
        //TRUCK Channel
        interface AMPacket as TAMPacket; 
	    interface Packet as TPacket;
	    interface AMSend as TSChannel;
        interface Receive as TRChannel;

        //TRUCK Channel
        interface AMPacket as BAMPacket; 
	    interface Packet as BPacket;
	    interface AMSend as BSChannel;
        interface Receive as BRChannel;

        interface PacketAcknowledgements;
    }

} implementation {
    // Global constants
    const uint16_t MAX_X = 2000;
    const uint16_t MAX_Y = 2000;
    const uint8_t ALPHA_BIN = 1;
    const uint8_t ALPHA_TRUCK = 60;

    // Bin related constants
    const uint8_t CRITICAL = 85;
    const uint8_t FULL = 100;

    // Global variables
    uint16_t x,y;
    bool bin;
    message_t bpacket;
    message_t tpacket;
    uint16_t distance;
    uint16_t node_d;

    // Bin related variables
    uint8_t trash_level;
    uint8_t extra_trash;
    // 0 = normal mode, 1 = alert mode, 2 = full mode
    uint8_t bin_mode;
    bool alerting;
    bool redirecting; 
    uint16_t min_distance;

    //Truck related variables
    bool moving;

    void init();
    void initBin();
    void initTruck();
    void computeDistance(uint16_t x2, uint16_t y2);
    uint32_t computeTravelTime();

    task void sendAlert();
    task void emptyTrash();
    task void signalArrival();
    task void askToNeighbours();


    event void Boot.booted() {
	    dbg("boot","Bin booted.\n");
        call SplitControl.start();
        init();

        if(TOS_NODE_ID >0){
            initBin(); 
            call Read.read();
            dbg("init","Started reading from sensor %i\n", TOS_NODE_ID);
        }else{
            dbg("init","Truck initialized\n");
            initTruck();
        }    
    }

    event void SplitControl.startDone(error_t err){
        if(err == SUCCESS) {
	        dbg("radio","Radio on!\n\n\n\n\n");
        }
        else{
            dbgerror("radio","something went wrong\n");
            call SplitControl.start();
        }
    }
  
    event void SplitControl.stopDone(error_t err){}


    void init(){
        x = call Random.rand16() % MAX_X;
        y = call Random.rand16() % MAX_Y;
        distance = 0;
        node_d = 0;
        dbg("init", "Bin location is (%i, %i)\n",x,y);
    }

    void initTruck(){
        moving=FALSE;
        bin=FALSE;
    }

    void initBin(){
        trash_level = 0;
        extra_trash = 0;
        bin_mode = 0;
        min_distance=0;
        alerting = FALSE;
        redirecting = FALSE;
        bin=TRUE;
    }

    void computeDistance(uint16_t x2, uint16_t y2){
        uint32_t xs= (x-x2)*(x-x2);
        uint32_t ys= (y-y2)*(y-y2);
        distance = sqrt(xs+ys);
    }

    uint32_t computeTravelTime(){
        if(bin)
            return ALPHA_BIN*distance;
        return ALPHA_TRUCK*distance;
    }
   
    event void Read.readDone(error_t result, uint8_t data) {
        if(result == SUCCESS){
            dbg("bin","Attempt to ADD %i UNITS to the bin at time %s\n",data,sim_time_string());
            if(bin_mode == 0){
                trash_level += data;
                if(trash_level >= CRITICAL) {
                    bin_mode = 1;
                    call AlertTimer.startOneShot(1000);
                    dbg("bin","TRASH LEVEL: %i\n", trash_level);
                    dbg("bin","STATUS: CRITICAL\n");
                }
                if((trash_level-data) == 0){
                    dbg("bin","TRASH LEVEL: %i\n", trash_level);
                    dbg("bin","STATUS: NORMAL\n");
                }

            }else if(bin_mode == 1){
                trash_level += data;
                if(trash_level >= FULL) {
                    bin_mode = 2;
                    extra_trash = trash_level - FULL;
                    trash_level = FULL;
                    if(extra_trash > 0){
                        post askToNeighbours();
                    }
                    dbg("bin","TRASH LEVEL: %i\n", trash_level);
                    dbg("bin","STATUS: FULL\n");
                    dbg("bin","TRASH OUTSIDE: %i\n", extra_trash);
                }
            }else if(bin_mode==2){
                extra_trash += data;
                if(redirecting == FALSE){
                    post askToNeighbours();
                }
                dbg("bin","TRASH OUTSIDE: %i\n", extra_trash);
            }    
            dbg_clear("bin","\n\n");    
        }      
    }

    task void sendAlert(){
        alert_msg_t* msg = (alert_msg_t*)(call TPacket.getPayload(&tpacket, sizeof(alert_msg_t)));
        msg->msg_type = ALERT;
        msg->node_id = TOS_NODE_ID;
        msg->node_x = x;
        msg->node_y = y;

        call PacketAcknowledgements.requestAck(&tpacket);

        if(call TSChannel.send(0,&tpacket,sizeof(alert_msg_t)) == SUCCESS){
            dbg("radio","Sending alert message to the truck\n");
        }
    }

    task void emptyTrash(){
        bin_mode=0;
        trash_level=0;
        extra_trash=0;
        alerting=FALSE;
        redirecting = FALSE;
        dbg("bin","Truck arrived at time %s\n",sim_time_string());
        dbg("bin","BIN EMPTIED, new level: %i\n",trash_level);
    }

    task void signalArrival(){
        truck_msg_t* msg = (truck_msg_t*) (call TPacket.getPayload(&tpacket,sizeof(truck_msg_t)));
        msg->msg_type=TRUCK;
        msg->success=1;
        call PacketAcknowledgements.requestAck(&tpacket);
        call TSChannel.send(node_d,&tpacket,sizeof(truck_msg_t));
        moving=FALSE;

    }

    task void askToNeighbours(){
        move_msg_t* msg = (move_msg_t*) (call BPacket.getPayload(&bpacket,sizeof(move_msg_t)));
        redirecting = TRUE;
        msg->msg_type=MOVE;
        msg->node_id = TOS_NODE_ID;
        call PacketAcknowledgements.noAck(&bpacket);
        if(call BSChannel.send(AM_BROADCAST_ADDR,&bpacket,sizeof(move_msg_t)))
        call MoveTrashTimer.startOneShot(2000);
        min_distance= 0;
        node_d=0;
    }


    event void TruckTimer.fired(){
        post signalArrival();
        dbg("truck","Reached destination at (%i,%i)\n",x,y);
        dbg("truck","Bin %i emptied\n",node_d);
    }
    
    event void AlertTimer.fired(){
        if(bin_mode > 0){
            post sendAlert();
            if(alerting == FALSE){
                call AlertTimer.startPeriodic(10000);
                alerting = TRUE;
            }
        }else{
            call AlertTimer.stop();
        }
    }

    event void MoveTrashTimer.fired(){
        if(redirecting == TRUE){
            if(node_d > 0){
                post MoveTrash();
            }else{
                extra_trash = 0;
                redirecting = FALSE;
            }

        }
    }

    task void MoveTrash(){
        if(redirecting==TRUE){
            move_msg_t* resp = (move_msg_t*) (call BPacket.getPayload(&bpacket,sizeof(move_msg_t)));
            resp->msg_type=MVTRASH;
            resp->node_id = TOS_NODE_ID;
            resp->trash = extra_trash;
            call PacketAcknowledgements.requestAck(&bpacket);
            call BSChannel.send(node_d, &bpacket, sizeof(move_msg_t));
        }
    }

    event void TSChannel.sendDone(message_t* buf,error_t err) {
        if(&tpacket == buf && err == SUCCESS){
            if(bin == TRUE){
                if (call PacketAcknowledgements.wasAcked(buf)) {
                    dbg("radio","Truck received the message and acknowledged\n\n\n");
                }else{
                    dbg("radio","Truck did not acknowledge the message\n\n\n");
                }
            }else{
                if (call PacketAcknowledgements.wasAcked(buf)) {
                    dbg("radio","Bin received the message and acknowledged\n\n\n");
                    moving = FALSE;
                }else{
                    dbg("radio","Bin did not acknowledge the message\n\n\n");
                    post signalArrival();
                }
            }
        }else{
            if(bin != TRUE){
                post signalArrival();
            }
        }
    }
 
    event message_t* TRChannel.receive(message_t* buf,void* payload, uint8_t len) {
            if(bin == FALSE){
                if(moving == FALSE){
                    alert_msg_t* msg = (alert_msg_t*)payload;
                    uint32_t travel_time;
                    moving=TRUE;
                    computeDistance(msg->node_x,msg->node_y);
                    node_d = msg->node_id;
                    travel_time = computeTravelTime();
                    call TruckTimer.startOneShot(travel_time);
                    x = msg->node_x;
                    y = msg->node_y;
                    dbg("truck","Received ALERT message from %i\n",node_d);
                    dbg("truck","Distance to bin is %i m\n",distance);
                    dbg("truck","Started traveling to (%i,%i)\n",x,y);
                    dbg("truck", "Expected travel time: %ims\n",travel_time);
                }
            }else{
                post emptyTrash();
            }
        return buf;
    }

    event void BSChannel.sendDone(message_t* buf,error_t err) {
        if(buf == &bpacket){
            move_msg_t* msg = (move_msg_t*) buf;
            if(msg->msg_type == 5){
                if(call PacketAcknowledgements.wasAcked(&bpacket)){
                    extra_trash = 0;
                    redirecting = FALSE;
                }else{
                    post MoveTrash();
                }
            }
        }
    }
 
    event message_t* BRChannel.receive(message_t* buf,void* payload, uint8_t len) {
        if(bin == TRUE){
             move_msg_t* msg = (move_msg_t*) payload;
                if(msg->msg_type == MOVE){
                    if(bin_mode == 0){
                        move_msg_t* resp = (move_msg_t*) (call BPacket.getPayload(&bpacket,sizeof(move_msg_t)));
                        resp->msg_type=BINRES;
                        resp->node_id = TOS_NODE_ID;
                        resp->node_x = x;
                        resp->node_y = y;
                        call PacketAcknowledgements.noAck(&bpacket);
                        call BSChannel.send(msg->node_id, &bpacket, sizeof(move_msg_t));
                    }
                }else if(msg->msg_type == BINRES){
                    if(redirecting == TRUE){
                        computeDistance(msg->node_x,msg->node_y);
                        if((min_distance > 0 && distance < min_distance) || min_distance == 0){
                            min_distance = distance;
                            node_d = msg->node_id;
                        }
                    }
                } else if(msg->msg_type == 5){
                    
                }
        }
           
        return buf;
    }

}
