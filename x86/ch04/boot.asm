;硬盘主引导扇区代码
;测试

section code            ;代码段
    start:
        mov ax,0x7c0     ;设置数据段基址
        mov ds,ax

        mov ax,0xb800     ;设置附加段基址，就是显存起始地址
        mov es,ax   

        ;以下显示字符串,使用循环的方式传送字符串
        mov bx,message
        mov ax,data_end
        mov ax,message2
        mov ax,section.code.start
        mov di,2880           ;将显卡偏移地址设置到目标索引寄存器,设置到第20行 
        mov cx,data_end-message
    ;显示到显存 输入ds:bx字符串地址    
    show:
        mov al,[bx]     ;获取message处的内容
        mov [es:di],al  ;转移到显存
        inc di          ;递增di
        mov byte [es:di],0x07   ;设置显示属性，黑底白字
        inc di
        inc bx          
        loop show        ;先将cx值减一，如果cx的值不为0，则执行循环，否则向下继续执行
    
    jmp $
    ;数据段
    message db '1234567890'
    data_end:
    message2 db ' :000'

    times 510-($-$$)  db  0;剩余的字节数用0填充，'$$'表示当前段的起始地址，'$-$$'正好是当前程序的字节大小
                      db  0x55,0xaa;引导扇区结束标识
