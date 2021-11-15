/*
* 定义了文件访问和修改时间结构 utimbuf{}以及 utime()函数原型，其中时间以秒计。
*/

#ifndef _UTIME_H
#define _UTIME_H

#include <sys/types.h> /* 我知道 - 不应该这样做，但是.. */

struct utimbuf
{
    // 文件访问时间。从 1970.1.1:0:0:0 开始的秒数
    time_t actime;
    // 文件修改时间。从 1970.1.1:0:0:0 开始的秒数
    time_t modtime;
};
// 设置文件访问和修改时间的函数
extern int utime(const char *filename, struct utimbuf *times);

#endif
