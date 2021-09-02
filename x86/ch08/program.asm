;用户程序

section header vstart=0                 ;用户程序头部段
    program_length dd program_end    ;[0x00]程序总长度，双字，32位
    ;用户程序入口点
    code_entry  dw start                ;[0x04]偏移地址
                dd section.code_1.start ;[0x06]段地址

    realloc_tbl_len dw (header_end-code_1_segment)/4    ;[0x0a]段重定位表项个数,因为每个表项占用4个字节，所以需要除以4
    ;段重定位表
    code_1_segment dd section.code_1.start  ;[0x0c],代码段1汇编地址（不是偏移地址，其中低20位为汇编地址），4字节
    code_2_segment dd section.code_2.start  ;[0x10],代码段2汇编地址，4字节
    data_1_segment dd section.data_1.start  ;[0x14],数据段1汇编地址，4字节
    data_2_segment dd section.data_2.start  ;[0x18],数据段2汇编地址，4字节
    stack_segment dd section.stack.start    ;[0x1c],栈段汇编地址，4字节

    header_end:                         ;段结束标号

section code_1 align=16 vstart=0     ;代码段1,16字节对齐
;-------------------------------------------------------------------------------
    put_string:             ;显示以0结尾的字符串，输入ds:bx字符串地址
        mov cl,[bx]
        or cl,cl            ;cl是否为0，如果为0 or指令会使ZF标志位改变
        jz .exit
        call put_char
        inc bx              ;访问下一个字符
        jmp put_string
    
    .exit:
        ret             ;返回

    put_char:               ;显示1个字符,输入cl=ascii
        push ax             ;保存用到的寄存器
        push bx
        push cx
        push dx
        push ds
        push es

        ;以下取光标位置
        mov dx,0x3d4        ;显卡索引寄存器端口号
        mov al,0x0e         ;光标的高8位寄存器索引值
        out dx,al           ;写入索引值
        mov dx,0x3d5        ;显卡数据端口
        in al,dx            ;读取光标高8位寄存器的值
        mov ah,al           ;高8位放到ah中

        mov dx,0x3d4        
        mov al,0x0f         ;光标的低8位寄存器索引值
        out dx,al
        mov dx,0x3d5
        in al,dx            ;读取光标低8位寄存器值
        mov bx,ax           ;将光标位置放到bx寄存器上

        cmp cl,0x0d         ;是否是回车符
        jnz .put_0a         ;如果非回车符则去判断是否是换行符
        mov ax,bx           ;是回车符，需要将光标移动到行首
        mov bl,80           ;显示器每行显示80个字符，将80设置为除数
        div bl              ;ax/bl,商在al,余数在ah,商就是当前行的行数
        mul bl              ;al*bl=ax,乘以80就是当前行首的光标数值,放在ax寄存器上
        mov bx,ax           ;光标位置值放到bx寄存器
        jmp .set_cursor     ;设置光标位置

    .put_0a:                ;判断是否是换行符
        cmp cl,0x0a
        jnz .put_other      ;非换行符则需要显示正常字符
        add bx,80           ;是换行符，光标位置增加80即可
        jmp .roll_screen


    .put_other:             ;显示正常字符
        mov ax,0xb800        ;显卡内存地址
        mov es,ax           ;设置附加段基址，就是显存起始地址
        shl bx,1            ;光标位置左移1位，就是乘以2，因为在显示器中显示字符会有2个字节，一个是字符属性，一个是字符本身
        mov [es:bx],cl      ;显示字符，字符属性默认是黑底白字，所以不需要写字符属性了
        
        ;以下将光标位置推进一个字符，bx刚才左移1位，右移还原回来在+1
        shr bx,1
        add bx,1
    .roll_screen:           ;判断是否需要滚屏
        cmp bx,2000         ;一屏最多显示2000字符，判断光标位置是否超出一屏
        jl .set_cursor      ;不超过一屏则去设置光标位置

        mov ax,0xb800       ;显存地址，滚屏就是将屏幕第2-25行内容上移，然后最后一行使用黑底白字的空白符填充
        mov ds,ax
        mov es,ax           ;设置数据段与附加段都为显存起始地址
        ;段之间批量传送数据
        cld                 ;将方向标志位DF清零,以指示传送是正方向的
        mov si,0xa0         ;源区域从显存第二行第一列，十进制160（80个字符属性+80个字符）
        mov di,0x00         ;目标区域从显存第一行第一列
        mov cx,1920         ;要传送的字数
        rep movsw           ;如果cx的值不为0，则重复传送，每次传送完cx的值都递减
        mov bx,3840         ;清除屏幕最后一行
        mov cx,80

    .cls:
        mov word[es:bx],0x0720 ;空白字符填充
        add bx,2
        loop .cls

        mov bx,1920 ;将光标位置设置到倒数第二行

    .set_cursor:            ;设置光标在屏幕上的位置
        mov dx,0x3d4        ;显示索引寄存器端口号
        mov al,0x0e         ;光标高8位寄存器索引值
        out dx,al           ;写入索引值
        mov dx,0x3d5        ;显示数据端口
        mov al,bh
        out dx,al           ;写入光标高8位寄存器的值

        mov dx,0x3d4        ;显示索引寄存器端口号
        mov al,0x0f         ;光标低8位寄存器索引值
        out dx,al           ;写入索引值
        mov dx,0x3d5        ;显示数据端口
        mov al,bl
        out dx,al           ;写入光标低8位寄存器的值

        pop es              ;出栈，恢复相关寄存器的原始值
        pop ds
        pop dx
        pop cx
        pop bx
        pop ax

        ret

