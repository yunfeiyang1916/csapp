#ifndef _SIGNAL_H
#define _SIGNAL_H

#include <sys/types.h> // 类型头文件。定义了基本的系统数据类型。
// 定义信号原子操作类型
typedef int sig_atomic_t;
// 定义信号集类型
typedef unsigned int sigset_t;

#define _NSIG 32   // 定义信号种类 -- 32 种
#define NSIG _NSIG // NSIG = _NSIG

// 以下这些是 Linux 0.12 内核中定义的信号。其中包括了 POSIX.1 要求的所有 20 个信号
// Hang Up -- 挂断控制终端或进程
#define SIGHUP 1
// Interrupt -- 来自键盘的中断
#define SIGINT 2
// Quit -- 来自键盘的退出
#define SIGQUIT 3
// Illeagle -- 非法指令
#define SIGILL 4
// Trap -- 跟踪断点
#define SIGTRAP 5
// Abort -- 异常结束
#define SIGABRT 6
// IO Trap -- 同上
#define SIGIOT 6
// Unused -- 没有使用
#define SIGUNUSED 7
// FPE -- 协处理器出错
#define SIGFPE 8
// Kill -- 强迫进程终止
#define SIGKILL 9
// User1 -- 用户信号 1，进程可使用
#define SIGUSR1 10
// Segment Violation -- 无效内存引用
#define SIGSEGV 11
// User2 -- 用户信号 2，进程可使用
#define SIGUSR2 12
// Pipe -- 管道写出错，无读者
#define SIGPIPE 13
// Alarm -- 实时定时器报警
#define SIGALRM 14
// Terminate -- 进程终止
#define SIGTERM 15
// Stack Fault -- 栈出错（协处理器）
#define SIGSTKFLT 16
// Child -- 子进程停止或被终止
#define SIGCHLD 17
// Continue -- 恢复进程继续执行
#define SIGCONT 18
// Stop -- 停止进程的执行
#define SIGSTOP 19
// TTY Stop -- tty 发出停止进程，可忽略
#define SIGTSTP 20
// TTY In -- 后台进程请求输入
#define SIGTTIN 21
// TTY Out -- 后台进程请求输出
#define SIGTTOU 22

/* OK，我还没有实现 sigactions 的编制，但在头文件中仍希望遵守 POSIX 标准 */
// 上面原注释已经过时，因为在 0.12 内核中已经实现了 sigaction()。下面是 sigaction 结构
// sa_flags 标志字段可取的符号常数值。
// 当子进程处于停止状态，就不对 SIGCHLD 处理
#define SA_NOCLDSTOP 1
// 系统调用被信号中断后不重新启动系统调用
#define SA_INTERRUPT 0x20000000
// 不阻止在指定的信号处理程序中再收到该信号
#define SA_NOMASK 0x40000000
// 信号句柄一旦被调用过就恢复到默认处理句柄
#define SA_ONESHOT 0x80000000

// 以下常量用于 sigprocmask(how, )-- 改变阻塞信号集(屏蔽码)。用于改变该函数的行为。
// 在阻塞信号集中加上给定信号
#define SIG_BLOCK 0
// 从阻塞信号集中删除指定信号
#define SIG_UNBLOCK 1
// 设置阻塞信号集
#define SIG_SETMASK 2

// 以下两个常数符号都表示指向无返回值的函数指针，且都有一个 int 整型参数。这两个指针
// 值是逻辑上讲实际上不可能出现的函数地址值。可作为下面 signal 函数的第二个参数。用
// 于告知内核，让内核处理信号或忽略对信号的处理。使用方法参见 kernel/signal.c 程序，第 94--96 行。
// 默认信号处理程序（信号句柄）
#define SIG_DFL ((void (*)(int))0)
// 忽略信号的处理程序
#define SIG_IGN ((void (*)(int))1)
// 信号处理返回错误
#define SIG_ERR ((void (*)(int)) - 1)

// 下面定义初始操作设置 sigaction 结构信号屏蔽码的宏。
#ifdef notdef
#define sigemptyset(mask) ((*(mask) = 0), 1) // 将 mask 清零。
#define sigfillset(mask) ((*(mask) = ~0), 1) // 将 mask 所有比特位置位。
#endif

