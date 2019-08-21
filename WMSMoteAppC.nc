configuration WMSMoteAppC {}

implementation {

  components MainC, WMSMoteC as Mote, RandomC;
  components new BinSensorAppC() as Sensor;

  Mote.Random -> RandomC;
	RandomC <- MainC.SoftwareInit;

  Mote.Boot -> MainC.Boot;

  Mote.Read -> Sensor;

}

