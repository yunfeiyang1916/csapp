/**********************************************************
        引导调式屏幕上显示输出文件bdvideo.c
***********************************************************
**********************************************************/
#include "cosmostypes.h"
#include "cosmosmctrl.h"

const char *cosmos_version = "Cosmos\n内核版本:00.01\n彭东 @ 构建于 "__DATE__
                             " "__TIME__
                             "\n";

// 初始化图形数据结构，里面放有图形模式，分辨率，图形驱动函数指针
PUBLIC LKINIT void init_dftgraph()
{
    dftgraph_t *kghp = &kdftgh;
    machbstart_t *kmbsp = &kmachbsp;
    memset(kghp, 0, sizeof(dftgraph_t));
    kghp->gh_mode = kmbsp->mb_ghparm.gh_mode;
    kghp->gh_x = kmbsp->mb_ghparm.gh_x;
    kghp->gh_y = kmbsp->mb_ghparm.gh_y;
    kghp->gh_framphyadr = phyadr_to_viradr((adr_t)kmbsp->mb_ghparm.gh_framphyadr);
    kghp->gh_fvrmphyadr = phyadr_to_viradr((adr_t)kmbsp->mb_fvrmphyadr);
    kghp->gh_fvrmsz = kmbsp->mb_fvrmsz;
    kghp->gh_onepixbits = kmbsp->mb_ghparm.gh_onepixbits;
    kghp->gh_onepixbyte = kmbsp->mb_ghparm.gh_onepixbits / 8;
    kghp->gh_vbemodenr = kmbsp->mb_ghparm.gh_vbemodenr;
    kghp->gh_bank = kmbsp->mb_ghparm.gh_bank;
    kghp->gh_curdipbnk = kmbsp->mb_ghparm.gh_curdipbnk;
    kghp->gh_nextbnk = kmbsp->mb_ghparm.gh_nextbnk;
    kghp->gh_banksz = kmbsp->mb_ghparm.gh_banksz;

    kghp->gh_fontadr = phyadr_to_viradr((adr_t)kmbsp->mb_bfontpadr);
    kghp->gh_fontsz = kmbsp->mb_bfontsz;
    kghp->gh_fnthight = 16;
    kghp->gh_linesz = 16 + 4;
    kghp->gh_deffontpx = BGRA(0xff, 0xff, 0xff);
    return;
}

// 初始化图形显示驱动
PUBLIC LKINIT void init_bdvideo()
{
    dftgraph_t *kghp = &kdftgh;
    // 初始化图形数据结构，里面放有图形模式，分辨率，图形驱动函数指针
    init_dftgraph();
    // 初始bga图形显卡的函数指针
    init_bga();
    // 初始vbe图形显卡的函数指针
    init_vbe();
    // 清空屏幕 为黑色
    fill_graph(kghp, BGRA(0, 0, 0));
    // 显示背景图片
    set_charsdxwflush(0, 0);
    hal_background();
    return;
}

// 初始bga图形显卡的函数指针
void init_bga()
{
    dftgraph_t *kghp = &kdftgh;
    if (kghp->gh_mode != BGAMODE)
    {
        return;
    }
    kghp->gh_opfun.dgo_read = bga_read;
    kghp->gh_opfun.dgo_write = bga_write;
    kghp->gh_opfun.dgo_ioctrl = bga_ioctrl;
    kghp->gh_opfun.dgo_flush = bga_flush;
    kghp->gh_opfun.dgo_set_bank = bga_set_bank;
    kghp->gh_opfun.dgo_readpix = bga_readpix;
    kghp->gh_opfun.dgo_writepix = bga_writepix;
    kghp->gh_opfun.dgo_dxreadpix = bga_dxreadpix;
    kghp->gh_opfun.dgo_dxwritepix = bga_dxwritepix;
    kghp->gh_opfun.dgo_set_xy = bga_set_xy;
    kghp->gh_opfun.dgo_set_vwh = bga_set_vwh;
    kghp->gh_opfun.dgo_set_xyoffset = bga_set_xyoffset;
    kghp->gh_opfun.dgo_get_xy = bga_get_xy;
    kghp->gh_opfun.dgo_get_vwh = bga_get_vwh;
    kghp->gh_opfun.dgo_get_xyoffset = bga_get_xyoffset;
}

