#include <linux/math_emu.h> // 协处理器头文件。定义临时实数结构和 387 寄存器操作宏等。

/*
 * 注意!!! 在 temp_to_long 和 temp_to_short 数据类型转换子程序中有些“不明显”
 * 的优化处理：如果不理解就不要随意修改。它们是舍入操作中的加 1：溢出位也同
 * 样被用于向指数中加 1。因此看上去溢出好像没有被正确地处理，但是由于 IEEE
 * 浮点数标准所规定数据格式的操作方式，这些做法是正确的。
 *
 * 不过这里没有对转换过程中总体溢出作检测（也即临时实数是否能够简单地放入短
 * 实数或长实数格式中）。
 */

// 短实数转换成临时实数格式。
// 短实数长度是 32 位，其有效数（尾数）长度是 23 位，指数是 8 位，还有 1 个符号位。
void short_to_temp(const short_real *a, temp_real *b)
{
    // 首先处理被转换的短实数是 0 的情况。若为 0，则设置对应临时实数 b 的有效数为 0。然后根
    // 据短实数符号位设置临时实数的符号位，即 exponent 的最高有效位。
    if (!(*a & 0x7fffffff))
    {
        b->a = b->b = 0; // 置临时实数的有效数 = 0。
        if (*a)
            b->exponent = 0x8000; // 设置符号位。
        else
            b->exponent = 0;
        return;
    }
    // 对于一般短实数，先确定对应临时实数的指数值。这里需要用到整型数偏置表示方法的概念。
    // 短实数指数的偏置量是 127，而临时实数指数的偏置量是 16383。因此在取出短实数中指数值
    // 后需要变更其中的偏置量为 16383。 此时就形成了临时实数格式的指数值 exponent。另外，
    // 如果短实数是负数，则需要设置临时实数的符号位（位 79）。下一步设置尾数值。方法是把
    // 短实数左移 8 位，让 23 位尾数最高有效位处于临时实数的位 62 处。而临时实数尾数的位 63
    // 处需要恒置一个 1，即需要或上 0x80000000。最后清掉临时实数低 32 位有效数。
    b->exponent = ((*a >> 23) & 0xff) - 127 + 16383; // 取出短实数指数位，更换偏置量。
    if (*a < 0)
        b->exponent |= 0x8000;     // 若为负数则设置符号位。
    b->b = (*a << 8) | 0x80000000; // 放置尾数，添加固定 1 值。
    b->a = 0;
}

// 长实数转换成临时实数格式。
// 方法与 short_to_temp()完全一样。不过长实数指数偏置量是 1023。
void long_to_temp(const long_real *a, temp_real *b)
{
    if (!a->a && !(a->b & 0x7fffffff))
    {
        b->a = b->b = 0; // 置临时实数的有效数 = 0。
        if (a->b)
            b->exponent = 0x8000; // 设置符号位。
        else
            b->exponent = 0;
        return;
    }
    b->exponent = ((a->b >> 20) & 0x7ff) - 1023 + 16383; // 取长实数指数，更换偏置量。
    if (a->b < 0)
        b->exponent |= 0x8000;                                        // 若为负数则设置符号位。
    b->b = 0x80000000 | (a->b << 11) | (((unsigned long)a->a) >> 21); // 放置尾数，添 1。
    b->a = a->a << 11;
}

// 临时实数转换成短实数格式。
// 过程与 short_to_temp()相反，但需要处理精度和舍入问题。
void temp_to_short(const temp_real *a, short_real *b)
{
    // 如果指数部分为 0，则根据有无符号位设置短实数为-0 或 0。
    if (!(a->exponent & 0x7fff))
    {
        *b = (a->exponent) ? 0x80000000 : 0;
        return;
    }
    // 先处理指数部分。即更换临时实数指数偏置量（16383）为短实数的偏置量 127。
    *b = ((((long)a->exponent) - 16383 + 127) << 23) & 0x7f800000;
    if (a->exponent < 0) // 若是负数则设置符号位。
        *b |= 0x80000000;
    *b |= (a->b >> 8) & 0x007fffff; // 取临时实数有效数高 23 位。
    // 根据控制字中的舍入设置执行舍入操作。
    switch (ROUNDING)
    {
    case ROUND_NEAREST:
        if ((a->b & 0xff) > 0x80)
            ++*b;
        break;
    case ROUND_DOWN:
        if ((a->exponent & 0x8000) && (a->b & 0xff))
            ++*b;
        break;
    case ROUND_UP:
        if (!(a->exponent & 0x8000) && (a->b & 0xff))
            ++*b;
        break;
    }
}

// 临时实数转换成长实数。
void temp_to_long(const temp_real *a, long_real *b)
{
    if (!(a->exponent & 0x7fff))
    {
        b->a = 0;
        b->b = (a->exponent) ? 0x80000000 : 0;
        return;
    }
    b->b = (((0x7fff & (long)a->exponent) - 16383 + 1023) << 20) & 0x7ff00000;
    if (a->exponent < 0)
        b->b |= 0x80000000;
    b->b |= (a->b >> 11) & 0x000fffff;
    b->a = a->b << 21;
    b->a |= (a->a >> 11) & 0x001fffff;
    switch (ROUNDING)
    {
    case ROUND_NEAREST:
        if ((a->a & 0x7ff) > 0x400)
            __asm__("addl $1,%0 ; adcl $0,%1"
                    : "=r"(b->a), "=r"(b->b)
                    : ""(b->a), "1"(b->b));
        break;
    case ROUND_DOWN:
        if ((a->exponent & 0x8000) && (a->b & 0xff))
            __asm__("addl $1,%0 ; adcl $0,%1"
                    : "=r"(b->a), "=r"(b->b)
                    : ""(b->a), "1"(b->b));
        break;
    case ROUND_UP:
        if (!(a->exponent & 0x8000) && (a->b & 0xff))
            __asm__("addl $1,%0 ; adcl $0,%1"
                    : "=r"(b->a), "=r"(b->b)
                    : ""(b->a), "1"(b->b));
        break;
    }
}

// 临时实数转换成临时整数格式。
// 临时整数也用 10 字节表示。其中低 8 字节是无符号整数值，高 2 字节表示指数值和符号位。
// 如果高 2 字节最高有效位为 1，则表示是负数；若位 0，表示是正数。
void real_to_int(const temp_real *a, temp_int *b)
{
    int shift = 16383 + 63 - (a->exponent & 0x7fff);
    unsigned long underflow;

    b->a = b->b = underflow = 0;
    b->sign = (a->exponent < 0);
    if (shift < 0)
    {
        set_OE();
        return;
    }
    if (shift < 32)
    {
        b->b = a->b;
        b->a = a->a;
    }
    else if (shift < 64)
    {
        b->a = a->b;
        underflow = a->a;
        shift -= 32;
    }
    else if (shift < 96)
    {
        underflow = a->b;
        shift -= 64;
    }
    else
        return;
    __asm__("shrdl %2,%1,%0"
            : "=r"(underflow), "=r"(b->a)
            : "c"((char)shift), ""(underflow), "1"(b->a));
    __asm__("shrdl %2,%1,%0"
            : "=r"(b->a), "=r"(b->b)
            : "c"((char)shift), ""(b->a), "1"(b->b));
    __asm__("shrl %1,%0"
            : "=r"(b->b)
            : "c"((char)shift), ""(b->b));
    switch (ROUNDING)
    {
    case ROUND_NEAREST:
        __asm__("addl %4,%5 ; adcl $0,%0 ; adcl $0,%1"
                : "=r"(b->a), "=r"(b->b)
                : ""(b->a), "1"(b->b), "r"(0x7fffffff + (b->a & 1)), "m"(*&underflow));
        break;
    case ROUND_UP:
        if (!b->sign && underflow)
            __asm__("addl $1,%0 ; adcl $0,%1"
                    : "=r"(b->a), "=r"(b->b)
                    : ""(b->a), "1"(b->b));
        break;
    case ROUND_DOWN:
        if (b->sign && underflow)
            __asm__("addl $1,%0 ; adcl $0,%1"
                    : "=r"(b->a), "=r"(b->b)
                    : ""(b->a), "1"(b->b));
        break;
    }
}

// 临时整数转换成临时实数格式。
void int_to_real(const temp_int *a, temp_real *b)
{
    // 由于原值是整数，所以转换成临时实数时指数除了需要加上偏置量 16383 外，还要加上 63。
    // 表示有效数要乘上 2 的 63 次方，即都是整数值。
    b->a = a->a;
    b->b = a->b;
    if (b->a || b->b)
        b->exponent = 16383 + 63 + (a->sign ? 0x8000 : 0);
    else
    {
        b->exponent = 0;
        return;
    }
    // 对格式转换后的临时实数进行规格化处理，即让有效数最高有效位不是 0。
    while (b->b >= 0)
    {
        b->exponent--;
        __asm__("addl %0,%0 ; adcl %1,%1"
                : "=r"(b->a), "=r"(b->b)
                : ""(b->a), "1"(b->b));
    }
}
