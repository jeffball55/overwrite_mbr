#include "common.h"

int main(int argc, char **argv)
{
	char * filename = NULL;
	if(argc > 1)
		filename = argv[1];
	return write_mbr_and_reboot(filename);
}