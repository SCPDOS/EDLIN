#!/bin/sh

edlin:
	nasm edlin.asm -o ./Binaries/EDLIN.COM -f bin -l ./Listings/edlin.lst -O0v

# Copy requires the disk image to be mounted on /mnt/DOSMNT
copy:
	~/mntdos
	sudo cp ./Binaries/EDLIN.COM /mnt/DOSMNT/EDLIN.COM
	~/umntdos

# Build, mount, copy and unmount
all:
	nasm edlin.asm -o ./Binaries/EDLIN.COM -f bin -l ./Listings/edlin.lst -O0v
	~/mntdos
	sudo cp ./Binaries/EDLIN.COM /mnt/DOSMNT/EDLIN.COM
	~/umntdos