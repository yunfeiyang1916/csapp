/*
 * math_emu.h 文件中包含第 11 章（数学协处理器）中所涉及的常量定义和结构，主要包括内核代码
 * 在仿真数学协处理器时用到的一些表示各种数据类型的数据结构。
 */
#ifndef _LINUX_MATH_EMU_H
#define _LINUX_MATH_EMU_H

#include <linux/sched.h> // 调度程序头文件。定义了任务结构 task_struct、任务 0 的数据，
// 还有一些有关描述符参数设置和获取的嵌入式汇编函数宏语句。

// CPU 产生异常中断 int 7 时在栈中分布的数据构成的结构，与系统调用时内核栈中数据分布类似。
struct info
{
    long ___math_ret; // math_emulate()调用者（int7）返回地址。
    long ___orig_eip; // 临时保存原 EIP 的地方。
    long ___edi;      // 异常中断 int7 处理过程入栈的寄存器。
    long ___esi;
    long ___ebp;
    long ___sys_call_ret; // 中断 7 返回时将去执行系统调用的返回处理代码。
    long ___eax;          // 以下部分（18--30 行）与系统调用时栈中结构相同。
    long ___ebx;
    long ___ecx;
    long ___edx;
    long ___orig_eax; // 如不是系统调用而是其它中断时，该值为-1。
    long ___fs;
    long ___es;
    long ___ds;
    long ___eip; // 26 -- 30 行 由 CPU 自动入栈。
    long ___cs;
    long ___eflags;
    long ___esp;
    long ___ss;
};

// 为便于引用 info 结构中各字段（栈中数据）所定义的一些常量。
#define EAX (info->___eax)
#define EBX (info->___ebx)
#define ECX (info->___ecx)
#define EDX (info->___edx)
#define ESI (info->___esi)
#define EDI (info->___edi)
#define EBP (info->___ebp)
#define ESP (info->___esp)
#define EIP (info->___eip)
#define ORIG_EIP (info->___orig_eip)
#define EFLAGS (info->___eflags)
#define DS (*(unsigned short *)&(info->___ds))
#define ES (*(unsigned short *)&(info->___es))
#define FS (*(unsigned short *)&(info->___fs))
#define CS (*(unsigned short *)&(info->___cs))
#define SS (*(unsigned short *)&(info->___ss))

// 终止数学协处理器仿真操作。在 math_emulation.c 程序中实现(L488 行）。
// 下面 52-53 行上宏定义的实际作用是把__math_abort 重新定义为一个不会返回的函数
// （即在前面加上了 volatile）。该宏的前部分：
// (volatile void (*)(struct info *,unsigned int))
// 是函数类型定义，用于重新指明 __math_abort 函数的定义。后面是其相应的参数。
// 关键词 volatile 放在函数名前来修饰函数，是用来通知 gcc 编译器该函数不会返回,
// 以让 gcc 产生更好一些的代码。详细说明请参见第 3 章 $3.3.2 节内容。
// 因此下面的宏定义，其主要目的就是利用__math_abort，让它即可用作普通有返回函数，
// 又可以在使用宏定义 math_abort() 时用作不返回的函数。
void __math_abort(struct info *, unsigned int);

#define math_abort(x, y) \
    (((volatile void (*)(struct info *, unsigned int))__math_abort)((x), (y)))

/*
 * Gcc forces this stupid alignment problem: I want to use only two longs
 * for the temporary real 64-bit mantissa, but then gcc aligns out the
 * structure to 12 bytes which breaks things in math_emulate.c. Shit. I
 * want some kind of "no-alignt" pragma or something.
 */
/*
 * Gcc 会强迫这种愚蠢的对齐问题：我只想使用两个 long 类型数据来表示 64 比特的
 * 临时实数尾数，但是 gcc 却会将该结构以 12 字节来对齐，这将导致 math_emulate.c
 * 中程序出问题。唉，我真需要某种非对齐“no-align”编译指令。
 */

// 临时实数对应的结构。
typedef struct
{
    long a, b;      // 共 64 比特尾数。其中 a 为低 32 位，b 为高 32 位（包括 1 位固定位）。
    short exponent; // 指数值。
} temp_real;

// 为了解决上面英文注释中所提及的对齐问题而设计的结构，作用同上面 temp_real 结构。
typedef struct
{
    short m0, m1, m2, m3;
    short exponent;
} temp_real_unaligned;

// 把 temp_real 类型值 a 赋值给 80387 栈寄存器 b (ST(i))。
#define real_to_real(a, b) \
    ((*(long long *)(b) = *(long long *)(a)), ((b)->exponent = (a)->exponent))

// 长实数（双精度）结构。
typedef struct
{
    long a, b; // a 为长实数的低 32 位；b 为高 32 位。
} long_real;

typedef long short_real; // 定义短实数类型。

// 临时整数结构。
typedef struct
{
    long a, b;  // a 为低 32 位；b 为高 32 位。
    short sign; // 符号标志。
} temp_int;

// 80387 协处理器内部的状态字寄存器内容对应的结构。（参见图 11-6）
struct swd
{
    int ie : 1; // 无效操作异常。
    int de : 1; // 非规格化异常。
    int ze : 1; // 除零异常。
    int oe : 1; // 上溢出异常。
    int ue : 1; // 下溢出异常。
    int pe : 1; // 精度异常。
    int sf : 1; // 栈出错标志，表示累加器溢出造成的异常。
    int ir : 1; // ir, b: 若上面 6 位任何未屏蔽异常发生，则置位。
    int c0 : 1; // c0--c3: 条件码比特位。
    int c1 : 1;
    int c2 : 1;
    int top : 3; // 指示 80387 中当前位于栈顶的 80 位寄存器。
    int c3 : 1;
    int b : 1;
};

