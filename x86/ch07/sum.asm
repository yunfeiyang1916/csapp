;硬盘主引导扇区代码
;求累加和

jmp start   ;跳过数据区

message db '1+2+3+...+100=' ;声明一串字符串

start:
    mov ax,0x7c0     ;设置数据段基址
    mov ds,ax

    mov ax,0xb800     ;设置附加段基址，就是显存起始地址
    mov es,ax   

    ;以下显示字符串,使用循环的方式传送字符串
    mov si,message     ;将源串的起始偏移地址设置到源索引寄存器
    mov di,0           ;将显卡偏移地址设置到目标索引寄存器
    mov cx,start-message;cx是计数器，设置要批量传送的字节数
@g:
    mov al,[si]     ;获取message处的内容
    mov [es:di],al  ;转移到显存
    inc di          ;递增di
    mov byte [es:di],0x07   ;设置显示属性，黑底白字
    inc di
    inc si          ;源索引寄存器递增
    loop @g         ;先将cx值减一，如果cx的值不为0，则执行循环，否则向下继续执行

    ;以下计算1-100的和
    xor ax,ax
    mov cx,1    ;从1开始累加
@f:
    add ax,cx   ;求和
    inc cx      ;递增计数器
    cmp cx,100  ;cx-100进行比较
    jle @f      ;cx小于等于100，则继续循环

    ;计算累加和的十进制数位，使用栈来处理
    xor cx,cx
    mov ss,cx   ;栈基址初始化为0
    mov sp,cx   ;栈指针初始化为0

    mov bx,10   ;除数
    xor cx,cx   ;计数器，用于计算十进制数位个数
@d:
    inc cx      ;递增十进制位个数
    xor dx,dx
    div bx      ;除10
    or dl,0x30  ;将十进制数转成ascii,等价于 add dl,0x30
    push dx     ;将余数压入栈中，操作数必须是16位的
    cmp ax,0    ;和是否不等于0
    jne @d
    
    ;显示各个位数
@a:
    pop dx  ;将栈顶元素弹出到数据寄存器中
    mov [es:di],dl
    add di,1
    mov byte [es:di],0x04 ;黑底红字
    inc di
    loop @a      ;先将cx值减一，如果cx的值不为0，则执行循环，否则向下继续执行

jmp $   ;无限循环，"$"表示当前命令的偏移地址


times 510-($-$$)  db  0 ;剩余的字节数用0填充，'$$'表示当前段的起始地址，'$-$$'正好是当前程序的字节大小
                  db  0x55,0xaa ;引导扇区结束标识
    
