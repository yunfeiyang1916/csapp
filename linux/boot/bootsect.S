; 它的后缀是大写的'.S'。使用这样的后缀可以让 as 使用 GNU C 编译器的预处理功能，因此可以在汇编语言程序中包括"#include"、"#if"等语句。
; 本程序使用大写后缀主要是为了能在程序中使用"#include"语句来包含进 linux/config.h 头文件定义的常数

; SYS_SIZE 是要加载的系统模块长度。长度单位是节（paragraph），每节 16 字节。这里 0x3000 共为
; 0x30000 字节=196KB。若以 1024 字节为 1KB 计，则应该是 192KB。对于当前内核版本这个空间长度
; 已足够了。当该值为 0x8000 时，表示内核最大为 512KB。因为内存 0x90000 处开始存放移动后的
; bootsect 和 setup 的代码，因此该值最大不得超过 0x9000（表示 584KB）。
;
; 头文件 linux/config.h 中定义了内核用到的一些常数符号和 Linus 自己使用的默认硬盘参数块。
; 例如其中定义了以下一些常数：
; DEF_SYSSIZE = 0x3000 - 默认系统模块长度。单位是节，每节为 16 字节；
; DEF_INITSEG = 0x9000 - 默认本程序代码移动目的段位置；
; DEF_SETUPSEG = 0x9020 - 默认 setup 程序代码段位置；
; DEF_SYSSEG = 0x1000 - 默认从磁盘加载系统模块到内存的段位置。

#include <linux/config.h>
;定义一个标号或符号。指明编译连接后 system 模块的大小
SYSSIZE=DEF_SYSSIZE

; bootsect.s (C) 1991 Linus Torvalds
; Drew Eckhardt 修改
; 
; bootsect.s 被 ROM BIOS 启动子程序加载至 0x7c00 (31KB)处，并将自己移到了地址 0x90000
; (576KB)处，并跳转至那里。
; 
; 它然后使用 BIOS 中断将'setup'直接加载到自己的后面(0x90200)(576.5KB)，并将 system 加
; 载到地址 0x10000 处。
; 
; 注意; 目前的内核系统最大长度限制为(8*65536)(512KB)字节，即使是在将来这也应该没有问
; 题的。我想让它保持简单明了。这样 512KB 的最大内核长度应该足够了，尤其是这里没有象
; MINIX 中一样包含缓冲区高速缓冲。
; 
; 加载程序已经做得够简单了，所以持续地读操作出错将导致死循环。只能手工重启。只要可能，
; 通过一次读取所有的扇区，加载过程可以做得很快。
; 伪指令（伪操作符）.globl 或.global 用于定义随后的标识符是外部的或全局的，并且即使不
; 使用也强制引入。 .text、.data 和.bss 用于分别定义当前代码段、数据段和未初始化数据段。
; 在链接多个目标模块时，链接程序（ld86）会根据它们的类别把各个目标模块中的相应段分别
; 组合（合并）在一起。这里把三个段都定义在同一重叠地址范围中，因此本程序实际上不分段。
; 另外，后面带冒号的字符串是标号，例如下面的'begtext:'。
; 一条汇编语句通常由标号（可选）、指令助记符（指令名）和操作数三个字段组成。标号位于
; 一条指令的第一个字段。它代表其所在位置的地址，通常指明一个跳转指令的目标位置。

.globl begtext, begdata, begbss, endtext, enddata, endbss
.text                           ;文本段（代码段）
begtext:
.data                           ;数据段
begdata:
.bss                            ;未初始化数据段
begbss:
.text                           ;文本段（代码段）

;下面等号'='或符号'EQU'用于定义标识符或标号所代表的值
;setup程序代码占用磁盘扇区数(setup-sectors)值
SETUPLEN = 4				
;bootsect代码所在内存原始段地址
BOOTSEG  = 0x07c0			
;将bootsect移到位置0x90000 - 避开系统模块占用处
INITSEG  = DEF_INITSEG
;setup程序从内存0x90200处开始			
SETUPSEG = DEF_SETUPSEG	
;system模块加载到0x10000（64 KB）处		
SYSSEG   = DEF_SYSSEG
;停止加载的段地址			
ENDSEG   = SYSSEG + SYSSIZE		

