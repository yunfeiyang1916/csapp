;硬盘主引导扇区代码
;借用栈反转字符串

jmp start   ;跳过数据区

string db 'abcdef' ;声明一串字符串

start:              ;代码段
    mov ax,0x7c0    ;设置数据段基址
    mov ds,ax

    mov ax,0xb800       ;设置附加段基址，显卡地址
    mov es,ax

    mov cx,start-string    ;计数器，设置字符串字节数量
    mov bx,string
lpush:
    mov al,[bx]
    push ax     ;入栈
    inc bx
    loop lpush  ;先将cx值减一，如果cx的值不为0，则执行循环，否则向下继续执行

    mov cx,start-string
    mov bx,string
lpop:
    pop ax
    mov [bx],al
    inc bx
    loop lpop   ;先将cx值减一，如果cx的值不为0，则执行循环，否则向下继续执行

    mov cx,start-string
    mov bx,string
    mov di,0
;显示
show:
    mov al,[bx]
    inc bx
    mov [es:di],al
    inc di
    mov byte [es:di],0x07    ;黑底白字
    inc di
    loop show   ;先将cx值减一，如果cx的值不为0，则执行循环，否则向下继续执行

    jmp $       ;无限循环

times 510-($-$$)  db  0 ;剩余的字节数用0填充，'$$'表示当前段的起始地址，'$-$$'正好是当前程序的字节大小
                  db  0x55,0xaa ;引导扇区结束标识



