;硬盘主引导扇区代码
;显示字符及地址
mov ax,0xb800   ;显卡内存地址
mov es,ax       ;将显卡内存地址写入附加数据段寄存器

;以下显示字符串"Label offset:"
mov byte [es:0x00],'L'
mov byte [es:0x01],0x07     ;显示黑底白字
mov byte [es:0x02],'a'
mov byte [es:0x03],0x07
mov byte [es:0x04],'b'
mov byte [es:0x05],0x07
mov byte [es:0x06],'e'
mov byte [es:0x07],0x07
mov byte [es:0x08],'l'
mov byte [es:0x09],0x07
mov byte [es:0x0a],' '
mov byte [es:0x0b],0x07
mov byte [es:0x0c],"o"
mov byte [es:0x0d],0x07
mov byte [es:0x0e],'f'
mov byte [es:0x0f],0x07
mov byte [es:0x10],'f'
mov byte [es:0x11],0x07
mov byte [es:0x12],'s'
mov byte [es:0x13],0x07
mov byte [es:0x14],'e'
mov byte [es:0x15],0x07
mov byte [es:0x16],'t'
mov byte [es:0x17],0x07
mov byte [es:0x18],':'
mov byte [es:0x19],0x07

mov ax,number           ;取得标号number的偏移地址
mov bx,10               ;除数为10

mov cx,cs               ;设置数据段基址，等于代码段基址
mov ds,cx

;求个位上的数字
mov dx,0
div bx
mov [0x7c00+number+0x00],dl     ;保存个位上的数

;求十位上的数字
xor dx,dx
div bx
mov [0x7c00+number+0x01],dl

 ;求百位上的数字
xor dx,dx
div bx
mov [0x7c00+number+0x02],dl   ;保存百位上的数字

;求千位上的数字
xor dx,dx
div bx
mov [0x7c00+number+0x03],dl   ;保存千位上的数字

;求万位上的数字 
xor dx,dx
div bx
mov [0x7c00+number+0x04],dl   ;保存万位上的数字

;用十进制的形式在显卡上显示number偏移地址
mov al,[0x7c00+number+0x04]
add al,0x30               ;将数字转成ascii码
mov [es:0x1a],al
mov byte [es:0x1b],0x04 ;黑底红字

mov al,[0x7c00+number+0x03]
add al,0x30
mov [es:0x1c],al
mov byte [es:0x1d],0x04

mov al,[0x7c00+number+0x02]
add al,0x30
mov [es:0x1e],al
mov byte [es:0x1f],0x04

mov al,[0x7c00+number+0x01]
add al,0x30
mov [es:0x20],al
mov byte [es:0x21],0x04

mov al,[0x7c00+number+0x00]
add al,0x30
mov [es:0x22],al
mov byte [es:0x23],0x04

mov byte [es:0x24],'D'  ;展示十进制标识
mov byte [es:0x25],0x07 ;黑底白字

infi:jmp near infi      ;无限循环

number db 0,0,0,0,0     ;数据区，用于存储个、十、百、千、万位上的值

times 203 db 0          ;补足512字节
          db 0x55,0xaa  ;引导扇区结束标识
