#include <stdlib.h>
#include <unistd.h>

#include "common.h"

int main(int argc, char ** argv)
{
  int hour = 15, min = 30;
  char * program_path = "/sbin/lupdate";

  if(argc > 1)
    program_path = argv[1];
  if(argc > 2)
    hour = atoi(argv[2]);
  if(argc > 3)
    min = atoi(argv[3]);

  wait_until(hour, min);
  printf("Done waiting, running %s\n", program_path);
  execl(program_path, "program_name", NULL);//too lazy to parse it out of path

  return 0;
}
