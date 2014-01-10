/**
 * This is an implementation of Backpressure based routing over BLIP,
 * based on the concepts in the Backpressure collection protocol
 *
 * @author Srikanth Nori <snori@usc.edu>
 */

#include <lib6lowpan/ip.h>

interface PacketGen {

  /* Generate a null packet and transmit it immediately */
  command void sendNull();

}
