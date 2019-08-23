
#include "wmsMsg.h"


configuration WMSMoteAppC {}

implementation {

  components MainC, WMSMoteC as Mote, RandomC;
  components new BinSensorAppC() as Sensor;
  components new TimerMilliC() as TruckTimer;
  components new TimerMilliC() as AlertTimer;
  components new AMSenderC(AM_BIN_CHANNEL) as TS;
  components new AMReceiverC(AM_BIN_CHANNEL) as TR;
  components ActiveMessageC;

  Mote.Boot -> MainC.Boot;
  
  //Radio Control
  Mote.SplitControl -> ActiveMessageC;
  Mote.PacketAcknowledgements -> ActiveMessageC;
  

  //TRUCK CHANNEL
  Mote.TAMPacket -> TS;
  Mote.TPacket -> TS;
  Mote.TSChannel -> TS;
  Mote.TRChannel -> TR;

  Mote.Random -> RandomC;
  RandomC <- MainC.SoftwareInit;

  Mote.Read -> Sensor;

  Mote.TruckTimer -> TruckTimer;
  Mote.AlertTimer -> AlertTimer;

}

