/*
 * 仿真范围有限的程序 91.12.27 - 绝大多数是一些加载/存储指令。除非你使用
 * 了 Bruce Evans 的补丁程序，否则即使使用软件执行浮点运算，gcc 也需要这些
 * 指令。Bruce 的补丁程序非常好，但每次更换 gcc 版本你都得用这个补丁程序。
 * 而且对于软件浮点实现和 80387，所使用的库是不同的。因此使用仿真是更为实
 * 际的方法，尽管仿真方法更慢。
 *
 * 91.12.28 - 加载/存储协处理器指令可以用了，即使是 BCD 码的也能使用。我将
 * 开始考虑实现 add/sub/mul/div 指令。唉，我应该找一些好的资料，不过现在
 * 我会先仿造一些操作。
 *
 * 91.12.30 - add/sub/mul/div/com 这些指令好像大多数都可以使用了。我真应
 * 该测试每种指令可能的组合操作。
 */

/*
 * This file is full of ugly macros etc: one problem was that gcc simply
 * didn't want to make the structures as they should be: it has to try to
 * align them. Sickening code, but at least I've hidden the ugly things
 * in this one file: the other files don't need to know about these things.
 *
 * The other files also don't care about ST(x) etc - they just get addresses
 * to 80-bit temporary reals, and do with them as they please. I wanted to
 * hide most of the 387-specific things here.
 */
/*
 * 这个程序中到处都是些别扭的宏：问题之一是 gcc 就是不想把结构建立成其应该
 * 成为的样子：gcc 企图对结构进行对齐处理。真是讨厌，不过我起码已经把所有
 * 蹩脚的代码都隐藏在这么一个文件中了：其他程序文件不需要了解这些信息。
 *
 * 其他的程序也不需要知道 ST(x)等 80387 内部结构 - 它们只需要得到 80 位临时
 * 实数的地址就可以随意操作。我想尽可能在这里隐藏所有 387 专有信息。
 */

#include <signal.h> // 信号头文件。定义信号符号，信号结构及信号操作函数原型。

#define __ALIGNED_TEMP_REAL 1
#include <linux/math_emu.h> // 协处理器头文件。定义临时实数结构和 387 寄存器操作宏等。
#include <linux/kernel.h>   // 内核头文件。含有一些内核常用函数的原形定义。
#include <asm/segment.h>    // 段操作头文件。定义了有关段寄存器操作的嵌入式汇编函数。

#define bswapw(x) __asm__("xchgb %%al,%%ah" \
                          : "=a"(x)         \
                          : ""((short)x))     // 交换 2 字节位置。
#define ST(x) (*__st((x)))                    // 取仿真的 ST(x)累加器值。
#define PST(x) ((const temp_real *)__st((x))) // 取仿真的 ST(x)累加器的指针。

/*
 * We don't want these inlined - it gets too messy in the machine-code.
 */
/*
 * 我们不想让这些成为嵌入的语句 - 因为这会使得到的机器码太混乱。
 */
// 以下这些是相同名称浮点指令的仿真函数。
static void fpop(void);
static void fpush(void);
static void fxchg(temp_real_unaligned *a, temp_real_unaligned *b);
static temp_real_unaligned *__st(int i);

