;保护模式微型内核程序 

;以下是常量定义。内核的大部分内容都应当固定 
core_code_seg_sel    equ  0x38    ;内核代码段选择子
core_data_seg_sel    equ  0x30    ;内核数据段选择子 
sys_routine_seg_sel  equ  0x28    ;系统公共例程代码段的选择子 
video_ram_seg_sel    equ  0x20    ;视频显示缓冲区的段选择子
core_stack_seg_sel   equ  0x18    ;内核堆栈段选择子
mem_0_4_gb_seg_sel   equ  0x08    ;整个0-4GB内存的段的选择子

;--------内核头部-----------------------------------------------------------------------
;以下是系统核心的头部，用于加载核心程序 
core_length dd core_end                         ;[0x00]内核总长度，双字，32位
sys_routine_seg dd section.sys_routine.start    ;[0x04]系统通用库偏移地址
core_data_seg dd section.core_data.start        ;[0x08]内核数据段偏移地址
core_code_seg dd section.core_code.start        ;[0x0c]内核代码段偏移地址
core_entry dd start                             ;[0x10]内核代码段入口地址偏移量
           dw core_code_seg_sel                 ;[0x14]内核代码段选择子,16位的


[bits 32]
;--------系统通用库、提供字符串显示等功能-----------------------------------------------------------------------
section sys_routine vstart=0
       ;字符串显示例程
       put_string:                                 ;显示0终止的字符串并移动光标 
                                                   ;输入：DS:EBX=串地址
              push ecx
       .getc:
              mov cl,[ebx]
              or cl,cl
              jz .exit
              call put_char
              inc ebx
              jmp .getc

       .exit:
              pop ecx
              retf                               ;段间返回

;-------显示文本--------------------------------------------------------------------
       put_char:                               ;在当前光标处显示一个字符,并推进
                                            ;光标。仅用于段内调用 
                                            ;输入：CL=字符ASCII码 
              pushad                        ;依次压入：EAX,ECX,EDX,EBX,ESP(初始值)，EBP,ESI,EDI     

              ;以下取当前光标位置
              mov dx,0x3d4
              mov al,0x0e
              out dx,al
              inc dx                             ;0x3d5
              in al,dx                           ;高字
              mov ah,al

              dec dx                             ;0x3d4
              mov al,0x0f
              out dx,al
              inc dx                             ;0x3d5
              in al,dx                           ;低字
              mov bx,ax                          ;BX=代表光标位置的16位数

              cmp cl,0x0d                        ;回车符？
              jnz .put_0a
              mov ax,bx
              mov bl,80
              div bl
              mul bl
              mov bx,ax
              jmp .set_cursor

       .put_0a:
              cmp cl,0x0a                        ;换行符？
              jnz .put_other
              add bx,80
              jmp .roll_screen

       .put_other:                               ;正常显示字符
              push es
              mov eax,video_ram_seg_sel          ;0xb8000段的选择子
              mov es,eax
              shl bx,1
              mov [es:bx],cl
              pop es

              ;以下将光标位置推进一个字符
              shr bx,1
              inc bx

       .roll_screen:
              cmp bx,2000                        ;光标超出屏幕？滚屏
              jl .set_cursor

              push ds
              push es
              mov eax,video_ram_seg_sel
              mov ds,eax
              mov es,eax
              cld
              mov esi,0xa0                       ;小心！32位模式下movsb/w/d 
              mov edi,0x00                       ;使用的是esi/edi/ecx 
              mov ecx,1920
              rep movsd
              mov bx,3840                        ;清除屏幕最底一行
         mov ecx,80                         ;32位程序应该使用ECX
       .cls:
              mov word[es:bx],0x0720
              add bx,2
              loop .cls

              pop es
              pop ds

              mov bx,1920

       .set_cursor:
              mov dx,0x3d4
              mov al,0x0e
              out dx,al
              inc dx                             ;0x3d5
              mov al,bh
              out dx,al
              dec dx                             ;0x3d4
              mov al,0x0f
              out dx,al
              inc dx                             ;0x3d5
              mov al,bl
              out dx,al

              popad
              ret                                


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

              retf                         ;段间返回

