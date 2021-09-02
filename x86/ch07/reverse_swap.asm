;硬盘主引导扇区代码
;交换参数，反转字符串

jmp start   ;跳过数据区

string db 'abcdef'

start:
    mov ax,0x7c0
    mov ds,ax

    mov ax,0xb800
    mov es,ax

    mov bx,string
    mov si,0
    mov di,start-string

swap:
    mov ah,[bx+si]
    mov al,[bx+di]
    mov [bx+si],al  ;交换
    mov [bx+di],ah
    inc si
    dec di
    cmp si,di
    jl swap     ;首尾没有相遇，继续循环

    mov cx,start-string
    mov di,0
show:
    mov al,[bx]
    inc bx
    mov [es:di],al
    inc di
    mov byte [es:di],0x07
    inc di
    loop show

jmp $

times 510-($-$$)  db  0 ;剩余的字节数用0填充，'$$'表示当前段的起始地址，'$-$$'正好是当前程序的字节大小
                  db  0x55,0xaa ;引导扇区结束标识

