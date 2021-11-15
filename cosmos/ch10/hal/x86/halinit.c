#include "cosmostypes.h"
#include "cosmosmctrl.h"

// hal(硬件抽象层)初始化
void init_hal()
{
    // 初始化平台
    init_halplaltform();
    // 初始化内存
    init_halmm();
    // 初始化中断
    init_halintupt();
}