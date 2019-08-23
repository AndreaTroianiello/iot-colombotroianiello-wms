#include "wmsMsg.h"

module WMSMoteC {

    uses {
	    interface Boot;    
	    interface Read<uint8_t>;
       	interface Random;
        interface Timer<TMilli> as TruckTimer;
        interface Timer<TMilli> as AlertTimer;
        
        interface SplitControl;    	
        //TRUCK Channel
        interface AMPacket as TAMPacket; 
	    interface Packet as TPacket;
	    interface AMSend as TSChannel;
        interface Receive as TRChannel;

        interface PacketAcknowledgements;
    }

} implementation {
    // Global constants
    const uint16_t MAX_X = 2000;
    const uint16_t MAX_Y = 2000;
    const uint8_t ALPHA_BIN = 1;
    const uint8_t ALPHA_TRUCK = 10;

    // Bin related constants
    const uint8_t CRITICAL = 85;
    const uint8_t FULL = 100;

    // Global variables
    uint16_t x,y;
    bool bin;
    message_t packet;
    uint16_t distance;
    uint16_t node_d;

    // Bin related variables
    uint8_t trash_level;
    uint8_t extra_trash;
    // 0 = normal mode, 1 = alert mode, 2 = full mode
    uint8_t bin_mode;
    bool alerting;
    bool redirecting; 

    //Truck related variables
    bool moving;

    void init();
    void initBin();
    void initTruck();
    void computeDistance(uint16_t x2, uint16_t y2);
    uint16_t computeTravelTime();

    task void sendAlert();
    task void emptyTrash();
    task void signalArrival();


    event void Boot.booted() {
	    dbg("boot","Bin booted.\n");
        call SplitControl.start();
        init();

        if(TOS_NODE_ID >1){
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
        alerting = FALSE;
        redirecting = FALSE;
        bin=TRUE;
    }

    void computeDistance(uint16_t x2, uint16_t y2){
        uint32_t xs= (x-x2)*(x-x2);
        uint32_t ys= (y-y2)*(y-y2);
        distance = sqrt(xs+ys);
    }

    uint16_t computeTravelTime(){
        if(bin)
            return ALPHA_BIN*distance;
        return ALPHA_TRUCK*distance;
    }
   
    event void Read.readDone(error_t result, uint8_t data) {
        dbg("bin","There was an attempt to add trash to the bin at time %s\n",sim_time_string());
        if(bin_mode == 0){
            trash_level += data;
            if(trash_level >= CRITICAL) {
            	bin_mode = 1;
                if(!alerting){
                	call AlertTimer.startPeriodic(4000);
                    alerting=TRUE;
                }
            }
        }else if(bin_mode == 1){
            trash_level += data;
            if(trash_level >= FULL) {
                bin_mode = 2;
                extra_trash = trash_level - FULL;
                trash_level = FULL;
                //post askToNeighbours();
            }
        }else if(bin_mode==2){
            extra_trash += data;
            //post askToNeighbours();
        }
        dbg("bin", "ADDED %i units\n",data);
        dbg("bin","TRASH LEVEL: %i\n", trash_level);
        dbg("bin","STATUS: %i\n", bin_mode);
        dbg("bin","TRASH OUTSIDE: %i\n\n\n\n\n", extra_trash);
        
    }
    

    task void sendAlert(){
        alert_msg_t* msg = (alert_msg_t*)(call TPacket.getPayload(&packet, sizeof(alert_msg_t)));
        msg->msg_type = ALERT;
        msg->node_id = TOS_NODE_ID;
        msg->node_x = x;
        msg->node_y = y;

        call PacketAcknowledgements.requestAck(&packet);

        if(call TSChannel.send(1,&packet,sizeof(alert_msg_t)) == SUCCESS){
            dbg("radio","Sending alert message to the truck\n");
        }
    }

    task void emptyTrash(){
        bin_mode=0;
        trash_level=0;
        extra_trash=0;
        alerting=FALSE;
        dbg("bin","Truck arrived at time %s\n",sim_time_string());
        dbg("bin","BIN EMPTIED, new level: %i\n\n\n",trash_level);
    }

    task void signalArrival(){
        truck_msg_t* msg = (truck_msg_t*) (call TPacket.getPayload(&packet,sizeof(truck_msg_t)));
        msg->msg_type=TRUCK;
        msg->success=1;

        call PacketAcknowledgements.requestAck(&packet);
        call TSChannel.send(node_d,&packet,sizeof(truck_msg_t));
        moving=FALSE;
        dbg("truck","Reached destination (%i,%i)\n",x,y);
        dbg("truck","Bin %i emptied\n\n\n",node_d);
    }

    task void sendTrash(){
        // COMPUTE DISTANCES
        // CHOOSE THE CLOSER ONE
        // SEND TRASH
        extra_trash = 0;
        redirecting = FALSE;
    }


    event void TruckTimer.fired(){
        post signalArrival();
    }
    
    event void AlertTimer.fired(){
        if(bin_mode > 0){
            post sendAlert();
        }else{
            call AlertTimer.stop();
        }
    }

    event void TSChannel.sendDone(message_t* buf,error_t err) {
        if(&packet ==buf && err == SUCCESS){
            if (call PacketAcknowledgements.wasAcked(buf)) {
                dbg("radio","Truck received the message and acknowledged\n\n\n");
            }else{
                dbg("radio","Truck did not acknowledge the message\n\n\n");
            }
        }else{
            dbg("radio", "ERROR \n\n\n\n\n\n\n");
            post sendAlert();
        }
    }
 
    event message_t* TRChannel.receive(message_t* buf,void* payload, uint8_t len) {
        if(bin == FALSE){
            if(moving == FALSE){
                alert_msg_t* msg = (alert_msg_t*)payload;
                moving=TRUE;
                computeDistance(msg->node_x,msg->node_y);
                dbg("truck","Distance to bin is %i m\n",distance);
                node_d = msg->node_id;
                call TruckTimer.startOneShot(computeTravelTime());
                x = msg->node_x;
                y = msg->node_y;
                dbg("truck","Received ALERT message from %i\n",node_d);
                dbg("truck","Started traveling to (%i,%i)\n\n\n",x,y);
            }
        }else{
            post emptyTrash();
        }
        return buf;
    }

}