// sigaction 的数据结构。另外，引起触发信号处理的信号也将被阻塞，除非使用了 SA_NOMASK 标志。
struct sigaction
{
    // 信号处理句柄。可以用上面的 SIG_DFL，或 SIG_IGN 来忽略该信号，也可以是指向处理该信号函数的一个指针。
    void (*sa_handler)(int);
    // 信号的屏蔽码，可以阻塞指定的信号集。
    sigset_t sa_mask;
    // 信号选项标志。
    int sa_flags;
    // 信号恢复函数指针（系统内部使用）。
    void (*sa_restorer)(void);
};

// 下面 signal 函数用于是为信号_sig 安装一新的信号处理程序（信号句柄），与 sigaction()类似。
// 该函数含有两个参数：指定需要捕获的信号_sig；具有一个参数且无返回值的函数指针_func。
// 该函数返回值也是具有一个 int 参数（最后一个(int)）且无返回值的函数指针，它是处理该信号的原处理句柄。
void (*signal(int _sig, void (*_func)(int)))(int);
// 下面两函数用于发送信号。kill() 用于向任何进程或进程组发送信号。raise()用于向当前进
// 程自身发送信号。其作用等价于 kill(getpid(),sig)。参见 kernel/exit.c，60 行。
int raise(int sig);
int kill(pid_t pid, int sig);
// 在进程的任务结构中，除有一个以比特位表示当前进程待处理的 32 位信号字段 signal 以外，
// 还有一个同样以比特位表示的用于屏蔽进程当前阻塞信号集（屏蔽信号集）的字段 blocked，
// 也是 32 位，每个比特代表一个对应的阻塞信号。修改进程的屏蔽信号集可以阻塞或解除阻塞
// 所指定的信号。 以下五个函数就是用于操作进程屏蔽信号集，虽然简单实现起来很简单，但
// 本版本内核中还未实现。
// 函数 sigaddset() 和 sigdelset() 用于对信号集中的信号进行增、删修改。 sigaddset()用
// 于向 mask 指向的信号集中增加指定的信号 signo。sigdelset 则反之。函数 sigemptyset()和
// sigfillset() 用于初始化进程屏蔽信号集。 每个程序在使用信号集前，都需要使用这两个函
// 数之一对屏蔽信号集进行初始化。 sigemptyset()用于清空屏蔽的所有信号，也即响应所有的
// 信号。sigfillset()向信号集中置入所有信号，也即屏蔽所有信号。当然 SIGINT 和 SIGSTOP
// 是不能被屏蔽的。
// sigismember()用于测试一个指定信号是否在信号集中（1 - 是，0 - 不是，-1 - 出错）。
int sigaddset(sigset_t *mask, int signo);
int sigdelset(sigset_t *mask, int signo);
int sigemptyset(sigset_t *mask);
int sigfillset(sigset_t *mask);
int sigismember(sigset_t *mask, int signo); /* 1 - is, 0 - not, -1 error */
// 对 set 中的信号进行检测，看是否有挂起的信号。在 set 中返回进程中当前被阻塞的信号集。
int sigpending(sigset_t *set);
// 下面函数用于改变进程目前被阻塞的信号集（信号屏蔽码）。若 oldset 不是 NULL，则通过其
// 返回进程当前屏蔽信号集。若 set 指针不是 NULL，则根据 how（41-43 行）指示修改进程屏蔽
// 信号集。
int sigprocmask(int how, sigset_t *set, sigset_t *oldset);
// 下面函数用 sigmask 临时替换进程的信号屏蔽码,然后暂停该进程直到收到一个信号。若捕捉
// 到某一信号并从该信号处理程序中返回，则该函数也返回，并且信号屏蔽码会恢复到调用调用
// 前的值。
int sigsuspend(sigset_t *sigmask);
// sigaction() 函数用于改变进程在收到指定信号时所采取的行动，即改变信号的处理句柄能。
// 参见对 kernel/signal.c 程序的说明。
int sigaction(int sig, struct sigaction *act, struct sigaction *oldact);

#endif /* _SIGNAL_H */