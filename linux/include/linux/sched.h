/*
 * sched.h 是调度程序头文件，其中定义了任务结构 task_struct、初始任务 0 的数据，
 * 还有一些有关描述符参数设置和获取以及任务上下文切换 switch_to()的嵌入式汇编函数宏。
 */

#ifndef _SCHED_H
#define _SCHED_H

#define HZ 100 // 定义系统时钟滴答频率(1 百赫兹，每个滴答 10ms)

#define NR_TASKS 64             // 系统中同时最多任务（进程）数。
#define TASK_SIZE 0x04000000    // 每个任务的长度（64MB）。
#define LIBRARY_SIZE 0x00400000 // 动态加载库长度（4MB）。

#if (TASK_SIZE & 0x3fffff)
#error "TASK_SIZE must be multiple of 4M" // 任务长度必须是 4MB 的倍数。
#endif

#if (LIBRARY_SIZE & 0x3fffff)
#error "LIBRARY_SIZE must be a multiple of 4M" // 库长度也必须是 4MB 的倍数。
#endif

#if (LIBRARY_SIZE >= (TASK_SIZE / 2))
#error "LIBRARY_SIZE too damn big!" // 加载库的长度不得大于任务长度的一半。
#endif

#if (((TASK_SIZE >> 16) * NR_TASKS) != 0x10000)
#error "TASK_SIZE*NR_TASKS must be 4GB" // 任务长度*任务总个数必须为 4GB。
#endif

// 在进程逻辑地址空间中动态库被加载的位置（60MB 处）。
#define LIBRARY_OFFSET (TASK_SIZE - LIBRARY_SIZE)

// 下面宏 CT_TO_SECS 和 CT_TO_USECS 用于把系统当前嘀嗒数转换成用秒值加微秒值表示。
#define CT_TO_SECS(x) ((x) / HZ)
#define CT_TO_USECS(x) (((x) % HZ) * 1000000 / HZ)

#define FIRST_TASK task[0]           // 任务 0 比较特殊，所以特意给它单独定义一个符号。
#define LAST_TASK task[NR_TASKS - 1] // 任务数组中的最后一项任务。

#include <linux/head.h>
#include <linux/fs.h>
#include <linux/mm.h>
#include <sys/param.h>
#include <sys/time.h>
#include <sys/resource.h>
#include <signal.h>

#if (NR_OPEN > 32)
#error "Currently the close-on-exec-flags and select masks are in one long, max 32 files/proc"
#endif

// 这里定义了进程运行时可能处的状态。
// 进程正在运行或已准备就绪
#define TASK_RUNNING 0
// 进程处于可中断等待状态
#define TASK_INTERRUPTIBLE 1
// 进程处于不可中断等待状态，主要用于 I/O 操作等待
#define TASK_UNINTERRUPTIBLE 2
// 进程处于僵死状态，已经停止运行，但父进程还没发信号
#define TASK_ZOMBIE 3
// 进程已停止
#define TASK_STOPPED 4

#ifndef NULL
#define NULL ((void *)0) // 定义 NULL 为空指针。
#endif

// 复制进程的页目录页表。Linus 认为这是内核中最复杂的函数之一。( mm/memory.c, 105 )
extern int copy_page_tables(unsigned long from, unsigned long to, long size);
// 释放页表所指定的内存块及页表本身。( mm/memory.c, 150 )
extern int free_page_tables(unsigned long from, unsigned long size);

// 调度程序的初始化函数。( kernel/sched.c, 385 )
extern void sched_init(void);
// 进程调度函数。( kernel/sched.c, 104 )
extern void schedule(void);
// 异常(陷阱)中断处理初始化函数，设置中断调用门并允许中断请求信号。( kernel/traps.c, 181 )
extern void trap_init(void);
// 显示内核出错信息，然后进入死循环。( kernel/panic.c, 16 )。
extern void panic(const char *str);
// 往 tty 上写指定长度的字符串。( kernel/chr_drv/tty_io.c, 290 )。
extern int tty_write(unsigned minor, char *buf, int count);
// 定义函数指针类型
typedef int (*fn_ptr)();

// 下面是数学协处理器使用的结构，主要用于保存进程切换时 i387 的执行状态信息。
struct i387_struct
{
    // 控制字(Control word)
    long cwd;
    // 状态字(Status word)
    long swd;
    // 标记字(Tag word)
    long twd;
    // 协处理器代码指针
    long fip;
    // 协处理器代码段寄存器
    long fcs;
    // 内存操作数的偏移位置
    long foo;
    // 内存操作数的段值
    long fos;
    /* 8 个 10 字节的协处理器累加器。*/
    long st_space[20];
};

// 任务状态段数据结构。
struct tss_struct
{
    // 前一任务链接（TSS选择符）
    long back_link; /* 16 high bits zero */
    // 特权级0栈指针
    long esp0;
    // 特权级1堆栈段选择子
    long ss0; /* 16 high bits zero */
    // 特权级1栈指针
    long esp1;
    // 特权级1堆栈段选择子
    long ss1; /* 16 high bits zero */
    // 特权级2栈指针
    long esp2;
    // 特权级2堆栈段选择子
    long ss2; /* 16 high bits zero */
    // 页目录基地址寄存器
    long cr3;
    long eip;
    long eflags;
    long eax, ecx, edx, ebx;
    long esp;
    long ebp;
    long esi;
    long edi;
    long es; /* 16 high bits zero */
    long cs; /* 16 high bits zero */
    long ss; /* 16 high bits zero */
    long ds; /* 16 high bits zero */
    long fs; /* 16 high bits zero */
    long gs; /* 16 high bits zero */
    // 局部描述符表
    long ldt; /* 16 high bits zero */
    // I/O 位图基地址字段
    long trace_bitmap; /* bits: trace 0, bitmap 16-31 */
    struct i387_struct i387;
};

// 任务（进程）数据结构，或称为进程描述符。
struct task_struct
{
    // 任务的运行状态（-1 不可运行，0 可运行(就绪)，>0 已停止
    long state;
    // 任务运行时间计数(递减)（滴答数），运行时间片
    long counter;
    // 优先数。任务开始运行时 counter=priority，越大运行越长
    long priority;
    // 信号位图，每个比特位代表一种信号，信号值=位偏移值+1
    long signal;
    // 信号执行属性结构，对应信号将要执行的操作和标志信息
    struct sigaction sigaction[32];
    // 进程信号屏蔽码（对应信号位图）
    long blocked;
    // 任务执行停止的退出码，其父进程会取
    int exit_code;
    // start_code 代码段地址 end_code 代码长度（字节数） end_data 代码长度 + 数据长度（字节数） brk 总长度（字节数） start_stack 堆栈段地址
    unsigned long start_code, end_code, end_data, brk, start_stack;
    // pid 进程标识号(进程号) pgrp 进程组号 session 会话号 leader 会话首领
    long pid, pgrp, session, leader;
    // 进程所属组号。一个进程可属于多个组。
    int groups[NGROUPS];
    //  *p_pptr 指向父进程的指针  *p_cptr 指向最新子进程的指针  *p_ysptr 指向比自己后创建的相邻进程的指针 *p_osptr 指向比自己早创建的相邻进程的指针
    struct task_struct *p_pptr, *p_cptr, *p_ysptr, *p_osptr;
    //  uid 用户标识号（用户 id）  euid 有效用户 id  suid 保存的用户 id
    unsigned short uid, euid, suid;
    // gid 组标识号（组 id） egid 有效组 id  sgid 保存的组 id
    unsigned short gid, egid, sgid;
    // timeout 内核定时超时值 alarm 报警定时值（滴答数）
    unsigned long timeout, alarm;
    // utime 用户态运行时间（滴答数）stime 系统态运行时间（滴答数） cutime 子进程用户态运行时间 cstime 子进程系统态运行时间 start_time 进程开始运行时刻
    long utime, stime, cutime, cstime, start_time;
    // 进程资源使用统计数组。
    struct rlimit rlim[RLIM_NLIMITS];
    // 各进程的标志，在下面第 149 行开始定义（还未使用）。
    unsigned int flags;
    // 标志：是否使用了协处理器。
    unsigned short used_math;
    //进程使用 tty 终端的子设备号。-1 表示没有使用。
    int tty;
    // 文件创建属性屏蔽位。
    unsigned short umask;
    // 当前工作目录 i 节点结构指针。
    struct m_inode *pwd;
    // 根目录 i 节点结构指针。
    struct m_inode *root;
    // 执行文件 i 节点结构指针。
    struct m_inode *executable;
    // 被加载库文件 i 节点结构指针。
    struct m_inode *library;
    // 执行时关闭文件句柄位图标志。（参见 include/fcntl.h）
    unsigned long close_on_exec;
    // 文件结构指针表，最多 32 项。表项号即是文件描述符的值。
    struct file *filp[NR_OPEN];
    // 局部描述符表。0-空，1-代码段 cs，2-数据和堆栈段 ds&ss。
    struct desc_struct ldt[3];
    // 进程的任务状态段信息结构。
    struct tss_struct tss;
};

/* 每个进程的标志 */ /* 打印对齐警告信息。还未实现，仅用于 486 */
#define PF_ALIGNWARN 0x00000001

/*
 * INIT_TASK 用于设置第 1 个任务表，若想修改，责任自负！
 * 基址 Base = 0，段长 limit = 0x9ffff（=640kB）。
 */
// 对应上面任务结构的第 1 个任务的信息。
#define INIT_TASK     \
    /* state etc */ { \
        0, 15, 15, \ // state, counter, priority
/* signals */ 0, {
                     {},
                 },
    0, \ // signal, sigaction[32], blocked
    /* ec,brk... */ 0,
    0, 0, 0, 0, 0, \ // exit_code,start_code,end_code,end_data,brk,start_stack
    /* pid etc.. */ 0,
    0, 0, 0, \ // pid, pgrp, session, leader
    /* suppl grps*/ {
        NOGROUP,
    }, \ // groups[]
           /* proc links*/ &init_task.task,
    0, 0, 0, \ // p_pptr, p_cptr, p_ysptr, p_osptr
    /* uid etc */ 0,
    0, 0, 0, 0, 0, \ // uid, euid, suid, gid, egid, sgid
    /* timeout */ 0,
    0, 0, 0, 0, 0, 0, \ // alarm,utime,stime,cutime,cstime,start_time,used_math
    /* rlimits */ {{0x7fffffff, 0x7fffffff}, {0x7fffffff, 0x7fffffff}, {0x7fffffff, 0x7fffffff}, {0x7fffffff, 0x7fffffff}, {0x7fffffff, 0x7fffffff}, {0x7fffffff, 0x7fffffff}},
    /* flags */ 0, \ // flags
    /* math */ 0, \  // used_math, tty,umask,pwd,root,executable,close_on_exec
                      /* fs info */
                      - 1,
    0022, NULL, NULL, NULL, NULL, 0, /* filp */ {
                                      NULL,
                                  }, \ // filp[20]
    { \                                // ldt[3]
        {0, 0},
        /* ldt */ {0x9f, 0xc0fa00}, \ // 代码长 640K，基址 0x0，G=1，D=1，DPL=3，P=1 TYPE=0xa
        {0x9f, 0xc0f200}, \           // 数据长 640K，基址 0x0，G=1，D=1，DPL=3，P=1 TYPE=0x2
    },
    /*tss*/ {0, PAGE_SIZE + (long)&init_task, 0x10, 0, 0, 0, 0, (long)&pg_dir,\ // tss
             0,
             0,
             0,
             0,
             0,
             0,
             0,
             0,
             0,
             0,
             0x17,
             0x17,
             0x17,
             0x17,
             0x17,
             0x17,
             _LDT(0),
             0x80000000,
             {}},
}

// 任务指针数组
extern struct task_struct *task[NR_TASKS];
// 上一个使用过协处理器的进程
extern struct task_struct *last_task_used_math;
// 当前运行进程结构指针变量
extern struct task_struct *current;
// 从开机开始算起的滴答数（10ms/滴答）
extern unsigned long volatile jiffies;
// 开机时间。从 1970:0:0:0 开始计时的秒数
extern unsigned long startup_time;
// 用于累计需要调整的时间嘀嗒数
extern int jiffies_offset;
// 当前时间（秒数）
#define CURRENT_TIME (startup_time + (jiffies + jiffies_offset) / HZ)

// 添加定时器函数（定时时间 jiffies 滴答数，定时到时调用函数*fn()）。( kernel/sched.c )
extern void add_timer(long jiffies, void (*fn)(void));
// 不可中断的等待睡眠。( kernel/sched.c )
extern void sleep_on(struct task_struct **p);
// 可中断的等待睡眠。( kernel/sched.c )
extern void interruptible_sleep_on(struct task_struct **p);
// 明确唤醒睡眠的进程。( kernel/sched.c )
extern void wake_up(struct task_struct **p);
// 检查当前进程是否在指定的用户组 grp 中。
extern int in_group_p(gid_t grp);

/*
 * 寻找第 1 个 TSS 在全局表中的入口。0-没有用 nul，1-代码段 cs，2-数据段 ds，3-系统段 syscall
 * 4-任务状态段 TSS0，5-局部表 LTD0，6-任务状态段 TSS1，等。
 */
// 从该英文注释可以猜想到，Linus 当时曾想把系统调用的代码专门放在 GDT 表中第 4 个独立的段中。
// 但后来并没有那样做，于是就一直把 GDT 表中第 4 个描述符项（上面 syscall 项）闲置在一旁。
// 下面定义宏：全局表中第 1 个任务状态段(TSS)描述符的选择符索引号。
#define FIRST_TSS_ENTRY 4
// 全局表中第 1 个局部描述符表(LDT)描述符的选择符索引号。
#define FIRST_LDT_ENTRY (FIRST_TSS_ENTRY + 1)
// 宏定义，计算在全局表中第 n 个任务的 TSS 段描述符的选择符值（偏移量）。
// 因每个描述符占 8 字节，因此 FIRST_TSS_ENTRY<<3 表示该描述符在 GDT 表中的起始偏移位置。
// 因为每个任务使用 1 个 TSS 和 1 个 LDT 描述符，共占用 16 字节，因此需要 n<<4 来表示对应
// TSS 起始位置。该宏得到的值正好也是该 TSS 的选择符值。
#define _TSS(n) ((((unsigned long)n) << 4) + (FIRST_TSS_ENTRY << 3))
// 宏定义，计算在全局表中第 n 个任务的 LDT 段描述符的选择符值（偏移量）。
#define _LDT(n) ((((unsigned long)n) << 4) + (FIRST_LDT_ENTRY << 3))
// 宏定义，把第 n 个任务的 TSS 段选择符加载到任务寄存器 TR 中。
#define ltr(n) __asm__("ltr %%ax" ::"a"(_TSS(n)))
// 宏定义，把第 n 个任务的 LDT 段选择符加载到局部描述符表寄存器 LDTR 中。
#define lldt(n) __asm__("lldt %%ax" ::"a"(_LDT(n)))
// 取当前运行任务的任务号（是任务数组中的索引值，与进程号 pid 不同）。
// 返回：n - 当前任务号。用于( kernel/traps.c )。
#define str(n) \
 __asm__("str %%ax\n\t" \ // 将任务寄存器中 TSS 段的选择符复制到 ax 中。
 "subl %2,%%eax\n\t" \ // (eax - FIRST_TSS_ENTRY*8)->eax
 "shrl $4,%%eax" \ // (eax/16)->eax = 当前任务号。
 :"=a" (n) \
 :"a" (0),"i" (FIRST_TSS_ENTRY<<3))

 /*
 * switch_to(n)将切换当前任务到任务 nr，即 n。首先检测任务 n 不是当前任务，
 * 如果是则什么也不做退出。如果我们切换到的任务最近（上次运行）使用过数学
 * 协处理器的话，则还需复位控制寄存器 cr0 中的 TS 标志。
 */
 // 跳转到一个任务的 TSS 段选择符组成的地址处会造成 CPU 进行任务切换操作。
 // 输入：%0 - 指向__tmp； %1 - 指向__tmp.b 处，用于存放新 TSS 的选择符；
 // dx - 新任务 n 的 TSS 段选择符； ecx - 新任务 n 的任务结构指针 task[n]。
 // 其中临时数据结构__tmp 用于组建 177 行远跳转（far jump）指令的操作数。该操作数由 4 字节
 // 偏移地址和 2 字节的段选择符组成。因此__tmp 中 a 的值是 32 位偏移值，而 b 的低 2 字节是新
 // TSS 段的选择符（高 2 字节不用）。跳转到 TSS 段选择符会造成任务切换到该 TSS 对应的进程。
 // 对于造成任务切换的长跳转，a 值无用。177 行上的内存间接跳转指令使用 6 字节操作数作为跳
 // 转目的地的长指针，其格式为：jmp 16 位段选择符：32 位偏移值。但在内存中操作数的表示顺
 // 序与这里正好相反。任务切换回来之后，在判断原任务上次执行是否使用过协处理器时，是通过
 // 将原任务指针与保存在 last_task_used_math 变量中的上次使用过协处理器任务指针进行比较而
 // 作出的，参见文件 kernel/sched.c 中有关 math_state_restore()函数的说明。
#define switch_to(n)   \
    {                  \
        struct         \
        {              \
            long a, b; \
        } __tmp;       \
 __asm__("cmpl %%ecx,_current\n\t" \ // 任务 n 是当前任务吗?(current ==task[n]?)
 "je 1f\n\t" \ // 是，则什么都不做，退出。
 "movw %%dx,%1\n\t" \ // 将新任务 TSS 的 16 位选择符存入__tmp.b 中。
 "xchgl %%ecx,_current\n\t" \ // current = task[n]；ecx = 被切换出的任务。
 "ljmp %0\n\t" \ // 执行长跳转至*&__tmp，造成任务切换。
 // 在任务切换回来后才会继续执行下面的语句。
 "cmpl %%ecx,_last_task_used_math\n\t" \ // 原任务上次使用过协处理器吗？
 "jne 1f\n\t" \ // 没有则跳转，退出。
 "clts\n" \ // 原任务上次使用过协处理器，则清 cr0 中的任务
 "1:" \ // 切换标志 TS。
 ::"m" (*&__tmp.a),"m" (*&__tmp.b), \
 "d" (_TSS(n)),"c" ((long) task[n]));
 }

 // 页面地址对准。（在内核代码中没有任何地方引用!!）
#define PAGE_ALIGN(n) (((n) + 0xfff) & 0xfffff000)

 // 设置位于地址 addr 处描述符中的各基地址字段(基地址是 base)。
 // %0 - 地址 addr 偏移 2；%1 - 地址 addr 偏移 4；%2 - 地址 addr 偏移 7；edx - 基地址 base。
#define _set_base(addr, base) \
 __asm__("movw %%dx,%0\n\t" \ // 基址 base 低 16 位(位 15-0)->[addr+2]。
 "rorl $16,%%edx\n\t" \ // edx 中基址高 16 位(位 31-16)->dx。
 "movb %%dl,%1\n\t" \ // 基址高 16 位中的低 8 位(位 23-16)->[addr+4]。
 "movb %%dh,%2" \ // 基址高 16 位中的高 8 位(位 31-24)->[addr+7]。
 ::"m" (*((addr)+2)), \
 "m" (*((addr)+4)), \
 "m" (*((addr)+7)), \
 "d" (base) \
 :"dx") // 告诉 gcc 编译器 edx 寄存器中的值已被嵌入汇编程序改变了。

 // 设置位于地址 addr 处描述符中的段限长字段(段长是 limit)。
 // %0 - 地址 addr；%1 - 地址 addr 偏移 6 处；edx - 段长值 limit。
#define _set_limit(addr, limit) \
 __asm__("movw %%dx,%0\n\t" \ // 段长 limit 低 16 位(位 15-0)->[addr]。
 "rorl $16,%%edx\n\t" \ // edx 中的段长高 4 位(位 19-16)->dl。
 "movb %1,%%dh\n\t" \ // 取原[addr+6]字节->dh，其中高 4 位是些标志。
 "andb $0xf0,%%dh\n\t" \ // 清 dh 的低 4 位(将存放段长的位 19-16)。
 "orb %%dh,%%dl\n\t" \ // 将原高 4 位标志和段长的高 4 位(位 19-16)合成 1 字节，
 "movb %%dl,%1" \ // 并放会[addr+6]处。
 ::"m" (*(addr)), \
 "m" (*((addr)+6)), \
 "d" (limit) \
 :"dx")

 // 设置局部描述符表中 ldt 描述符的基地址字段。
#define set_base(ldt, base) _set_base(((char *)&(ldt)), base)
 // 设置局部描述符表中 ldt 描述符的段长字段。
#define set_limit(ldt, limit) _set_limit(((char *)&(ldt)), (limit - 1) >> 12)

 // 从地址 addr 处描述符中取段基地址。功能与_set_base()正好相反。
 // edx - 存放基地址(__base)；%1 - 地址 addr 偏移 2；%2 - 地址 addr 偏移 4；%3 - addr 偏移 7。
#define _get_base(addr) ({\
 unsigned long __base; \
 __asm__("movb %3,%%dh\n\t" \ // 取[addr+7]处基址高 16 位的高 8 位(位 31-24)->dh。
 "movb %2,%%dl\n\t" \ // 取[addr+4]处基址高 16 位的低 8 位(位 23-16)->dl。
 "shll $16,%%edx\n\t" \ // 基地址高 16 位移到 edx 中高 16 位处。
 "movw %1,%%dx" \ // 取[addr+2]处基址低 16 位(位 15-0)->dx。
 :"=d" (__base) \ // 从而 edx 中含有 32 位的段基地址。
 :"m" (*((addr)+2)), \
 "m" (*((addr)+4)), \
 "m" (*((addr)+7)));
 __base;
 })

 // 取局部描述符表中 ldt 所指段描述符中的基地址。
#define get_base(ldt) _get_base(((char *)&(ldt)))

 // 取段选择符 segment 指定的描述符中的段限长值。
 // 指令 lsl 是 Load Segment Limit 缩写。它从指定段描述符中取出分散的限长比特位拼成完整的
 // 段限长值放入指定寄存器中。所得的段限长是实际字节数减 1，因此这里还需要加 1 后才返回。
 // %0 - 存放段长值(字节数)；%1 - 段选择符 segment。
#define get_limit(segment) (            \
    {                                   \
        unsigned long __limit;          \
        __asm__("lsll %1,%0\n\tincl %0" \
                : "=r"(__limit)         \
                : "r"(segment));        \
        __limit;                        \
    })

#endif
