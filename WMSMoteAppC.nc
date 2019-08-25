
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
  components SerialActiveMessageC as AM;

  Mote.Boot -> MainC.Boot;
  
  //Radio Control
  Mote.SplitControl -> ActiveMessageC;
  Mote.PacketAcknowledgements -> ActiveMessageC;

  // Serial Control
  Mote.SerialSplitControl -> AM;
  Mote.AMSerialSend -> AM.AMSend[AM_SERIAL_MSG];

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

  //SERIAL CHANNEL
  Mote.SerialPacket -> AM;


  Mote.Random -> RandomC;
  RandomC <- MainC.SoftwareInit;

  Mote.Read -> Sensor;

  Mote.TruckTimer -> TruckTimer;
  Mote.AlertTimer -> AlertTimer;
  Mote.MoveTrashTimer -> MoveTrashTimer;
  Mote.MoveResTimer -> MoveResTimer;
  Mote.UnlockBinTimer -> UnlockBinTimer;

}

