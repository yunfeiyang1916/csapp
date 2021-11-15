// 二级引导器核心入口
#include "cmctl.h"

extern idtr_t IDT_PTR;

// 引导器核心入口
void ldrkrl_entry()
{
    init_curs();
    close_curs();
    clear_screen(VGADP_DFVL);
    // 处理开始参数，负责管理检查 CPU 模式、收集内存信息，设置内核栈，设置内核字体、建立内核 MMU 页表数据。
    init_bstartparm();
    return;
}

void kerror(char_t *kestr)
{
    kprint("INITKLDR DIE ERROR:%s\n", kestr);
    for (;;)
        ;
    return;
}

#pragma GCC push_options
#pragma GCC optimize("O0")
void die(u32_t dt)
{

    u32_t dttt = dt, dtt = dt;
    if (dt == 0)
    {
        for (;;)
            ;
    }

    for (u32_t i = 0; i < dt; i++)
    {
        for (u32_t j = 0; j < dtt; j++)
        {
            for (u32_t k = 0; k < dttt; k++)
            {
                ;
            }
        }
    }

    return;
}
#pragma GCC pop_options
