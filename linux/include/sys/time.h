/**
 * time.h 头文件中定义了 timeval 结构和内部使用的 itimerval 结构，以及一些时区常数等。
*/
#ifndef _SYS_TIME_H
#define _SYS_TIME_H

// gettimeofday()函数返回该时间结构。
struct timeval
{
    long tv_sec;  // 秒。
    long tv_usec; // 微秒。
};

// 时间区结构。tz 为时区（Time Zone）的缩写，DST（Daylight Saving Time）是夏令时的缩写。
struct timezone
{
    int tz_minuteswest; // 格林威治西部分钟时间。
    int tz_dsttime;     // 夏令时区调整时间。
};

#define DST_NONE 0     // 非夏令时。
#define DST_USA 1      // USA 形式的夏令时。
#define DST_AUST 2     // 澳洲形式的夏令时。
#define DST_WET 3      /* Western European dst */
#define DST_MET 4      /* Middle European dst */
#define DST_EET 5      /* Eastern European dst */
#define DST_CAN 6      /* Canada */
#define DST_GB 7       /* Great Britain and Eire */
#define DST_RUM 8      /* Rumania */
#define DST_TUR 9      /* Turkey */
#define DST_AUSTALT 10 /* Australian style with shift in 1986 */

// 文件描述符集的设置宏，用于 select()函数。
#define FD_SET(fd, fdsetp) (*(fdsetp) |= (1 << (fd)))
#define FD_CLR(fd, fdsetp) (*(fdsetp) &= ~(1 << (fd)))
#define FD_ISSET(fd, fdsetp) ((*(fdsetp) >> fd) & 1)
#define FD_ZERO(fdsetp) (*(fdsetp) = 0)

// timeval 时间结构的操作函数。
#define timerisset(tvp) ((tvp)->tv_sec || (tvp)->tv_usec)
#define timercmp(tvp, uvp, cmp)        \
    ((tvp)->tv_sec cmp(uvp)->tv_sec || \
     (tvp)->tv_sec == (uvp)->tv_sec && (tvp)->tv_usec cmp(uvp)->tv_usec)
#define timerclear(tvp) ((tvp)->tv_sec = (tvp)->tv_usec = 0)

/* 内部定时器名称和结构，用于定义定时器设置。 */
#define ITIMER_REAL 0    // 以实际时间递减。
#define ITIMER_VIRTUAL 1 // 以进程虚拟时间递减。
#define ITIMER_PROF 2    // 以进程虚拟时间或者当系统运行时以进程时间递减。

// 内部时间结构。其中 it（Internal Timer）是内部定时器的缩写。
struct itimerval
{
    struct timeval it_interval; /* timer interval */
    struct timeval it_value;    /* current value */
};

#include <time.h>
#include <sys/types.h>

int gettimeofday(struct timeval *tp, struct timezone *tz);
int select(int width, fd_set *readfds, fd_set *writefds,
           fd_set *exceptfds, struct timeval *timeout);

#endif /*_SYS_TIME_H*/
