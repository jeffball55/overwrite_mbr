#include "common.h"

int main(int argc, char ** argv)
{
  int hour = 15, min = 30;

  if(argc > 1)
    hour = atoi(argv[1]);
  if(argc > 2)
    min = atoi(argv[2]);

  wait_until(hour, min);
  return write_mbr_and_reboot(NULL);
}