; 根文件系统设备号 ROOT_DEV 和交换设备号 SWAP_DEV 现在由 tools 目录下的 build 程序写入。
; 设备号 0x306 指定根文件系统设备是第 2 个硬盘的第 1 个分区。当年 Linus 是在第 2 个硬盘上
; 安装了 Linux 0.11 系统，所以这里 ROOT_DEV 被设置为 0x306。在编译这个内核时你可以根据
; 自己根文件系统所在设备位置修改这个设备号。例如，若你的根文件系统在第 1 个硬盘的第 1 个
; 分区上，那么该值应该为 0x0301，即（0x01, 0x03）。这个设备号是 Linux 系统老式的硬盘设备
; 号命名方式，硬盘设备号具体值的含义如下：
; 设备号=主设备号*256 + 次设备号（也即 dev_no = (major<<8) + minor ）
; （主设备号：1-内存,2-磁盘,3-硬盘,4-ttyx,5-tty,6-并行口,7-非命名管道）
; 0x300 - /dev/hd0 - 代表整个第 1 个硬盘；
; 0x301 - /dev/hd1 - 第 1 个盘的第 1 个分区；
; …
; 0x304 - /dev/hd4 - 第 1 个盘的第 4 个分区；
; 0x305 - /dev/hd5 - 代表整个第 2 个硬盘；
; 0x306 - /dev/hd6 - 第 2 个盘的第 1 个分区；
; …
; 0x309 - /dev/hd9 - 第 2 个盘的第 4 个分区；
; 从 Linux 内核 0.95 版后就已经使用与现在内核相同的命名方法了。

;根文件系统设备使用与系统引导时同样的设备
ROOT_DEV = 0
;交换设备使用与系统引导时同样的设备
SWAP_DEV = 0

;告知链接程序，程序从start标号开始执行
entry start
start:
	mov	ax,#BOOTSEG
	mov	ds,ax           ;将ds段寄存器置为0x7C0
	mov	ax,#INITSEG     
	mov	es,ax           ;将es段寄存器置为0x9000
	mov	cx,#256         ;设置移动计数值=256字（512字节）
	sub	si,si           ;源地址   ds:si = 0x07C0:0x0000
	sub	di,di           ;目的地址 es:di = 0x9000:0x0000
	rep                 ;重复执行并递减cx的值，直到cx = 0为止
	movw                ;即movs指令。从内存[si]处移动cx个字到[di]处
	jmpi	go,INITSEG  ;段间跳转（Jump Intersegment）。这里INITSEG指出跳转到的段地址，标号go是段内偏移地址

