;硬盘主引导扇区代码

%include "pm.inc"	; 常量, 宏, 以及一些说明


org	07c00h
jmp	LABEL_BEGIN

;-----------全局描述符----------------------------------------------------------------
    ;                              段基址,       段界限     , 属性
    LABEL_GDT:	        Descriptor         0,                0, 0               ; 空描述符
    LABEL_DESC_CODE32:  Descriptor         0, SegCode32Len - 1, DA_C + DA_32    ;代码段描述符
    LABEL_DESC_VIDEO:   Descriptor   0xB8000,           0xffff, DA_DRW          ;显存段描述符

    GdtLen equ $-LABEL_DESC_VIDEO       ;全局描述符大小
    ;全局描述符线性地址
    GdtPtr dw GdtLen-1                  ;GDT界限
           dd 0                         ;GDT首地址

    ;选择子
    SelectorCode32 equ LABEL_DESC_CODE32-LABEL_GDT
    SelectorVideo  equ LABEL_DESC_VIDEO-LABEL_GDT

    LABEL_BEGIN:
        mov	ax, cs
        mov	ds, ax
        mov	es, ax
        mov	ss, ax
        mov	sp, 0x0100

        ; 初始化 32 位代码段描述符
        xor	eax, eax
        mov	ax, cs
        shl	eax, 4                              ;代码段左移4位，把低4位留出
        add	eax, LABEL_SEG_CODE32
        mov	word [LABEL_DESC_CODE32 + 2], ax
        shr	eax, 16
        mov	byte [LABEL_DESC_CODE32 + 4], al
        mov	byte [LABEL_DESC_CODE32 + 7], ah

        ; 为加载 GDTR 作准备
        xor	eax, eax
        mov	ax, ds
        shl	eax, 4
        add	eax, LABEL_GDT		; eax <- gdt 基地址
        mov	dword [GdtPtr + 2], eax	; [GdtPtr + 2] <- gdt 基地址

        ; 加载 GDTR
        lgdt	[GdtPtr]

        ; 关中断
        cli

        ; 打开地址线A20
        in	al, 92h
        or	al, 00000010b
        out	92h, al

        ; 准备切换到保护模式
        mov	eax, cr0
        or	eax, 1
        mov	cr0, eax

        ; 真正进入保护模式
        jmp	dword SelectorCode32:0	; 执行这一句会把 SelectorCode32 装入 cs,
                        ; 并跳转到 Code32Selector:0  处
    ; END of [SECTION .s16]

[bits 32]
    LABEL_SEG_CODE32:
        mov ax,SelectorVideo
        mov es,ax               ;使es指向视频选择子

        mov	edi, (80 * 11 + 79) * 2	; 屏幕第 11 行, 第 79 列。
        mov	ah, 0x0C			; 0000: 黑底    1100: 红字
        mov	al, 'P'
        mov	[es:edi], ax

        ; 到此停止
        jmp	$

SegCode32Len	equ	$ - LABEL_SEG_CODE32

times 	510-($-$$)	db	0	; 填充剩下的空间，使生成的二进制代码恰好为512字节
						dw 	0xaa55				; 结束标志

