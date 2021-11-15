/*
 * 累加器中临时实数比较子程序。
 */

#include <linux/math_emu.h> // 协处理器头文件。定义临时实数结构和 387 寄存器操作宏等。

// 复位状态字中的 C3、C2、C1 和 C0 条件位。
#define clear_Cx() (I387.swd &= ~0x4500)

// 对临时实数 a 进行规格化处理。即表示成指数、有效数形式。
// 例如：102.345 表示成 1.02345 X 102。 0.0001234 表示成 1.234 X 10-4。当然，函数中是
// 二进制表示。
static void normalize(temp_real *a)
{
    int i = a->exponent & 0x7fff;    // 取指数值（略去符号位）。
    int sign = a->exponent & 0x8000; // 取符号位。

    // 如果临时实数 a 的 64 位有效数（尾数）为 0，那么说明 a 等于 0。于是清 a 的指数，并返回。
    if (!(a->a || a->b))
    {
        a->exponent = 0;
        return;
    }
    // 如果 a 的尾数最左端有 0 值比特位，那么将尾数左移，同时调整指数值（递减）。直到尾数
    // 的 b 字段最高有效位 MSB 是 1 位置（此时 b 表现为负值）。最后再添加上符号位。
    while (i && a->b >= 0)
    {
        i--;
        __asm__("addl %0,%0 ; adcl %1,%1"
                : "=r"(a->a), "=r"(a->b)
                : ""(a->a), "1"(a->b));
    }
    a->exponent = i | sign;
}

// 仿真浮点指令 FTST。
// 即栈定累加器 ST(0)与 0 比较，并根据比较结果设置条件位。若 ST > 0.0，则 C3，C2，C0
// 分别为 000；若 ST < 0.0，则条件位为 001；若 ST == 0.0，则条件位是 100；若不可比较，
// 则条件位为 111。
void ftst(const temp_real *a)
{
    temp_real b;

    // 首先清状态字中条件标志位，并对比较值 b（ST）进行规格化处理。若 b 不等于零并且设置
    // 了符号位（是负数），则设置条件位 C0。否则设置条件位 C3。
    clear_Cx();
    b = *a;
    normalize(&b);
    if (b.a || b.b || b.exponent)
    {
        if (b.exponent < 0)
            set_C0();
    }
    else
        set_C3();
}

// 仿真浮点指令 FCOM。
// 比较两个参数 src1、src2。并根据比较结果设置条件位。若 src1 > src2，则 C3，C2，C0
// 分别为 000；若 src1 < src2，则条件位为 001；若两者相等，则条件位是 100。
void fcom(const temp_real *src1, const temp_real *src2)
{
    temp_real a;

    a = *src1;
    a.exponent ^= 0x8000; // 符号位取反。
    fadd(&a, src2, &a);   // 两者相加（即相减）。
    ftst(&a);             // 测试结果并设置条件位。
}

// 仿真浮点指令 FUCOM（无次序比较）。
// 用于操作数之一是 NaN 的比较。
void fucom(const temp_real *src1, const temp_real *src2)
{
    fcom(src1, src2);
}
