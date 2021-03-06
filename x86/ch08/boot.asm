;硬盘主引导扇区代码
;加载器

app_lba_start equ 100   ;声明常数（用户程序起始逻辑扇区号,要加载的用户程序所在的磁盘位置）
                        ;常数的声明不会占用汇编地址
;-------------------------------------------------------------------------------
section mbr align=16 vstart=0x7c00 ;主段落，偏移起始地址为0x7c00
    ;设置栈段和栈指针都为0，栈指针将在0xffff-0x0000之间变化，栈段的长度就是64k
    mov ax,0
    mov ss,ax
    mov sp,ax

    mov ax,[cs:phy_base]        ;计算用于加载用户程序的逻辑段地址，这里使用cs段是因为ds和es段有其他用处
    mov dx,[cs:phy_base+2]      ;地址是20位的，16位寄存器放不下，所以使用两个寄存器来表示，高16位在dx，低16位在ax
    mov bx,16                   ;将32位物理地址变成16位段地址，该物理地址是16位对齐的，直接右移4位即可
    div bx                      ;ax中的商就是段地址
    mov ds,ax                   ;ds与es均设置该段地址
    mov es,ax

    ;以下读取程序的起始部分
    xor di,di                   
    mov si,app_lba_start        ;用户程序在磁盘上的逻辑扇区号，值为100，si完全可以放的下，所以将di清零
    xor bx,bx                   ;加载到ds:0x0000处
    call read_hard_disk_0

    ;已经读取到程序的头部了，现在判断程序的总大小
    mov dx,[2]                  ;程序大小的高16位
    mov ax,[0]                  ;程序大小的低16位
    mov bx,512                  ;每扇区512字节
    div bx                      ;计算该程序占多数个扇区
    cmp dx,0                    ;余数是否为0
    jnz @1                      ;未除尽，表示还有一个扇区需要读，不需要去减去一个扇区了，直接跳转到@1
    dec ax                      ;已经读取过头扇区了，所以需要减去一个

    @1:
        cmp ax,0                ;商为0表示程序的大小刚好小于等于512字节
        jz direct
        ;读取剩余扇区
        push ds                 ;保存ds段寄存器，后面会改变ds段
        mov cx,ax               ;循环次数（剩余扇区数）

    @2:
        mov ax,ds               ;每次读取一个扇区都初始化ds段寄存器，因为每个扇区512字节，也就是0x200,段偏移地址需要左移4位，也就是0x20
        add ax,0x20             ;ds加上0x20，表示已经读取了512字节
        mov ds,ax

        xor bx,bx               ;每次读取时，偏移地址始终为0x0000
        inc si                  ;下一个逻辑扇区
        call read_hard_disk_0   ;从磁盘读取
        loop @2                 ;先将cx值减一，如果cx的值不为0，则执行循环，否则向下继续执行

        pop ds                  ;恢复ds段寄存器原始值,此时ds的值为用户程序的起始地址
    ;计算入口点代码段基址
    direct:
        mov dx,[0x08]           ;入口点段地址高16位
        mov ax,[0x06]           ;入口点段地址低16位
        call calc_segment_base  ;计算16位段地址

        mov [0x06],ax           ;回填真正的代码入口点代码段地址

        ;开始处理段重定位表
        mov cx,[0x0a]           ;段重定位表项个数
        mov bx,0x0c             ;重定位表首地址
    ;重定位表项中的段基址    
    realloc:
        mov dx,[bx+0x02]        ;32位地址的高16位
        mov ax,[bx]             ;低16位
        call calc_segment_base  ;计算16位段地址
        
        mov [bx],ax             ;回填段的基址
        add bx,4                ;下一个重定位表项（每项占4个字节）
        loop realloc            ;先将cx值减一，如果cx的值不为0，则执行循环，否则向下继续执行

    jmp far [0x04]              ;转移到用户程序

