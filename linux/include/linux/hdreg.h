/*
 * 该文件中主要定义了对硬盘控制器进行编程的一些命令常量符号。其中包括控制器端口、硬盘状态
 * 寄存器各位的状态、控制器命令以及出错状态常量符号。另外还给出了硬盘分区表数据结构。
 * 本文件含有一些 AT 硬盘控制器的定义。来自各种资料。请查证某些定义（带有问号的注释）。
 */
#ifndef _HDREG_H
#define _HDREG_H

/* 硬盘控制器寄存器端口。参见：IBM AT Bios 程序 */
#define HD_DATA 0x1f0        /* _CTL when writing */
#define HD_ERROR 0x1f1       /* see err-bits */
#define HD_NSECTOR 0x1f2     /* nr of sectors to read/write */
#define HD_SECTOR 0x1f3      /* starting sector */
#define HD_LCYL 0x1f4        /* starting cylinder */
#define HD_HCYL 0x1f5        /* high byte of starting cyl */
#define HD_CURRENT 0x1f6     /* 101dhhhh , d=drive, hhhh=head */
#define HD_STATUS 0x1f7      /* see status-bits */
#define HD_PRECOMP HD_ERROR  /* same io address, read=error, write=precomp */
#define HD_COMMAND HD_STATUS /* same io address, read=status, write=cmd */

#define HD_CMD 0x3f6 // 控制寄存器端口。

/* 硬盘状态寄存器各位的定义(HD_STATUS) */
#define ERR_STAT 0x01                       // 命令执行错误。
#define INDEX_STAT 0x02                     // 收到索引。
#define ECC_STAT 0x04 /* Corrected error */ // ECC 校验错。
#define DRQ_STAT 0x08                       // 请求服务。
#define SEEK_STAT 0x10                      // 寻道结束。
#define WRERR_STAT 0x20                     // 驱动器故障。
#define READY_STAT 0x40                     // 驱动器准备好（就绪）。
#define BUSY_STAT 0x80                      // 控制器忙碌。

/* 硬盘命令值（HD_CMD） */
#define WIN_RESTORE 0x10  // 驱动器重新校正（驱动器复位）。
#define WIN_READ 0x20     // 读扇区。
#define WIN_WRITE 0x30    // 写扇区。
#define WIN_VERIFY 0x40   // 扇区检验。
#define WIN_FORMAT 0x50   // 格式化磁道。
#define WIN_INIT 0x60     // 控制器初始化。
#define WIN_SEEK 0x70     // 寻道。
#define WIN_DIAGNOSE 0x90 // 控制器诊断。
#define WIN_SPECIFY 0x91  // 建立驱动器参数。

/* 错误寄存器各比特位的含义（HD_ERROR） */
// 执行控制器诊断命令时含义与其他命令时的不同。下面分别列出：
// ==================================================
// 诊断命令时 其他命令时
// --------------------------------------------------
// 0x01 无错误 数据标志丢失
// 0x02 控制器出错 磁道 0 错
// 0x03 扇区缓冲区错
// 0x04 ECC 部件错 命令放弃
// 0x05 控制处理器错
// 0x10 ID 未找到
// 0x40 ECC 错误
// 0x80 坏扇区
//---------------------------------------------------
#define MARK_ERR 0x01 /* Bad address mark ? */
#define TRK0_ERR 0x02 /* couldn't find track 0 */
#define ABRT_ERR 0x04 /* ? */
#define ID_ERR 0x10   /* ? */
#define ECC_ERR 0x40  /* ? */
#define BBD_ERR 0x80  /* ? */

// 硬盘分区表结构。参见下面列表后信息。
struct partition
{
    // 活动分区标记，此标记有两种取值， Ox80表示活动分区，也就是此分区的引导扇区中保护引导程序 0x0表示非活动分区
    unsigned char boot_ind;
    // 分区起始处的磁头号。磁头号范围为 0--255。
    unsigned char head;
    // 分区起始扇区号
    unsigned char sector;  
    // 分区起始柱面号   
    unsigned char cyl;        
    // 文件系统类型 ID ，如 表示不可识别的文件系统， 表示 '32
    unsigned char sys_ind;   
    // 分区结束磁头号
    unsigned char end_head;   
    // 分区结束扇区号
    unsigned char end_sector; 
    // 分区结束柱面号
    unsigned char end_cyl;    
    // 分区起始的物理扇区号。它以整个硬盘的扇区号顺序从 0 计起。
    unsigned int start_sect;  
    // 分区占用的扇区数
    unsigned int nr_sects;    
};

#endif
