;保护模式示例
;硬盘主引导扇区代码

;设置栈段和栈指针
mov ax,cs               ;栈段寄存器指向cs代码段
mov ss,ax
mov sp,0x7c00           ;栈指针指向代码起始位置，栈是向下增长的，范围为0x7c00-0x00

;计算GDT所在逻辑段的地址
mov ax,[cs:gdt_base+0x7c00]     ;低16位
mov dx,[cs:gdt_base+0x7c00+2]   ;高16位
mov bx,16
div bx      
mov ds,ax                       ;ax是商，也就是段地址放到ds中
mov bx,dx                       ;dx是余数，也就是偏移地址，放到bx中

;创建#0描述符，它是空描述符，处理器要求的
mov dword [bx],0x00
mov dword [bx+0x04],0x00

;创建#1描述符，保护模式下的代码段描述符
mov dword [bx+0x08],0x7c0001ff     
mov dword [bx+0x0c],0x00409800     ;线性基地址为0x00007c00,段界限为0x001FF。该描述符指向的就是当前正在运行的引导程序

;创建#2描述符，保护模式下的数据段描述符（文本模式下的显示缓冲区） 
mov dword [bx+0x10],0x8000ffff     ;线性基地址为0x000B8000,段界限为0x0ffff。该描述符指向的是显存地址
mov dword [bx+0x14],0x0040920b     

;创建#3描述符，保护模式下的堆栈段描述符
mov dword [bx+0x18],0x00007a00     ;线性基地址为0x00000000,段界限为0x07a00
mov dword [bx+0x1c],0x00409600

;初始化描述符表寄存器GDTR
mov word [cs:gdt_size+0x7c00],31    ;描述符表的界限，总共4个描述符，总字节数：4*8=32，需要在-1，所以是31
lgdt [cs:gdt_size+0x7c00]           ;加载全局描述符表寄存器，正好需要加载48位

in al,0x92                          ;南桥芯片内的端口 
or al,0000_0010B
out 0x92,al                         ;打开A20，使地址线A20可用

cli                                 ;实模式下的中断不能在保护模式下运行了，所以需要禁掉中断

mov eax,cr0                         ;cr0是控制寄存器0，位0用于控制是否开启保护模式
or eax,1                            ;开启保护模式（PE）
mov cr0,eax

;以下进入保护模式
jmp dword 0x0008:flush              ;16位描述符选择子（描述符表中的代码段，索引为1，因为每个描述符大小为8，所以需要乘以8）
                                    ;flush指的是32位偏移地址，jmp指令会清空流水线并串行化处理器

[bits 32]                           ;按32位模式译码，也就是下面的代码是保护模式代码
flush:
    mov cx,0x10                     ;16位描述符选择子，描述符表中的数据段，索引为2
    mov ds,cx                       

    ;以下在屏幕上显示"Protect mode OK." 
    mov byte [0x00],'P'  
    mov byte [0x02],'r'
    mov byte [0x04],'o'
    mov byte [0x06],'t'
    mov byte [0x08],'e'
    mov byte [0x0a],'c'
    mov byte [0x0c],'t'
    mov byte [0x0e],' '
    mov byte [0x10],'m'
    mov byte [0x12],'o'
    mov byte [0x14],'d'
    mov byte [0x16],'e'
    mov byte [0x18],' '
    mov byte [0x1a],'O'
    mov byte [0x1c],'K'
    
    ;以下用简单的示例来帮助阐述32位保护模式下的堆栈操作 
    mov cx,0x18                 ;栈段选择子，索引为3，3*8=0x18
    mov ss,cx
    mov esp,0x7c00              ;栈指针为0x7c00

    mov ebp,esp                 ;保存栈指针
    push byte '.'               ;压入1字节立即数

    sub ebp,4
    cmp ebp,esp                 ;判断压入立即数时esp是否-4
    jnz ghalt                   ;不相等则结束
    pop eax
    mov byte [0x1e],al          ;显示.

ghalt:
    hlt                         ;使CPU进入低功耗状态。已经禁止中断，将不会被唤醒 

;-------------------------------------------------------------------------------
gdt_size dw 0           ;描述符表的界限
gdt_base dd 0x00007e00  ;全局描述符表起始物理地址，该地址刚好是主引导程序后面的地址。
                        ;总共是16位+32位=48位，正好与GDTR寄存器的位数匹配

times 510-($-$$)  db  0 ;剩余的字节数用0填充，'$$'表示当前段的起始地址，'$-$$'正好是当前程序的字节大小
                  db  0x55,0xaa ;引导扇区结束标识