size_t bga_read(void *ghpdev, void *outp, size_t rdsz)
{
    //dftgraph_t* kghp=(dftgraph_t*)ghpdev;
    return rdsz;
}

size_t bga_write(void *ghpdev, void *inp, size_t wesz)
{
    //dftgraph_t* kghp=(dftgraph_t*)ghpdev;
    return wesz;
}

sint_t bga_ioctrl(void *ghpdev, void *outp, uint_t iocode)
{
    return -1;
}

void bga_flush(void *ghpdev)
{
    dftgraph_t *kghp = (dftgraph_t *)ghpdev;

    u64_t *s = (u64_t *)((uint_t)kghp->gh_fvrmphyadr);
    u64_t *d = ret_vramadr_inbnk(kghp);
    u64_t i = 0, j = 0;
    u64_t e = kghp->gh_x * kghp->gh_y * kghp->gh_onepixbyte;

    for (; i < e; i += 8)
    {
        d[j] = s[j];
        j++;
    }
    bga_disp_nxtbank(kghp);
    return;
}

u64_t *ret_vramadr_inbnk(void *ghpdev)
{
    dftgraph_t *kghp = (dftgraph_t *)ghpdev;
    u64_t *d = (u64_t *)((uint_t)(kghp->gh_framphyadr + (kghp->gh_x * kghp->gh_y * kghp->gh_onepixbyte * kghp->gh_nextbnk)));

    return d;
}

void bga_disp_nxtbank(void *ghpdev)
{
    dftgraph_t *kghp = (dftgraph_t *)ghpdev;
    u16_t h = (u16_t)(kghp->gh_y * kghp->gh_nextbnk + 1);
    u16_t ofy = (u16_t)(kghp->gh_y * (kghp->gh_nextbnk));
    bga_write_reg(VBE_DISPI_INDEX_VIRT_HEIGHT, h);
    bga_write_reg(VBE_DISPI_INDEX_Y_OFFSET, ofy);
    kghp->gh_curdipbnk = kghp->gh_nextbnk;
    kghp->gh_nextbnk++;
    if (kghp->gh_nextbnk > kghp->gh_bank)
    {
        kghp->gh_nextbnk = 0;
    }
    return;
}

void bga_write_reg(u16_t index, u16_t data)
{
    out_u16(VBE_DISPI_IOPORT_INDEX, index);
    out_u16(VBE_DISPI_IOPORT_DATA, data);
    return;
}

sint_t bga_set_bank(void *ghpdev, sint_t bnr)
{
    return -1;
}

pixl_t bga_readpix(void *ghpdev, uint_t x, uint_t y)
{
    return 0;
}

void bga_writepix(void *ghpdev, pixl_t pix, uint_t x, uint_t y)
{
    dftgraph_t *kghp = (dftgraph_t *)ghpdev;
    u8_t *p24bas;
    if (kghp->gh_onepixbits == 24)
    {
        u64_t p24adr = (x + (y * kghp->gh_x)) * 3;
        p24bas = (u8_t *)((uint_t)(p24adr + kghp->gh_fvrmphyadr));
        p24bas[0] = (u8_t)(pix);
        p24bas[1] = (u8_t)(pix >> 8);
        p24bas[2] = (u8_t)(pix >> 16);
        return;
    }
    u32_t *phybas = (u32_t *)((uint_t)kghp->gh_fvrmphyadr);
    phybas[x + (y * kghp->gh_x)] = pix;
    return;
}

pixl_t bga_dxreadpix(void *ghpdev, uint_t x, uint_t y)
{
    return 0;
}

void bga_dxwritepix(void *ghpdev, pixl_t pix, uint_t x, uint_t y)
{
    dftgraph_t *kghp = (dftgraph_t *)ghpdev;
    u8_t *p24bas;
    if (kghp->gh_onepixbits == 24)
    {
        u64_t p24adr = (x + (y * kghp->gh_x)) * 3 * kghp->gh_curdipbnk;
        p24bas = (u8_t *)((uint_t)(p24adr + kghp->gh_framphyadr));
        p24bas[0] = (u8_t)(pix);
        p24bas[1] = (u8_t)(pix >> 8);
        p24bas[2] = (u8_t)(pix >> 16);
        return;
    }
    u32_t *phybas = (u32_t *)((uint_t)(kghp->gh_framphyadr + (kghp->gh_x * kghp->gh_y * kghp->gh_onepixbyte * kghp->gh_curdipbnk)));
    phybas[x + (y * kghp->gh_x)] = pix;
    return;
}

sint_t bga_set_xy(void *ghpdev, uint_t x, uint_t y)
{

    bga_write_reg(VBE_DISPI_INDEX_XRES, (u16_t)(x));
    bga_write_reg(VBE_DISPI_INDEX_YRES, (u16_t)(y));

    return 0;
}

sint_t bga_set_vwh(void *ghpdev, uint_t vwt, uint_t vhi)
{

    bga_write_reg(VBE_DISPI_INDEX_VIRT_WIDTH, (u16_t)vwt);
    bga_write_reg(VBE_DISPI_INDEX_VIRT_HEIGHT, (u16_t)vhi);
    return 0;
}

sint_t bga_set_xyoffset(void *ghpdev, uint_t xoff, uint_t yoff)
{
    bga_write_reg(VBE_DISPI_INDEX_X_OFFSET, (u16_t)(xoff));
    bga_write_reg(VBE_DISPI_INDEX_Y_OFFSET, (u16_t)(yoff));
    return 0;
}

sint_t bga_get_xy(void *ghpdev, uint_t *rx, uint_t *ry)
{
    if (rx == NULL || ry == NULL)
    {
        return -1;
    }
    u16_t retx, rety;
    retx = bga_read_reg(VBE_DISPI_INDEX_XRES);
    rety = bga_read_reg(VBE_DISPI_INDEX_YRES);
    *rx = (uint_t)retx;
    *ry = (uint_t)rety;
    return 0;
}

u16_t bga_read_reg(u16_t index)
{
    out_u16(VBE_DISPI_IOPORT_INDEX, index);
    return in_u16(VBE_DISPI_IOPORT_DATA);
}

sint_t bga_get_vwh(void *ghpdev, uint_t *rvwt, uint_t *rvhi)
{
    if (rvwt == NULL || rvhi == NULL)
    {
        return -1;
    }
    u16_t retwt, rethi;
    retwt = bga_read_reg(VBE_DISPI_INDEX_VIRT_WIDTH);
    rethi = bga_read_reg(VBE_DISPI_INDEX_VIRT_HEIGHT);
    *rvwt = (uint_t)retwt;
    *rvhi = (uint_t)rethi;
    return 0;
}

sint_t bga_get_xyoffset(void *ghpdev, uint_t *rxoff, uint_t *ryoff)
{
    if (rxoff == NULL || ryoff == NULL)
    {
        return -1;
    }
    u16_t retxoff, retyoff;
    retxoff = bga_read_reg(VBE_DISPI_INDEX_X_OFFSET);
    retyoff = bga_read_reg(VBE_DISPI_INDEX_Y_OFFSET);
    *rxoff = (uint_t)retxoff;
    *ryoff = (uint_t)retyoff;
    return 0;
}

// 初始vbe图形显卡的函数指针
void init_vbe()
{
    dftgraph_t *kghp = &kdftgh;
    if (kghp->gh_mode != VBEMODE)
    {
        return;
    }
    kghp->gh_opfun.dgo_read = vbe_read;
    kghp->gh_opfun.dgo_write = vbe_write;
    kghp->gh_opfun.dgo_ioctrl = vbe_ioctrl;
    kghp->gh_opfun.dgo_flush = vbe_flush;
    kghp->gh_opfun.dgo_set_bank = vbe_set_bank;
    kghp->gh_opfun.dgo_readpix = vbe_readpix;
    kghp->gh_opfun.dgo_writepix = vbe_writepix;
    kghp->gh_opfun.dgo_dxreadpix = vbe_dxreadpix;
    kghp->gh_opfun.dgo_dxwritepix = vbe_dxwritepix;
    kghp->gh_opfun.dgo_set_xy = vbe_set_xy;
    kghp->gh_opfun.dgo_set_vwh = vbe_set_vwh;
    kghp->gh_opfun.dgo_set_xyoffset = vbe_set_xyoffset;
    kghp->gh_opfun.dgo_get_xy = vbe_get_xy;
    kghp->gh_opfun.dgo_get_vwh = vbe_get_vwh;
    kghp->gh_opfun.dgo_get_xyoffset = vbe_get_xyoffset;
    return;
}

