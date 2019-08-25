#include "wmsMsg.h"

module WMSMoteC {

    uses {
	    interface Boot;    
	    interface Read<uint8_t>;
       	interface Random;
        interface Timer<TMilli> as TruckTimer;
        interface Timer<TMilli> as AlertTimer;
        interface Timer<TMilli> as MoveTrashTimer;
        interface Timer<TMilli> as MoveResTimer;
        interface Timer<TMilli> as UnlockBinTimer;
        
        interface SplitControl;    	
        
        /**
         * Interfaces used to communicate on the "truck" channel.
         * 
         */
        interface AMPacket as TAMPacket; 
	    interface Packet as TPacket;
	    interface AMSend as TSChannel;
        interface Receive as TRChannel;

        /**
         * Interfaces used to communicate on the "bin" channel.
         * This channel is used for bin-bin communications.
         * On this channel, every time a bin wants to communicate, it send a broadcast message,
         * then the following message are bin to bin in a p2p way. 
         */
        interface AMPacket as BAMPacket; 
	    interface Packet as BPacket;
	    interface AMSend as BSChannel;
        interface Receive as BRChannel;

        interface PacketAcknowledgements;
    }

} implementation {
    /**
     * Global constants used by both the bins and the truck.
     */
    const uint16_t MAX_X = 2000;
    const uint16_t MAX_Y = 2000;
    const uint8_t ALPHA_BIN = 1;
    const uint8_t ALPHA_TRUCK = 60;

    /**
     * Bin related constants and enum, they are needed only by the bin type motes.
     */
    const uint8_t CRITICAL_LEVEL = 85;
    const uint8_t FULL_LEVEL = 100;

    // An enumeration that represent the possible states of the bins.
    enum{ 
        NORMAL = 0,
        CRITICAL = 1, 
        FULL = 2
    };

    /**
     * Global variables used by both the bins and the truck.
     */
    
    uint16_t x, y, distance, node_d;
    bool bin;
    message_t tpacket;

    /**
     * Bin related variables, they are needed only by the bin type motes.
     */
    uint8_t trash_level;
    // Trash outside the bin exceeding the capacity.
    uint8_t extra_trash;
    // 0 = normal mode, 1 = alert mode, 2 = full mode, uses the enum.
    uint8_t bin_mode;
    bool alerting, redirecting; 
    uint16_t min_distance;
    message_t bpacket;

    /**
     * Truck related variables, they are needed only by the truck type motes.
     */
    bool moving;

    void init();
    void initBin();
    void initTruck();
    uint16_t computeDistance(uint16_t x2, uint16_t y2);
    uint32_t computeTravelTime();
    void addTrashNormal(uint8_t trash);
    void addTrashAlert(uint8_t trash);
    void addTrashFull(uint8_t trash);

    task void sendAlert();
    task void emptyTrash();
    task void signalArrival();
    task void askToNeighbours();
    task void moveTrash();
    task void replyAvailable();


    /**
     * The "main" method of the node. After the mote booted, it turns on the network and then calls the init methods.
     */
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
	        dbg("radio","Radio on!\n\n\n");
        }
        else{
            dbgerror("radio","something went wrong\n");
            call SplitControl.start();
        }
    }
  
    event void SplitControl.stopDone(error_t err){}

    /**
     * The "global" init method. It is used by both the truck and bin motes.
     * Randomly generates the truck coordinates and sets distance and node_d to 0.
     */
    void init(){
        x = call Random.rand16() % MAX_X;
        y = call Random.rand16() % MAX_Y;
        distance = 0;
        node_d = 0;
        dbg("init", "Bin location is (%i, %i)\n",x,y);
    }

    /**
     * The truck init method. It is used only by the truck, initializes its variables.
     */
    void initTruck(){
        moving=FALSE;
        bin=FALSE;
    }

    /**
     * The bin init method. It is used only by the bins, initializes their variables.
     */
    void initBin(){
        trash_level = 0;
        extra_trash = 0;
        bin_mode = NORMAL;
        min_distance=0;
        alerting = FALSE;
        redirecting = FALSE;
        bin=TRUE;
    }

    /** 
     * Compute the distance of this mode from the one which has coordinates x,y represented by the parameters of this method.
     * The dostance is stored in the glboal variable "distance" so that it can be reused by all the tasks.
     */
    uint16_t computeDistance(uint16_t x2, uint16_t y2){
        uint32_t xs= (x-x2)*(x-x2);
        uint32_t ys= (y-y2)*(y-y2);
        distance = sqrt(xs+ys);
        return distance;
    }

    /**
     * Compute the travel time (T-bin and T-truck)
     * To compute the travel time is multiplies the distance and the ALPHA value.
     */
    uint32_t computeTravelTime(){
        if(bin)
            return ALPHA_BIN*distance;
        return ALPHA_TRUCK*distance;
    }

    /**
     * Method used to add trash to the bin when its status is "NORMAL"
     * After adding the trash, the method checks if the status changed and in case it is needed, it starts alerting.
     */
    void addTrashNormal(uint8_t trash){
        trash_level += trash;
        if(trash_level >= CRITICAL_LEVEL) {
            bin_mode = CRITICAL;
            call AlertTimer.startOneShot(1000);
            dbg("bin","Level: %i, Status: CRITICAL\n\n",trash_level);
        }else{
             dbg("bin","Level: %i, Status: NORMAL\n\n",trash_level);
        }
    }

    /**
     * Method used to add trash to the bin when its status is "CRITICAL"
     * After adding the trash, the method checks if the status changed. 
     * In case there is the needed, it starts redirecting the trash to other bins.
     */
    void addTrashAlert(uint8_t trash){
        trash_level += trash;
        if(trash_level >= FULL_LEVEL) {
            bin_mode = FULL;
            extra_trash = trash_level - FULL_LEVEL;
            trash_level = FULL_LEVEL;
            if(extra_trash > 0){
                post askToNeighbours();
            }
            dbg("bin","Level: %i, Status: FULL, Trash outside: %i\n\n",trash_level, extra_trash);
        }else{
            dbg("bin","Level: %i, Status: CRITICAL\n\n",trash_level);
        }
    }

    /**
     * Method used to add trash to the bin when its status is "FULL"
     * After adding the trash, if the bin isn't alreadt redirecting, starts to redirect trash to neighbour bins.
     */
    void addTrashFull(uint8_t trash){
        extra_trash += trash;
        if(redirecting == FALSE){
            post askToNeighbours();
        }
        dbg("bin","Level: %i, Status: FULL, Trash outside: %i\n\n",trash_level, extra_trash);
    }

    
    event void Read.readDone(error_t result, uint8_t data) {
        if(result == SUCCESS){
            dbg("bin","Attempt to ADD %i UNITS to the bin at time %s\n",data,sim_time_string());
            if(bin_mode == NORMAL){
               addTrashNormal(data);
            }else if(bin_mode == CRITICAL){
               addTrashAlert(data);
            }else if(bin_mode==FULL){
                addTrashFull(data);
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

    /**
     * Empties the bin when the trucks arrives to collect the trash.
     * After emptiying the bin, it sets the status to normal and resets the alerting and redirecting actions.
     */
    task void emptyTrash(){
        bin_mode=NORMAL;
        trash_level=0;
        extra_trash=0;
        alerting=FALSE;
        redirecting = FALSE;
        dbg("bin","Truck arrived at time %s\n",sim_time_string());
        dbg("bin","BIN EMPTIED, new level: %i\n",trash_level);
    }

    /**
     * Task used by the truck to send a message notifying its arrival to a bin.
     */
    task void signalArrival(){
        truck_msg_t* msg = (truck_msg_t*) (call TPacket.getPayload(&tpacket,sizeof(truck_msg_t)));
        msg->msg_type=TRUCK;
        msg->success=1;
        call PacketAcknowledgements.requestAck(&tpacket);
        call TSChannel.send(node_d,&tpacket,sizeof(truck_msg_t));
        moving=FALSE;
    }

    /**
     * Task used to ask to the neighbours if they are available to accept the extra trash.
     */
    task void askToNeighbours(){
        move_msg_t* msg = (move_msg_t*) (call BPacket.getPayload(&bpacket,sizeof(move_msg_t)));
        redirecting = TRUE;
        msg->msg_type=MOVE;
        msg->node_id = TOS_NODE_ID;
        msg->node_x = x;
        msg->node_y = y;
        call PacketAcknowledgements.noAck(&bpacket);
        call BSChannel.send(AM_BROADCAST_ADDR,&bpacket,sizeof(move_msg_t));
        call MoveTrashTimer.startOneShot(2000);
        // Set to 0 both the min_distance and node_d so that we can compute the closest bin who accepts.
        min_distance= 0;
        node_d=0;
        dbg("bin","Sent request to neighbours to redirect extra trash\n\n\n");
    }

    /**
     * Task used to reply after a MOVE request. It is used only in case the bin status is normal.
     */
    task void replyAvailable(){
        move_msg_t* resp = (move_msg_t*) (call BPacket.getPayload(&bpacket,sizeof(move_msg_t)));
        resp->msg_type=BINRES;
        resp->node_id = TOS_NODE_ID;
        resp->node_x = x;
        resp->node_y = y;
        call PacketAcknowledgements.noAck(&bpacket);
        call BSChannel.send(node_d, &bpacket, sizeof(move_msg_t));
        dbg("bin","Received MOVE request from bin %i. ACCEPTED.\n",node_d);
        call UnlockBinTimer.startOneShot(2000);
    }

    /**
     * Task used to move trash from a bin to another when the latter one accepted and is the closer to the former one.
     * If redirecting == FALSE it means that in the meanwhile the truck arrived and collected all the trash so there is no need to redirect.
     */
    task void moveTrash(){
        if(redirecting==TRUE){
            move_msg_t* resp = (move_msg_t*) (call BPacket.getPayload(&bpacket,sizeof(move_msg_t)));
            resp->msg_type=MVTRASH;
            resp->node_id = TOS_NODE_ID;
            resp->trash = extra_trash;
            call PacketAcknowledgements.requestAck(&bpacket);
            call BSChannel.send(node_d, &bpacket, sizeof(move_msg_t));
        }
    }


    event void TruckTimer.fired(){
        post signalArrival();
        dbg("truck","Reached destination at (%i,%i)\n",x,y);
        dbg("truck","Bin %i emptied\n",node_d);
    }

    event void UnlockBinTimer.fired(){
        node_d=0;
    }
    
    event void AlertTimer.fired(){
        if(bin_mode > NORMAL){
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
            dbg("bin","MOVE request timeout\n");
            if(node_d > 0){
                post moveTrash();
                dbg("bin","Redirecting %i units to bin %i\n\n\n",extra_trash,node_d);
            }else{
                extra_trash = 0;
                redirecting = FALSE;
                dbg("bin","No bin found to redirect. Discarding extra units\n\n\n");
            }

        }
    }



    event void MoveResTimer.fired(){
        post replyAvailable();
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
            move_msg_t* msg = (move_msg_t*) ((call BPacket.getPayload(&bpacket,sizeof(move_msg_t))));
            if(msg->msg_type == MVTRASH){
                if(call PacketAcknowledgements.wasAcked(&bpacket)){
                    extra_trash = 0;
                    redirecting = FALSE;
                    dbg("bin","Trash was moved to bin %i\n",msg->node_id);
                }else{
                    dbgerror("radio","There was a problem while moving trash. Therefore trash was deleted\n");
                    post moveTrash();
                }
            }
        }
    }
 
    event message_t* BRChannel.receive(message_t* buf,void* payload, uint8_t len) {
        if(bin == TRUE){
             move_msg_t* msg = (move_msg_t*) payload;
                if(msg->msg_type == MOVE){
                    if(bin_mode == NORMAL && node_d == 0){
                        uint32_t wait;
                        node_d = msg->node_id;
                        computeDistance(msg->node_x,msg->node_y);
                        wait = computeTravelTime();
                        call MoveResTimer.startOneShot(wait);
                    }else{
                        dbg("bin","Received MOVE request from bin %i. DISCARDED.\n",msg->node_id);
                    }
                }else if(msg->msg_type == BINRES){
                    if(redirecting == TRUE){
                        computeDistance(msg->node_x,msg->node_y);
                        if((min_distance > 0 && distance < min_distance) || min_distance == 0){
                            min_distance = distance;
                            node_d = msg->node_id;
                        }
                        dbg("bin","Bin %i accepted MOVE request. Distance: %im\n",msg->node_id,distance);
                    }
                } else if(msg->msg_type == MVTRASH  && msg->node_id == node_d){
                    node_d=0;
                    call UnlockBinTimer.stop();
                    dbg("bin","Received %i units from bin %i at %s\n",msg->trash,msg->node_id,sim_time_string());
                    if(bin_mode == NORMAL){
                        addTrashNormal(msg->trash);
                    }else if(bin_mode == CRITICAL){
                        addTrashAlert(msg->trash);
                    }else if(bin_mode == FULL){
                        addTrashFull(msg->trash);
                    } 
                }
        }
           
        return buf;
    }



   
}
