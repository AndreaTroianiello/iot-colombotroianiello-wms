module BinMoteC {

    uses {
	    interface Boot;    
	    interface Read<uint8_t>;
       	interface Random;
    }

} implementation {
    
    const uint16_t MAX_X = 2000;
    const uint16_t MAX_Y = 2000;
    const uint8_t ALPHA = 1;
    const uint8_t CRITICAL = 85;
    const uint8_t FULL = 100;

    uint8_t trash_level;
    uint8_t extra_trash;
    uint16_t x,y;
    uint8_t bin_mode;
    bool alerting;
    bool redirecting; 

    void init();

    event void Boot.booted() {
	    dbg("boot","Bin booted.\n");
        init();
	    call Read.read();
    }

    void init(){
        x = call Random.rand16() % MAX_X;
        y = call Random.rand16() % MAX_Y;
        dbg("init", "Bin location is (%i, %i)\n\n\n\n\n",x,y);
        trash_level = 0;
        extra_trash = 0;
        bin_mode = 0;
        alerting = false;
        redirecting = false;
    }

   
    event void Read.readDone(error_t result, uint8_t data) {
        if(bin_mode == 0){
            trash_level + = data;
            if(trash_level >= CRITICAL) bin_mode = 1;
        }else if(bin_mode == 1){
            trash_level += data;
            if(trash_level >= FULL) {
                bin_mode = 2;
                extra_trash = trash_level - FULL;
                trash_level = FULL;
                // start Alerting
            }
        }else if(bin_mode==2){
            extra_trash += data;
            // send to Neighbours
        }
    }

}

