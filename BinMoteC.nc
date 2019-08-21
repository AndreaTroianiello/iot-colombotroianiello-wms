module BinMoteC {

    uses {
	    interface Boot;    
	    interface Read<uint8_t>;
    }

} implementation {
    
    const uint16_t MAX_X = 2000;
    const uint16_t MAX_Y = 2000;
    const uint8_t ALPHA = 1;

    uint8_t counter;
    uint16_t x,y;
      

    event void Boot.booted() {
	    dbg("boot","Application booted.\n");
	    call Read.read();
    }

   
    event void Read.readDone(error_t result, uint8_t data) {
	    dbg("boot", "Some trash was added to the bin: %i\n", data);
    }

}

