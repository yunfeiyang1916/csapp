;-----------------------------------打印字符-------------------------------------------- 
TI_GDT equ  0
RPL0  equ   0
SELECTOR_VIDEO equ (0x0003<<3) + TI_GDT + RPL0  ; 显卡选择子

section .data
put_int_buffer dq 0     ;定义8字节缓冲区用于数字到字符的转换

[bits 32]
section .text
;-----------------------------------打印以\0结尾的字符串-------------------------------------------- 
global put_str
put_str:
    push ebx
    push ecx
    xor ecx,ecx
    mov ebx,[esp+12]        ;从栈中获取要打印的字符串地址
    .goon:
        mov cl,[ebx]
        cmp cl,0            ;是否遇到\0字符(ascii代码为0)
        jz .str_over
        push ecx            ;往栈中压入要打印的字符
        call put_char
        add esp,4           ;回收参数所占用的栈空间
        inc ebx
        jmp .goon
    .str_over:
        pop ecx
        pop ebx
        ret

;-----------------------------------把栈中的1个字符写入光标所在处-------------------------------------------- 
global put_char
put_char:
    pushad          ;push all double 压入4×8＝32字节
    ;需要保证gs中为正确的视频段选择子,为保险起见,每次打印时都为gs赋值
    mov ax,SELECTOR_VIDEO   
    mov gs,ax

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
    ; 取出要打印的字符
    mov ecx,[esp+36]    ;pushad压入4×8＝32字节,加上主调函数的返回地址4字节,故esp+36字节

    cmp cl,0x0d         ;是否是回车符（CR）0x0d
    jz .is_carriage_return
    cmp cl, 0xa         ;是否是换行符（LF）0x0a
    jz .is_line_feed
    cmp cl, 0x8			;BS(backspace)的asc码是8
    jz .is_backspace
    jmp .put_other

    .is_backspace:              ;退格符
        dec bx                  ;先递减光标，移到要删除的字符光标出，光标乘以2才是字符的位置
        shl bx,1                ;相当于乘以2，这是要删除的字符位置
        mov byte [gs:bx],0x20   ;将待删除的字节补为0或空格皆可
        inc bx
        mov byte [gs:bx],0x70   ;字符属性，白底黑字
        shr bx,1                ;右移1位，相当于除以2，余数不要了
        jmp .set_cursor
    .put_other:             ;显示正常字符
        shl bx,1            ;光标位置左移1位，就是乘以2，因为在显示器中显示字符会有2个字节，一个是字符属性，一个是字符本身,所以光标乘以2才是字符的位置
        mov [gs:bx],cl      ;显示字符，字符属性默认是黑底白字，所以不需要写字符属性了
        inc bx              ;这是字符属性的位置
        mov byte [gs:bx],0x70

        ;以下将光标位置推进一个字符，bx刚才左移1位，右移还原回来在+1
        shr bx,1
        inc bx              ;下一个光标值
        cmp bx,2000         ;若光标值小于2000,表示未写到显存的最后,则去设置新的光标值
        jl .set_cursor      ;若超出屏幕字符数大小(2000)则换行处理
    .is_line_feed:          ;是换行符LF(\n)
    .is_carriage_return:    ;是回车符CR(\r),换行与回车处理成都按换行处理，需要将光标移动到行首
        xor dx,dx           ;dx是被除数的高16位,清0.
        mov ax,bx           ;ax是被除数的低16位
        mov si,80           ;显示器每行显示80个字符，将80设置为除数
        div si              ;商就是当前行的行数
        sub bx, dx          ;光标值减去除80的余数便是取整
    .is_carriage_return_end:		;回车符CR处理结束
        add bx, 80
        cmp bx, 2000
    .is_line_feed_end:			      
     jl .set_cursor                 ;如果光标位置小于2000，直接设置光标即可，否则需要滚屏
     ;屏幕行范围是0~24,滚屏的原理是将屏幕的1~24行搬运到0~23行,再将第24行用空格填充
    .roll_screen:		    ; 若超出屏幕大小，开始滚屏
        ;段之间批量传送数据
        cld                 ;将方向标志位DF清零,以指示传送是正方向的
        mov ecx, 960		; 一共有2000-80=1920个字符要搬运,共1920*2=3840字节.一次搬4字节,共3840/4=960次 
        mov esi, 0xb80a0	; 第1行行首
        mov edi, 0xb8000	; 第0行行首
        rep movsd           ;如果ecx的值不为0，则重复传送，每次传送完ecx的值都递减
        ;将最后一行填充为空白
        mov ebx, 3840			  ; 最后一行首字符的第一个字节偏移= 1920 * 2
        mov ecx, 80				  ;一行是80字符(160字节),每次清空1字符(2字节),一行需要移动80次
    .cls:
        mov word [gs:ebx], 0x0720   ;0x0720是黑底白字的空格键
        add ebx, 2
        loop .cls 
        mov bx,1920			;将光标值重置为1920,最后一行的首字符.

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
    .put_char_done:         ;打印单个字符结束
        popad
        ret

;--------------------   将小端字节序的数字变成对应的ascii后，倒置   -----------------------
;输入：栈中参数为待打印的数字
;输出：在屏幕上打印16进制数字,并不会打印前缀0x,如打印10进制15时，只会直接打印f，不会是0xf
;------------------------------------------------------------------------------------------
global put_int
put_int:

