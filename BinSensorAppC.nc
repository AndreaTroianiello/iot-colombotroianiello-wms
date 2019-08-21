generic configuration BinSensorAppC() {

	provides interface Read<uint16_t>;

} implementation {

	components MainC, RandomC;
	components new BinSensorC() as Sensor;
	components new TimerMilliC() as Timer0;
	
	Read = Sensor;
	
	Sensor.Random -> RandomC;
	RandomC <- MainC.SoftwareInit;
	
	Sensor.Timer0 -> Timer0;

}
