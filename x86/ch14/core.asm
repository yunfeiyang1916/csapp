;保护模式微型内核程序 

;以下常量定义部分。内核的大部分内容都应当固定 
core_code_seg_sel     equ  0x38    ;内核代码段选择子
core_data_seg_sel     equ  0x30    ;内核数据段选择子 
sys_routine_seg_sel   equ  0x28    ;系统公共例程代码段的选择子 
video_ram_seg_sel     equ  0x20    ;视频显示缓冲区的段选择子
core_stack_seg_sel    equ  0x18    ;内核堆栈段选择子
mem_0_4_gb_seg_sel    equ  0x08    ;整个0-4GB内存的段的选择子

;-----------内核头部-----------------------------------------------------------------------
;以下是系统核心的头部，用于加载核心程序 
core_length dd core_end                         ;[0x00]内核总长度，双字，32位
sys_routine_seg dd section.sys_routine.start    ;[0x04]系统通用库偏移地址
core_data_seg dd section.core_data.start        ;[0x08]内核数据段偏移地址
core_code_seg dd section.core_code.start        ;[0x0c]内核代码段偏移地址
core_entry dd start                             ;[0x10]内核代码段入口地址偏移量
           dw core_code_seg_sel                 ;[0x14]内核代码段选择子,16位的


[bits 32]
;-----------系统通用库、提供字符串显示等功能-----------------------------------------------------------------------
section sys_routine vstart=0
;-----------显示字符串--------------------------------------------------------------------
    put_string:                             ;显示0终止的字符串并移动光标 
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

;-----------输出调试信息-----------------------------------------------------------------------
    put_hex_dword:                      ;汇编语言程序是极难一次成功，而且调试非常困难。这个例程可以提供帮助 
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

;-----------分配内存-----------------------------------------------------------------------
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
    make_seg_descriptor:            ;输入：eax=线性基址，ebx=段界限,ecx=属性（各属性位都在原始位置，其它没用到的位置0） 
                                    ;输出edx:eax=完整的描述符
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

;-----------构造门的描述符（调用门等）--------------------------------------------------------------------
    make_gate_descriptor:           ;输入：eax=门代码在段内的偏移地址，bx=门代码的段选择子，cx=门属性
                                    ;输出：edx:eax=完整的描述符
        push ebx
        push ecx

        mov edx,eax
        and edx,0xffff0000          ;得到偏移地址高16位 
        or  dx,cx                   ;组装属性部分到edx

        and eax,0x0000ffff          ;得到偏移地址低16位
        shl ebx,16                  ;左移16位使段选择子位于它的高16位        
        or eax,ebx                  ;组装段选择子部分
    
        pop ecx
        pop ebx
    
        retf   

    sys_routine_end:

;-----------内核数据段-----------------------------------------------------------------------
section core_data vstart=0                   
    pgdt            dw  0             ;用于设置和修改GDT 
                    dd  0

    ram_alloc       dd  0x00100000    ;下次分配内存时的起始地址

    ;符号地址检索表
    salt:
        salt_1          db  '@PrintString'      ;打印字符串函数别名
                    times 256-($-salt_1) db 0   ;不足256长度的补0
                        dd  put_string          ;函数偏移量
                        dw  sys_routine_seg_sel ;公共库代码段选择子，内核执行时会使用调用门段选择子替换

        salt_2          db  '@ReadDiskData'
                    times 256-($-salt_2) db 0
                        dd  read_hard_disk_0
                        dw  sys_routine_seg_sel

        salt_3          db  '@PrintDwordAsHexString'
                    times 256-($-salt_3) db 0
                        dd  put_hex_dword
                        dw  sys_routine_seg_sel

        salt_4          db  '@TerminateProgram'
                    times 256-($-salt_4) db 0
                        dd  return_point
                        dw  core_code_seg_sel

        salt_item_len   equ $-salt_4                ;单个符号表大小，262字节
        salt_items      equ ($-salt)/salt_item_len  ;符号表数量

    message_1       db  '  If you seen this message,that means we '
                    db  'are now in protect mode,and the system '
                    db  'core is loaded,and the video display '
                    db  'routine works perfectly.',0x0d,0x0a,0

    message_2       db  '  System wide CALL-GATE mounted.',0x0d,0x0a,0

    message_3       db  0x0d,0x0a,'  Loading user program...',0

    do_status       db  'Done.',0x0d,0x0a,0

    message_6       db  0x0d,0x0a,0x0d,0x0a,0x0d,0x0a
                    db  '  User program terminated,control returned.',0

    bin_hex         db '0123456789ABCDEF'
                                    ;put_hex_dword子过程用的查找表 

    core_buf   times 2048 db 0         ;内核用的缓冲区

    esp_pointer     dd 0              ;内核用来临时保存自己的栈指针     

    cpu_brnd0       db 0x0d,0x0a,'  ',0
    cpu_brand  times 52 db 0
    cpu_brnd1       db 0x0d,0x0a,0x0d,0x0a,0

    ;任务控制块链表头
    tcb_chain       dd  0

    core_data_end:

