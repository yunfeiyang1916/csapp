#include <linux/math_emu.h> // 协处理器头文件。定义临时实数结构和 387 寄存器操作宏等。

// 将指针 c 指向的 4 字节中内容左移 1 位。
static void
shift_left(int *c)
{
    __asm__ __volatile__("movl (%0),%%eax ; addl %%eax,(%0)\n\t"
                         "movl 4(%0),%%eax ; adcl %%eax,4(%0)\n\t"
                         "movl 8(%0),%%eax ; adcl %%eax,8(%0)\n\t"
                         "movl 12(%0),%%eax ; adcl %%eax,12(%0)" ::"r"((long)c)
                         : "ax");
}

// 将指针 c 指向的 4 字节中内容右移 1 位。
static void shift_right(int *c)
{
    __asm__("shrl $1,12(%0) ; rcrl $1,8(%0) ; rcrl $1,4(%0) ; rcrl $1,(%0)" ::"r"((long)c));
}

// 减法运算。
// 16 字节减法运算，a - b  a。最后根据是否有借位（CF=1）设置 ok。若无借位（CF=0）
// 则 ok = 1。否则 ok=0。
static int try_sub(int *a, int *b)
{
    char ok;

    __asm__ __volatile__("movl (%1),%%eax ; subl %%eax,(%2)\n\t"
                         "movl 4(%1),%%eax ; sbbl %%eax,4(%2)\n\t"
                         "movl 8(%1),%%eax ; sbbl %%eax,8(%2)\n\t"
                         "movl 12(%1),%%eax ; sbbl %%eax,12(%2)\n\t"
                         "setae %%al"
                         : "=a"(ok)
                         : "c"((long)a), "d"((long)b));
    return ok;
}

// 16 字节除法。
// 参数 a /b  c。利用减法模拟多字节除法。
static void div64(int *a, int *b, int *c)
{
    int tmp[4];
    int i;
    unsigned int mask = 0;

    c += 4;
    for (i = 0; i < 64; i++)
    {
        if (!(mask >>= 1))
        {
            c--;
            mask = 0x80000000;
        }
        tmp[0] = a[0];
        tmp[1] = a[1];
        tmp[2] = a[2];
        tmp[3] = a[3];
        if (try_sub(b, tmp))
        {
            *c |= mask;
            a[0] = tmp[0];
            a[1] = tmp[1];
            a[2] = tmp[2];
            a[3] = tmp[3];
        }
        shift_right(b);
    }
}

// 仿真浮点指令 FDIV。
void fdiv(const temp_real *src1, const temp_real *src2, temp_real *result)
{
    int i, sign;
    int a[4], b[4], tmp[4] = {0, 0, 0, 0};

    sign = (src1->exponent ^ src2->exponent) & 0x8000;
    if (!(src2->a || src2->b))
    {
        set_ZE();
        return;
    }
    i = (src1->exponent & 0x7fff) - (src2->exponent & 0x7fff) + 16383;
    if (i < 0)
    {
        set_UE();
        result->exponent = sign;
        result->a = result->b = 0;
        return;
    }
    a[0] = a[1] = 0;
    a[2] = src1->a;
    a[3] = src1->b;
    b[0] = b[1] = 0;
    b[2] = src2->a;
    b[3] = src2->b;
    while (b[3] >= 0)
    {
        i++;
        shift_left(b);
    }
    div64(a, b, tmp);
    if (tmp[0] || tmp[1] || tmp[2] || tmp[3])
    {
        while (i && tmp[3] >= 0)
        {
            i--;
            shift_left(tmp);
        }
        if (tmp[3] >= 0)
            set_DE();
    }
    else
        i = 0;
    if (i > 0x7fff)
    {
        set_OE();
        return;
    }
    if (tmp[0] || tmp[1])
        set_PE();
    result->exponent = i | sign;
    result->a = tmp[2];
    result->b = tmp[3];
}