;--------输出调试信息-----------------------------------------------------------------------
       put_hex_dword:                     ;汇编语言程序是极难一次成功，而且调试非常困难。这个例程可以提供帮助 
                                          ;输入：EDX=要转换并显示的数字。在当前光标处以十六进制形式显示 ;一个双字并推进光标 
              pushad
              push ds

              mov ax,core_data_seg_sel           ;切换到核心数据段 
              mov ds,ax

              mov ebx,bin_hex                    ;指向核心数据段内的转换表
              mov ecx,8
       .xlt:    
              rol edx,4
              mov eax,edx
              and eax,0x0000000f
              xlat

              push ecx
              mov cl,al                           
              call put_char
              pop ecx

              loop .xlt

              pop ds
              popad
              retf
;--------分配内存-----------------------------------------------------------------------
       allocate_memory:
                                          ;输入ecx=希望分配的内存字节数，输出ecx=已分配的内存起始线性地址
              push ds
              push eax
              push ebx

              mov eax,core_data_seg_sel
              mov ds,eax                  ;使ds指向4G内存选择子

              mov eax,[ram_alloc]           
              add eax,ecx                 ;下一次分配内存时的起始地址

              ;todo 这里应当有检测可用内存数量的指令

              mov ecx,[ram_alloc]         ;返回分配的起始地址

              mov ebx,eax
              and ebx,0xfffffffc
              and ebx,4                   ;强制4字节对齐
              test eax,0x00000003         ;测试下一次分配内存的起始地址是不是4字节对齐的
              cmovnz eax,ebx              ;如果没有对齐，则强制对齐。cmovnz指令可以避免控制转移
              mov [ram_alloc],eax         ;下次从该地址分配内存 

              pop ebx
              pop eax
              pop ds

              retf

;-----------在GDT内安装一个新的描述符--------------------------------------------------------------------
       set_up_gdt_descriptor:             ;输入edx:eax=描述符，输出cx=描述符选择子
              push eax
              push ebx
              push edx
       
              push ds
              push es
       
              mov ebx,core_data_seg_sel          ;切换到核心数据段
              mov ds,ebx

              sgdt [pgdt]                        ;读取寄存器GDTR，存放到内存

              mov ebx,mem_0_4_gb_seg_sel
              mov es,ebx

              movzx ebx,word [pgdt]              ;GDT界限 
              inc bx                             ;GDT总字节数，也是下一个描述符偏移 
              add ebx,[pgdt+2]                   ;下一个描述符的线性地址 
       
              mov [es:ebx],eax
              mov [es:ebx+4],edx
       
              add word [pgdt],8                  ;增加一个描述符的大小   
       
              lgdt [pgdt]                        ;对GDT的更改生效 
              
              mov ax,[pgdt]                      ;得到GDT界限值
              xor dx,dx
              mov bx,8
              div bx                             ;除以8，去掉余数
              mov cx,ax                          
              shl cx,3                           ;将索引号移到正确位置 

              pop es
              pop ds

              pop edx
              pop ebx
              pop eax
       
              retf 

;-----------构造描述符--------------------------------------------------------------------
       make_seg_descriptor:               ;输入：eax=线性基址，ebx=段界限,ecx=属性（各属性位都在原始位置，其它没用到的位置0） 
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

              retf
;--------内核数据段-----------------------------------------------------------------------
section core_data vstart=0
       pgdt          dw     0      ;用于保存全局描述符表
                     dd     0

       ram_alloc     dd  0x00100000    ;下次分配内存时的起始地址
       ;符号地址检索表
       salt:
              salt_1 db '@PrintString'           ;打印字符串函数别名
              times 256-($-salt_1) db 0          ;不足256长度的补0
                     dd put_string               ;函数偏移量       
                     dw sys_routine_seg_sel      ;公共库代码段选择子

              salt_2 db  '@ReadDiskData'
                     times 256-($-salt_2) db 0
                     dd  read_hard_disk_0
                     dw  sys_routine_seg_sel

              salt_3 db  '@PrintDwordAsHexString'
                     times 256-($-salt_3) db 0
                     dd  put_hex_dword
                     dw  sys_routine_seg_sel

              salt_4 db  '@TerminateProgram'     ;终止用户程序
                     times 256-($-salt_4) db 0
                     dd  return_point
                     dw  core_code_seg_sel

       salt_item_len equ $-salt_4                ;单个符号表大小
       salt_items equ ($-salt)/salt_item_len     ;符号表数量

       message_1     db  '  If you seen this message,that means we '
                     db  'are now in protect mode,and the system '
                     db  'core is loaded,and the video display '
                     db  'routine works perfectly.',0x0d,0x0a,0
       ;加载用户程序时需要显示的提示
       message_5     db  '  Loading user program...',0
       ;用户程序加载完成提示
       do_status        db  'Done.',0x0d,0x0a,0

       ;用户程序执行完毕的提示
       message_6     db  0x0d,0x0a,0x0d,0x0a,0x0d,0x0a
                     db  '  User program terminated,control returned.',0

       bin_hex       db '0123456789ABCDEF'
       ;内核缓冲区，可以放用户程序
       core_buf   times 2048 db 0
       esp_pointer      dd 0              ;内核用来临时保存自己的栈指针 
       ;cpu处理器品牌信息
       cpu_brnd0        db 0x0d,0x0a,'  ',0
       cpu_brand  times 52 db 0
       cpu_brnd1        db 0x0d,0x0a,0x0d,0x0a,0
