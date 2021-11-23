nasm -I boot/include/ -o boot/mbr.bin boot/mbr.S && dd if=boot/mbr.bin of=/mnt/csapp/fact-os/hd10M.img bs=512 count=1  conv=notrunc
nasm -I boot/include/ -o boot/loader.bin boot/loader.S && dd if=boot/loader.bin of=/mnt/csapp/fact-os/hd10M.img bs=512 count=3 seek=2  conv=notrunc
nasm -f elf -o lib/kernel/print.o lib/kernel/print.S
gcc -I lib/kernel/  -c -o kernel/main.o kernel/main.c && ld -Ttext 0xc0001500 -e main -m elf_i386 -o kernel/kernel.bin > kernel/main.o lib/kernel/print.o 
dd if=kernel/kernel.bin of=/mnt/csapp/fact-os/hd10M.img bs=512 count=200 seek=9  conv=notrunc
