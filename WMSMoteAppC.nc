
#include "wmsMsg.h"


configuration WMSMoteAppC {}

implementation {

  components MainC, WMSMoteC as Mote, RandomC;
  components new BinSensorAppC() as Sensor;
  components new TimerMilliC() as TruckTimer;
  components new TimerMilliC() as BinTimer;
  components new TimerMilliC() as NeighTimeout;
  components new TimerMilliC() as AlertTimer;
  components new AMSenderC(AM_BIN_CHANNEL);
  components new AMReceiverC(AM_BIN_CHANNEL);
  components ActiveMessageC;


  Mote.Boot -> MainC.Boot;

  Mote.AMSend -> AMSenderC;
  Mote.Receive -> AMReceiverC;

  //Radio Control
  Mote.SplitControl -> ActiveMessageC;

  Mote.AMPacket -> AMSenderC;
  Mote.Packet -> AMSenderC;
  Mote.PacketAcknowledgements -> ActiveMessageC;
  



  Mote.Random -> RandomC;
  RandomC <- MainC.SoftwareInit;

  Mote.Read -> Sensor;

  Mote.TruckTimer -> TruckTimer;
  Mote.BinTimer -> BinTimer;
  Mote.NeighTimeout -> NeighTimeout;
  Mote.AlertTimer -> AlertTimer;

}

