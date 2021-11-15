/*
 * 运行执行程序的系统调用函数。
 */

#define __LIBRARY__
#include <unistd.h> // Linux 标准头文件。定义了各种符号常数和类型，并声明了各种函数。如定义了__LIBRARY__，则还含系统调用号和内嵌汇编_syscall0()等。

// 加载并执行子进程(其他程序)函数。
// 下面该调用宏函数对应：int execve(const char * file, char ** argv, char ** envp)。
// 参数：file - 被执行程序文件名；argv - 命令行参数指针数组；envp - 环境变量指针数组。
// 直接调用了系统中断 int 0x80，参数是__NR_execve。参见 include/unistd.h 和 fs/exec.c 程序。
_syscall3(int, execve, const char *, file, char **, argv, char **, envp)
