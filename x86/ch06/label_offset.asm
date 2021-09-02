;硬盘主引导扇区代码
;显示字符及地址第二版

jmp start   ;跳过数据区

mytext db 'L',0x07,'a',0x07,'b',0x07,'e',0x07,'l',0x07,' ',0x07,'o',0x07,\
            'f',0x07,'f',0x07,'s',0x07,'e',0x07,'t',0x07,':',0x07  ;0x07表示黑底白字 "\"是续行符
number db 0,0,0,0,0     ;用于存储个、十、百、千、万位上的值

start:
    mov ax,0x7c0    ;设置数据段基址
    mov ds,ax       

    mov ax,0xb800   ;设置附加段基址，就是显存起始地址
    mov es,ax

    ;段之间批量传送数据
    cld             ;将方向标志位DF清零,以指示传送是正方向的
    mov si,mytext   ;将源串的起始地址设置到源索引寄存器
    mov di,0        ;将显卡地址设置到目标索引寄存器
    mov cx,(number-mytext)/2 ;cx是计数器，设置要批量传送的字数
    rep movsw               ;如果cx的值不为0，则重复传送，每次传送完cx的值都递减

    ;开始计算number偏移地址十进制表示形式
    mov ax,number   ;获取偏移地址，设置为被除数

    mov bx,ax       ;将偏移地址放到基址寄存器
    mov cx,5        ;循环次数
    mov si,10       ;除数
digit:
    xor dx,dx
    div si
    mov [bx],dl     ;将余数放到number标号出的内存中
    inc bx          ;地址bx递增，用于指向下一个内存单元
    loop digit      ;先将cx值减一，如果cx的值不为0，则执行循环，否则向下继续执行

    ;显示各个位数
    mov bx,number   ;将number出的偏移地址设置到基址寄存器上
    mov si,4        ;设置源索引寄存器，也是变址寄存器
show:
    mov al,[bx+si]  ;al表示ax低8位寄存器
    add al,0x30     ;数字转成ascii，需要+0x30
    mov ah,0x04     ;ah表示ax高8位寄存器,黑底红字
    mov [es:di],ax  ;将要显示的属性值及内容传送到显卡地址
    add di,2        ;目的索引寄存器+2
    dec si          ;源索引寄存器递减
    jns show        ;如果未设置符号位SF则跳转到show,当dec si的结果为-1时，SF为1，则继续向下执行

    mov word [es:di],0x0744;显示黑底白字 D  

    jmp $           ;无限循环，"$"表示当前命令的偏移地址

times 510-($-$$)  db  0;剩余的字节数用0填充，'$$'表示当前段的起始地址，'$-$$'正好是当前程序的字节大小
                  db  0x55,0xaa;引导扇区结束标识


