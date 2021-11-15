/*
 * 所有字符串操作函数已经存在于 string.h 头文件中。
 * 这里通过首先声明'extern'和'inline'前缀为空，然后再包含 string.h 头文件，实现了 string.c 中仅包含字符串函数的实现代码。
 */

#ifndef __GNUC__ // 需要 GNU 的 C 编译器编译。
#error I want gcc!
#endif

#define extern
#define inline
#define __LIBRARY__
#include <string.h>