; 从下面开始，CPU 在已移动到 0x90000 位置处的代码中执行。
; 这段代码设置几个段寄存器，包括栈寄存器 ss 和 sp。栈指针 sp 只要指向远大于 512 字节偏移
; （即地址 0x90200）处都可以。因为从 0x90200 地址开始处还要放置 setup 程序，而此时 setup
; 程序大约为 4 个扇区，因此 sp 要指向大于（0x200 + 0x200 * 4 +堆栈大小）位置处。这里 sp
; 设置为 0x9ff00 - 12（参数表长度），即 sp = 0xfef4。在此位置之上会存放一个自建的驱动
; 器参数表，见下面说明。实际上 BIOS 把引导扇区加载到 0x7c00 处并把执行权交给引导程序时，
; ss = 0x00，sp = 0xfffe。
; 另外，第 65 行上 push 指令的期望作用是想暂时把段值保留在栈中，然后等下面执行完判断磁道
; 扇区数后再弹出栈，并给段寄存器 fs 和 gs 赋值（第 109 行）。但是由于第 67、68 两语句修改
; 了栈段的位置，因此除非在执行栈弹出操作之前把栈段恢复到原位置，否则这样设计就是错误的。
; 因此这里存在一个 bug。改正的方法之一是去掉第 65 行，并把第 109 行修改成“mov ax,cs”。
go:	mov	ax,cs	    ; 将 ds、es 和 ss 都置成移动后代码所在的段处(0x9000)	
	mov	dx,#0xfef4	; arbitrary value >>512 - disk parm size

	mov	ds,ax
	mov	es,ax
	push	ax      ;临时保存段值（0x9000），供 109 行使用。（滑头;）

	mov	ss,ax		; put stack at 0x9ff00 - 12.
	mov	sp,dx

	/*
	* 对于多扇区读操作所读的扇区数超过默认磁盘参数表中指定的最大扇区数时，
	* 很多 BIOS 将不能进行正确识别。在某些情况下是 7 个扇区。
	*
	* 由于单扇区读操作太慢，不予以考虑，因此我们必须通过在内存中重创建新的
	* 参数表（为第 1 个驱动器）来解决这个问题。我们将把其中最大扇区数设置为
	* 18 -- 即在 1.44MB 磁盘上会碰到的最大数值。
	* 
	* 这个数值大了不会出问题，但是太小就不行了。
	*
	* 段寄存器将被设置成：ds=es=ss=cs - 都为 INITSEG（0x9000），
	* fs = 0，gs = 参数表所在段值。
	*/

	push	#0
	pop	fs              ;置段寄存器 fs = 0
	mov	bx,#0x78		;fs:bx 指向存有软驱参数表地址处（指针的指针）
    ;指令 seg fs 表示其下一条语句的操作数在 fs 段中。该指令仅影响其下一条语句。这里把 fs:bx
    ;所指内存位置处的表地址放到寄存器对 gs:si 中作为原地址。寄存器对 es:di = 0x9000:0xfef4
    ;作为目的地址
	seg fs
	lgs	si,(bx)			; gs:si is source

	mov	di,dx			; dx=0xfef4，在 61 行被设置
	mov	cx,#6			; copy 12 bytes
	cld                 ;清方向标志。复制时指针递增

	rep                 ;复制 12 字节的软驱参数表到 0x9000:0xfef4 处
	seg gs
	movw

	mov	di,dx               ; es:di 指向新表，然后修改表中偏移 4 处的最大扇区数
	movb 4(di),*18		; patch sector count

	seg fs                  ;让中断向量 0x1E 的值指向新表
	mov	(bx),di
	seg fs
	mov	2(bx),es

	pop	ax                  ;此时 ax 中是上面第 65 行保留下来的段值（0x9000）
	mov	fs,ax               ;设置 fs = gs = 0x9000，恢复原段值
	mov	gs,ax
	
	xor	ah,ah			    ;复位软盘控制器，让其采用新参数
	xor	dl,dl               ;dl = 0，第 1 个软驱
	int 0x13	

; 在 bootsect 程序块后紧根着加载 setup 模块的代码数据。
; 注意 es 已经设置好了。（在移动代码时 es 已经指向目的段地址处 0x9000）。

; 121--137 行的用途是利用 ROM BIOS 中断 INT 0x13 将 setup 模块从磁盘第 2 个扇区开始读到
; 0x90200 开始处，共读 4 个扇区。在读操作过程中如果读出错，则显示磁盘上出错扇区位置，
; 然后复位驱动器并重试，没有退路。
; INT 0x13 读扇区使用调用参数设置如下：
; ah = 0x02 - 读磁盘扇区到内存；al = 需要读出的扇区数量；
; ch = 磁道(柱面)号的低 8 位； cl = 开始扇区(位 0-5)，磁道号高 2 位(位 6-7)；
; dh = 磁头号； dl = 驱动器号（如果是硬盘则位 7 要置位）；
; es:bx →指向数据缓冲区； 如果出错则 CF 标志置位，ah 中是出错码。
load_setup:
	xor	dx, dx			; drive 0, head 0
	mov	cx,#0x0002		; sector 2, track 0
	mov	bx,#0x0200		; address = 512, in INITSEG
	mov	ax,#0x0200+SETUPLEN	; service 2, nr of sectors
	int	0x13			; read it
	jnc	ok_load_setup		; ok - continue

	push	ax			; 显示出错信息。出错码入栈
	call	print_nl    ; 屏幕光标回车
	mov	bp, sp          ; ss:bp 指向欲显示的字（word）
	call	print_hex   ; 显示十六进制值
	pop	ax	
	
	xor	dl, dl			; 复位磁盘控制器，重试
	xor	ah, ah
	int	0x13
	j	load_setup      ; j 即 jmp 指令

