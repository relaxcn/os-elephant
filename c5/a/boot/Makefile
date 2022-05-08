default:
	nasm -I ./include -o loader.bin loader.s
	nasm -I ./include -o mbr.bin mbr.s

install: default
	dd if=./mbr.bin of=/home/ciel/bochs/hd60M.img bs=512 count=1 conv=notrunc
	dd if=./loader.bin of=/home/ciel/bochs/hd60M.img bs=512 count=4 seek=2 conv=notrunc

clean:
	rm loader.bin mbr.bin
