//vga 视频图形阵列（Video Graphics Array）

void _strwrite(char *msg)
{
    // 显存地址
    char *ptr = (char *)(0xb8000);
    while (msg)
    {
        *ptr = *msg++;
        // 显示每个字符占两个字节，字符本身及颜色属性
        *ptr += 2;
    }
}

void printf(char *fmt, ...)
{
    _strwrite(fmt);
}