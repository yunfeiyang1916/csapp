;用于演示BIOS中断的用户程序 

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
;----------------------程序入口--------------------------------------------------------- 
    start:
         ;初始执行时，ds、es均指向头部段
        mov ax,[stack_segment]      ;设置用户程序自己的栈段
        mov ss,ax
        mov sp,ss_pointer           ;初始化栈指针，执行栈最大地址，栈是从高地址向低地址增长的

        mov ax,[data_segment]       ;设置用户程序自己的数据段
        mov ds,ax

        mov cx,msg_end-message      ;文本长度
        mov bx,message
    .putc:
        mov ah,0x0e                 ;ah用于指定同设备的不同功能，在这里0x0e表示在屏幕上写入一个字符，并推进光标位置
        mov al,[bx]                 ;al用于读取或写入设备执行的结果
        int 0x10                    ;0x10表示显示器中断
        inc bx
        loop .putc                  ;先将cx值减一，如果cx的值不为0，则执行循环，否则向下继续执行
    .reps:
        mov ah,0x00                 ;0x00表示从键盘读取字符功能
        int 0x16                    ;键盘中断，结果放到al中

        mov ah,0x0e                 ;显示到显示器
        mov bl,0x07
        int 0x10
        jmp .reps


section data align=16 vstart=0      ;数据段，16字节对齐
    message       db 'Hello, friend!',0x0d,0x0a
                  db 'This simple procedure used to demonstrate '
                  db 'the BIOS interrupt.',0x0d,0x0a
                  db 'Please press the keys on the keyboard ->'
    msg_end:
section stack align=16 vstart=0     ;栈段，16字节对齐
    resb 256                        ;保留256字节栈空间，但不初始化它们的值
    ss_pointer:                      ;栈段结束标号，偏移量为256
section trail align=16
    program_end:                    ;程序结尾标号，因为段没有定义vstart,所以该标号的偏移地址是从程序头开始的