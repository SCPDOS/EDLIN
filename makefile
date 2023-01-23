#!/bin/sh

edlin:
	nasm edlin.asm -o ./Binaries/EDLIN.COM -f bin -l ./Listings/edlin.lst -O0v