// 执行浮点指令仿真。
// 该函数首先检测仿真的 I387 结构状态字寄存器中是否有未屏蔽的异常标志置位。若有则对状
// 态字中忙标志 B 进行设置。然后把指令指针保存起来，并取出代码指针 EIP 处的 2 字节浮点
// 指令代码 code。接着分析代码 code，并根据其含义进行处理。针对不同代码类型值，Linus
// 使用了几个不同的 switch 程序块进行仿真处理。
// 参数是 info 结构的指针。
static void do_emu(struct info *info)
{
    unsigned short code;
    temp_real tmp;
    char *address;

    // 该函数首先检测仿真的 I387 结构状态字寄存器中是否有未屏蔽的异常标志置位。若有就设置
    // 状态字中的忙标志 B（位 15），否则复位 B 标志。然后我们把指令指针保存起来。再看看执
    // 行本函数的代码是否是用户代码。如果不是，即调用者的代码段选择符不等于 0x0f，则说明
    // 内核中有代码使用了浮点指令。于是在显示出浮点指令出的 CS、EIP 值和信息“内核中需要
    // 数学仿真”后停机。
    if (I387.cwd & I387.swd & 0x3f)
        I387.swd |= 0x8000; // 设置忙标志 B。
    else
        I387.swd &= 0x7fff; // 清忙标志 B。
    ORIG_EIP = EIP;         // 保存浮点指令指针。
    /* 0x0007 means user code space */
    if (CS != 0x000F)
    { // 不是用户代码则停机。
        printk("math_emulate: %04x:%08x\n\r", CS, EIP);
        panic("Math emulation needed in kernel");
    }
    // 然后我们取出代码指针 EIP 处的 2 字节浮点指令代码 code。 由于 Intel CPU 存储数据时是
    // “小头”（Little endien）在前的，此时取出的代码正好与指令的第 1、第 2 字节顺序颠倒。
    // 因此我们需要交换一下 code 中两个字节的顺序。然后再屏蔽掉第 1 个代码字节中的 ESC 位
    // （二进制 11011）。接着把浮点指令指针 EIP 保存到 TSS 段 i387 结构中的 fip 字段中，而 CS
    // 保存到 fcs 字段中，同时把略微处理过的浮点指令代码 code 放到 fcs 字段的高 16 位中。
    // 保存这些值是为了在出现仿真的处理器异常时程序可以像使用真实的协处理器一样进行处理。
    // 最后让 EIP 指向随后的浮点指令或操作数。
    code = get_fs_word((unsigned short *)EIP); // 取 2 字节的浮点指令代码。
    bswapw(code);                              // 交换高低字节。
    code &= 0x7ff;                             // 屏蔽代码中的 ESC 码。
    I387.fip = EIP;                            // 保存指令指针。
    *(unsigned short *)&I387.fcs = CS;         // 保存代码段选择符。
    *(1 + (unsigned short *)&I387.fcs) = code; // 保存代码。
    EIP += 2;                                  // 指令指针指向下一个字节。
    // 然后分析代码值 code，并根据其含义进行处理。针对不同代码类型值，Linus 使用了几个不同
    // 的 switch 程序块进行处理。首先，若指令操作码是具有固定代码值（与寄存器等无关），则
    // 在下面处理。
    switch (code)
    {
    case 0x1d0: /* fnop */ /* 空操作指令 FNOP */
        return;
    case 0x1d1:
    case 0x1d2:
    case 0x1d3: // 无效指令代码。发信号，退出。
    case 0x1d4:
    case 0x1d5:
    case 0x1d6:
    case 0x1d7:
        math_abort(info, 1 << (SIGILL - 1));
    case 0x1e0: // FCHS - 改变 ST 符号位。即 ST = -ST。
        ST(0).exponent ^= 0x8000;
        return;
    case 0x1e1: // FABS - 取绝对值。即 ST = |ST|。
        ST(0).exponent &= 0x7fff;
        return;
    case 0x1e2:
    case 0x1e3: // 无效指令代码。发信号，退出。
        math_abort(info, 1 << (SIGILL - 1));
    case 0x1e4: // FTST - 测试 TS，同时设置状态字中 Cn。
        ftst(PST(0));
        return;
    case 0x1e5:                             // FXAM - 检查 TS 值，同时修改状态字中 Cn。
        printk("fxam not implemented\n\r"); // 未实现。发信号退出。
        math_abort(info, 1 << (SIGILL - 1));
    case 0x1e6:
    case 0x1e7: // 无效指令代码。发信号，退出。
        math_abort(info, 1 << (SIGILL - 1));
    case 0x1e8: // FLD1 - 加载常数 1.0 到累加器 ST。
        fpush();
        ST(0) = CONST1;
        return;
    case 0x1e9: // FLDL2T - 加载常数 Log2(10) 到累加器 ST。
        fpush();
        ST(0) = CONSTL2T;
        return;
    case 0x1ea: // FLDL2E - 加载常数 Log2(e) 到累加器 ST。
        fpush();
        ST(0) = CONSTL2E;
        return;
    case 0x1eb: // FLDPI - 加载常数 Pi 到累加器 ST。
        fpush();
        ST(0) = CONSTPI;
        return;
    case 0x1ec: // FLDLG2 - 加载常数 Log10(2) 到累加器 ST。
        fpush();
        ST(0) = CONSTLG2;
        return;
    case 0x1ed: // FLDLN2 - 加载常数 Loge(2) 到累加器 ST。
        fpush();
        ST(0) = CONSTLN2;
        return;
    case 0x1ee: // FLDZ - 加载常数 0.0 到累加器 ST。
        fpush();
        ST(0) = CONSTZ;
        return;
    case 0x1ef: // 无效和未实现仿真指令代码。发信号，退出。
        math_abort(info, 1 << (SIGILL - 1));
    case 0x1f0:
    case 0x1f1:
    case 0x1f2:
    case 0x1f3:
    case 0x1f4:
    case 0x1f5:
    case 0x1f6:
    case 0x1f7:
    case 0x1f8:
    case 0x1f9:
    case 0x1fa:
    case 0x1fb:
    case 0x1fc:
    case 0x1fd:
    case 0x1fe:
    case 0x1ff:
        printk("%04x fxxx not implemented\n\r", code + 0xc800);
        math_abort(info, 1 << (SIGILL - 1));
    case 0x2e9: // FUCOMPP - 无次序比较。
        fucom(PST(1), PST(0));
        fpop();
        fpop();
        return;
    case 0x3d0:
    case 0x3d1: // FNOP - 对 387。!!应该是 0x3e0, 0x3e1。
        return;
    case 0x3e2: // FCLEX - 清状态字中异常标志。
        I387.swd &= 0x7f00;
        return;
    case 0x3e3: // FINIT - 初始化协处理器。
        I387.cwd = 0x037f;
        I387.swd = 0x0000;
        I387.twd = 0x0000;
        return;
    case 0x3e4: // FNOP - 对 80387。
        return;
    case 0x6d9: // FCOMPP - ST(1)与 ST 比较，出栈操作两次。
        fcom(PST(1), PST(0));
        fpop();
        fpop();
        return;
    case 0x7e0: // FSTSW AX - 保存当前状态字到 AX 寄存器中。
        *(short *)&EAX = I387.swd;
        return;
    }
    // 下面开始处理第 2 字节最后 3 比特是 REG 的指令。即 11011,XXXXXXXX,REG 形式的代码。
    switch (code >> 3)
    {
    case 0x18: // FADD ST, ST(i)。
        fadd(PST(0), PST(code & 7), &tmp);
        real_to_real(&tmp, &ST(0));
        return;
    case 0x19: // FMUL ST, ST(i)。
        fmul(PST(0), PST(code & 7), &tmp);
        real_to_real(&tmp, &ST(0));
        return;
    case 0x1a: // FCOM ST(i)。
        fcom(PST(code & 7), &tmp);
        real_to_real(&tmp, &ST(0));
        return;
    case 0x1b: // FCOMP ST(i)。
        fcom(PST(code & 7), &tmp);
        real_to_real(&tmp, &ST(0));
        fpop();
        return;
    case 0x1c: // FSUB ST, ST(i)。
        real_to_real(&ST(code & 7), &tmp);
        tmp.exponent ^= 0x8000;
        fadd(PST(0), &tmp, &tmp);
        real_to_real(&tmp, &ST(0));
        return;
    case 0x1d: // FSUBR ST, ST(i)。
        ST(0).exponent ^= 0x8000;
        fadd(PST(0), PST(code & 7), &tmp);
        real_to_real(&tmp, &ST(0));
        return;
    case 0x1e: // FDIV ST, ST(i)。
        fdiv(PST(0), PST(code & 7), &tmp);
        real_to_real(&tmp, &ST(0));
        return;
    case 0x1f: // FDIVR ST, ST(i)。
        fdiv(PST(code & 7), PST(0), &tmp);
        real_to_real(&tmp, &ST(0));
        return;
    case 0x38: // FLD ST(i)。
        fpush();
        ST(0) = ST((code & 7) + 1);
        return;
    case 0x39: // FXCH ST(i)。
        fxchg(&ST(0), &ST(code & 7));
        return;
    case 0x3b: // FSTP ST(i)。
        ST(code & 7) = ST(0);
        fpop();
        return;
    case 0x98: // FADD ST(i), ST。
        fadd(PST(0), PST(code & 7), &tmp);
        real_to_real(&tmp, &ST(code & 7));
        return;
    case 0x99: // FMUL ST(i), ST。
        fmul(PST(0), PST(code & 7), &tmp);
        real_to_real(&tmp, &ST(code & 7));
        return;
    case 0x9a: // FCOM ST(i)。
        fcom(PST(code & 7), PST(0));
        return;
    case 0x9b: // FCOMP ST(i)。
        fcom(PST(code & 7), PST(0));
        fpop();
        return;
    case 0x9c: // FSUBR ST(i), ST。
        ST(code & 7).exponent ^= 0x8000;
        fadd(PST(0), PST(code & 7), &tmp);
        real_to_real(&tmp, &ST(code & 7));
        return;
    case 0x9d: // FSUB ST(i), ST。
        real_to_real(&ST(0), &tmp);
        tmp.exponent ^= 0x8000;
        fadd(PST(code & 7), &tmp, &tmp);
        real_to_real(&tmp, &ST(code & 7));
        return;
    case 0x9e: // FDIVR ST(i), ST。
        fdiv(PST(0), PST(code & 7), &tmp);
        real_to_real(&tmp, &ST(code & 7));
        return;
    case 0x9f: // FDIV ST(i), ST。
        fdiv(PST(code & 7), PST(0), &tmp);
        real_to_real(&tmp, &ST(code & 7));
        return;
    case 0xb8: // FFREE ST(i)。未实现。
        printk("ffree not implemented\n\r");
        math_abort(info, 1 << (SIGILL - 1));
    case 0xb9: // FXCH ST(i)。
        fxchg(&ST(0), &ST(code & 7));
        return;
    case 0xba: // FST ST(i)。
        ST(code & 7) = ST(0);
        return;
    case 0xbb: // FSTP ST(i)。
        ST(code & 7) = ST(0);
        fpop();
        return;
    case 0xbc: // FUCOM ST(i)。
        fucom(PST(code & 7), PST(0));
        return;
    case 0xbd: // FUCOMP ST(i)。
        fucom(PST(code & 7), PST(0));
        fpop();
        return;
    case 0xd8: // FADDP ST(i), ST。
        fadd(PST(code & 7), PST(0), &tmp);
        real_to_real(&tmp, &ST(code & 7));
        fpop();
        return;
    case 0xd9: // FMULP ST(i), ST。
        fmul(PST(code & 7), PST(0), &tmp);
        real_to_real(&tmp, &ST(code & 7));
        fpop();
        return;
    case 0xda: // FCOMP ST(i)。
        fcom(PST(code & 7), PST(0));
        fpop();
        return;
    case 0xdc: // FSUBRP ST(i), ST。
        ST(code & 7).exponent ^= 0x8000;
        fadd(PST(0), PST(code & 7), &tmp);
        real_to_real(&tmp, &ST(code & 7));
        fpop();
        return;
    case 0xdd: // FSUBP ST(i), ST。
        real_to_real(&ST(0), &tmp);
        tmp.exponent ^= 0x8000;
        fadd(PST(code & 7), &tmp, &tmp);
        real_to_real(&tmp, &ST(code & 7));
        fpop();
        return;
    case 0xde: // FDIVRP ST(i), ST。
        fdiv(PST(0), PST(code & 7), &tmp);
        real_to_real(&tmp, &ST(code & 7));
        fpop();
        return;
    case 0xdf: // FDIVP ST(i), ST。
        fdiv(PST(code & 7), PST(0), &tmp);
        real_to_real(&tmp, &ST(code & 7));
        fpop();
        return;
    case 0xf8: // FFREE ST(i)。未实现。
        printk("ffree not implemented\n\r");
        math_abort(info, 1 << (SIGILL - 1));
        fpop();
        return;
    case 0xf9: // FXCH ST(i)。
        fxchg(&ST(0), &ST(code & 7));
        return;
    case 0xfa: // FSTP ST(i)。
    case 0xfb: // FSTP ST(i)。
        ST(code & 7) = ST(0);
        fpop();
        return;
    }
    // 处理第 2 个字节位 7--6 是 MOD、位 2--0 是 R/M 的指令，即 11011,XXX,MOD,XXX,R/M 形式的
    // 代码。MOD 在各子程序中处理，因此这里首先让代码与上 0xe7（0b11100111）屏蔽掉 MOD。
    switch ((code >> 3) & 0xe7)
    {
    case 0x22: // FST - 保存单精度实数（短实数）。
        put_short_real(PST(0), info, code);
        return;
    case 0x23: // FSTP - 保存单精度实数（短实数）。
        put_short_real(PST(0), info, code);
        fpop();
        return;
    case 0x24: // FLDENV - 加载协处理器状态和控制寄存器等。
        address = ea(info, code);
        for (code = 0; code < 7; code++)
        {
            ((long *)&I387)[code] =
                get_fs_long((unsigned long *)address);
            address += 4;
        }
        return;
    case 0x25: // FLDCW - 加载控制字。
        address = ea(info, code);
        *(unsigned short *)&I387.cwd =
            get_fs_word((unsigned short *)address);
        return;
    case 0x26: // FSTENV - 储存协处理器状态和控制寄存器等。
        address = ea(info, code);
        verify_area(address, 28);
        for (code = 0; code < 7; code++)
        {
            put_fs_long(((long *)&I387)[code],
                        (unsigned long *)address);
            address += 4;
        }
        return;
    case 0x27: // FSTCW - 储存控制字。
        address = ea(info, code);
        verify_area(address, 2);
        put_fs_word(I387.cwd, (short *)address);
        return;
    case 0x62: // FIST - 储存短整形数。
        put_long_int(PST(0), info, code);
        return;
    case 0x63: // FISTP - 储存短整形数。
        put_long_int(PST(0), info, code);
        fpop();
        return;
    case 0x65: // FLD - 加载扩展（临时）实数。
        fpush();
        get_temp_real(&tmp, info, code);
        real_to_real(&tmp, &ST(0));
        return;
    case 0x67: // FSTP - 储存扩展实数。
        put_temp_real(PST(0), info, code);
        fpop();
        return;
    case 0xa2: // FST - 储存双精度实数。
        put_long_real(PST(0), info, code);
        return;
    case 0xa3: // FSTP - 储存双精度实数。
        put_long_real(PST(0), info, code);
        fpop();
        return;
    case 0xa4: // FRSTOR - 恢复所有 108 字节的寄存器内容。
        address = ea(info, code);
        for (code = 0; code < 27; code++)
        {
            ((long *)&I387)[code] =
                get_fs_long((unsigned long *)address);
            address += 4;
        }
        return;
    case 0xa6: // FSAVE - 保存所有 108 字节寄存器内容。
        address = ea(info, code);
        verify_area(address, 108);
        for (code = 0; code < 27; code++)
        {
            put_fs_long(((long *)&I387)[code],
                        (unsigned long *)address);
            address += 4;
        }
        I387.cwd = 0x037f;
        I387.swd = 0x0000;
        I387.twd = 0x0000;
        return;
    case 0xa7: // FSTSW - 保存状态字。
        address = ea(info, code);
        verify_area(address, 2);
        put_fs_word(I387.swd, (short *)address);
        return;
    case 0xe2: // FIST - 保存短整型数。
        put_short_int(PST(0), info, code);
        return;
    case 0xe3: // FISTP - 保存短整型数。
        put_short_int(PST(0), info, code);
        fpop();
        return;
    case 0xe4: // FBLD - 加载 BCD 类型数。
        fpush();
        get_BCD(&tmp, info, code);
        real_to_real(&tmp, &ST(0));
        return;
    case 0xe5: // FILD - 加载长整型数。
        fpush();
        get_longlong_int(&tmp, info, code);
        real_to_real(&tmp, &ST(0));
        return;
    case 0xe6: // FBSTP - 保存 BCD 类型数。
        put_BCD(PST(0), info, code);
        fpop();
        return;
    case 0xe7: // BISTP - 保存长整型数。
        put_longlong_int(PST(0), info, code);
        fpop();
        return;
    }
    // 下面处理第 2 类浮点指令。首先根据指令代码的位 10--9 的 MF 值取指定类型的数，然后根据
    // OPA 和 OPB 的组合值进行分别处理。即处理 11011,MF,000,XXX,R/M 形式的指令代码。
    switch (code >> 9)
    {
    case 0: // MF = 00，短实数（32 位实数）。
        get_short_real(&tmp, info, code);
        break;
    case 1: // MF = 01，短整数（32 位整数）。
        get_long_int(&tmp, info, code);
        break;
    case 2: // MF = 10，长实数（64 位实数）。
        get_long_real(&tmp, info, code);
        break;
    case 4: // MF = 11，长整数（64 位整数）。！应是 case 3。
        get_short_int(&tmp, info, code);
    }
    // 处理浮点指令第 2 字节中的 OPB 代码。
    switch ((code >> 3) & 0x27)
    {
    case 0: // FADD。
        fadd(&tmp, PST(0), &tmp);
        real_to_real(&tmp, &ST(0));
        return;
    case 1: // FMUL。
        fmul(&tmp, PST(0), &tmp);
        real_to_real(&tmp, &ST(0));
        return;
    case 2: // FCOM。
        fcom(&tmp, PST(0));
        return;
    case 3: // FCOMP。
        fcom(&tmp, PST(0));
        fpop();
        return;
    case 4: // FSUB。
        tmp.exponent ^= 0x8000;
        fadd(&tmp, PST(0), &tmp);
        real_to_real(&tmp, &ST(0));
        return;
    case 5: // FSUBR。
        ST(0).exponent ^= 0x8000;
        fadd(&tmp, PST(0), &tmp);
        real_to_real(&tmp, &ST(0));
        return;
    case 6: // FDIV。
        fdiv(PST(0), &tmp, &tmp);
        real_to_real(&tmp, &ST(0));
        return;
    case 7: // FDIVR。
        fdiv(&tmp, PST(0), &tmp);
        real_to_real(&tmp, &ST(0));
        return;
    }
    // 处理形如 11011,XX,1,XX,000,R/M 的指令代码。
    if ((code & 0x138) == 0x100)
    { // FLD、FILD。
        fpush();
        real_to_real(&tmp, &ST(0));
        return;
    }
    // 其余均为无效指令。
    printk("Unknown math-insns: %04x:%08x %04x\n\r", CS, EIP, code);
    math_abort(info, 1 << (SIGFPE - 1));
}

