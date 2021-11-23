nasm -I include/ -o mbr.bin -l mbr.lst mbr.S 
nasm -I include/ -o loader.bin loader.S