// 80387 内部寄存器控制方式常量。
#define I387 (current->tss.i387)        // 进程的 80387 状态信息。参见 sched.h 文件。
#define SWD (*(struct swd *)&I387.swd)  // 80387 中状态控制字。
#define ROUNDING ((I387.cwd >> 10) & 3) // 取控制字中舍入控制方式。
#define PRECISION ((I387.cwd >> 8) & 3) // 取控制字中精度控制方式。

// 定义精度有效位常量。
#define BITS24 0 // 精度有效数：24 位。（参见图 11-6）
#define BITS53 2 // 精度有效数：53 位。
#define BITS64 3 // 精度有效数：64 位。

// 定义舍入方式常量。
#define ROUND_NEAREST 0 // 舍入方式：舍入到最近或偶数。
#define ROUND_DOWN 1    // 舍入方式：趋向负无限。
#define ROUND_UP 2      // 舍入方式：趋向正无限。
#define ROUND_0 3       // 舍入方式：趋向截 0。

// 常数定义。
#define CONSTZ \
    (temp_real_unaligned) { 0x0000, 0x0000, 0x0000, 0x0000, 0x0000 } // 0
#define CONST1 \
    (temp_real_unaligned) { 0x0000, 0x0000, 0x0000, 0x8000, 0x3FFF } // 1.0
#define CONSTPI \
    (temp_real_unaligned) { 0xC235, 0x2168, 0xDAA2, 0xC90F, 0x4000 } // Pi
#define CONSTLN2 \
    (temp_real_unaligned) { 0x79AC, 0xD1CF, 0x17F7, 0xB172, 0x3FFE } // Loge(2)
#define CONSTLG2 \
    (temp_real_unaligned) { 0xF799, 0xFBCF, 0x9A84, 0x9A20, 0x3FFD } // Log10(2)
#define CONSTL2E \
    (temp_real_unaligned) { 0xF0BC, 0x5C17, 0x3B29, 0xB8AA, 0x3FFF } // Log2(e)
#define CONSTL2T \
    (temp_real_unaligned) { 0x8AFE, 0xCD1B, 0x784B, 0xD49A, 0x4000 } // Log2(10)

// 设置 80387 各状态
#define set_IE() (I387.swd |= 1)
#define set_DE() (I387.swd |= 2)
#define set_ZE() (I387.swd |= 4)
#define set_OE() (I387.swd |= 8)
#define set_UE() (I387.swd |= 16)
#define set_PE() (I387.swd |= 32)

// 设置 80387 各控制条件
#define set_C0() (I387.swd |= 0x0100)
#define set_C1() (I387.swd |= 0x0200)
#define set_C2() (I387.swd |= 0x0400)
#define set_C3() (I387.swd |= 0x4000)

/* ea.c */

// 计算仿真指令中操作数使用到的有效地址值，即根据指令中寻址模式字节计算有效地址值。
// 参数：__info - 中断时栈中内容对应结构；__code - 指令代码。
// 返回：有效地址值。
char *ea(struct info *__info, unsigned short __code);

/* convert.c */

// 各种数据类型转换函数。在 convert.c 文件中实现。
void short_to_temp(const short_real *__a, temp_real *__b);
void long_to_temp(const long_real *__a, temp_real *__b);
void temp_to_short(const temp_real *__a, short_real *__b);
void temp_to_long(const temp_real *__a, long_real *__b);
void real_to_int(const temp_real *__a, temp_int *__b);
void int_to_real(const temp_int *__a, temp_real *__b);

/* get_put.c */

// 存取各种类型数的函数。
void get_short_real(temp_real *, struct info *, unsigned short);
void get_long_real(temp_real *, struct info *, unsigned short);
void get_temp_real(temp_real *, struct info *, unsigned short);
void get_short_int(temp_real *, struct info *, unsigned short);
void get_long_int(temp_real *, struct info *, unsigned short);
void get_longlong_int(temp_real *, struct info *, unsigned short);
void get_BCD(temp_real *, struct info *, unsigned short);
void put_short_real(const temp_real *, struct info *, unsigned short);
void put_long_real(const temp_real *, struct info *, unsigned short);
void put_temp_real(const temp_real *, struct info *, unsigned short);
void put_short_int(const temp_real *, struct info *, unsigned short);
void put_long_int(const temp_real *, struct info *, unsigned short);
void put_longlong_int(const temp_real *, struct info *, unsigned short);
void put_BCD(const temp_real *, struct info *, unsigned short);

/* add.c */

// 仿真浮点加法指令的函数。
void fadd(const temp_real *, const temp_real *, temp_real *);

/* mul.c */

// 仿真浮点乘法指令。
void fmul(const temp_real *, const temp_real *, temp_real *);

/* div.c */

// 仿真浮点除法指令。
void fdiv(const temp_real *, const temp_real *, temp_real *);

/* compare.c */

// 比较函数。
void fcom(const temp_real *, const temp_real *);  // 仿真浮点指令 FCOM，比较两个数。
void fucom(const temp_real *, const temp_real *); // 仿真浮点指令 FUCOM，无次序比较。
void ftst(const temp_real *);                     // 仿真浮点指令 FTST，栈顶累加器与 0 比较。

#endif