;-----------内核代码段-----------------------------------------------------------------------
section core_code vstart=0
;-----------在LDT内安装一个新的描述符-----------------------------------------------------------------------
    fill_descriptor_in_ldt:             ;输入：edx:eax=完整描述符，ebx=TCB基地址
                                        ;输出：cx=描述符选择子
        push eax
        push edx
        push edi
        push ds

        mov ecx,mem_0_4_gb_seg_sel
        mov ds,ecx                      ;使ds指向4G数据段

        mov edi,[ebx+0x0c]              ;获得LDT基地址

        xor ecx,ecx
        mov cx,[ebx+0x0a]               ;获得LDT界限
        inc cx                          ;LDT的总字节数，即新描述符偏移地址

        mov [edi+ecx+0x00],eax
        mov [edi+ecx+0x04],edx          ;安装描述符

        add cx,8                           
        dec cx                          ;得到新的LDT界限值 

        mov [ebx+0x0a],cx               ;更新LDT界限值到TCB

        mov ax,cx
        xor dx,dx
        mov cx,8
        div cx                          ;除以8，商就是新描述符的索引

        mov cx,ax
        shl cx,3                         ;左移3位，并且
        or cx,0000_0000_0000_0100B       ;使TI位=1，指向LDT，最后使RPL=00 

        pop ds
        pop edi
        pop edx
        pop eax
    
        ret