ok_load_setup:
	; 这段代码利用 BIOS INT 0x13 功能 8 来取磁盘驱动器的参数。实际是取每磁道扇区数，并保存在
	; 位置 sectors 处。取磁盘驱动器参数 INT 0x13 调用格式和返回信息如下：
	; ah = 0x08 dl = 驱动器号（如果是硬盘则要置位 7 为 1）。
	; 返回信息：
	; 如果出错则 CF 置位，并且 ah = 状态码。
	; ah = 0， al = 0， bl = 驱动器类型（AT/PS2）
	; ch = 最大磁道号的低 8 位， cl = 每磁道最大扇区数(位 0-5)，最大磁道号高 2 位(位 6-7)
	; dh = 最大磁头数， dl = 驱动器数量，
	; es:di -→ 软驱磁盘参数表。
	xor	dl,dl
	mov	ah,#0x08		; AH=8 is get drive parameters
	int	0x13
	xor	ch,ch
    ; 下面指令表示下一条语句的操作数在 cs 段寄存器所指的段中。它只影响其下一条语句。
	; 实际上，由于本程序代码和数据都被设置处于同一个段中，即段寄存器 cs 和 ds、es 的值相同，
	; 因此本程序中此处可以不使用该指令
	seg cs
	; 下句保存每磁道扇区数。对于软盘来说（dl=0），其最大磁道号不会超过 256，ch 已经足够表
	; 示它，因此 cl 的位 6-7 肯定为 0。又 146 行已置 ch=0，因此此时 cx 中是每磁道扇区数。
	mov	sectors,cx
	mov	ax,#INITSEG
	mov	es,ax			; 因为上面取磁盘参数中断改了 es 值，这里重新改回
	; 下面利用 BIOS INT 0x10 功能 0x03 和 0x13 来显示信息：“'Loading'+回车+换行”，显示包括
	; 回车和换行控制字符在内共 9 个字符。
	; BIOS 中断 0x10 功能号 ah = 0x03，读光标位置。
	; 输入：bh = 页号
	; 返回：ch = 扫描开始线；cl = 扫描结束线；dh = 行号(0x00 顶端)；dl = 列号(0x00 最左边)。
	; 
	; BIOS 中断 0x10 功能号 ah = 0x13，显示字符串。
	; 输入：al = 放置光标的方式及规定属性。0x01-表示使用 bl 中的属性值，光标停在字符串结尾处。
	; bh = 显示页面号；bl = 字符属性；dh = 行号；dl = 列号。cx = 显示的字符串字符数。
	; es:bp 此寄存器对指向要显示的字符串起始位置处。
	mov	ah,#0x03		; read cursor pos
	xor	bh,bh			; 首先读光标位置。返回光标位置值在 dx 中
	int	0x10			; dh - 行（0--24）；dl - 列(0--79)
	
	mov	cx,#9			; 共显示 9 个字符
	mov	bx,#0x0007		; page 0, attribute 7 (normal)
	mov	bp,#msg1		; es:bp 指向要显示的字符串
	mov	ax,#0x1301		; 写字符串并移动光标到串结尾处
	int	0x10
	; 现在开始将 system 模块加载到 0x10000（64KB）开始处
	mov	ax,#SYSSEG
	mov	es,ax			; es = 存放 system 的段地址
	call read_it		; 读磁盘上 system 模块，es 为输入参数
	call kill_motor		; 关闭驱动器马达，这样就可以知道驱动器的状态了
	call print_nl		; 光标回车换行

	; 此后，我们检查要使用哪个根文件系统设备（简称根设备）。如果已经指定了设备(;=0)，
	; 就直接使用给定的设备。否则就需要根据 BIOS 报告的每磁道扇区数来确定到底使用/dev/PS0
	; (2,28)，还是 /dev/at0 (2,8)。
	;; 上面一行中两个设备文件的含义说明如下：
	;; 在 Linux 中软驱的主设备号是 2(参见第 43 行的注释)，次设备号 = type*4 + nr，其中
	;; nr 为 0-3 分别对应软驱 A、B、C 或 D；type 是软驱的类型（2→1.2MB 或 7→1.44MB 等）。
	;; 因为 7*4 + 0 = 28，所以 /dev/PS0 (2,28)指的是 1.44MB A 驱动器,其设备号是 0x021c 
	;; 同理 /dev/at0 (2,8)指的是 1.2MB A 驱动器，其设备号是 0x0208。
	; 下面 root_dev 定义在引导扇区 508，509 字节处，指根文件系统所在设备号。0x0306 指第 2
	; 个硬盘第 1 个分区。这里默认为 0x0306 是因为当时 Linus 开发 Linux 系统时是在第 2 个硬
	; 盘第 1 个分区中存放根文件系统。这个值需要根据你自己根文件系统所在硬盘和分区进行修
	; 改。例如，如果你的根文件系统在第 1 个硬盘的第 1 个分区上，那么该值应该为 0x0301，即
	; （0x01, 0x03）。如果根文件系统是在第 2 个 1.44MB 软盘上，那么该值应该为 0x021D，即
	; （0x1D,0x02）。当编译内核时，你可以在 Makefile 文件中另行指定你自己的值。内核映像
	; 文件 Image 的创建程序 tools/build 会使用你指定的值来设置你的根文件系统所在设备号。
	seg cs
	mov	ax,root_dev		; 取 508,509 字节处的根设备号并判断是否已被定义
	or	ax,ax
	jne	root_defined
	; 下面语句取上面第 148 行保存的每磁道扇区数 sectors 来判断磁盘类型。如果 sectors=15 则说明
	; 是 1.2MB 的驱动器；如果 sectors=18，则是 1.44MB 软驱。因为是可引导驱动器，所以肯定是 A 驱
	seg cs
	mov	bx,sectors
	mov	ax,#0x0208		; /dev/ps0 - 1.2Mb
	cmp	bx,#15			; 判断每磁道扇区数是否=15
	je	root_defined	; 如果等于，则 ax 中就是引导驱动器的设备号
	mov	ax,#0x021c		; /dev/PS0 - 1.44Mb
	cmp	bx,#18
	je	root_defined