size_t vbe_read(void *ghpdev, void *outp, size_t rdsz)
{

    return rdsz;
}

size_t vbe_write(void *ghpdev, void *inp, size_t wesz)
{
    return wesz;
}

sint_t vbe_ioctrl(void *ghpdev, void *outp, uint_t iocode)
{
    return -1;
}

void vbe_flush(void *ghpdev)
{
    dftgraph_t *kghp = (dftgraph_t *)ghpdev;

    u64_t *s = (u64_t *)((uint_t)kghp->gh_fvrmphyadr);
    u64_t *d = (u64_t *)((uint_t)kghp->gh_framphyadr);
    u64_t i = 0, j = 0;
    u64_t e = kghp->gh_x * kghp->gh_y * kghp->gh_onepixbyte;
    for (; i < e; i += 8)
    {
        d[j] = s[j];
        j++;
    }
    return;
}

sint_t vbe_set_bank(void *ghpdev, sint_t bnr)
{
    return -1;
}

pixl_t vbe_readpix(void *ghpdev, uint_t x, uint_t y)
{
    return 0;
}

void vbe_writepix(void *ghpdev, pixl_t pix, uint_t x, uint_t y)
{
    dftgraph_t *kghp = (dftgraph_t *)ghpdev;
    u8_t *p24bas;
    if (kghp->gh_onepixbits == 24)
    {
        u64_t p24adr = (x + (y * kghp->gh_x)) * 3;
        p24bas = (u8_t *)((uint_t)(p24adr + kghp->gh_fvrmphyadr));
        p24bas[0] = (u8_t)(pix);
        p24bas[1] = (u8_t)(pix >> 8);
        p24bas[2] = (u8_t)(pix >> 16);
        return;
    }
    u32_t *phybas = (u32_t *)((uint_t)kghp->gh_fvrmphyadr);
    phybas[x + (y * kghp->gh_x)] = pix;
    return;
}

pixl_t vbe_dxreadpix(void *ghpdev, uint_t x, uint_t y)
{

    return 0;
}

void vbe_dxwritepix(void *ghpdev, pixl_t pix, uint_t x, uint_t y)
{
    dftgraph_t *kghp = (dftgraph_t *)ghpdev;
    u8_t *p24bas;
    if (kghp->gh_onepixbits == 24)
    {
        u64_t p24adr = (x + (y * kghp->gh_x)) * 3;
        p24bas = (u8_t *)((uint_t)(p24adr + kghp->gh_framphyadr));
        p24bas[0] = (u8_t)(pix);
        p24bas[1] = (u8_t)(pix >> 8);
        p24bas[2] = (u8_t)(pix >> 16);
        return;
    }
    u32_t *phybas = (u32_t *)((uint_t)kghp->gh_framphyadr);
    phybas[x + (y * kghp->gh_x)] = pix;
    return;
}

sint_t vbe_set_xy(void *ghpdev, uint_t x, uint_t y)
{
    return -1;
}

sint_t vbe_set_vwh(void *ghpdev, uint_t vwt, uint_t vhi)
{
    return -1;
}

sint_t vbe_set_xyoffset(void *ghpdev, uint_t xoff, uint_t yoff)
{
    return -1;
}

sint_t vbe_get_xy(void *ghpdev, uint_t *rx, uint_t *ry)
{
    return -1;
}

sint_t vbe_get_vwh(void *ghpdev, uint_t *rvwt, uint_t *rvhi)
{
    return -1;
}

