/*输出大小端字节序*/
#include <stdio.h>
#include <string.h>

typedef unsigned char *byte_pointer;

// 输出二进制
void print_byte(char num)
{
    int k;
    char *p = (char *)&num;
    for (int k = 7; k >= 0; k--) //处理8个位
    {
        if (*p & (1 << k))
            printf("1");
        else
            printf("0");
    }
    printf(" ");
}
// 输出字节序
void show_bytes(byte_pointer start, size_t len)
{
    size_t i;
    for (i = 0; i < len; i++)
    {
        printf("%.2x ", start[i]);
    }
    printf("\n");
    // 输出二进制
    for (i = 0; i < len; i++)
    {
        print_byte(start[i]);
    }
    printf("\n");
}
// 输出整型字节序
void show_int(int x)
{
    show_bytes((byte_pointer)&x, sizeof(int));
}

void show_float(float x)
{
    show_bytes((byte_pointer)&x, sizeof(float));
}
// 输出指针字节序
void show_pointer(void *x)
{
    show_bytes((byte_pointer)&x, sizeof(void *));
}
// 输出字符串
void show_str(char *x)
{
    show_bytes((byte_pointer)x, strlen(x));
}

// 测试输出字节序
void test_show_bytes()
{
    int ival = 12345;
    float fval = (float)ival;
    int *pval = &ival;
    show_int(ival);
    show_float(fval);
    show_pointer(pval);
    char *s = "abcdef";
    show_str(s);
}
// 测试补码
void testT()
{
    short x = -12345;
    printf("x=%d\n", x);
    show_bytes((byte_pointer)&x, sizeof(short));

    unsigned short mx = (unsigned short)x;
    printf("mx=%d\n", mx);
    show_bytes((byte_pointer)&mx, sizeof(short));

    int ix = (int)x;
    printf("ix=%d\n", ix);
    show_bytes((byte_pointer)&ix, sizeof(int));

    unsigned ux = (unsigned)mx;
    printf("ux=%d\n", ux);
    show_bytes((byte_pointer)&ux, sizeof(unsigned));
}
// 测试截断
void testCut()
{
    int x = 53191;
    printf("x=%d\n", x);
    show_bytes((byte_pointer)&x, sizeof(int));

    short sx = (short)x;
    printf("x=%d\n", sx);
    show_bytes((byte_pointer)&sx, sizeof(short));

    int y = sx;
    printf("x=%d\n", y);
    show_bytes((byte_pointer)&y, sizeof(int));
}

int main()
{
    //test_show_bytes(val);
    //testT();
    testCut();
    return 0;
}