;-----------加载并重定位用户程序-----------------------------------------------------------------------
    load_relocate_program:              ;输入push:逻辑扇区号，push:任务控制块起始地址
                                        ;调用该函数时会先压入EIP
        pushad                          ;依次压入：EAX,ECX,EDX,EBX,ESP(初始值)，EBP,ESI,EDI,共8个寄存器
        push ds
        push es                         

        mov ebp,esp                     ;使栈基址寄存器指向初始栈地址
        mov ecx,mem_0_4_gb_seg_sel
        mov es,ecx                      ;es指向4G数据段

        mov esi,[ebp+11*4]              ;因为又压入了11个寄存器的值，所以取任务控制块起始地址需要从11偏移量开始
                                        ;用ebp寻址时，会使用段寄存器ss

        ;以下申请创建LDT局部描述符表内存
        mov ecx,160                     ;允许安装20个LDT,每个描述符占8字节
        call sys_routine_seg_sel:allocate_memory    ;分配内存，返回ecx=已分配起始内存地址
        mov [es:esi+0x0c],ecx           ;登记LDT基地址到TCB中
        mov word [es:esi+0x0a],0xffff   ;登记LDT初始的界限到TCB中 

        ;以下开始加载用户程序
        mov eax,core_data_seg_sel
        mov ds,eax                      ;使ds指向内核数据段

        mov eax,[ebp+12*4]              ;读取起始扇区号
        mov ebx,core_buf                ;用于读取磁盘数据的内核缓冲区
        call sys_routine_seg_sel:read_hard_disk_0

        ;以下判断整个程序有多大
        mov eax,[core_buf]                  ;程序尺寸
        mov ebx,eax
        and ebx,0xfffffe00                  ;使之512字节对齐（能被512整除的数低 
        add ebx,512                         ;9位都为0 
        test eax,0x000001ff                 ;程序的大小正好是512的倍数吗? 
        cmovnz eax,ebx                      ;不是。使用凑整的结果

        mov ecx,eax                         ;程序的大小
        call sys_routine_seg_sel:allocate_memory    ;分配内存，返回ecx=已分配起始内存地址
        mov [es:esi+0x06],ecx               ;登记用户程序起始线性地址到TCB中

        mov ebx,ecx                         ;ebx -> 申请到的内存首地址
        xor edx,edx
        mov ecx,512
        div ecx
        mov ecx,eax                         ;总扇区数 
    
        mov eax,mem_0_4_gb_seg_sel          ;切换DS到0-4GB的段
        mov ds,eax

        mov eax,[ebp+12*4]                  ;起始扇区号 
    .b1:
        call sys_routine_seg_sel:read_hard_disk_0         ;读取剩余部分
        inc eax
        loop .b1                                          ;先将ecx值减一，如果ecx的值不为0，则执行循环，否则向下继续执行  

        mov edi,[es:esi+0x06]                             ;获得程序加载基地址    

        
        ;建立程序头部段描述符
        mov eax,edi                        ;程序头部起始线性地址
        mov ebx,[edi+0x04]                 ;段长度
        dec ebx                            ;段界限
        mov ecx,0x0040f200                 ;字节粒度的数据段描述符，特权级3 
        call sys_routine_seg_sel:make_seg_descriptor

        ;安装头部段描述符到LDT中
        mov ebx,esi                         ;TCB基地址                              
        call fill_descriptor_in_ldt         ;安装头部段描述符到LDT中

        or cx,0000_0000_0000_0011B         ;设置选择子的特权级为3
        mov [es:esi+0x44],cx               ;登记程序头部段选择子到TCB 
        mov [edi+0x04],cx                  ;和用户程序头部内 

        ;建立程序代码段描述符
        mov eax,edi
        add eax,[edi+0x14]                 ;代码起始线性地址
        mov ebx,[edi+0x18]                 ;段长度
        dec ebx                            ;段界限
        mov ecx,0x0040f800                 ;字节粒度的代码段描述符，特权级3
        call sys_routine_seg_sel:make_seg_descriptor
        mov ebx,esi                        ;TCB的基地址
        call fill_descriptor_in_ldt
        or cx,0000_0000_0000_0011B         ;设置选择子的特权级为3
        mov [edi+0x14],cx                  ;登记代码段选择子到头部

        ;建立程序数据段描述符
        mov eax,edi
        add eax,[edi+0x1c]                 ;数据段起始线性地址
        mov ebx,[edi+0x20]                 ;段长度
        dec ebx                            ;段界限 
        mov ecx,0x0040f200                 ;字节粒度的数据段描述符，特权级3
        call sys_routine_seg_sel:make_seg_descriptor
        mov ebx,esi                        ;TCB的基地址
        call fill_descriptor_in_ldt
        or cx,0000_0000_0000_0011B         ;设置选择子的特权级为3
        mov [edi+0x1c],cx                  ;登记数据段选择子到头部

        ;建立程序堆栈段描述符
        mov ecx,[edi+0x0c]                 ;4KB的倍率 
        mov ebx,0x000fffff
        sub ebx,ecx                        ;得到段界限
        mov eax,4096                        
        mul ecx                         
        mov ecx,eax                        ;准备为堆栈分配内存 
        call sys_routine_seg_sel:allocate_memory
        add eax,ecx                        ;得到堆栈的高端物理地址 
        mov ecx,0x00c0f600                 ;字节粒度的堆栈段描述符，特权级3
        call sys_routine_seg_sel:make_seg_descriptor
        mov ebx,esi                        ;TCB的基地址
        call fill_descriptor_in_ldt
        or cx,0000_0000_0000_0011B         ;设置选择子的特权级为3
        mov [edi+0x08],cx                  ;登记堆栈段选择子到头部

        ;重定位SALT 
        mov eax,mem_0_4_gb_seg_sel         ;这里和前一章不同，头部段描述符已安装，但还没有生效，故只能通过4GB段访问用户程序头部  
        mov es,eax

        mov eax,core_data_seg_sel
        mov ds,eax
    
        cld

        mov ecx,[es:edi+0x24]              ;U-SALT条目数(通过访问4GB段取得) 
        add edi,0x28                       ;U-SALT在4GB段内的偏移 

    .b2: 
        push ecx
        push edi

        mov ecx,salt_items                  ;内核符号表数量
        mov esi,salt                        ;源索引寄存器，内核符号表起始地址
    .b3:
        push edi
        push esi
        push ecx

        mov ecx,64                         ;检索表中，每条目的比较次数 
        repe cmpsd                         ;每次比较4字节，repe是连续比较直到ecx为0，如果字符相等则重复比较 
        jnz .b4
        mov eax,[esi]                      ;若匹配，则esi恰好指向其后的地址
        mov [es:edi-256],eax               ;将字符串改写成偏移地址 
        mov ax,[esi+4]
        or ax,0000000000000011B            ;以用户程序自己的特权级使用调用门故RPL=3 

        mov [es:edi-252],ax                ;回填调用门选择子 
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

        mov esi,[ebp+11*4]                 ;从堆栈中取得TCB的基地址

        ;创建0特权级栈
        mov ecx,4096                       ;栈大小为4kb
        mov eax,ecx                        ;为生成堆栈高端地址做准备
        mov [es:esi+0x1a],ecx              
        shr dword [es:esi+0x1a],12         ;登记0特权级堆栈尺寸到TCB，逻辑右移12位，相当于除以4096
        call sys_routine_seg_sel:allocate_memory    ;分配内存，返回ecx=已分配起始内存地址
        add eax,ecx                        ;堆栈必须使用高端地址为基地址   
        mov [es:esi+0x1e],eax              ;登记0特权级堆栈基地址到TCB 
        mov ebx,0xffffe                    ;段长度（界限）
        mov ecx,0x00c09600                 ;4KB粒度，读写，特权级0
        call sys_routine_seg_sel:make_seg_descriptor;构建段描述符
        mov ebx,esi                        ;TCB的基地址
        call fill_descriptor_in_ldt        ;安装段描述符到LDT中
        ;or cx,0000_0000_0000_0000         ;设置选择子的特权级为0
        mov [es:esi+0x22],cx               ;登记0特权级堆栈选择子到TCB
        mov dword [es:esi+0x24],0          ;登记0特权级堆栈初始ESP到TCB

        ;创建1特权级堆栈
        mov ecx,4096
        mov eax,ecx                        ;为生成堆栈高端地址做准备
        mov [es:esi+0x28],ecx
        shr dword [es:esi+0x28],12               ;登记1特权级堆栈尺寸到TCB
        call sys_routine_seg_sel:allocate_memory
        add eax,ecx                        ;堆栈必须使用高端地址为基地址
        mov [es:esi+0x2c],eax              ;登记1特权级堆栈基地址到TCB
        mov ebx,0xffffe                    ;段长度（界限）
        mov ecx,0x00c0b600                 ;4KB粒度，读写，特权级1
        call sys_routine_seg_sel:make_seg_descriptor
        mov ebx,esi                        ;TCB的基地址
        call fill_descriptor_in_ldt
        or cx,0000_0000_0000_0001          ;设置选择子的特权级为1
        mov [es:esi+0x30],cx               ;登记1特权级堆栈选择子到TCB
        mov dword [es:esi+0x32],0          ;登记1特权级堆栈初始ESP到TCB

        ;创建2特权级堆栈
        mov ecx,4096
        mov eax,ecx                        ;为生成堆栈高端地址做准备
        mov [es:esi+0x36],ecx
        shr dword [es:esi+0x36],12               ;登记2特权级堆栈尺寸到TCB
        call sys_routine_seg_sel:allocate_memory
        add eax,ecx                        ;堆栈必须使用高端地址为基地址
        mov [es:esi+0x3a],ecx              ;登记2特权级堆栈基地址到TCB
        mov ebx,0xffffe                    ;段长度（界限）
        mov ecx,0x00c0d600                 ;4KB粒度，读写，特权级2
        call sys_routine_seg_sel:make_seg_descriptor
        mov ebx,esi                        ;TCB的基地址
        call fill_descriptor_in_ldt
        or cx,0000_0000_0000_0010          ;设置选择子的特权级为2
        mov [es:esi+0x3e],cx               ;登记2特权级堆栈选择子到TCB
        mov dword [es:esi+0x40],0          ;登记2特权级堆栈初始ESP到TCB

        ;在GDT中登记LDT描述符
        mov eax,[es:esi+0x0c]              ;LDT的起始线性地址
        movzx ebx,word [es:esi+0x0a]       ;LDT段界限
        mov ecx,0x00408200                 ;LDT描述符，特权级0
        call sys_routine_seg_sel:make_seg_descriptor
        call sys_routine_seg_sel:set_up_gdt_descriptor
        mov [es:esi+0x10],cx               ;登记LDT选择子到TCB中

        ;创建用户程序的TSS
        mov ecx,104                        ;tss的基本尺寸，还可以更大
        mov [es:esi+0x12],cx              
        dec word [es:esi+0x12]             ;登记TSS界限值到TCB，界限值需要减一 
        call sys_routine_seg_sel:allocate_memory    ;分配内存，返回ecx=已分配起始内存地址
        mov [es:esi+0x14],ecx              ;登记TSS基地址到TCB

        ;登记基本的TSS表格内容
        mov word [es:ecx+0],0              ;反向链=0
    
        mov edx,[es:esi+0x24]              ;登记0特权级堆栈初始ESP
        mov [es:ecx+4],edx                 ;到TSS中
    
        mov dx,[es:esi+0x22]               ;登记0特权级堆栈段选择子
        mov [es:ecx+8],dx                  ;到TSS中
    
        mov edx,[es:esi+0x32]              ;登记1特权级堆栈初始ESP
        mov [es:ecx+12],edx                ;到TSS中

        mov dx,[es:esi+0x30]               ;登记1特权级堆栈段选择子
        mov [es:ecx+16],dx                 ;到TSS中

        mov edx,[es:esi+0x40]              ;登记2特权级堆栈初始ESP
        mov [es:ecx+20],edx                ;到TSS中

        mov dx,[es:esi+0x3e]               ;登记2特权级堆栈段选择子
        mov [es:ecx+24],dx                 ;到TSS中

        mov dx,[es:esi+0x10]               ;登记任务的LDT选择子
        mov [es:ecx+96],dx                 ;到TSS中
    
        mov dx,[es:esi+0x12]               ;登记任务的I/O位图偏移
        mov [es:ecx+102],dx                ;到TSS中 
    
        mov word [es:ecx+100],0            ;T=0

        ;在GDT中登记TSS描述符
        mov eax,[es:esi+0x14]              ;TSS的起始线性地址
        movzx ebx,word [es:esi+0x12]       ;段长度（界限）
        mov ecx,0x00408900                 ;TSS描述符，特权级0
        call sys_routine_seg_sel:make_seg_descriptor
        call sys_routine_seg_sel:set_up_gdt_descriptor
        mov [es:esi+0x18],cx               ;登记TSS选择子到TCB

        pop es                             ;恢复到调用此过程前的es段 
        pop ds                             ;恢复到调用此过程前的ds段
    
        popad
    
        ret 8                              ;丢弃调用本过程前压入的参数，也就是压入的两个参数，8个字节