;--------内核代码段-----------------------------------------------------------------------
section core_code vstart=0
;--------加载并重定位用户程序-----------------------------------------------------------------------
       load_relocate_program:      ;输入esi=起始逻辑扇区号，返回：ax=指向用户程序头部的选择子
              push ebx
              push ecx
              push edx
              push esi
              push edi

              push ds
              push es

              mov eax,core_data_seg_sel
              mov ds,eax                      ;使ds指向内核数据区

              mov eax,esi                     ;用户程序所在扇区号
              mov ebx,core_buf
              call sys_routine_seg_sel:read_hard_disk_0   ;读取用户头

              ;以下判断用户程序大小
              mov eax,[core_buf]              ;用户程序大小就放在开头部分
              mov ebx,eax
              and ebx,0xfffffe00                 ;使之512字节对齐（能被512整除的数， 
              add ebx,512                        ;低9位都为0 
              test eax,0x000001ff                ;程序的大小正好是512的倍数吗? 
              cmovnz eax,ebx                     ;不是。使用凑整的结果。使用条件传输指令

              mov ecx,eax                               ;实际需要申请的内存数量
              call sys_routine_seg_sel:allocate_memory  ;申请内存分配
              mov ebx,ecx
              push ebx                                  ;保存该首地址
              xor edx,edx
              mov ecx,512
              div ecx
              mov ecx,eax                               ;商就是总扇区数

              mov eax,mem_0_4_gb_seg_sel                ;ds切换到4G内存数据段
              mov ds,eax

              mov eax,esi                               ;起始扇区号

       .b1:
              call sys_routine_seg_sel:read_hard_disk_0        ;读取剩余部分
              inc eax
              loop .b1                                         ;先将ecx值减一，如果ecx的值不为0，则执行循环，否则向下继续执行

              ;建立程序头部段描述符
              pop edi                                          ;恢复程序装载的首地址
              mov eax,edi
              mov ebx,[edi+0x04]                               ;头部段长度
              dec ebx                                          ;长度-1就是段界限
              mov ecx,0x00409200                               ;字节粒度的数据段描述符
              call sys_routine_seg_sel:make_seg_descriptor     ;构造段描述符
              call sys_routine_seg_sel:set_up_gdt_descriptor   ;安装段描述符并返回段选择子
              mov [edi+0x04],cx                                ;将段选择子写回头部

              ;建立程序代码段描述符
              mov eax,edi
              add eax,[edi+0x14]                               ;代码段偏移地址
              mov ebx,[edi+0x18]                               ;段长度
              dec ebx                                          ;段界限
              mov ecx,0x00409800                               ;字节粒度的代码段描述符
              call sys_routine_seg_sel:make_seg_descriptor     ;构造段描述符
              call sys_routine_seg_sel:set_up_gdt_descriptor   ;安装段描述符并返回段选择子
              mov [edi+0x14],cx                                ;将段选择子写回

              ;建立程序数据段描述符
              mov eax,edi
              add eax,[edi+0x1c]                 ;数据段起始线性地址
              mov ebx,[edi+0x20]                 ;段长度
              dec ebx                            ;段界限
              mov ecx,0x00409200                 ;字节粒度的数据段描述符
              call sys_routine_seg_sel:make_seg_descriptor
              call sys_routine_seg_sel:set_up_gdt_descriptor
              mov [edi+0x1c],cx

              ;建立程序栈段描述符
              mov ecx,[edi+0x0c]                 ;4KB的倍率 
              mov ebx,0x000fffff
              sub ebx,ecx                        ;得到段界限
              mov eax,4096                        
              mul dword [edi+0x0c]                         
              mov ecx,eax                        ;准备为堆栈分配内存 
              call sys_routine_seg_sel:allocate_memory
              add eax,ecx                        ;得到堆栈的高端物理地址 
              mov ecx,0x00c09600                 ;4KB粒度的堆栈段描述符
              call sys_routine_seg_sel:make_seg_descriptor
              call sys_routine_seg_sel:set_up_gdt_descriptor
              mov [edi+0x08],cx

              ;重定位SALT(符号地址检索表)
              mov eax,[edi+0x04]                 ;用户程序头部段选择子
              mov es,eax                         ;附加段寄存器指向用户程序头部
              mov eax,core_data_seg_sel
              mov ds,eax                         ;使数据段指向内核数据段

              cld                                ;将方向标志位DF清零,以指示比较是正方向的

              mov ecx,[es:0x24]                  ;用户程序符号表数量
              mov edi,0x28                       ;用户程序符号表起始地址
       .b2:
              push ecx
              push edi

              mov ecx,salt_items                 ;内核符号表数量
              mov esi,salt                       ;源索引寄存器，内核符号表起始地址

       .b3:
              push edi
              push esi
              push ecx

              mov ecx,64                         ;检索表中，每条目的比较次数。因为一次比较4字节，符号长度为256字节，所以比较次数为64
              repe cmpsd                         ;每次比较4字节字符串，repe是连续比较直到ecx为0，如果字符相等则重复比较
              jnz .b4                            ;不相等，跳走
              mov eax,[esi]                      ;若匹配，esi恰好指向其后的地址
              mov [es:edi-256],eax               ;修改用户符号为匹配到的地址
              mov ax,[esi+4]
              mov [es:edi-252],ax                ;以及段选择子
       .b4:
              pop ecx
              pop esi
              add esi,salt_item_len
              pop edi                            ;从头比较 
              loop .b3
       
              pop edi
              add edi,256
              pop ecx
              loop .b2

              mov ax,[es:0x04]

              pop es                             ;恢复到调用此过程前的es段 
              pop ds                             ;恢复到调用此过程前的ds段
       
              pop edi
              pop esi
              pop edx
              pop ecx
              pop ebx
       
              ret

