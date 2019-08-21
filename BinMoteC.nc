module BinMoteC {

//interface that we use
  uses {
	interface Boot;    
	interface Read<uint8_t>;
  }

} implementation {

  uint8_t counter=0;
  
      

 event void Boot.booted() {
	dbg("boot","Application booted.\n");
	call Read.read();
  }

   
  event void Read.readDone(error_t result, uint8_t data) {
	dbg("boot", "Some trash was added to the bin");
  }

}

