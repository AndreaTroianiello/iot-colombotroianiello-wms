
#include "wmsMsg.h"


configuration WMSMoteAppC {}

implementation {

  components MainC, WMSMoteC as Mote, RandomC;
  components new BinSensorAppC() as Sensor;
  components new TimerMilliC() as TruckTimer;
  components new TimerMilliC() as BinTimer;
  components new TimerMilliC() as NeighTimeout;
  components new TimerMilliC() as AlertTimer;
  components new AMSenderC(AM_MY_MSG);
  components new AMReceiverC(AM_MY_MSG);
  components ActiveMessageC;


  Mote.Random -> RandomC;
  RandomC <- MainC.SoftwareInit;

  Mote.Boot -> MainC.Boot;

  //Send and Receive interfaces
  Mote.Receive -> AMReceiverC;
  Mote.AMSend -> AMSenderC;

  //Radio Control
  Mote.SplitControl -> ActiveMessageC;

  //Interfaces to access package fields
  Mote.AMPacket -> AMSenderC;
  Mote.Packet -> AMSenderC;
  Mote.PacketAcknowledgements->ActiveMessageC;




  Mote.Read -> Sensor;

  Mote.TruckTimer -> TruckTimer;
  Mote.BinTimer -> BinTimer;
  Mote.NeighTimeout -> NeighTimeout;
  Mote.AlertTimer -> AlertTimer;

}

