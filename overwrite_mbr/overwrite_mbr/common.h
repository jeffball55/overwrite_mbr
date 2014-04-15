#ifndef __COMMON_H__
#define __COMMON_H__
#include <Windows.h>
#include <Strsafe.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <io.h>
#include <stdio.h>

#define MAX_SIZE 1024*1024*3

BYTE * get_file_contents(char * filename, int * size);
int check_raw_drive(HANDLE rawdriveh);
int write_mbr(BYTE * new_mbr, int size);
int reboot();
char *str_replace(char *orig, char *rep, char *with);
char * translate_path(LPCTSTR env_var, char * cenv_var, char * path);
void wait_until(int hour, int min);
int write_mbr_and_reboot(char * filename);

#endif //__COMMON_H__