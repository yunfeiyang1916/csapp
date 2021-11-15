/**********************************************************
        hal层中断处理头文件halintupt.c
***********************************************************
**********************************************************/

#include "cosmostypes.h"
#include "cosmosmctrl.h"

// 初始化中断
PUBLIC void init_halintupt()
{
    // 初始化全局描述符表
    init_descriptor();
    // 初始化中断门描述符表
    init_idt_descriptor();
}