;-----------在TCB链上追加任务控制块-----------------------------------------------------------------------
    append_to_tcb_link:                 ;输入：ecx=起始线性地址
        push eax
        push edx
        push ds
        push es

        mov eax,core_data_seg_sel
        mov ds,eax                      ;令DS指向内核数据段 

        mov eax,mem_0_4_gb_seg_sel
        mov es,eax                      ;令ES指向0..4GB段

        mov dword [es: ecx+0x00],0      ;当前TCB指针域清零，以指示这是最后一个TCB
        mov eax,[tcb_chain]
        or eax,eax  
        jz .notcb                       ;如果表头指针为0，表明任务链表尚未有数据

    .searc:                             ;查找链表尾部
        mov edx,eax 
        mov eax,[es:edx+0x00]           
        or eax,eax
        jnz .searc                      ;当前结点的指针域是否为空，不为空则继续查找
        mov [es:edx+0x00],ecx           ;找到最后一个结点了，将新结点的起始线性地址赋值到最后一个结点的指针域
        jmp .retpc

    .notcb:
        mov [tcb_chain],ecx             ;如果表头为空，则赋值当前链表起始线性地址

    .retpc:
        pop es
        pop ds
        pop edx
        pop eax
        
        ret

;-----------程序入口-----------------------------------------------------------------------
    start:
        mov ecx,core_data_seg_sel
        mov ds,ecx                              ;使ds指向内核数据段
        
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

        ;以下开始安装调用门
        mov edi,salt                            ;符号表起始位置
        mov ecx,salt_items                      ;符号表数量
    .b3:
        push ecx                                ;压栈符号表的数量
        mov eax,[edi+256]                       ;该符号入口点的32位偏移地址
        mov bx,[edi+260]                        ;该符号入口点的段选择子
        mov cx,1_11_0_1100_000_00000B           ;门属性，P=1,DPL=3。即只有特权级大于等于3的才能调用该门。0个参数，未使用栈传参

        call sys_routine_seg_sel:make_gate_descriptor   ;构建调用门描述符
        call sys_routine_seg_sel:set_up_gdt_descriptor  ;安装调用门描述符，返回ex=段描述符选择子

        mov [edi+260],cx                        ;将返回的门段选择子回填
        add edi,salt_item_len                   ;指向下一个符号
        pop ecx
        loop .b3

        ;对门进行测试
        mov ebx,message_2
        call far [salt_1+256]                   ;通过门显示信息,间接取得偏移量（会被忽略）与段选择子

        mov ebx,message_3
        call sys_routine_seg_sel:put_string     ;在内核中可以直接调用例程，不使用门调用

        ;创建任务控制块。这不是处理器要求的，是我们自己定义的链表结构，用来记录任务的状态和信息
        mov ecx,0x46                            ;单个链表项的长度为70字节
        call sys_routine_seg_sel:allocate_memory;分配内存，返回ecx=已分配起始内存地址
        call append_to_tcb_link                 ;将当前任务控制块加入到任务控制链表尾部

        ;加载并重定位用户程序,使用栈传递参数
        push dword 50                           ;用户程序所在磁盘扇区
        push ecx                                ;任务控制块的起始地址
        call load_relocate_program              ;加载并重定位用户程序

        mov ebx,do_status
        call sys_routine_seg_sel:put_string     ;显示程序加载成功

        mov eax,mem_0_4_gb_seg_sel
        mov ds,eax

        ltr [ecx+0x18]                      ;加载任务状态段,存储到TR寄存器
        lldt [ecx+0x10]                     ;加载LDT，存储到LDTR寄存器

        mov eax,[ecx+0x44]
        mov ds,eax                         ;切换到用户程序头部段 

        ;因为没有办法从高等级特权转移到低等级，只能是假装从调用门返回来模拟
        ;以下假装从调用门返回。模仿处理器压入返回参数，压入到内核栈
        push dword [0x08]                   ;用户程序的栈选择子
        push dword 0                        ;用户程序的esp指针

        push dword [0x14]                  ;用户程序的代码段选择子 
        push dword [0x10]                  ;用户程序的的eip

        retf                               ;远返回会依次弹出eip、代码段选择子、esp、用户程序的栈选择子，此时eip、esp均指向了用户程序代码，刚好可以指向用户程序的代码
;-----------终止用户程序-----------------------------------------------------------------------
    return_point:
        mov eax,core_data_seg_sel          ;因为c14.asm是以JMP的方式使用调 
        mov ds,eax                         ;用门@TerminateProgram，回到这里时，特权级为3，会导致异常。 

        mov ebx,message_6
        call sys_routine_seg_sel:put_string

        hlt
    core_code_end:
;-----------尾部段-----------------------------------------------------------------------
section core_trail
       core_end:   ;程序结尾标号，因为段没有定义vstart,所以该标号的偏移地址是从程序头开始的