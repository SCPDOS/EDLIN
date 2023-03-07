#!/bin/sh

edlin:
	nasm edlin.asm -o ./Binaries/EDLIN.COM -f bin -l ./Listings/edlin.lst -O0v

# Copy requires the disk image to be mounted on /mnt/DOSMNT
copy:
	cp ./Binaries/EDLIN.COM /mnt/DOSMNT/EDLIN.COM