configuration EasyCollectionAppC {}
implementation {
  components EasyCollectionC, MainC, LedsC,ActiveMessageC;
  //components CollectionC as Collector;
  //components new CollectionSenderC(0xee);
  components BcpC;
  components new TimerMilliC();
//  components PrintfC;
//  components SerialStartC;



  EasyCollectionC.Boot -> MainC;
  EasyCollectionC.RadioControl -> ActiveMessageC;
  EasyCollectionC.Leds -> LedsC;
  EasyCollectionC.Timer -> TimerMilliC;

  EasyCollectionC.Send -> BcpC;
  EasyCollectionC.Receive -> BcpC;
  EasyCollectionC.RoutingControl -> BcpC;
  EasyCollectionC.RootControl -> BcpC;

  BcpC.BcpDebugIF -> EasyCollectionC;



/*
  EasyCollectionC.Boot -> MainC;
  EasyCollectionC.RadioControl -> ActiveMessageC;
  EasyCollectionC.RoutingControl -> Collector;
  EasyCollectionC.Leds -> LedsC;
  EasyCollectionC.Timer -> TimerMilliC;
  EasyCollectionC.Send -> CollectionSenderC;
  EasyCollectionC.RootControl -> Collector;
  EasyCollectionC.Receive -> Collector.Receive[0xee];
*/
}