;------------------------------------------------------------------------------- 
    ;程序入口
    start:
        ;初始执行时，ds、es均指向头部段
        mov ax,[stack_segment]      ;设置用户程序自己的栈段
        mov ss,ax
        mov sp,stack_end            ;初始化栈指针，执行栈最大地址，栈是从高地址向低地址增长的

        mov ax,[data_1_segment]     ;设置用户程序自己的数据段
        mov ds,ax

        mov bx,msg0                 ;显示第一段字符串
        call put_string

        push word [es:code_2_segment]   ;将代码段2的段地址压入栈中
        mov ax,begin                ;8086不支持直接压栈立即数，80386之后可以直接使用push begin
        push ax                     ;将代码段2的偏移地址压入栈中
        retf                        ;远返回指令会先从栈中弹出ip值，然后再弹出cs代码段寄存器值，此时相当于跳转到代码段2执行

    ;继续执行
    continue:
        mov ax,[es:data_2_segment]  ;将数据段2地址设置到ds中
        mov ds,ax
        
        mov bx,msg1
        call put_string             ;显示第二段信息

        jmp $

section code_2 align=16 vstart=0    ;代码段2,16字节对齐,啥也没干，又调回到了代码段1中继续执行
    begin:
        push word [es:code_1_segment]   ;将代码段1的段地址压入栈中
        mov ax,continue             ;8086不支持直接压栈立即数，80386之后可以直接使用push begin
        push ax                     ;将代码段2的偏移地址压入栈中
        retf                        ;远返回指令会先从栈中弹出ip值，然后再弹出cs代码段寄存器值，此时相当于跳转到代码段1执行

section data_1 align=16 vstart=0    ;数据段1,16字节对齐
    ;定义一段要显示的文本
    msg0 db '  This is NASM - the famous Netwide Assembler. '
         db 'Back at SourceForge and in intensive development! '
         db 'Get the current versions from http://www.nasm.us/.'
         db 0x0d,0x0a,0x0d,0x0a
         db '  Example code for calculate 1+2+...+1000:',0x0d,0x0a,0x0d,0x0a
         db '     xor dx,dx',0x0d,0x0a
         db '     xor ax,ax',0x0d,0x0a
         db '     xor cx,cx',0x0d,0x0a
         db '  @@:',0x0d,0x0a
         db '     inc cx',0x0d,0x0a
         db '     add ax,cx',0x0d,0x0a
         db '     adc dx,0',0x0d,0x0a
         db '     inc cx',0x0d,0x0a
         db '     cmp cx,1000',0x0d,0x0a
         db '     jle @@',0x0d,0x0a
         db '     ... ...(Some other codes)',0x0d,0x0a,0x0d,0x0a
         db 0

section data_2 align=16 vstart=0    ;数据段2,16字节对齐
    ;数据段2中要显示的文本
     msg1 db '  The above contents is written by yunfeiyang. '
         db '2021-08-16'
         db 0

section stack align=16 vstart=0     ;栈段，16字节对齐
    resb 256                        ;保留256字节栈空间，但不初始化它们的值
    stack_end:                      ;栈段结束标号，偏移量为256

section trail align=16
    program_end:                    ;程序结尾标号，因为段没有定义vstart,所以该标号的偏移地址是从程序头开始的

