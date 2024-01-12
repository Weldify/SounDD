CFLAGS = -c -O3

all: sokol dr_flac

sokol:
	$(CC) $(CFLAGS) ../c/sokol.c
	ar r sokol.a sokol.o

dr_flac:
	$(CC) $(CFLAGS) ../c/dr_flac.c
	ar r dr_flac.a dr_flac.o
