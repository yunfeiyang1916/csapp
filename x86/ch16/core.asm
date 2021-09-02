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

;-----------分配一个4kb的页-----------------------------------------------------------------------
    allocate_a_4k_page:
                                    ;输入：无。输出：eax=页的物理地址
        push ebx
        push ecx
        push edx
        push ds

        mov eax,core_data_seg_sel
        mov ds,eax                  ;使ds指向内核数据区
         
        xor eax,eax       
    .b1:
        bts [page_bit_map],eax      ;将指定位置(eax)的比特传送到CF标志为并将该位置的值设置为1
        jnc .b2                     ;找到了为0的位，则去分配内存
        inc eax
        cmp eax,page_map_len*8      ;用于判断是否已经比较了所有位，如果仍未找到可以分配的页，则提示错误信息并停机
        jl .b1

        mov ebx,message_3
        call sys_routine_seg_sel:put_string
        hlt                                ;没有可以分配的页，停机 
    .b2:
        shl eax,12                         ;左移12位，相当于乘以4096(0x1000)
                                           ;页映射位串中位的值乘以0x1000就是页的物理地址

        pop ds
        pop edx
        pop ecx
        pop ebx
        
        ret

;-----------分配一个页并安装-----------------------------------------------------------------------
    alloc_inst_a_page:                      ;分配一个页，并安装在当前活动的层级分页结构中
                                            ;输入：ebx=页的线性地址
        push eax
        push ebx
        push esi
        push ds

        mov eax,mem_0_4_gb_seg_sel
        mov ds,eax                          ;使ds指向4G内存段

        ;检查该线性地址所对应的页表是否存在
        mov esi,ebx
        and esi,0xffc00000                  ;只保留高10位
        shr esi,20                          ;得到页目录索引，并乘以4。等价于(shr esi,22)*4
        or esi,0xfffff000                   ;页目录自身的线性地址+表内偏移，就是要访问的目录项的线性地址（存储的是页表物理地址）

        test dword [esi],0x00000001         ;P位是否为“1”。检查该线性地址是否已经有对应的页表。test等价于and
        jnz .b1                             ;已分配，跳转
        ;创建该线性地址所对应的页表
        call allocate_a_4k_page             ;分配一个页当页表
        or eax,0x00000007                   ;设置页的属性，可读写的，特权3的也可访问
        mov [esi],eax
    .b1:
        ;开始访问该线性地址所对应的页表
        mov esi,ebx
        shr esi,10                          ;右移10位，将高10位移动到中间10位
        and esi,0x003ff000                  ;或者0xfffff000，因高10位是零。只保留中间10位 
        or esi,0xffc00000                   ;得到该页表的线性地址

        ;得到该线性地址在页表内的对应条目（页表项）
        and ebx,0x003ff000                  ;只保留中间10位
        shr ebx,10                          ;相当于右移12位，再乘以4
        or esi,ebx                          ;页表项的线性地址 
        call allocate_a_4k_page             ;分配一个页，这才是要安装的页
        or eax,0x00000007
        mov [esi],eax 
        
        pop ds
        pop esi
        pop ebx
        pop eax
        
        retf  

;-----------创建新的内存页目录-----------------------------------------------------------------------
    create_copy_cur_pdir:                   ;创建新页目录，并复制当前页目录内容
                                            ;输入无，输出：eax=新页目录的物理地址
        push ds
        push es
        push esi
        push edi
        push ebx
        push ecx
        
        mov ebx,mem_0_4_gb_seg_sel
        mov ds,ebx
        mov es,ebx

        mov ebx,mem_0_4_gb_seg_sel
        mov ds,ebx
        mov es,ebx
        
        call allocate_a_4k_page            
        mov ebx,eax
        or ebx,0x00000007
        mov [0xfffffff8],ebx               ;将新目录页的物理地址登记到内核目录页的倒数第二个项内
        
        mov esi,0xfffff000                 ;ESI->当前页目录的线性地址
        mov edi,0xffffe000                 ;EDI->新页目录的线性地址
        mov ecx,1024                       ;ECX=要复制的目录项数
        cld
        repe movsd 
        
        pop ecx
        pop ebx
        pop edi
        pop esi
        pop es
        pop ds
        
        retf

