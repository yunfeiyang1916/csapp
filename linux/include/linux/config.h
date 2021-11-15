/*
 * 内核配置头文件。其中定义了 uname 命令使用的系统信息，以及系统所使用的键盘语言类型和硬盘类型（HD_TYPE）可选项。
 */

#ifndef _CONFIG_H
#define _CONFIG_H

/* 
 * 定义 uname()函数应该返回的值。
 */
#define UTS_SYSNAME "Linux"
#define UTS_NODENAME "(none)" /* set by sethostname() */
#define UTS_RELEASE "0"       /* patchlevel */
#define UTS_VERSION "0.12"
#define UTS_MACHINE "i386" /* hardware type */

/* 请不要随意修改下面定义值，除非你知道自己正在干什么。 */
// 下面这些符号常数用于指明系统引导和加载内核时的具体内存位置，以及默认的最大内核大小值。
// 引导扇区程序将被移动到的段值
#define DEF_INITSEG 0x9000
// 引导扇区程序把系统模块加载到内存的段值
#define DEF_SYSSEG 0x1000
// setup 程序所处内存段位置
#define DEF_SETUPSEG 0x9020
// 内核系统模块默认最大节数（16 字节=1 节）
#define DEF_SYSSIZE 0x3000

#endif