;硬盘主引导扇区代码
;也是内核代码的初始部分
                                    
core_base_address equ 0x00040000   ;常数，内核加载的起始内存物理地址
core_start_sector equ 0x00000001   ;常数，内核的起始逻辑扇区号。常数的声明不会占用汇编地址

;设置栈段和栈指针
mov ax,cs               ;栈段寄存器指向cs代码段
mov ss,ax
mov sp,0x7c00           ;栈指针指向代码起始位置，栈是向下增长的，范围为0x7c00-0x00

;计算GDT所在逻辑段的地址
mov eax,[cs:pgdt+0x7c00+0x02]   ;GDT的32位线性基地址 
xor edx,edx                     
mov ebx,16
div ebx
mov ds,eax                      ;商就是段地址
mov ebx,edx                     ;余数就是偏移地址

;跳过#0描述符，它是空描述符，处理器要求的

;创建#1描述符，这是一个数据段，对应0~4GB的线性地址空间
mov dword [ebx+0x08],0x0000ffff    ;基地址为0，段界限为0xFFFFF
mov dword [ebx+0x0c],0x00cf9200    ;粒度为4KB，存储器段描述符 

;创建保护模式下初始代码段描述符
mov dword [ebx+0x10],0x7c0001ff    ;基地址为0x00007c00，界限0x1FF 
mov dword [ebx+0x14],0x00409800    ;粒度为1个字节，代码段描述符 

;建立保护模式下的堆栈段描述符     
mov dword [ebx+0x18],0x7c00fffe     ;基地址为0x00007C00，界限0xFFFFE     
mov dword [ebx+0x1c],0x00cf9600     ;粒度为4KB 

;建立保护模式下的显示缓冲区描述符   
mov dword [ebx+0x20],0x80007fff    ;基地址为0x000B8000，界限0x07FFF 
mov dword [ebx+0x24],0x0040920b    ;粒度为字节

;初始化描述符表寄存器GDTR，尚未进入守护模式，仍然可以向代码段内存写数据
mov word [cs:pgdt+0x7c00],39        ;描述符表的界限，总共5个描述符，总字节数：5*8=40，需要在-1，所以是39
lgdt [cs:pgdt+0x7c00]               ;加载全局描述符表寄存器，正好需要加载48位

in al,0x92                          ;南桥芯片内的端口 
or al,0000_0010B
out 0x92,al                         ;打开A20，使地址线A20可用

cli                                 ;实模式下的中断不能在保护模式下运行了，所以需要禁掉中断

mov eax,cr0                         ;cr0是控制寄存器0，位0用于控制是否开启保护模式
or eax,1                            ;开启保护模式（PE）
mov cr0,eax

;以下进入保护模式
jmp dword 0x0010:flush              ;16位描述符选择子（描述符表中的代码段，索引为2，因为每个描述符大小为8，所以需要乘以8）
                                    ;flush指的是32位偏移地址，jmp指令会清空流水线并串行化处理器

[bits 32]                           ;按32位模式译码，也就是下面的代码是保护模式代码
flush:
    mov eax,0x08                   ;16位描述符选择子，描述符表中的数据段，索引为1
    mov ds,eax

    mov eax,0x18                   ;16位描述符选择子，描述符表中的栈段，索引为3
    mov ss,eax
    xor esp,esp                    ;栈指针设置为0

    ;以下加载内核程序
    mov edi,core_base_address       ;edi目标索引寄存器,内核代码所在内存起始地址

    mov eax,core_start_sector       ;内核程序所在扇区
    mov ebx,edi                     ;起始地址
    call read_hard_disk_0           ;读取程序的起始部分（一个扇区）

    ;以下判断整个程序有多大
    mov eax,[edi]                   ;内核起始地址数据，就是内核程序的长度
    xor edx,edx
    mov ecx,512                     ;硬盘扇区大小
    div ecx

    or edx,edx                      
    jnz @1                          ;余数不为0表示未除尽，表示还有一个扇区需要读，不需要去减去一个扇区了，因为已经读了一个扇区了，直接跳转到@1
    dec eax                         ;已经读取过头扇区了，所以需要减去一个
@1:
    or eax,eax                      ;商为0表示程序的大小刚好小于等于512字节
    jz setup

    ;读取剩余扇区
    mov ecx,eax                     ;32位模式下的LOOP使用ECX
    mov eax,core_start_sector
    inc eax                         ;扇区号+1,从下一个扇区接着读
@2:
    call read_hard_disk_0
    inc eax                         ;扇区号+1
    loop @2                         ;先将ecx值减一，如果ecx的值不为0，则执行循环，否则向下继续执行