;-----------终止当前任务--------------------------------------------------------------------
    terminate_current_task:
                                           ;注意，执行此例程时，当前任务仍在运行中。此例程其实也是当前任务的一部分
        mov eax,core_data_seg_sel
        mov ds,eax

        pushfd
        pop edx

        test dx,0100_0000_0000_0000B       ;测试NT位
        jnz .b1                            ;当前任务是嵌套的，到.b1执行iretd 
        jmp far [program_man_tss]          ;程序管理器任务 
    .b1: 
        iretd                              ;从中断返回，依次从栈中弹出IP、CS、FLAGS内容 
        
    sys_routine_end:

;-----------内核数据段-----------------------------------------------------------------------
section core_data vstart=0                   
    pgdt            dw  0             ;用于设置和修改GDT 
                    dd  0
    ;页映射位串，假定只有2M内存可用，可分为512页，每一位表示每一页是否分配
    ;低端1m内存已经被内核、bios和外设占用了，所以设置为0xff
    page_bit_map    db  0xff,0xff,0xff,0xff,0xff,0x55,0x55,0xff
                    db  0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff
                    db  0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff
                    db  0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff
                    db  0x55,0x55,0x55,0x55,0x55,0x55,0x55,0x55
                    db  0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
                    db  0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
                    db  0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
    page_map_len    equ $-page_bit_map

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
                        dd  terminate_current_task
                        dw  sys_routine_seg_sel

        salt_item_len   equ $-salt_4                ;单个符号表大小，262字节
        salt_items      equ ($-salt)/salt_item_len  ;符号表数量

        message_0       db  '  Working in system core,protect mode.'
                        db  0x0d,0x0a,0

        message_1       db  '  Paging is enabled.System core is mapped to'
                        db  ' address 0x80000000.',0x0d,0x0a,0
        
        message_2       db  0x0d,0x0a
                        db  '  System wide CALL-GATE mounted.',0x0d,0x0a,0
        
        message_3       db  '********No more pages********',0
        
        message_4       db  0x0d,0x0a,'  Task switching...@_@',0x0d,0x0a,0
        
        message_5       db  0x0d,0x0a,'  Processor HALT.',0

    bin_hex         db '0123456789ABCDEF'
                                    ;put_hex_dword子过程用的查找表 

    core_buf   times 2048 db 0         ;内核用的缓冲区 

    cpu_brnd0       db 0x0d,0x0a,'  ',0
    cpu_brand  times 52 db 0
    cpu_brnd1       db 0x0d,0x0a,0x0d,0x0a,0

    ;任务控制块链表头
    tcb_chain       dd  0

    ;内核信息
    core_next_laddr dd  0x80100000    ;内核空间中下一个可分配的线性地址        
    program_man_tss dd  0             ;程序管理器的TSS描述符选择子 
                    dw  0
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

        ;清空当前页目录的前半部分（对应低2GB的局部地址空间）
        mov ebx,0xfffff000              ;页目录表的线性地址
        xor esi,esi
    .b1:
        mov dword [es:ebx+esi*4],0x00000000
        inc esi
        cmp esi,512                     ;前512页目录项全置为0
        jl .b1

        ;以下开始分配内存并加载用户程序
        mov eax,core_data_seg_sel
        mov ds,eax                      ;切换DS到内核数据段


        mov eax,[ebp+12*4]              ;读取起始扇区号
        mov ebx,core_buf                ;用于读取磁盘数据的内核缓冲区
        call sys_routine_seg_sel:read_hard_disk_0

        ;以下判断整个程序有多大
        mov eax,[core_buf]                 ;程序尺寸
        mov ebx,eax
        and ebx,0xfffff000                 ;使之4KB对齐 
        add ebx,0x1000                        
        test eax,0x00000fff                ;程序的大小正好是4KB的倍数吗? 
        cmovnz eax,ebx                     ;不是。使用凑整的结果

        mov ecx,eax
        shr ecx,12                         ;程序占用的总4KB页数，右移12位相当于除以4096
        
        mov eax,mem_0_4_gb_seg_sel         ;切换DS到0-4GB的段
        mov ds,eax

        mov eax,[ebp+12*4]                 ;起始扇区号
        mov esi,[ebp+11*4]                 ;从堆栈中取得TCB的基地址
    .b2:
        mov ebx,[es:esi+0x06]              ;取得可用的线性地址
        add dword [es:esi+0x06],0x1000
        call sys_routine_seg_sel:alloc_inst_a_page

        push ecx
        mov ecx,8                          ;控制内循环，因为磁盘每次读取512字节，要想读取4k，则需要读取8次
    .b3:
        call sys_routine_seg_sel:read_hard_disk_0
        inc eax                            ;递增扇区号
        loop .b3

        pop ecx
        loop .b2                           ;继续执行外循环，先分配内存

        ;在内核地址空间内创建用户任务的TSS
        mov eax,core_data_seg_sel          ;切换DS到内核数据段
        mov ds,eax

        mov ebx,[core_next_laddr]          ;用户任务的TSS必须在全局空间上分配 
        call sys_routine_seg_sel:alloc_inst_a_page
        add dword [core_next_laddr],4096
        
        mov [es:esi+0x14],ebx              ;在TCB中填写TSS的线性地址 
        mov word [es:esi+0x12],103         ;在TCB中填写TSS的界限值 
        
        ;在用户任务的局部地址空间内创建LDT 
        mov ebx,[es:esi+0x06]              ;从TCB中取得可用的线性地址
        add dword [es:esi+0x06],0x1000
        call sys_routine_seg_sel:alloc_inst_a_page
        mov [es:esi+0x0c],ebx              ;填写LDT线性地址到TCB中 

        ;建立程序代码段描述符
        mov eax,0x00000000
        mov ebx,0x000fffff                 
        mov ecx,0x00c0f800                 ;4KB粒度的代码段描述符，特权级3
        call sys_routine_seg_sel:make_seg_descriptor
        mov ebx,esi                        ;TCB的基地址
        call fill_descriptor_in_ldt
        or cx,0000_0000_0000_0011B         ;设置选择子的特权级为3
        
        mov ebx,[es:esi+0x14]              ;从TCB中获取TSS的线性地址
        mov [es:ebx+76],cx                 ;填写TSS的CS域 

        ;建立程序数据段描述符
        mov eax,0x00000000
        mov ebx,0x000fffff                 
        mov ecx,0x00c0f200                 ;4KB粒度的数据段描述符，特权级3
        call sys_routine_seg_sel:make_seg_descriptor
        mov ebx,esi                        ;TCB的基地址
        call fill_descriptor_in_ldt
        or cx,0000_0000_0000_0011B         ;设置选择子的特权级为3
        
        mov ebx,[es:esi+0x14]              ;从TCB中获取TSS的线性地址
        mov [es:ebx+84],cx                 ;填写TSS的DS域 
        mov [es:ebx+72],cx                 ;填写TSS的ES域
        mov [es:ebx+88],cx                 ;填写TSS的FS域
        mov [es:ebx+92],cx                 ;填写TSS的GS域

        ;将数据段作为用户任务的3特权级固有堆栈 
        mov ebx,[es:esi+0x06]              ;从TCB中取得可用的线性地址
        add dword [es:esi+0x06],0x1000
        call sys_routine_seg_sel:alloc_inst_a_page  ;分配4k的栈内存

        mov ebx,[es:esi+0x14]              ;从TCB中获取TSS的线性地址
        mov [es:ebx+80],cx                 ;填写TSS的SS域
        mov edx,[es:esi+0x06]              ;堆栈的高端线性地址 
        mov [es:ebx+56],edx                ;填写TSS的ESP域 

        ;在用户任务的局部地址空间内创建0特权级堆栈
        mov ebx,[es:esi+0x06]              ;从TCB中取得可用的线性地址
        add dword [es:esi+0x06],0x1000
        call sys_routine_seg_sel:alloc_inst_a_page

        mov eax,0x00000000
        mov ebx,0x000fffff
        mov ecx,0x00c09200                 ;4KB粒度的堆栈段描述符，特权级0
        call sys_routine_seg_sel:make_seg_descriptor
        mov ebx,esi                        ;TCB的基地址
        call fill_descriptor_in_ldt
        or cx,0000_0000_0000_0000B         ;设置选择子的特权级为0

        mov ebx,[es:esi+0x14]              ;从TCB中获取TSS的线性地址
        mov [es:ebx+8],cx                  ;填写TSS的SS0域
        mov edx,[es:esi+0x06]              ;堆栈的高端线性地址
        mov [es:ebx+4],edx                 ;填写TSS的ESP0域 

        ;在用户任务的局部地址空间内创建1特权级堆栈
        mov ebx,[es:esi+0x06]              ;从TCB中取得可用的线性地址
        add dword [es:esi+0x06],0x1000
        call sys_routine_seg_sel:alloc_inst_a_page

        mov eax,0x00000000
        mov ebx,0x000fffff
        mov ecx,0x00c0b200                 ;4KB粒度的堆栈段描述符，特权级1
        call sys_routine_seg_sel:make_seg_descriptor
        mov ebx,esi                        ;TCB的基地址
        call fill_descriptor_in_ldt
        or cx,0000_0000_0000_0001B         ;设置选择子的特权级为1

        mov ebx,[es:esi+0x14]              ;从TCB中获取TSS的线性地址
        mov [es:ebx+16],cx                 ;填写TSS的SS1域
        mov edx,[es:esi+0x06]              ;堆栈的高端线性地址
        mov [es:ebx+12],edx                ;填写TSS的ESP1域 

        ;在用户任务的局部地址空间内创建2特权级堆栈
        mov ebx,[es:esi+0x06]              ;从TCB中取得可用的线性地址
        add dword [es:esi+0x06],0x1000
        call sys_routine_seg_sel:alloc_inst_a_page

        mov eax,0x00000000
        mov ebx,0x000fffff
        mov ecx,0x00c0d200                 ;4KB粒度的堆栈段描述符，特权级2
        call sys_routine_seg_sel:make_seg_descriptor
        mov ebx,esi                        ;TCB的基地址
        call fill_descriptor_in_ldt
        or cx,0000_0000_0000_0010B         ;设置选择子的特权级为2

        mov ebx,[es:esi+0x14]              ;从TCB中获取TSS的线性地址
        mov [es:ebx+24],cx                 ;填写TSS的SS2域
        mov edx,[es:esi+0x06]              ;堆栈的高端线性地址
        mov [es:ebx+20],edx                ;填写TSS的ESP2域 

        ;重定位SALT 
        mov eax,mem_0_4_gb_seg_sel         ;访问任务的4GB虚拟地址空间时用 
        mov es,eax                         
                                                
        mov eax,core_data_seg_sel
        mov ds,eax
    
        cld

        mov ecx,[es:0x0c]                  ;U-SALT条目数 
        mov edi,[es:0x08]                  ;U-SALT在4GB空间内的偏移 
    .b4:
        push ecx
        push edi
    
        mov ecx,salt_items
        mov esi,salt
    .b5:
        push edi
        push esi
        push ecx

        mov ecx,64                         ;检索表中，每条目的比较次数 
        repe cmpsd                         ;每次比较4字节 
        jnz .b6
        mov eax,[esi]                      ;若匹配，则esi恰好指向其后的地址
        mov [es:edi-256],eax               ;将字符串改写成偏移地址 
        mov ax,[esi+4]
        or ax,0000000000000011B            ;以用户程序自己的特权级使用调用门
                                        ;故RPL=3 
        mov [es:edi-252],ax                ;回填调用门选择子 
    .b6:
    
        pop ecx
        pop esi
        add esi,salt_item_len
        pop edi                            ;从头比较 
        loop .b5
    
        pop edi
        add edi,256
        pop ecx
        loop .b4

        ;在GDT中登记LDT描述符
        mov esi,[ebp+11*4]                 ;从堆栈中取得TCB的基地址
        mov eax,[es:esi+0x0c]              ;LDT的起始线性地址
        movzx ebx,word [es:esi+0x0a]       ;LDT段界限
        mov ecx,0x00408200                 ;LDT描述符，特权级0
        call sys_routine_seg_sel:make_seg_descriptor
        call sys_routine_seg_sel:set_up_gdt_descriptor
        mov [es:esi+0x10],cx               ;登记LDT选择子到TCB中

        mov ebx,[es:esi+0x14]              ;从TCB中获取TSS的线性地址
        mov [es:ebx+96],cx                 ;填写TSS的LDT域 

        mov word [es:ebx+0],0              ;反向链=0
    
        mov dx,[es:esi+0x12]               ;段长度（界限）
        mov [es:ebx+102],dx                ;填写TSS的I/O位图偏移域 
    
        mov word [es:ebx+100],0            ;T=0
    
        mov eax,[es:0x04]                  ;从任务的4GB地址空间获取入口点 
        mov [es:ebx+32],eax                ;填写TSS的EIP域 

        pushfd
        pop edx
        mov [es:ebx+36],edx                ;填写TSS的EFLAGS域 

        ;在GDT中登记TSS描述符
        mov eax,[es:esi+0x14]              ;从TCB中获取TSS的起始线性地址
        movzx ebx,word [es:esi+0x12]       ;段长度（界限）
        mov ecx,0x00408900                 ;TSS描述符，特权级0
        call sys_routine_seg_sel:make_seg_descriptor
        call sys_routine_seg_sel:set_up_gdt_descriptor
        mov [es:esi+0x18],cx               ;登记TSS选择子到TCB

        ;创建用户任务的页目录
        ;注意,页的分配和使用是由页位图决定的，可以不占用线性地址空间 
        call sys_routine_seg_sel:create_copy_cur_pdir
        mov ebx,[es:esi+0x14]              ;从TCB中获取TSS的线性地址
        mov dword [es:ebx+28],eax          ;填写TSS的CR3(PDBR)域

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
        
        mov ecx,mem_0_4_gb_seg_sel              ;令ES指向4GB数据段 
        mov es,ecx

        mov ebx,message_0
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

        ;准备打开分页机制
         
        ;创建系统内核的页目录表PDT
        ;页目录表清零，是为了将其P位置0 
        mov ecx,1024                       ;1024个页目录项
        mov ebx,0x00020000                 ;页目录的物理地址
        xor esi,esi
    .b1:
        mov dword [es:ebx+esi],0x00000000  ;页目录表项清零 
        add esi,4                          ;地址加4 
        loop .b1                           ;循环1024次

        ;在页目录内创建指向页目录自己的目录项，就是最后一项
        mov dword [es:ebx+4092],0x00020003 ;每项的高20位才是物理地址，低16位为控制位，最后的0x0003表示页的属性，可读写的，特权3的也可访问

        ;在页目录内创建与线性地址0x00000000对应的目录项
        mov dword [es:ebx+0],0x00021003    ;写入目录项（页表的物理地址和属性）,页表的物理地址为：0x00021000

        ;创建与上面那个目录项相对应的页表，初始化页表项 
        mov ebx,0x00021000                 ;页表的物理地址 
        xor eax,eax                        ;起始页的物理地址 
        xor esi,esi
    .b2:
        mov edx,eax
        or edx,0x00000003                  ;页的属性都为11，表示可读写以及不允许特权3访问的
        mov [es:ebx+esi*4],edx             ;登记页的物理地址
        add eax,0x1000                     ;下一个相邻页的物理地址 
        inc esi                            ;下一页的索引 
        cmp esi,256                        ;仅低端1MB内存对应的页才是有效的 
        jl .b2
    .b3:                                   ;其余的页表项置为无效
        mov dword [es:ebx+esi*4],0x00000000  
        inc esi
        cmp esi,1024
        jl .b3 

        ;令CR3寄存器指向页目录，并正式开启分页功能
        mov eax,0x00020000
        mov cr3,eax

        ;开启分页功能
        mov eax,cr0
        or eax,0x80000000                   ;cr0的最高位设置为1表示开启分页
        mov cr0,eax
        
        ;为了让所有任务都能访问到内核空间，所以将线性地址0x80000000-0xFFFFFFFF设置为内核空间
        ;0x00000000-0x7FFFFFFF设置为用户空间。所以页目录表前半部分指向用户空间，后半部分指向内核空间
        ;在页目录内创建和线性地址0x80000000对应的目录项
        mov ebx,0xfffff000                 ;页目录自己的线性地址
        mov esi,0x80000000                 ;映射的起始地址
        shr esi,22                         ;线性地址的高10位是目录索引
        shl esi,2                          ;在左移2位也就是乘以4，为目录表内偏移量，结果为0x800
        mov dword [es:ebx+esi],0x00021003  ;写入目录项（页表的物理地址和属性）
                                           ;目标单元的线性地址为0xFFFFF200
        
        ;将GDT中的段描述符映射到线性地址0x80000000
        sgdt [pgdt]                        ;将寄存器GDTR的值加载到内存pgdt出，此时给出的的pgdt是线性地址

        mov ebx,[pgdt+2]                   ;全局描述符表基地址
        ;依次修改内核栈段、视频缓冲区段等段的线性地址为高位地址
        or dword [es:ebx+0x10+4],0x80000000
        or dword [es:ebx+0x18+4],0x80000000
        or dword [es:ebx+0x20+4],0x80000000
        or dword [es:ebx+0x28+4],0x80000000
        or dword [es:ebx+0x30+4],0x80000000
        or dword [es:ebx+0x38+4],0x80000000

        add dword [pgdt+2],0x80000000      ;GDTR也用的是线性地址 

        lgdt [pgdt]                        ;将GDT新值写回GDTR寄存器

        jmp core_code_seg_sel:flush        ;使用jmp远端跳转是为了刷新段寄存器CS，启用高端线性地址  

    flush:
        mov eax,core_stack_seg_sel
        mov ss,eax                         ;刷新栈段寄存器
        
        mov eax,core_data_seg_sel
        mov ds,eax

        mov ebx,message_1
        call sys_routine_seg_sel:put_string

        ;以下开始安装调用门,特权级之间的控制转移必须使用门
        mov edi,salt                            ;符号表起始位置
        mov ecx,salt_items                      ;符号表数量

    .b4:
        push ecx                                ;压栈符号表的数量
        mov eax,[edi+256]                       ;该符号入口点的32位偏移地址
        mov bx,[edi+260]                        ;该符号入口点的段选择子
        mov cx,1_11_0_1100_000_00000B           ;门属性，P=1,DPL=3。即只有特权级大于等于3的才能调用该门。0个参数，未使用栈传参

        call sys_routine_seg_sel:make_gate_descriptor   ;构建调用门描述符
        call sys_routine_seg_sel:set_up_gdt_descriptor  ;安装调用门描述符，返回ex=段描述符选择子

        mov [edi+260],cx                        ;将返回的门段选择子回填
        add edi,salt_item_len                   ;指向下一个符号
        pop ecx
        loop .b4

        ;对门进行测试
        mov ebx,message_2
        call far [salt_1+256]                   ;通过门显示信息,间接取得偏移量（会被忽略）与段选择子

        ;为程序管理器的TSS分配内存空间
        mov ebx,[core_next_laddr]               ;内核空间中下一个可分配的线性地址
        call sys_routine_seg_sel:alloc_inst_a_page
        add dword [core_next_laddr],4096        ;加上已分配的一个页的大小就是下一个要分配的内存地址

        ;在程序管理器的TSS中设置必要的项目 
        mov word [es:ebx+0],0              ;反向链=0

        mov eax,cr3
        mov dword [es:ebx+28],eax          ;登记CR3(PDBR)

        mov word [es:ebx+96],0             ;没有LDT。处理器允许没有LDT的任务。
        mov word [es:ebx+100],0            ;T=0
        mov word [es:ebx+102],103          ;没有I/O位图。0特权级事实上不需要。

        ;创建程序管理器的TSS描述符，并安装到GDT中 
        mov eax,ebx                        ;TSS的起始线性地址
        mov ebx,103                        ;段长度（界限）
        mov ecx,0x00408900                 ;TSS描述符，特权级0
        call sys_routine_seg_sel:make_seg_descriptor
        call sys_routine_seg_sel:set_up_gdt_descriptor
        mov [program_man_tss+4],cx         ;保存程序管理器的TSS描述符选择子 

        ;任务寄存器TR中的内容是任务存在的标志，该内容也决定了当前任务是谁。
        ;下面的指令为当前正在执行的0特权级任务“程序管理器”后补手续（TSS）。
        ltr cx

        ;现在可认为“程序管理器”任务正执行中

        ;创建用户任务的任务控制块 
        mov ebx,[core_next_laddr]
        call sys_routine_seg_sel:alloc_inst_a_page  ;先分配一个内存页
        add dword [core_next_laddr],4096   
        
        mov dword [es:ebx+0x06],0          ;用户任务局部空间的分配从0开始。
        mov word [es:ebx+0x0a],0xffff      ;登记LDT初始的界限到TCB中
        mov ecx,ebx
        call append_to_tcb_link            ;将此TCB添加到TCB链中 
    
        push dword 50                      ;用户程序位于逻辑50扇区
        push ecx                           ;压入任务控制块起始线性地址 

        call load_relocate_program         
    
        mov ebx,message_4
        call sys_routine_seg_sel:put_string
        
        call far [es:ecx+0x14]             ;执行任务切换。
        
        mov ebx,message_5
        call sys_routine_seg_sel:put_string

        hlt

    core_code_end:
;-----------尾部段-----------------------------------------------------------------------
section core_trail
       core_end:   ;程序结尾标号，因为段没有定义vstart,所以该标号的偏移地址是从程序头开始的