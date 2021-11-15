/*
 * printk()是内核中使用的打印（显示）函数，功能与 C 标准函数库中的 printf()相同。
 */
/*
 * 当处于内核模式时，我们不能使用 printf，因为寄存器 fs 指向其他不感兴趣
 * 的地方。自己编制一个 printf 并在使用前保存 fs，一切就解决了。
 */
// 标准参数头文件。以宏的形式定义变量参数列表。主要说明了-个类型(va_list)和三个宏
// va_start、va_arg 和 va_end，用于 vsprintf、vprintf、vfprintf 函数。
#include <stdarg.h>
#include <stddef.h> // 标准定义头文件。定义了 NULL, offsetof(TYPE, MEMBER)。

#include <linux/kernel.h> // 内核头文件。含有一些内核常用函数的原形定义。

static char buf[1024]; // 显示用临时缓冲区。

// 函数 vsprintf()定义在 linux/kernel/vsprintf.c 中 92 行开始处。
extern int vsprintf(char *buf, const char *fmt, va_list args);

// 内核使用的显示函数。
int printk(const char *fmt, ...)
{
    va_list args; // va_list 实际上是一个字符指针类型。
    int i;

    // 运行参数处理开始函数。然后使用格式串 fmt 将参数列表 args 输出到 buf 中。返回值 i
    // 等于输出字符串的长度。再运行参数处理结束函数。最后调用控制台显示函数并返回显示
    // 字符数。
    va_start(args, fmt);
    i = vsprintf(buf, fmt, args);
    va_end(args);
    console_print(buf); // chr_drv/console.c，第 995 行开始。
    return i;
}
