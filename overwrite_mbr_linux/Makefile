
CFLAGS=-I. --static -m32

all: mbr wait_mbr wait

mbr:
	gcc -o overwrite_mbr overwrite_mbr.c common.c $(CFLAGS)

wait_mbr:
	gcc -o wait_and_overwrite_mbr wait_and_overwrite_mbr.c common.c $(CFLAGS)

wait:
	gcc -o wait_and_run wait_and_run.c common.c $(CFLAGS)

clean:
	rm -f wait_and_run overwrite_mbr wait_and_overwrite_mbr
