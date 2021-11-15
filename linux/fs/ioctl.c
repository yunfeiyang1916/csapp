/*
 * ioctl.c 文件实现了输入/输出控制系统调用 ioctl()。ioctl()函数可以看作是各个具体设备驱动程序 ioctl函数的接口函数。
 */

#include <string.h>   // 字符串头文件。主要定义了一些有关字符串操作的嵌入函数。
#include <errno.h>    // 错误号头文件。包含系统中各种出错号。
#include <sys/stat.h> // 文件状态头文件。含有文件状态结构 stat{}和常量。

#include <linux/sched.h> // 调度程序头文件，定义了任务结构 task_struct、任务 0 数据等。

extern int tty_ioctl(int dev, int cmd, int arg);               // chr_drv/tty_ioctl.c，第 133 行。
extern int pipe_ioctl(struct m_inode *pino, int cmd, int arg); // fs/pipe.c，第 118 行。

// 定义输入输出控制(ioctl)函数指针类型。
typedef int (*ioctl_ptr)(int dev, int cmd, int arg);

// 取系统中设备种数的宏。
#define NRDEVS ((sizeof(ioctl_table)) / (sizeof(ioctl_ptr)))

// ioctl 操作函数指针表。
static ioctl_ptr ioctl_table[] = {
    NULL,      /* nodev */
    NULL,      /* /dev/mem */
    NULL,      /* /dev/fd */
    NULL,      /* /dev/hd */
    tty_ioctl, /* /dev/ttyx */
    tty_ioctl, /* /dev/tty */
    NULL,      /* /dev/lp */
    NULL};     /* named pipes */

//// 系统调用函数 - 输入输出控制函数。
// 该函数首先判断参数给出的文件描述符是否有效。然后根据对应 i 节点中文件属性判断文件
// 类型，并根据具体文件类型调用相关的处理函数。
// 参数：fd - 文件描述符；cmd - 命令码；arg - 参数。
// 返回：成功则返回 0，否则返回出错码。
int sys_ioctl(unsigned int fd, unsigned int cmd, unsigned long arg)
{
    struct file *filp;
    int dev, mode;

    // 首先判断给出的文件描述符的有效性。如果文件描述符超出可打开的文件数，或者对应描述
    // 符的文件结构指针为空，则返回出错码退出。
    if (fd >= NR_OPEN || !(filp = current->filp[fd]))
        return -EBADF;
    // 如果文件结构对应的是管道 i 节点，则根据进程是否有权操作该管道确定是否执行管道 IO
    // 控制操作。若有权执行则调用 pipe_ioctl()，否则返回无效文件错误码。
    if (filp->f_inode->i_pipe)
        return (filp->f_mode & 1) ? pipe_ioctl(filp->f_inode, cmd, arg) : -EBADF;
    // 对于其他类型文件，取对应文件的属性，并据此判断文件的类型。如果该文件既不是字符设
    // 备文件，也不是块设备文件，则返回出错码退出。若是字符或块设备文件，则从文件的 i 节
    // 点中取设备号。如果设备号大于系统现有的设备数，则返回出错号。
    mode = filp->f_inode->i_mode;
    if (!S_ISCHR(mode) && !S_ISBLK(mode))
        return -EINVAL;
    dev = filp->f_inode->i_zone[0];
    if (MAJOR(dev) >= NRDEVS)
        return -ENODEV;
    // 然后根据 IO 控制表 ioctl_table 查得对应设备的 ioctl 函数指针，并调用该函数。如果该设
    // 备在 ioctl 函数指针表中没有对应函数，则返回出错码。
    if (!ioctl_table[MAJOR(dev)])
        return -ENOTTY;
    return ioctl_table[MAJOR(dev)](dev, cmd, arg);
}
