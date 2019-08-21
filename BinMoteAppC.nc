configuration BinMoteAppC {}

implementation {

  components MainC, BinMoteC as Mote, RandomC;
  components new BinSensorAppC() as Sensor;

  Mote.Random -> RandomC;
	RandomC <- MainC.SoftwareInit;

  Mote.Boot -> MainC.Boot;

  Mote.Read -> Sensor;

}

