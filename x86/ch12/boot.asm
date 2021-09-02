;保护模式示例
;硬盘主引导扇区代码

;设置栈段和栈指针
mov eax,cs              ;栈段寄存器指向cs代码段
mov ss,eax
mov sp,0x7c00           ;栈指针指向代码起始位置，栈是向下增长的，范围为0x7c00-0x00

;计算GDT所在逻辑段的地址
mov eax,[cs:pgdt+0x7c00+0x02]   ;GDT的32位线性基地址 
xor edx,edx                     
mov ebx,16
div ebx
mov ds,eax                      ;商就是段地址
mov ebx,edx                     ;余数就是偏移地址

;创建#0描述符，它是空描述符，处理器要求的
mov dword [ebx],0x00
mov dword [ebx+0x04],0x00

;创建#1描述符，这是一个数据段，对应0~4GB的线性地址空间
mov dword [ebx+0x08],0x0000ffff    ;基地址为0，段界限为0xfffff
mov dword [ebx+0x0c],0x00cf9200    ;粒度为4KB，存储器段描述符 

;#2描述符，创建保护模式下初始代码段描述符
mov dword [ebx+0x10],0x7c0001ff    ;基地址为0x00007c00，512字节 。该描述符指向的就是当前正在运行的引导程序
mov dword [ebx+0x14],0x00409800    ;粒度为1个字节，代码段描述符。使用此代码段访问时该块内存是不能写的 

;#3描述符，创建保护模式代码段的别名描述符
mov dword [ebx+0x18],0x7c0001ff    ;基地址为0x00007c00，512字节
mov dword [ebx+0x1c],0x00409200    ;粒度为1个字节，数据段描述符。使用该段访问时该块内存是可写的

;创建#4描述符，保护模式下的堆栈段描述符
mov dword [ebx+0x20],0x7c00fffe     ;基地址为0x00007c00,段界限为0xffffe
mov dword [ebx+0x24],0x00cf9600     ;粒度为4KB

;初始化描述符表寄存器GDTR
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
     mov eax,0x18                   ;16位描述符选择子，描述符表中的代码段别名描述符，索引为3
     mov ds,eax

     mov eax,0x08                   ;16位描述符选择子，描述符表中的数据段，索引为1
     mov es,eax
     mov fs,eax                    
     mov gs,eax                     ;其他段

     mov eax,0x20                   ;16位描述符选择子，描述符表中的栈段，索引为4
     mov ss,eax
     xor esp,esp                    ;栈指针设置为0

     mov dword [es:0x0b8000],0x072e0750 ;字符'P'、'.'及其显示属性
     mov dword [es:0x0b8004],0x072e074d ;字符'M'、'.'及其显示属性
     mov dword [es:0x0b8008],0x07200720 ;两个空白字符及其显示属性
     mov dword [es:0x0b800c],0x076b076f ;字符'o'、'k'及其显示属性

     ;开始冒泡排序
     mov ecx,pgdt-string-1         ;遍历次数=串长度-1 
@@1:
     push ecx                           ;32位模式下的loop使用ecx 
     xor bx,bx                          ;32位模式下，偏移量可以是16位，也可以是后面的32位
@@2:
     mov ax,[string+bx]                 ;一次读两个字符，ah上放的是高字节
     cmp ah,al
     jge @@3
     xchg al,ah                         ;交换内容
     mov [string+bx],ax                 ;回写
@@3:
     inc bx
     loop @@2                           ;先将ecx值减一，如果ecx的值不为0，则执行循环，否则向下继续执行
     pop ecx
     loop @@1
     
     ;以下循环输出排序后的结果
     mov ecx,pgdt-string
     xor ebx,ebx
@@4:
     mov ah,0x07                        ;黑底白字
     mov al,[string+ebx]
     mov [es:0xb80a0+2*ebx],ax       ;演示0~4GB寻址。
     inc ebx
     loop @@4

hlt

;-------------------------------------------------------------------------------
string           db 's0ke4or92xap3fv8giuzjcy5l1m7hd6bnqtw.'
;-------------------------------------------------------------------------------
pgdt dw 0           ;描述符表的界限
     dd 0x00007e00  ;全局描述符表起始物理地址，该地址刚好是主引导程序后面的地址。
                    ;总共是16位+32位=48位，正好与GDTR寄存器的位数匹配

;-------------------------------------------------------------------------------
times 510-($-$$)  db  0 ;剩余的字节数用0填充，'$$'表示当前段的起始地址，'$-$$'正好是当前程序的字节大小
                  db  0x55,0xaa ;引导扇区结束标识