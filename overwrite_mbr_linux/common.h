#ifndef __COMMON_H__
#define __COMMON_H__
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <stdio.h>

#define MAX_SIZE 1024*1024*3

char * get_file_contents(char * filename, int * size);
int write_mbr(char * new_mbr, int size);
int reboot_system();
void wait_until(int hour, int min);
int write_mbr_and_reboot(char * filename);

#endif //__COMMON_H__
