#include <signal.h> // 信号头文件。定义信号符号常量，信号结构及信号操作函数原型。

#include <linux/sched.h> // 调度程序头文件，定义任务结构 task_struct、任务 0 数据等。

// 协处理器错误中断 int16 调用的处理函数。
// 当协处理器检测到自己发生错误时，就会通过 ERROR 引脚通知 CPU。下面代码用于处理协处理
// 器发出的出错信号。并跳转去执行 math_error()。返回后将跳转到标号 ret_from_sys_call
// 处继续执行。
void math_error(void)
{
    __asm__("fnclex");       // 让 80387 清除状态字中所有异常标志位和忙位。
    if (last_task_used_math) // 若使用了协处理器，则设置协处理器出错信号。
        last_task_used_math->signal |= 1 << (SIGFPE - 1);
}