setup:
    mov esi,[0x7c00+pgdt+0x02]      ;已经进入保护模式了，不能在通过代码段进行内存读写了，但可以通过4G数据段访问
                                    ;+0x02是为了跳过描述符的界限

    ;创建内核通用例程段描述符
    mov eax,[edi+0x04]              ;通用例程段汇编偏移地址
    mov ebx,[edi+0x08]              ;内核数据段汇编偏移地址
    sub ebx,eax
    dec ebx                         ;两者差值再减一就是通用例程的段界限
    add eax,edi                     ;通用例程段基地址
    mov ecx,0x00409800              ;字节粒度的代码段描述符
    call make_gdt_descriptor        ;构造段描述符，结果在：edx:eax
    mov [esi+0x28],eax              ;写入全局段描述符表
    mov [esi+0x2c],edx

    ;创建核心数据段描述符
    mov eax,[edi+0x08]                 ;核心数据段起始汇编地址
    mov ebx,[edi+0x0c]                 ;核心代码段汇编地址 
    sub ebx,eax
    dec ebx                            ;核心数据段界限
    add eax,edi                        ;核心数据段基地址
    mov ecx,0x00409200                 ;字节粒度的数据段描述符 
    call make_gdt_descriptor
    mov [esi+0x30],eax
    mov [esi+0x34],edx 

    ;创建核心代码段描述符
    mov eax,[edi+0x0c]                 ;核心代码段起始汇编地址
    mov ebx,[edi+0x00]                 ;程序总长度
    sub ebx,eax
    dec ebx                            ;核心代码段界限
    add eax,edi                        ;核心代码段基地址
    mov ecx,0x00409800                 ;字节粒度的代码段描述符
    call make_gdt_descriptor
    mov [esi+0x38],eax
    mov [esi+0x3c],edx

    mov word [0x7c00+pgdt],63           ;又增加3个描述符，总共8个描述符了
    lgdt [0x7c00+pgdt]                  ;重新加载到全局描述符表寄存器

    jmp far [edi+0x10]                    ;跳转到内核程序入口处，将控制权交给内核程序

;-----------从硬盘读取一个逻辑扇区----------------------------------------------------------------
read_hard_disk_0:               ;使用的逻辑扇区编址方法为LBA28，也就是用28位来表示扇区号，每个扇区512字节
                                ;eax=逻辑扇区号
                                ;ds:ebx=目标缓冲区地址，将读到的硬盘数据放到ds段指定的内存中

    push eax                    ;将该过程会用到的寄存器入栈保存，函数返回时需要出栈还原
    push ecx
    push edx

    push eax                    ;在入栈一次eax的值

    mov dx,0x1f2                ;0x1f2端口表示要读取或写入的扇区数量，8位长度
    mov al,1                    ;每次要读取1个扇区
    out dx,al

    ;28位的扇区号太长，需要放到4个8位端口中，0x1f3存0-7位，0x1f4存8-15位，0x1f5存16-23位，
    ;0x1f6低4位存24-27位，第4位用于指示硬盘号，0是主盘、1是从盘,高三为全为1，表示LBA模式
    inc dx                      ;0x1f3
    pop eax                     ;eax存放的是32位逻辑扇区号
    out dx,al                   ;LBA地址7-0

    inc dx                      ;0x1f4
    mov cl,8
    shr eax,cl
    out dx,al                    ;LBA地址15~8

    inc dx                       ;0x1f5
    shr eax,cl
    out dx,al                    ;LBA地址23~16

    inc dx                      ;0x1f6
    shr eax,cl
    or al,0xe0                  ;因为al是1110 0000，ah高4位是0，0000 xxxx,使用or运算后al就是xxxx,表示LBA地址27-24
    out dx,al

    inc dx                      ;0x1f7，既是命令端口也是状态端口，0x20表示读，0x30表示写
    mov al,0x20                 ;表示读硬盘
    out dx,al                  

    .waits:
        in al,dx                    ;读取硬盘状态，第7位是1表示硬盘在忙碌，第3位是1表示已经读取完可以传输数据了
        and al,0x88                 ;二进制值：1000 1000，保留第7位与第3位的值，其他位全清0
        cmp al,0x08                 ;二进制值：0000 1000，是否已经准备好了
        jnz .waits                  ;尚未准备好，继续循环等待

    mov ecx,256                  ;总共要读取的字数
    mov dx,0x1f0                 ;硬盘数据端口，长度为16位的

    .readw:
        in ax,dx                    ;从硬盘读取一个字
        mov [ebx],ax                ;放到ds段内存中
        add ebx,2                   ;bx偏移地址+2
        loop .readw                 ;先将ecx值减一，如果ecx的值不为0，则执行循环，否则向下继续执行

    pop edx                      ;出栈，还原相关寄存器的原始值
    pop ecx
    pop eax

    ret                         ;返回

;-----------构造描述符--------------------------------------------------------------------
make_gdt_descriptor:            ;输入：eax=线性基址，ebx=段界限,ecx=属性（各属性位都在原始位置，其它没用到的位置0） 
                                ;输出edx:eax
    mov edx,eax
    shl eax,16                  ;描述符低32位中的高16位是基地址部分，所以左移16位使其基地址部分就位
    or ax,bx                    ;低16位是段界限，取的段界限

    and edx,0xffff0000          ;清除低16位
    rol edx,8                   ;edx循环左移8位，循环左移会将左移出的位放到右边。这样edx中低8位的值就是原先高8位的值
    bswap edx                   ;字节交换指令。装配基址的31~24和23~16  (80486+)

    xor bx,bx
    or edx,ebx                  ;装配段界限的高4位
    
    or edx,ecx                  ;装配段属性

    ret

;-----------描述符物理地址--------------------------------------------------------------------
pgdt dw 0           ;描述符表的界限
     dd 0x00007e00  ;全局描述符表起始物理地址，该地址刚好是主引导程序后面的地址。
                    ;总共是16位+32位=48位，正好与GDTR寄存器的位数匹配

;-------------------------------------------------------------------------------
times 510-($-$$)  db  0 ;剩余的字节数用0填充，'$$'表示当前段的起始地址，'$-$$'正好是当前程序的字节大小
                  db  0x55,0xaa ;引导扇区结束标识