;-------------------------------------------------------------------------------
read_hard_disk_0:               ;从硬盘读取一个逻辑扇区，使用的逻辑扇区编址方法为LBA28，也就是用28位来表示扇区号，每个扇区512字节
                                ;di:si=起始逻辑扇区号，28位只能用2个16位寄存器来表示，其中di中的高4位清零，剩余12位表示高12位，si表示低16位
                                ;ds:bx=目标缓冲区地址，将读到的硬盘数据放到ds段指定的内存中

    push ax                     ;将该过程会用到的寄存器入栈保存，函数返回时需要出栈还原
    push bx
    push cx
    push dx

    mov dx,0x1f2                ;0x1f2端口表示要读取或写入的扇区数量，8位长度
    mov al,1                    ;每次要读取1个扇区
    out dx,al

    ;28位的扇区号太长，需要放到4个8位端口中，0x1f3存0-7位，0x1f4存8-15位，0x1f5存16-23位，
    ;0x1f6低4位存24-27位，第4位用于指示硬盘号，0是主盘、1是从盘,高三为全为1，表示LBA模式
    inc dx                      ;0x1f3
    mov ax,si
    out dx,al                   ;LBA地址7-0

    inc dx                      ;0x1f4
    mov al,ah
    out dx,al                   ;LBA地址15-8

    inc dx                      ;0x1f5
    mov ax,di
    out dx,al                   ;LBA地址23-16

    inc dx                      ;0x1f6
    mov al,0xe0                 ;LBA28模式，使用主盘  二进制值1110 0000
    or al,ah                    ;因为al是1110 0000，ah高4位是0，0000 xxxx,使用or运算后al就是xxxx,表示LBA地址27-24
    out dx,al

    inc dx                      ;0x1f7，既是命令端口也是状态端口，0x20表示读，0x30表示写
    mov al,0x20                 ;表示读硬盘
    out dx,al                  

    .waits:
        in al,dx                    ;读取硬盘状态，第7位是1表示硬盘在忙碌，第3位是1表示已经读取完可以传输数据了
        and al,0x88                 ;二进制值：1000 1000，保留第7位与第3位的值，其他位全清0
        cmp al,0x08                 ;二进制值：0000 1000，是否已经准备好了
        jnz .waits                  ;尚未准备好，继续循环等待

    mov cx,256                  ;总共要读取的字数
    mov dx,0x1f0                ;硬盘数据端口，长度为16位的

    .readw:
        in ax,dx                    ;从硬盘读取一个字
        mov [bx],ax                 ;放到ds段内存中
        add bx,2                    ;bx偏移地址+2
        loop .readw                 ;先将cx值减一，如果cx的值不为0，则执行循环，否则向下继续执行

    pop dx                      ;出栈，还原相关寄存器的原始值
    pop cx
    pop bx
    pop ax

    ret                         ;返回




;-------------------------------------------------------------------------------
calc_segment_base:              ;计算16位段地址，输入dx:ax=32位物理地址，输出ax=16位段基址
    push dx                     ;保存dx寄存器中的值

    add ax,[cs:phy_base]        ;如果有进位则CF位的值为1
    adc dx,[cs:phy_base+0x02]   ;adc是进位加法，两数相加后再加上标志寄存器CF位的值（0或1）
                                ;这样分两步就完成了32位的加法
                                ;dx:ax存放的是32位物理地址，而只有20位有效，高4位在dx中，低16位在ax
    shr ax,4                    ;ax右移4位(因为是求段地址)，空出高4位
    ror dx,4                    ;dx循环右移4位，循环右移会将右移出的位放到左边。这样dx中高4位的值就是原先低4位的值
    and dx,0xf000               ;将dx低12位清零
    or ax,dx                    ;将dx高4位与ax合并

    pop dx                      ;还原dx中的值
    ret

;-------------------------------------------------------------------------------
phy_base dd 0x10000     ;用户程序被加载的物理起始地址,用32位长度来表示20的地址

times 510-($-$$)  db  0 ;剩余的字节数用0填充，'$$'表示当前段的起始地址，'$-$$'正好是当前程序的字节大小
                  db  0x55,0xaa ;引导扇区结束标识