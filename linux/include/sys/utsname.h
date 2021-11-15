/**
 * utsname.h 是系统名称结构头文件。
*/
#ifndef _SYS_UTSNAME_H
#define _SYS_UTSNAME_H

#include <sys/types.h> // 类型头文件。定义了基本的系统数据类型。
#include <sys/param.h> // 内核参数文件。
// utsname 是 Unix Timesharing System name 的缩写,unix分时操作系统名称
struct utsname
{
    // 当前运行系统的名称。
    char sysname[9];
    // 与实现相关的网络中节点名称（主机名称）。
    char nodename[MAXHOSTNAMELEN + 1];
    // 本操作系统实现的当前发行级别。
    char release[9];
    // 本次发行的操作系统版本级别。
    char version[9];
    // 系统运行的硬件类型名称。
    char machine[9];
};
// 该函数利用utsname 结构中的信息给出系统标识、版本号以及硬件类型等信息。
extern int uname(struct utsname *utsbuf);

#endif
