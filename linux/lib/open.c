/*
 * 该 open.c 文件中的 open()库函数用于打开一个指定文件名的文件。当函数调用成功时，会返回该文 件的文件描述符。
 * 该调用创建一个新的打开文件，并不与任何其他进程共享。在执行 exec 函数时，该新的文件描述符将始终保持着打开状态。
 * 文件的读写指针被设置在文件开始位置。
 */

#define __LIBRARY__
#include <unistd.h> // Linux 标准头文件。定义了各种符号常数和类型，并声明了各种函数。如定义了__LIBRARY__，则还含系统调用号和内嵌汇编_syscall0()等。

// 标准参数头文件。以宏的形式定义变量参数列表。主要说明了一个
// 类型(va_list)和三个宏(va_start, va_arg 和 va_end)，用于
// vsprintf、vprintf、vfprintf 函数。
#include <stdarg.h>

// 打开文件函数。
// 打开并有可能创建一个文件。
// 参数：filename - 文件名；flag - 文件打开标志；...
// 返回：文件描述符，若出错则置出错码，并返回-1。
// 第 13 行定义了一个寄存器变量 res，该变量将被保存在一个寄存器中，以便于高效访问和操作。
// 若想指定存放的寄存器（例如 eax），那么可以把该句写成“register int res asm("ax");”。
int open(const char *filename, int flag, ...)
{
    register int res;
    va_list arg;

    // 利用 va_start()宏函数，取得 flag 后面参数的指针，然后调用系统中断 int 0x80，功能 open 进行
    // 文件打开操作。
    // %0 - eax(返回的描述符或出错码)；%1 - eax(系统中断调用功能号__NR_open)；
    // %2 - ebx(文件名 filename)；%3 - ecx(打开文件标志 flag)；%4 - edx(后随参数文件属性 mode)。
    va_start(arg, flag);
    __asm__("int $0x80"
            : "=a"(res)
            : ""(__NR_open), "b"(filename), "c"(flag),
              "d"(va_arg(arg, int)));
    // 系统中断调用返回值大于或等于 0，表示是一个文件描述符，则直接返回之。
    if (res >= 0)
        return res;
    // 否则说明返回值小于 0，则代表一个出错码。设置该出错码并返回-1。
    errno = -res;
    return -1;
}
