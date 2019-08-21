configuration BinMoteAppC {}

implementation {

  components MainC, BinMoteC as Mote;
  components new BinSensorC() as Sensor;

  Mote.Boot -> MainC.Boot;

  Mote.Read -> Sensor;

}

