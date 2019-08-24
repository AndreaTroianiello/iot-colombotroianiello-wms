
#include "wmsMsg.h"


configuration WMSMoteAppC {}

implementation {

  components MainC, WMSMoteC as Mote, RandomC;
  components new BinSensorAppC() as Sensor;
  components new TimerMilliC() as TruckTimer;
  components new TimerMilliC() as AlertTimer;
  components new TimerMilliC() as MoveTrashTimer;  
  components new TimerMilliC() as MoveResTimer;  
  components new TimerMilliC() as UnlockBinTimer;  
  components new AMSenderC(AM_TRUCK_CHANNEL) as TS;
  components new AMReceiverC(AM_TRUCK_CHANNEL) as TR;
  components new AMSenderC(AM_BIN_CHANNEL) as BS;
  components new AMReceiverC(AM_BIN_CHANNEL) as BR;
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

  //BIN CHANNEL
  Mote.BAMPacket -> BS;
  Mote.BPacket -> BS;
  Mote.BSChannel -> BS;
  Mote.BRChannel -> BR;



  Mote.Random -> RandomC;
  RandomC <- MainC.SoftwareInit;

  Mote.Read -> Sensor;

  Mote.TruckTimer -> TruckTimer;
  Mote.AlertTimer -> AlertTimer;
  Mote.MoveTrashTimer -> MoveTrashTimer;
  Mote.MoveResTimer -> MoveResTimer;
  Mote.UnlockBinTimer -> UnlockBinTimer;

}

