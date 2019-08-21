generic module BinSensorC() {

	provides interface Read<uint8_t>;
	
	uses interface Random;
	uses interface Timer<TMilli> as Timer0;

} implementation {

	const uint8_t MAX_TRASH = 10;
	const uint8_t GENERATION_INTERVAL = 30;

	void setTimer();

	command error_t Read.read(){
		dbg("boot","Read called\n");
		setTimer();
		return SUCCESS;
	}

	event void Timer0.fired() {
		uint8_t trash = 1 + ( call Random.rand16() %MAX_TRASH);
		signal Read.readDone( SUCCESS, trash );
		setTimer();
	}
	
	void setTimer(){
		call Timer0.startOneShot( 1000 * (1 + (call Random.rand16() % GENERATION_INTERVAL)));
	}
	
}
