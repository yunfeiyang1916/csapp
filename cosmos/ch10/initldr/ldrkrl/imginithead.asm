;grub头汇编部分，它有两个功能，既能让 GRUB 识别，又能设置 C 语言运行环境，用于调用 C 函数
;主要用于初始化 CPU 的寄存器，加载 GDT，切换到 CPU 的保护模式

;引导头--hdr=header
MBT_HDR_FLAGS	EQU 0x00010003
;多引导协议头常数
MBT_HDR_MAGIC	EQU 0x1BADB002
;第二版多引导协议头常数
MBT2_MAGIC	EQU 0xe85250d6

;导出_start符号，以便让链接器识别
global _start 
;导入外部的函数符号
extern inithead_entry 

_start:
	jmp _entry
align 4
mbt_hdr:
	dd MBT_HDR_MAGIC
	dd MBT_HDR_FLAGS
	dd -(MBT_HDR_MAGIC+MBT_HDR_FLAGS)
	dd mbt_hdr
	dd _start
	dd 0
	dd 0
	dd _entry

	; multiboot header
	;以上是GRUB所需要的头

ALIGN 8
mbhdr:
	DD	0xE85250D6
	DD	0
	DD	mhdrend - mbhdr
	DD	-(0xE85250D6 + 0 + (mhdrend - mbhdr))
	DW	2, 0
	DD	24
	DD	mbhdr
	DD	_start
	DD	0
	DD	0
	DW	3, 0
	DD	12
	DD	_entry 
	DD      0  
	DW	0, 0
	DD	8
mhdrend:
;以上是GRUB2所需要的头
;包含两个头是为了同时兼容GRUB、GRUB2

_entry:
    ;关中断
    cli
    ;关不可屏蔽中断
    in al, 0x70
    or al, 0x80
    out 0x70,al
    ;重新加载GDT
    lgdt [GDT_PTR]
	jmp dword 0x8 :_32bits_mode

;下面初始化C语言可能会用到的寄存器
_32bits_mode:
	mov ax, 0x10
	mov ds, ax
	mov ss, ax          ;栈段寄存器
	mov es, ax
	mov fs, ax
	mov gs, ax
	xor eax,eax
	xor ebx,ebx
	xor ecx,ecx
	xor edx,edx
	xor edi,edi
	xor esi,esi
	xor ebp,ebp
	xor esp,esp
	mov esp,0x7c00          ;初始化栈，C语言需要栈才能工作
	call inithead_entry     ;调用c语言函数
	jmp 0x200000



GDT_START:
    knull_dsc: dq 0
    kcode_dsc: dq 0x00cf9e000000ffff
    kdata_dsc: dq 0x00cf92000000ffff
    k16cd_dsc: dq 0x00009e000000ffff    ;16位代码段描述符
    k16da_dsc: dq 0x000092000000ffff    ;16位数据段描述符
    GDT_END:
    GDT_PTR:
    GDTLEN	dw GDT_END-GDT_START-1	;GDT界限
    GDTBASE	dd GDT_START