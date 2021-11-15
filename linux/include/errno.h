#ifndef _ERRNO_H
#define _ERRNO_H

/*
 * ok，由于我没有得到任何其他有关出错号的资料，我只能使用与 minix 系统相同的出错号了。
 * 希望这些是 POSIX 兼容的或者在一定程度上是这样的，我不知道（而且 POSIX没有告诉我 - 要获得他们的混蛋标准需要出钱）。
 *
 * 我们没有使用 minix 那样的_SIGN 簇，所以内核的返回值必须自己辨别正负号。
 *
 * 注意！如果你改变该文件的话，记着也要修改 strerror()函数。
 */

// 系统调用以及很多库函数返回一个特殊的值以表示操作失败或出错。这个值通常选择-1 或者
// 其他一些特定的值来表示。但是这个返回值仅说明错误发生了。 如果需要知道出错的类型，
// 就需要查看表示系统出错号的变量 errno。该变量即在 errno.h 文件中声明。在程序开始执
// 行时该变量值被初始化为 0。
extern int errno;

// 在出错时，系统调用会把出错号放在变量 errno 中（负值），然后返回-1。因此程序若需要知道具体错误号，就需要查看 errno 的值。
// 一般错误。
#define ERROR 99
// 操作没有许可。
#define EPERM 1
// 文件或目录不存在。
#define ENOENT 2
// 指定的进程不存在。
#define ESRCH 3
// 中断的系统调用。
#define EINTR 4
// 输入/输出错。
#define EIO 5
// 指定设备或地址不存在。
#define ENXIO 6
// 参数列表太长。
#define E2BIG 7
// 执行程序格式错误。
#define ENOEXEC 8
// 文件句柄(描述符)错误。
#define EBADF 9
// 子进程不存在。
#define ECHILD 10
// 资源暂时不可用。
#define EAGAIN 11
// 内存不足。
#define ENOMEM 12
// 没有许可权限。
#define EACCES 13
// 地址错。
#define EFAULT 14
// 不是块设备文件。
#define ENOTBLK 15
// 资源正忙。
#define EBUSY 16
// 文件已存在。
#define EEXIST 17
// 非法连接。
#define EXDEV 18
// 设备不存在。
#define ENODEV 19
// 不是目录文件。
#define ENOTDIR 20
// 是目录文件。
#define EISDIR 21
// 参数无效。
#define EINVAL 22
// 系统打开文件数太多。
#define ENFILE 23
// 打开文件数太多。
#define EMFILE 24
// 不恰当的 IO 控制操作(没有 tty 终端)。
#define ENOTTY 25
// 不再使用。
#define ETXTBSY 26
// 文件太大。
#define EFBIG 27
// 设备已满（设备已经没有空间）。
#define ENOSPC 28
// 无效的文件指针重定位。
#define ESPIPE 29
// 文件系统只读。
#define EROFS 30
// 连接太多。
#define EMLINK 31
// 管道错。
#define EPIPE 32
// 域(domain)出错。
#define EDOM 33
// 结果太大。
#define ERANGE 34
// 避免资源死锁。
#define EDEADLK 35
// 文件名太长。
#define ENAMETOOLONG 36
// 没有锁定可用。
#define ENOLCK 37
// 功能还没有实现。
#define ENOSYS 38
// 目录不空。
#define ENOTEMPTY 39

/* 用户程序不应该见到下面这两中错误号 */
#define ERESTARTSYS 512    // 重新执行系统调用。
#define ERESTARTNOINTR 513 // 重新执行系统调用，无中断。

#endif
