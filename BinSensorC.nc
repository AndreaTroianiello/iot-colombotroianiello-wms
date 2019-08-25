generic module BinSensorC() {

	provides interface Read<uint8_t>;
	
	uses interface Random;
	uses interface Timer<TMilli> as Timer0;

} implementation {

	/**
	 * The maximum units of trash that can be generate each time the timer fires.
	 */
	const uint8_t MAX_TRASH = 10;
	/**
	 * The time interval in which the timer randomly fires.
	 */
	const uint8_t GENERATION_INTERVAL = 30;

	void setTimer();

	/**
	 * Read command, starts the timer for the first time and returns SUCCESS
	 */
	command error_t Read.read(){
		setTimer();
		return SUCCESS;
	}

	/**
	 * Event called when the timer fires.
	 * It generates a random value of trash in the range [1,MAX_TRASH] and emits a Read event.
	 * Then calls again the method to set the timer.
	 */
	event void Timer0.fired() {
		uint8_t trash = 1 + ( call Random.rand16() % MAX_TRASH);
		signal Read.readDone( SUCCESS, trash );
		setTimer();
	}
	
	/**
	 * Method used to set the timer, it uses random time in the range [1,GENERATION_INTERVAL] 
	 */
	void setTimer(){
		call Timer0.startOneShot( 1000 * (1 + (call Random.rand16() % GENERATION_INTERVAL)));
	}
	
}
