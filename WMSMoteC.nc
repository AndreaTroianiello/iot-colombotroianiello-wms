module WMSMoteC {

    uses {
	    interface Boot;    
	    interface Read<uint8_t>;
       	interface Random;
        interface Timer<TMilli> as TruckTimer;
        interface Timer<TMilli> as BinTimer;
        interface Timer<TMilli> as NeighTimeout;
        interface Timer<TMilli> as AlertTimer;
        interface AMPacket;
        interface Packet;
        interface PacketAcknowledgements;
        interface AMSend;
        interface SplitControl;
        interface Receive;
    }

} implementation {
    // Global constants
    const uint16_t MAX_X = 2000;
    const uint16_t MAX_Y = 2000;
    const uint8_t ALPHA_BIN = 1;
    const uint8_t ALPHA_TRUCK = 100;

    // Bin related constants
    const uint8_t CRITICAL = 85;
    const uint8_t FULL = 100;

    // Global variables
    uint16_t x,y;
    bool bin;

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
    uint16_t computeDistance(uint16_t x2, uint16_t y2);

    task void sendAlert();
    task void emptyTrash();
    task void askToNeighbours();
    task void sendTrash();

    event void Boot.booted() {
	    dbg("boot","Bin booted.\n");
        call SplitControl.start();
        init();

        if(TOS_NODE_ID >0){
            initBin(); 
            call Read.read();
        }else{
            initTruck();
        }    
    }

    void init(){
        x = call Random.rand16() % MAX_X;
        y = call Random.rand16() % MAX_Y;
        dbg("init", "Bin location is (%i, %i)\n\n\n\n\n",x,y);
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

    uint16_t computeDistance(uint16_t x2, uint16_t y2){
        uint16_t xs= (x-x2)*(x-x2);
        uint16_t ys= (y-y2)*(y-y2);
        uint16_t distance = sqrt(xs+ys);
        return distance;
    }

    uint16_t computeTravelTime(uint16_t distance){
        if(bin)
            return ALPHA_BIN*distance;
        return ALPHA_TRUCK*distance;
    }
   
    event void Read.readDone(error_t result, uint8_t data) {
        if(bin_mode == 0){
            trash_level += data;
            if(trash_level >= CRITICAL) {
            	bin_mode = 1;
                if(!alerting){
                	call AlertTimer.startPeriodic(2000);
                    alerting=TRUE;
                }
            }
        }else if(bin_mode == 1){
            trash_level += data;
            if(trash_level >= FULL) {
                bin_mode = 2;
                extra_trash = trash_level - FULL;
                trash_level = FULL;
                post askToNeighbours();
            }
        }else if(bin_mode==2){
            extra_trash += data;
            post askToNeighbours();
        }
    }
    
    event void SplitControl.startDone(error_t err){
      
        if(err == SUCCESS) {
	        dbg("radio","Radio on!\n");
        }
        else{
        dbgerror("radio","something went wrong\n");
        call SplitControl.start();
        }

    }
  
    event void SplitControl.stopDone(error_t err){}

    task void sendAlert(){

    }

    task void emptyTrash(){
        bin_mode=0;
        call AlertTimer.stop();
        trash_level=0;
        extra_trash=0;
        alerting=FALSE;
    }

    task void askToNeighbours(){

    }

    task void sendTrash(){
        // COMPUTE DISTANCES
        // CHOOSE THE CLOSER ONE
        // SEND TRASH
        extra_trash = 0;
        redirecting = FALSE;
    }

    event void TruckTimer.fired(){
        // SEND TRUCK;
    }
    
    event void AlertTimer.fired(){
        if(bin_mode > 0){
            post sendAlert();
        }  
    }


    event void BinTimer.fired(){
        // SEND OK IM NORMAL
    }

    event void NeighTimeout.fired(){
        post sendTrash();
    }

    event void AMSend.sendDone(message_t* buf,error_t err) {

    }

    event message_t* Receive.receive(message_t* buf,void* payload, uint8_t len) {
        return 0;
    }

}
