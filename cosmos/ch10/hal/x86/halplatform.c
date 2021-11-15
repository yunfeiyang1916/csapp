/**********************************************************
        平台相关的文件halplatform.c
***********************************************************
主要负责完成两个任务：
    一是把二级引导器建立的机器信息结构复制到hal层中的一个全局变量中，方便内核中的其它代码使用里面的信息，之后二级引导器建立的数据所占用的内存都会被释放。
    二是要初始化图形显示驱动，内核在运行过程要在屏幕上输出信息。               
**********************************************************/
#include "cosmostypes.h"
#include "cosmosmctrl.h"

// 虚拟地址转成物理地址
adr_t virtadr_to_phyadr(adr_t kviradr)
{
    if (kviradr < KRNL_MAP_VIRTADDRESS_START || kviradr > KRNL_MAP_VIRTADDRESS_END)
    {
        system_error("virtadr_to_phyadr err\n");
        return KRNL_ADDR_ERROR;
    }
    return kviradr - KRNL_MAP_VIRTADDRESS_START;
}
// 物理地址转成虚拟地址
adr_t phyadr_to_viradr(adr_t kphyadr)
{
    if (kphyadr >= KRNL_MAP_PHYADDRESS_END)
    {
        system_error("phyadr_to_viradr err\n");
        return KRNL_ADDR_ERROR;
    }
    return kphyadr + KRNL_MAP_VIRTADDRESS_START;
}

void machbstart_t_init(machbstart_t *initp)
{
    //清零
    memset(initp, 0, sizeof(machbstart_t));
}

// 复制机器信息结构，把二级引导器建立的机器信息结构复制到hal层中的一个全局变量中
void init_machbstart()
{
    machbstart_t *kmbsp = &kmachbsp;
    // 物理地址1MB处
    machbstart_t *smbsp = MBSPADR;
    machbstart_t_init(kmbsp);
    // 复制，要把地址转换成虚拟地址
    memcopy((void *)phyadr_to_viradr((adr_t)smbsp), (void *)kmbsp, sizeof(machbstart_t));
}

// 初始化平台
void init_halplaltform()
{
    // 复制机器信息结构
    init_machbstart();
    // 初始化图形显示驱动
    init_bdvideo();
}

int strcmpl(const char *a, const char *b)
{
    while (*b && *a && (*b == *a))
    {

        b++;

        a++;
    }
    return *b - *a;
}

fhdsc_t *get_fileinfo(char_t *fname, machbstart_t *mbsp)
{
    mlosrddsc_t *mrddadrs = (mlosrddsc_t *)phyadr_to_viradr((adr_t)(mbsp->mb_imgpadr + MLOSDSC_OFF));
    if (mrddadrs->mdc_endgic != MDC_ENDGIC ||
        mrddadrs->mdc_rv != MDC_RVGIC ||
        mrddadrs->mdc_fhdnr < 2 ||
        mrddadrs->mdc_filnr < 2)
    {
        system_error("no mrddsc");
    }
    s64_t rethn = -1;
    fhdsc_t *fhdscstart = (fhdsc_t *)((uint_t)((mrddadrs->mdc_fhdbk_s) + (phyadr_to_viradr((adr_t)mbsp->mb_imgpadr))));

    for (u64_t i = 0; i < mrddadrs->mdc_fhdnr; i++)
    {
        if (strcmpl(fname, fhdscstart[i].fhd_name) == 0)
        {
            rethn = (s64_t)i;
            goto ok_l;
        }
    }
    rethn = -1;
ok_l:
    if (rethn < 0)
    {
        system_error("not find file");
    }
    return &fhdscstart[rethn];
}

void get_file_rvadrandsz(char_t *fname, machbstart_t *mbsp, u64_t *retadr, u64_t *retsz)
{
    u64_t padr = 0, fsz = 0;
    if (NULL == fname || NULL == mbsp)
    {
        *retadr = 0;
        return;
    }
    fhdsc_t *fhdsc = get_fileinfo(fname, mbsp);
    if (fhdsc == NULL)
    {
        *retadr = 0;
        return;
    }
    padr = fhdsc->fhd_intsfsoff + phyadr_to_viradr((adr_t)mbsp->mb_imgpadr);
    fsz = fhdsc->fhd_frealsz;

    *retadr = padr;
    *retsz = fsz;
    return;
}