sint_t vbe_get_xyoffset(void *ghpdev, uint_t *rxoff, uint_t *ryoff)
{

    return -1;
}

// 清空屏幕 为黑色
void fill_graph(dftgraph_t *kghp, pixl_t pix)
{
    for (u64_t y = 0; y < kghp->gh_y; y++)
    {
        for (u64_t x = 0; x < kghp->gh_x; x++)
        {
            write_pixcolor(kghp, (u32_t)x, (u32_t)y, pix);
        }
    }
    flush_videoram(kghp);
    return;
}
// 刷新显存
void flush_videoram(dftgraph_t *kghp)
{
    kghp->gh_opfun.dgo_flush(kghp);
    return;
}

void set_charsdxwflush(u64_t chardxw, u64_t flush)
{
    kdftgh.gh_chardxw = chardxw;
    kdftgh.gh_flush = flush;
    return;
}

// 显示背景图片
void hal_background()
{
    dftgraph_t *kghp = &kdftgh;
    machbstart_t *kmbsp = &kmachbsp;
    u64_t fadr = 0, fsz = 0;
    get_file_rvadrandsz("background.bmp", kmbsp, &fadr, &fsz);
    if (0 == fadr || 0 == fsz)
    {
        system_error("lmosbkgderr");
    }
    bmdbgr_t *bmdp;
    u64_t img = fadr + sizeof(bmfhead_t) + sizeof(bitminfo_t);
    bmdp = (bmdbgr_t *)((uint_t)img);
    pixl_t pix;
    int k = 0, l = 0;
    for (int j = 768; j >= 0; j--, l++)
    {
        for (int i = 0; i < 1024; i++)
        {
            pix = BGRA(bmdp[k].bmd_r, bmdp[k].bmd_g, bmdp[k].bmd_b);
            drxw_pixcolor(kghp, i, j, pix);
            k++;
        }
    }
    hal_dspversion();
    return;
}

void write_pixcolor(dftgraph_t *kghp, u32_t x, u32_t y, pixl_t pix)
{
    kghp->gh_opfun.dgo_writepix(kghp, pix, x, y);
    return;
}

void drxw_pixcolor(dftgraph_t *kghp, u32_t x, u32_t y, pixl_t pix)
{

    kghp->gh_opfun.dgo_dxwritepix(kghp, pix, x, y);
    return;
}
// 显示系统版本、内存等信息
void hal_dspversion()
{
    pixl_t bkpx = set_deffontpx(BGRA(0xff, 0, 0));
    kprint(cosmos_version);
    kprint("系统处理器工作模式:%d位 系统物理内存大小:%dMB\n", (uint_t)kmachbsp.mb_cpumode, (uint_t)(kmachbsp.mb_memsz >> 20));
    set_deffontpx(bkpx);
    return;
}

pixl_t set_deffontpx(pixl_t setpx)
{
    dftgraph_t *kghp = &kdftgh;
    pixl_t bkpx = kghp->gh_deffontpx;
    kghp->gh_deffontpx = setpx;
    return bkpx;
}
// 显示logo
void hal_logo()
{
    dftgraph_t *kghp = &kdftgh;
    machbstart_t *kmbsp = &kmachbsp;
    u64_t fadr = 0, fsz = 0;
    get_file_rvadrandsz("logo.bmp", kmbsp, &fadr, &fsz);
    if (0 == fadr || 0 == fsz)
    {
        system_error("logoerr");
    }
    bmdbgr_t *bmdp;
    u64_t img = fadr + sizeof(bmfhead_t) + sizeof(bitminfo_t);
    bmdp = (bmdbgr_t *)((uint_t)img);
    pixl_t pix;
    int k = 0, l = 0;
    for (int j = 617; j >= 153; j--, l++)
    {
        for (int i = 402; i < 622; i++)
        {
            pix = BGRA(bmdp[k].bmd_r, bmdp[k].bmd_g, bmdp[k].bmd_b);
            drxw_pixcolor(kghp, i, j, pix);
            k++;
        }
        if (l > 205)
        {
            die(0x80);
        }
    }
    return;
}
