;引导程序

org 0x7c00
BaseOfStack		equ	0x7c00	; Boot状态下堆栈基地址(栈底, 从这个位置向低地址生长)

BaseOfLoader		equ	0x9000	; LOADER.BIN 被加载到的位置 ----  段地址
OffsetOfLoader		equ	0x100	; LOADER.BIN 被加载到的位置 ---- 偏移地址

jmp short LABEL_START		; Start to boot.
nop				            ; 这个 nop 不可少

; 下面是 FAT12 磁盘的头, 之所以包含它是因为下面用到了磁盘的一些信息
%include	"fat12hdr.inc"

LABEL_START:
	mov	ax, cs
	mov	ds, ax
	mov	es, ax
	mov	ss, ax
	mov	sp, BaseOfStack

	; 清屏
	mov	ax, 0600h		; AH = 6,  AL = 0h
	mov	bx, 0700h		; 黑底白字(BL = 07h)
	mov	cx, 0			; 左上角: (0, 0)
	mov	dx, 0184fh		; 右下角: (80, 50)
	int	10h			; int 10h

	mov	dh, 0			; "Booting  "
	call	DispStr			; 显示字符串
	
	xor	ah, ah	; ┓
	xor	dl, dl	; ┣ 软驱复位
	int	13h	; ┛