;--------程序入口-----------------------------------------------------------------------
       start:
              mov ecx,core_data_seg_sel
              mov ds,ecx                      ;使ds指向内核数据段
              
              mov ebx,message_1
              call sys_routine_seg_sel:put_string     ;显示消息

              ;显示处理器品牌信息 
              mov eax,0x80000002
              cpuid
              mov [cpu_brand + 0x00],eax
              mov [cpu_brand + 0x04],ebx
              mov [cpu_brand + 0x08],ecx
              mov [cpu_brand + 0x0c],edx

              mov eax,0x80000003
              cpuid
              mov [cpu_brand + 0x10],eax
              mov [cpu_brand + 0x14],ebx
              mov [cpu_brand + 0x18],ecx
              mov [cpu_brand + 0x1c],edx

              mov eax,0x80000004
              cpuid
              mov [cpu_brand + 0x20],eax
              mov [cpu_brand + 0x24],ebx
              mov [cpu_brand + 0x28],ecx
              mov [cpu_brand + 0x2c],edx

              mov ebx,cpu_brnd0
              call sys_routine_seg_sel:put_string
              mov ebx,cpu_brand
              call sys_routine_seg_sel:put_string
              mov ebx,cpu_brnd1
              call sys_routine_seg_sel:put_string

              ;加载用户程序前的提示
              mov ebx,message_5
              call sys_routine_seg_sel:put_string

              mov esi,50                                ;用户程序放在硬盘第50扇区
              call load_relocate_program                ;加载并重定位用户程序

              mov ebx,do_status
              call sys_routine_seg_sel:put_string       ;显示用户程序加载完成提示

              mov [esp_pointer],esp                     ;临时保存栈指针

              mov ds,ax                                 ;ax中的值为用户程序头部选择子
              jmp far [0x10]                            ;跳转到用户程序

;--------终止用户程序-----------------------------------------------------------------------
       return_point:
              mov eax,core_data_seg_sel
              mov ds,eax                         ;使ds指向内核数据段

              mov eax,core_stack_seg_sel
              mov ss,eax                         ;切换回内核字节的堆栈
              mov esp,[esp_pointer]

              mov ebx,message_6
              call sys_routine_seg_sel:put_string       ;打印用户程序结束提示语

              ;这里可以放置清除用户程序各种描述符的指令
              ;也可以加载并启动其它程序

              hlt                                       ;使CPU进入低功耗状态，
;--------尾部段-----------------------------------------------------------------------
section core_trail
       core_end:   ;程序结尾标号，因为段没有定义vstart,所以该标号的偏移地址是从程序头开始的