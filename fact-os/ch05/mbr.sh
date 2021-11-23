nasm -I include/ -o mbr.bin mbr.S && dd if=./mbr.bin of=/mnt/csapp/fact-os/hd10M.img bs=512 count=1  conv=notrunc
nasm -I include/ -o loader.bin loader.S && dd if=./loader.bin of=/mnt/csapp/fact-os/hd10M.img bs=512 count=3 seek=2  conv=notrunc
gcc -c -o kernel/main.o kernel/main.c && ld kernel/main.o -Ttext 0xc0001500 -e main -o kernel/kernel.bin
dd if=kernel/kernel.bin of=/mnt/csapp/fact-os/hd10M.img bs=512 count=200 seek=9  conv=notrunc
