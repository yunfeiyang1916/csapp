/*
* 主要用于存放 UNIX 类操作系统中一些常用的符号和函数原型等“标准定义”。
*/
#ifndef _STDDEF_H
#define _STDDEF_H

#ifndef _PTRDIFF_T
#define _PTRDIFF_T
typedef long ptrdiff_t; // 两个指针相减结果的类型。
#endif

#ifndef _SIZE_T
#define _SIZE_T
typedef unsigned long size_t; // sizeof 返回的类型。
#endif

#undef NULL
#define NULL ((void *)0) // 空指针。

// 下面定义了一个计算某成员在类型中偏移位置的宏。使用该宏可以确定一个成员（字段）在
// 包含它的结构类型中从结构开始处算起的字节偏移量。宏的结果是类型为 size_t 的整数常
// 数表达式。这里是一个技巧用法。((TYPE *)0)是将一个整数 0 类型投射（type cast）成数
// 据对象指针类型，然后在该结果上进行运算。
#define offsetof(TYPE, MEMBER) ((size_t) & ((TYPE *)0)->MEMBER)

#endif