undef_root:
	jmp undef_root		; 如果都不一样，则死循环（死机）
root_defined:
	seg cs
	mov	root_dev,ax		; 将检查过的设备号保存到 root_dev 中

	; 到此，所有程序都加载完毕，我们就跳转到被加载在 bootsect 后面的 setup 程序去。
 	; 下面段间跳转指令（Jump Intersegment）。跳转到 0x9020:0000(setup.s 程序开始处)去执行
	jmpi	0,SETUPSEG

; 下面是几个子程序。read_it 用于读取磁盘上的 system 模块。kill_moter 用于关闭软驱马达。还有一些屏幕显示子程序。

; 该子程序将系统模块加载到内存地址 0x10000 处，并确定没有跨越 64KB 的内存边界。
; 我们试图尽快地进行加载，只要可能，就每次加载整条磁道的数据。
; 输入：es – 开始内存地址段值（通常是 0x1000）
;
; 下面伪操作符.word 定义一个 2 字节目标。相当于 C 语言程序中定义的变量和所占内存空间大小。
; 常数值'1+SETUPLEN'表示开始时已经读进 1 个引导扇区和 setup 程序所占的扇区数 SETUPLEN。
sread:	.word 1+SETUPLEN	; 当前磁道中已读扇区数
head:	.word 0				; 当前磁头号
track:	.word 0				; 当前磁道号

