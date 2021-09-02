;中断演示

section header vstart=0             ;用户程序头部段
    program_length dd program_end   ;[0x00]程序总长度，双字，32位
    ;用户程序入口点
    code_entry dw start             ;[0x04]偏移地址
               dd section.code.start;[0x06]段地址
    
    realloc_tbl_len dw (header_end-realloc_begin)/4 ;段重定位表项个数[0x0a]
    
    realloc_begin:
    ;段重定位表           
        code_segment    dd section.code.start   ;[0x0c]
        data_segment    dd section.data.start   ;[0x14]
        stack_segment   dd section.stack.start  ;[0x1c]

    header_end:                      ;段结束标号 

section code align=16 vstart=0      ;代码段，16字节对齐
;----------------------新0x70中断号处理程序---------------------------------------------------------
    new_int_0x70:
        push ax                         ;保护现场
        push bx
        push cx
        push dx
        push es
    .w0:
        mov al,0x0a                     ;RTC(实时时钟电路)寄存器A索引
        or al,0x80                      ;将al最高位置1,用于阻断NMI（非屏蔽中断）。通常是不必要的
        out 0x70,al                     ;0x70是CMOS RAM索引端口
        in al,0x71                      ;读寄存器A
        test al,0x80                    ;测试第7位UIP，根据该值来判断是否需要等待更新周期结束。test等价于and操作，只是不改变al的值
        jnz .w0                         ;以上代码对于更新周期结束中断来说 
                                        ;是不必要的 
        xor al,al                          ;读CMOS 0内存单元
        or al,0x80                         ;每次都阻断NMI?
        out 0x70,al
        in al,0x71                         ;读RTC当前时间(秒)
        push ax

        mov al,2
        or al,0x80
        out 0x70,al
        in al,0x71                         ;读RTC当前时间(分)
        push ax

        mov al,4
        or al,0x80
        out 0x70,al
        in al,0x71                         ;读RTC当前时间(时)
        push ax

        mov al,7                
        or al,0x80
        out 0x70,al
        in al,0x71
        push ax                            ;读RTC当前时间(日)

        mov al,0x0c                        ;寄存器C的索引。且开放NMI 
        out 0x70,al
        in al,0x71                         ;读一下RTC的寄存器C，否则只发生一次中断
                                           ;此处不考虑闹钟和周期性中断的情况 
        mov ax,0xb800
        mov es,ax                           ;设置显存地址到附加段寄存器

        pop ax                              ;先弹出日期数
        call bcd_to_ascii
        mov bx,12*160 + 36*2               ;从屏幕上的12行36列开始显示

        mov [es:bx],ah
        mov [es:bx+2],al                    ;显示2位日期数
                       
        mov byte [es:bx+4],':'              ;显示分隔符
        not byte [es:bx+5]                  ;反转显示属性

        pop ax
        call bcd_to_ascii
        mov [es:bx+6],ah
        mov [es:bx+8],al                   ;显示两位小时数字

        mov byte [es:bx+10],':'            ;显示分隔符':'
        not byte [es:bx+11]                ;反转显示属性

        pop ax
        call bcd_to_ascii
        mov [es:bx+12],ah
        mov [es:bx+14],al                  ;显示两位分钟字
        
        mov byte [es:bx+16],':'            ;显示分隔符':'
        not byte [es:bx+17]                ;反转显示属性

        pop ax
        call bcd_to_ascii
        mov [es:bx+18],ah
        mov [es:bx+20],al                  ;显示两位秒数字

        mov al,0x20                        ;中断结束命令EOI 
        out 0xa0,al                        ;向从片发送 
        out 0x20,al                        ;向主片发送 

        pop es
        pop dx
        pop cx
        pop bx
        pop ax

        iret                               ;依次从栈中弹出IP、CS、FLAGS内容

;-------------------------------------------------------------------------------
bcd_to_ascii:                            ;BCD码转ASCII
                                         ;输入：AL=bcd码
                                         ;输出：AX=ascii
      mov ah,al                          ;分拆成两个数字 
      and al,0x0f                        ;仅保留低4位 
      add al,0x30                        ;转换成ASCII 

      shr ah,4                           ;逻辑右移4位 
      and ah,0x0f                        
      add ah,0x30

      ret

;----------------------程序入口--------------------------------------------------------- 
    start:
         ;初始执行时，ds、es均指向头部段
        mov ax,[stack_segment]      ;设置用户程序自己的栈段
        mov ss,ax
        mov sp,ss_pointer           ;初始化栈指针，执行栈最大地址，栈是从高地址向低地址增长的

        mov ax,[data_segment]       ;设置用户程序自己的数据段
        mov ds,ax

        mov bx,init_msg             ;显示初始化信息
        call put_string

        mov bx,inst_msg             ;显示安装信息
        call put_string

        mov al,0x70                 ;0x70中断号
        mov bl,4                    
        mul bl                      ;计算0x70号中断在中断向量表中的偏移
        mov bx,ax

        cli                         ;清除IF中断标志位，此时不在接受其他中断

        push es                     ;保存es
        mov ax,0x0000
        mov es,ax
        mov word [es:bx],new_int_0x70   ;中断处理程序偏移地址
        mov word [es:bx+2],cs           ;段地址

        pop es                          ;恢复es

        ;以下设置时钟更新结束中断，每秒更新一次
        mov al,0x0b                     ;RTC(实时时钟电路)寄存器B索引
        or al,0x80                      ;将al最高位置1,用于阻断NMI（非屏蔽中断）
        out 0x70,al                     ;0x70是CMOS RAM索引端口
        mov al,0x12                     ;二进制形式为00010010，设置寄存器B，禁止周期性中断，开放更新结束后中断，BCD码，24小时制 
        out 0x71,al                     ;0x71是数据端口

        mov al,0x0c
        out 0x70,al
        in al,0x71                      ;读RTC寄存器C，复位未决的中断状态

        in al,0xa1                         ;读8259从片的IMR寄存器 
        and al,0xfe                        ;清除bit 0(此位连接RTC)
        out 0xa1,al                        ;写回此寄存器 

        sti                                ;设置IF中断标志位，重新开放中断

        mov bx,done_msg                    ;显示安装完成信息
        call put_string

        mov bx,tips_msg                    ;显示提示信息
        call put_string

        mov cx,0xb800
        mov ds,cx                           ;设置数据段寄存器为显示地址
        mov byte [12*160 + 33*2],'@'        ;在屏幕的第12行，35列显示，屏幕中心

    .idle:
        hlt                                 ;使CPU进入低功耗状态，直到用中断唤醒
        not byte [12*160 + 33*2+1]          ;反转显示属性 
        jmp .idle
;-----------------------显示文本--------------------------------------------------------
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
section data align=16 vstart=0      ;数据段，16字节对齐
    init_msg       db 'Starting...',0x0d,0x0a,0             ;启动提示信息          
    inst_msg       db 'Installing a new interrupt 70H...',0 ;安装中断号提示信息
    done_msg       db 'Done.',0x0d,0x0a,0                   ;安装完成提示信息
    tips_msg       db 'Clock is now working.',0 
section stack align=16 vstart=0     ;栈段，16字节对齐
    resb 256                        ;保留256字节栈空间，但不初始化它们的值
    ss_pointer:                      ;栈段结束标号，偏移量为256
section trail align=16
    program_end:                    ;程序结尾标号，因为段没有定义vstart,所以该标号的偏移地址是从程序头开始的