// CPU 异常中断 int7 调用的 80387 仿真接口函数。
// 若当前进程没有使用过协处理器，就设置使用协处理器标志 used_math，然后初始化 80387
// 的控制字、状态字和特征字。最后使用中断 int7 调用本函数的返回地址指针作为参数调用
// 浮点指令仿真主函数 do_emu()。
// 参数 ___false 是 _orig_eip。
void math_emulate(long ___false)
{
    if (!current->used_math)
    {
        current->used_math = 1;
        I387.cwd = 0x037f;
        I387.swd = 0x0000;
        I387.twd = 0x0000;
    }
    /* &___false points to info->___orig_eip, so subtract 1 to get info */
    do_emu((struct info *)((&___false) - 1));
}

// 终止仿真操作。
// 当处理到无效指令代码或者未实现的指令代码时，该函数首先恢复程序的原 EIP，并发送指定
// 信号给当前进程。最后将栈指针指向中断 int7 处理过程调用本函数的返回地址，直接返回到
// 中断处理过程中。
void __math_abort(struct info *info, unsigned int signal)
{
    EIP = ORIG_EIP;
    current->signal |= signal;
    __asm__("movl %0,%%esp ; ret" ::"g"((long)info));
}

// 累加器栈弹出操作。
// 将状态字 TOP 字段值加 1，并以 7 取模。
static void fpop(void)
{
    unsigned long tmp;

    tmp = I387.swd & 0xffffc7ff;
    I387.swd += 0x00000800;
    I387.swd &= 0x00003800;
    I387.swd |= tmp;
}

// 累加器栈入栈操作。
// 将状态字 TOP 字段减 1（即加 7），并以 7 取模。
static void fpush(void)
{
    unsigned long tmp;

    tmp = I387.swd & 0xffffc7ff;
    I387.swd += 0x00003800;
    I387.swd &= 0x00003800;
    I387.swd |= tmp;
}

// 交换两个累加器寄存器的值。
static void fxchg(temp_real_unaligned *a, temp_real_unaligned *b)
{
    temp_real_unaligned c;

    c = *a;
    *a = *b;
    *b = c;
}

// 取 ST(i)的内存指针。
// 取状态字中 TOP 字段值。加上指定的物理数据寄存器号并取模，最后返回 ST(i)对应的指针。
static temp_real_unaligned *__st(int i)
{
    i += I387.swd >> 11; // 取状态字中 TOP 字段值。
    i &= 7;
    return (temp_real_unaligned *)(i * 10 + (char *)(I387.st_space));
}