; 首先测试输入的段值。从盘上读入的数据必须存放在位于内存地址 64KB 的边界开始处，否则
; 进入死循环。bx 寄存器用于当前段内存放数据的开始位置。
; 214 行上的指令 test 以比特位逻辑与两个操作数。若两个操作数对应的比特位都为 1，则结果
; 值的对应比特位为 1，否则为 0。该操作结果只影响标志（零标志 ZF 等）。例如若 AX=0x1000，
; 那么 test 指令的执行结果是(0x1000 & 0x0fff) = 0x0000，于是 ZF 标志置位。此时即下一条
; 指令 jne 条件不成立
read_it:
	mov ax,es
	test ax,#0x0fff
die:	jne die			; es 值必须位于 64KB 边界
	xor bx,bx			; bx 为段内偏移
; 接着判断是否已经读入全部数据。比较当前所读段是否就是系统数据末端所处的段(#ENDSEG)，
; 如果不是就跳转至下面 ok1_read 标号处继续读数据。否则退出子程序返回。
rp_read:
	mov ax,es
	cmp ax,#ENDSEG		; 是否已经加载了全部数据？
	jb ok1_read
	ret
; 然后计算和验证当前磁道需要读取的扇区数，放在 ax 寄存器中。
; 根据当前磁道还未读取的扇区数以及段内数据字节开始偏移位置，计算如果全部读取这些未读
; 扇区，所读总字节数是否会超过 64KB 段长度的限制。若会超过，则根据此次最多能读入的字节
; 数 (64KB –段内偏移位置)，反算出此次需要读取的扇区数。
ok1_read:
	seg cs
	mov ax,sectors		; 取每磁道扇区数
	sub ax,sread		; 减去当前磁道已读扇区数
	mov cx,ax			; cx = ax = 当前磁道未读扇区数
	shl cx,#9			; cx = cx * 512 字节 + 段内当前偏移值(bx)
	add cx,bx			; = 此次读操作后，段内共读入的字节数
	jnc ok2_read		; 若没有超过 64KB 字节，则跳转至 ok2_read 处执行
	je ok2_read
	; 若加上此次将读磁道上所有未读扇区时会超过 64KB，则计算此时最多能读入的字节数：
 	; (64KB–段内读偏移位置)，再转换成需读取的扇区数。其中 0 减某数就是取该数 64KB 的补值。
	xor ax,ax
	sub ax,bx
	shr ax,#9
; 读当前磁道上指定开始扇区（cl）和需读扇区数（al）的数据到 es:bx 开始处。然后统计当前
; 磁道上已经读取的扇区数并与磁道最大扇区数 sectors 作比较。如果小于 sectors 说明当前磁
; 道上还有扇区未读。于是跳转到 ok3_read 处继续操作。
ok2_read:
	call read_track		; 读当前磁道上指定开始扇区和需读扇区数的数据
	mov cx,ax			; cx = 该次操作已读取的扇区数
	add ax,sread		; 加上当前磁道上已经读取的扇区数
	seg cs
	cmp ax,sectors		; 若当前磁道上还有扇区未读，则跳转到 ok3_read 处
	jne ok3_read
	; 若该磁道的当前磁头面所有扇区已经读取，则读该磁道的下一磁头面（1 号磁头）上的数据。
 	; 如果已经完成，则去读下一磁道。
	mov ax,#1
	sub ax,head			; 判断当前磁头号
	jne ok4_read		; 如果是 0 磁头，则再去读 1 磁头面上的扇区数据
	inc track			; 否则去读下一磁道
ok4_read:
	mov head,ax			; 保存当前磁头号
	xor ax,ax			; 清当前磁道已读扇区数
; 如果当前磁道上还有未读扇区，则首先保存当前磁道已读扇区数，然后调整存放数据处的开
; 始位置。若小于 64KB 边界值，则跳转到 rp_read(217 行)处，继续读数据。
ok3_read:
	mov sread,ax		; 保存当前磁道已读扇区数
	shl cx,#9			; 上次已读扇区数*512 字节		
	add bx,cx			; 调整当前段内数据开始位置
	jnc rp_read	
	; 否则说明已经读取 64KB 数据。此时调整当前段，为读下一段数据作准备		
	mov ax,es
	add ah,#0x10		; 将段基址调整为指向下一个 64KB 内存开始处
	mov es,ax
	xor bx,bx			; 清段内数据开始偏移值
	jmp rp_read			; 跳转至 rp_read(217 行)处，继续读数据

; read_track 子程序。读当前磁道上指定开始扇区和需读扇区数的数据到 es:bx 开始处。参见
; 第 119 行下对 BIOS 磁盘读中断 int 0x13，ah=2 的说明。
; al – 需读扇区数；es:bx – 缓冲区开始位置。
read_track:
	; 首先调用 BIOS 中断 0x10，功能 0x0e（以电传方式写字符），光标前移一位置。显示一个'.'
	pusha				; 压入所有寄存器（push all）
	pusha				; 为调用显示中断压入所有寄存器值	
	mov	ax, #0xe2e 		; loading... message 2e = .
	mov	bx, #7			; 字符前景色属性
 	int	0x10
	popa		

	; 然后正式进行磁道扇区读操作
	mov dx,track		; 取当前磁道号
	mov cx,sread ; 取当前磁道上已读扇区数。
	inc cx ; cl = 开始读扇区。
	mov ch,dl ; ch = 当前磁道号。
	mov dx,head ; 取当前磁头号。
	mov dh,dl ; dh = 磁头号，dl = 驱动器号(为 0 表示当前 A 驱动器)。
	and dx,#0x0100 ; 磁头号不大于 1。
	mov ah,#2 ; ah = 2，读磁盘扇区功能号。
	
	push dx ; save for error dump
	push cx ; 为出错情况保存一些信息。
	push bx

	push ax

	int 0x13
	jc bad_rt ; 若出错，则跳转至 bad_rt。
	add sp,#8 ; 没有出错。因此丢弃为出错情况保存的信息。
	popa
	ret

; 读磁盘操作出错。则先显示出错信息，然后执行驱动器复位操作（磁盘中断功能号 0），再跳转
; 到 read_track 处重试。
bad_rt: push ax 	; save error code
 	call print_all 	; ah = error, al = read
 
 
	xor ah,ah
	xor dl,dl
	int 0x13
 

	add sp, #10 ; 丢弃为出错情况保存的信息。
	popa 
	jmp read_track

/*
* print_all is for debugging purposes. 
* It will print out all of the registers. The assumption is that this is
* called from a routine, with a stack frame like
* dx 
* cx
* bx
* ax
* error
* ret <- sp
*
*/
/*
* 子程序 print_all 用于调试目的。它会显示所有寄存器的内容。前提条件是需要从
* 一个子程序中调用，并且栈帧结构为如下所示：（见上面）
*/
; 若标志寄存器的 CF=0，则不显示寄存器名称。
 
print_all:
	mov cx, #5 ; error code + 4 registers ; 显示值个数。
	mov bp, sp ; 保存当前栈指针 sp。

print_loop:
	push cx ; save count left ; 保存需要显示的剩余个数。
	call print_nl ; nl for readability ; 为可读性先让光标回车换行。
	jae no_reg ; see if register name is needed
	; 若 FLAGS 的标志 CF=0 则不显示寄存器名，于是跳转。
	; 对应入栈寄存器顺序分别显示它们的名称“AX：”等。
	mov ax, #0xe05 + 0x41 - 1 ; ah =功能号（0x0e）；al =字符（0x05 + 0x41 -1）。
	sub al, cl

	int 0x10

	mov al, #0x58 ; X ; 显示字符'X'。
	int 0x10

	mov al, #0x3a ; : ; 显示字符':'。
	int 0x10

; 显示寄存器 bp 所指栈中内容。开始时 bp 指向返回地址。
no_reg:
	add bp, #2 ; next register ; 栈中下一个位置。
	call print_hex ; print it ; 以十六进制显示。
	pop cx
	loop print_loop
	ret

; 调用 BIOS 中断 0x10，以电传方式显示回车换行。
print_nl:
	mov ax, #0xe0d ; CR
	int 0x10
	mov al, #0xa ; LF
	int 0x10
	ret

/*
* print_hex is for debugging purposes, and prints the word
* pointed to by ss:bp in hexadecmial.
*/
/*
* 子程序 print_hex 用于调试目的。它使用十六进制在屏幕上显示出
* ss:bp 指向的字。
*/

; 调用 BIOS 中断 0x10，以电传方式和 4 个十六进制数显示 ss:bp 指向的字。
print_hex:
	mov cx, #4 ; 4 hex digits ; 要显示 4 个十六进制数字。
	mov dx, (bp) ; load word into dx ; 显示值放入 dx 中。
print_digit:
	; 先显示高字节，因此需要把 dx 中值左旋 4 比特，此时高 4 比特在 dx 的低 4 位中。
	rol dx, #4 ; rotate so that lowest 4 bits are used
	mov ah, #0xe ; 中断功能号。
	mov al, dl ; mask off so we have only next nibble
	and al, #0xf ; 放入 al 中并只取低 4 比特（1 个值）。
	; 加上'0' 的 ASCII 码值 0x30，把显示值转换成基于数字'0' 的字符。若此时 al 值超过 0x39，
	; 表示欲显示值超过数字 9，因此需要使用'A'--'F'来表示。
	add al, #0x30 ; convert to 0 based digit, '0'
	cmp al, #0x39 ; check for overflow
	jbe good_digit
	add al, #0x41 - 0x30 - 0xa ; 'A' - '0' - 0xa

good_digit:
	int 0x10
	loop print_digit ; cx--。若 cx>0 则去显示下一个值。

	ret


/*
* This procedure turns off the floppy drive motor, so
* that we enter the kernel in a known state, and
* don't have to worry about it later.
*/
/* 这个子程序用于关闭软驱的马达，这样我们进入内核后就能
* 知道它所处的状态，以后也就无须担心它了。
*/
; 下面第 377 行上的值 0x3f2 是软盘控制器的一个端口，被称为数字输出寄存器（DOR）端口。它是
; 一个 8 位的寄存器，其位 7--位 4 分别用于控制 4 个软驱（D--A）的启动和关闭。位 3--位 2 用于
; 允许/禁止 DMA 和中断请求以及启动/复位软盘控制器 FDC。 位 1--位 0 用于选择选择操作的软驱。
; 第 378 行上在 al 中设置并输出的 0 值，就是用于选择 A 驱动器，关闭 FDC，禁止 DMA 和中断请求，
; 关闭马达。有关软驱控制卡编程的详细信息请参见 kernel/blk_drv/floppy.c 程序后面的说明。
kill_motor:
	push dx
	mov dx,#0x3f2 ; 软驱控制卡的数字输出寄存器端口，只写。
	xor al, al ; A 驱动器，关闭 FDC，禁止 DMA 和中断请求，关闭马达。
	outb ; 将 al 中的内容输出到 dx 指定的端口去。
	pop dx
	ret

sectors:
	.word 0 ; 存放当前启动软盘每磁道的扇区数。

msg1: ; 开机调用 BIOS 中断显示的信息。共 9 个字符。
	.byte 13,10 ; 回车、换行的 ASCII 码。
	.ascii "Loading"

; 表示下面语句从地址 506(0x1FA)开始，所以 root_dev 在启动扇区的第 508 开始的 2 个字节中。
.org 506
swap_dev:
	.word SWAP_DEV ; 这里存放交换系统所在设备号(init/main.c 中会用)。
root_dev:
	.word ROOT_DEV ; 这里存放根文件系统所在设备号(init/main.c 中会用)。
; 下面 0Xaa55 是启动盘具有有效引导扇区的标志。供 BIOS 中的程序加载引导扇区时识别使用。
; 它必须位于引导扇区的最后两个字节中。
boot_flag:
	.word 0xAA55

.text
endtext:
.data
enddata:
.bss
endbss: