/**
 * param.h 文件中给出了与系统硬件相关的一些参数值。
*/
#ifndef _SYS_PARAM_H
#define _SYS_PARAM_H

#define HZ 100             // 系统时钟频率，每秒中断 100 次。
#define EXEC_PAGESIZE 4096 // 页面大小。

#define NGROUPS 32 /* 每个进程最多组号*/
#define NOGROUP -1

#define MAXHOSTNAMELEN 8 // 主机名最大长度，8 字节。

#endif
