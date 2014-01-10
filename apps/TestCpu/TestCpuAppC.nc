/**
 * This application is used to test the basic functionality of the printf service.
 * Calls to the standard c-style printf command are made to print various strings
 * of text over the serial line.  Only upon calling printfflush() does the
 * data actually get sent out over the serial line.
 *
 * @author Kevin Klues (klueska@cs.wustl.edu)
 * @version $Revision: 1.9 $
 * @date $Date: 2010-06-29 22:07:25 $
 */

#define NEW_PRINTF_SEMANTICS
#include "printf.h"

configuration TestCpuAppC{
}
implementation {
  components MainC, PrintfC, TestCpuC, SerialStartC;
  components new TimerMilliC();
  //components new TimerMilliC() as Perf;
  components CounterMilli32C;

  TestCpuC.Boot -> MainC;
  TestCpuC.Timer -> TimerMilliC;
  //TestCpuC.Perf -> Perf;
	TestCpuC.Counter -> CounterMilli32C;

	components SerialActiveMessageC as AM;
	TestCpuC.Control -> AM;
	TestCpuC.Receive -> AM.Receive[AM_MSG_T];
	TestCpuC.AMSend  -> AM.AMSend[AM_MSG_T];
	TestCpuC.Packet  -> AM;

	components LedsC;
	TestCpuC.Leds -> LedsC;
}

