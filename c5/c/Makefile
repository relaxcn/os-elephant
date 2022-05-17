default:
	nasm -I ./boot/include -o ./out/loader.bin ./boot/loader.s
	nasm -I ./boot/include -o ./out/mbr.bin ./boot/mbr.s
	gcc -c -o ./out/main.o ./kernel/main.c
	ld ./out/main.o -Ttext 0xc0001500 --entry main -o ./out/kernel.bin

install: default
	dd if=./out/mbr.bin of=/home/ciel/Documents/bochs/hd60M.img bs=512 count=1 conv=notrunc
	dd if=./out/loader.bin of=/home/ciel/Documents/bochs/hd60M.img bs=512 count=4 seek=2 conv=notrunc
	dd if=./out/kernel.bin of=/home/ciel/Documents/bochs/hd60M.img bs=512 count=200 seek=9 conv=notrunc

clean:
	rm -rf ./out
