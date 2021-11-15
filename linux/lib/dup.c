/*
 * 该程序包括一个创建文件描述符拷贝的函数 dup()。
 * 在成功返回之后，新的和原来的描述符可以交替使用。它们共享锁定、文件读写指针以及文件标志。
 */

#define __LIBRARY__
#include <unistd.h> // Linux 标准头文件。定义了各种符号常数和类型，并声明了各种函数。如定义了__LIBRARY__，则还含系统调用号和内嵌汇编_syscall0()等。

// 复制文件描述符函数。
// 下面该调用宏函数对应：int dup(int fd)。直接调用了系统中断 int 0x80，参数是__NR_dup。
// 其中 fd 是文件描述符。
_syscall1(int, dup, int, fd)
