default:
	nasm -I ./boot/include -o ./loader.bin ./boot/loader.s
	nasm -I ./boot/include -o ./mbr.bin ./boot/mbr.s
	nasm -f elf -o print.o ./lib/kernel/print.s
	gcc -I lib/kernel -m32 -c -o ./main.o ./kernel/main.c
	ld -m elf_i386 -Ttext 0xc0001500 -e main -o kernel.bin main.o print.o


install: default
	dd if=./mbr.bin of=/home/ciel/Documents/bochs/hd60M.img bs=512 count=1 conv=notrunc
	dd if=./loader.bin of=/home/ciel/Documents/bochs/hd60M.img bs=512 count=4 seek=2 conv=notrunc
	dd if=./kernel.bin of=/home/ciel/Documents/bochs/hd60M.img bs=512 count=200 seek=9 conv=notrunc

clean:
	rm mbr.bin loader.bin kernel.bin
	rm main.o print.o
