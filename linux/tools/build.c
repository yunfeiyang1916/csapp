/*
 * 个生成内核磁盘映像文件的工具程序 build.c。该程序将被单
独编译成可执行文件，并在 Makefile 文件中被调用运行，用于将所有内核编译代码连接和合并成一个可
运行的映像文件 Image。
 */
/*
 * 该程序从三个不同的程序中创建磁盘映像文件：
 *
 * - bootsect：该文件的 8086 机器码最长为 510 字节，用于加载其他程序。
 * - setup：该文件的 8086 机器码最长为 4 个磁盘扇区，用于设置系统参数。
 * - system：实际系统的 80386 代码。
 *
 * 该程序首先检查所有程序模块的类型是否正确，并将检查结果在终端上显示出来，
 * 然后删除模块头部并扩充大正确的长度。该程序也会将一些系统数据写到 stderr。
 */

/*
 * tytso 对该程序作了修改，以允许指定根文件设备。
 *
 * 添加了指定交换设备功能：Linus 20.12.91
 */

#include <stdio.h> /* fprintf */                 // 使用其中的 fprintf()函数。
#include <string.h>                              // 字符串操作函数。
#include <stdlib.h> /* contains exit */          // 含 exit 函数原型说明。
#include <sys/types.h> /* unistd.h needs this */ // 该头文件供 unistd.h 文件使用。
#include <sys/stat.h>                            // 含文件状态信息结构定义。
#include <linux/fs.h>                            // 文件系统头文件。
#include <unistd.h> /* contains read/write */    // 含 read/write 函数原型说明。
#include <fcntl.h>                               // 包含文件操作模式符号常数。

#define MINIX_HEADER 32 // minix 二进制目标文件模块头部长度为 32 字节。
#define GCC_HEADER 1024 // GCC 头部信息长度为 1024 字节。

#define SYS_SIZE 0x3000 // system 文件最长节数(字节数为 SYS_SIZE*16=128KB)。

// 默认地把 Linux 根文件系统所在设备设置为在第 2 个硬盘的第 1 个分区上（即设备号为 0x0306），
// 是因为 Linus 当时开发 Linux 时，把第 1 个硬盘用作 MINIX 系统盘，而第 2 个硬盘用作为 Linux
// 的根文件系统盘。
#define DEFAULT_MAJOR_ROOT 3 // 默认根设备主设备号 - 3（硬盘）。
#define DEFAULT_MINOR_ROOT 6 // 默认根设备次设备号 - 6（第 2 个硬盘的第 1 分区）。

#define DEFAULT_MAJOR_SWAP 0 // 默认交换设备主设备号。
#define DEFAULT_MINOR_SWAP 0 // 默认交换设备次设备号。

/* 下面指定 setup 模块占的最大扇区数：不要改变该值，除非也改变 bootsect 等相应文件。*/
#define SETUP_SECTS 4 // setup 最大长度为 4 个扇区（2KB）。

#define STRINGIFY(x) #x // 把 x 转换成字符串类型，用于出错显示语句中。

// 显示出错信息，并终止程序。
void die(char *str)
{
    fprintf(stderr, "%s\n", str);
    exit(1);
}

// 显示程序使用方法，并退出。
void usage(void)
{
    die("Usage: build bootsect setup system [rootdev] [> image]");
}

// 主程序开始。
int main(int argc, char **argv)
{
    int i, c, id;
    char buf[1024];
    char major_root, minor_root;
    char major_swap, minor_swap;
    struct stat sb;

    // 首先检查 build 程序执行时实际命令行参数个数，并根据参数个数作相应设置。如果 build 程序
    // 命令行参数个数不是 4 到 6 个（程序名算作 1 个），则显示程序用法并退出。
    if ((argc < 4) || (argc > 6))
        usage();
    // 若程序命令行上有多于 4 个参数，那么如果根设备名不是软盘（"FLOPPY"），则取该设备文件的
    // 状态信息。若取状态出错则显示信息并退出，否则取该设备名状态结构中的主设备号和次设备号
    // 作为根设备号。如果根设备就是 FLOPPY 设备，则让主设备号和次设备号取 0。表示根设备是当前
    // 启动引导设备。
    if (argc > 4)
    {
        if (strcmp(argv[4], "FLOPPY"))
        {
            if (stat(argv[4], &sb))
            {
                perror(argv[4]);
                die("Couldn't stat root device.");
            }
            major_root = MAJOR(sb.st_rdev); // 取设备名状态结构中设备号。
            minor_root = MINOR(sb.st_rdev);
        }
        else
        {
            major_root = 0;
            minor_root = 0;
        }
        // 若参数只有 4 个，则让主设备号和次设备号等于系统默认的根设备号。
    }
    else
    {
        major_root = DEFAULT_MAJOR_ROOT;
        minor_root = DEFAULT_MINOR_ROOT;
    }
    // 若程序命令行上有 6 个参数，那么如果最后一个表示交换设备的参数不是无（"NONE"），则取该
    // 设备文件的状态信息。若取状态出错则显示信息并退出，否则取该设备名状态结构中的主设备号
    // 和次设备号作为交换设备号。如果最后一个参数就是"NONE"，则让交换设备的主设备号和次设备
    // 号取为 0。表示交换设备就是当前启动引导设备。
    if (argc == 6)
    {
        if (strcmp(argv[5], "NONE"))
        {
            if (stat(argv[5], &sb))
            {
                perror(argv[5]);
                die("Couldn't stat root device.");
            }
            major_swap = MAJOR(sb.st_rdev); // 取设备名状态结构中设备号。
            minor_swap = MINOR(sb.st_rdev);
        }
        else
        {
            major_swap = 0;
            minor_swap = 0;
        }
        // 若参数没有 6 个而是 5 个，表示命令行上没有带交换设备名。于是就让交换设备主设备号和次设备
        // 号等于系统默认的交换设备号。
    }
    else
    {
        major_swap = DEFAULT_MAJOR_SWAP;
        minor_swap = DEFAULT_MINOR_SWAP;
    }
    // 接下来在标准错误终端上显示上面所选择的根设备主、次设备号和交换设备主、次设备号。如果
    // 主设备号不等于 2（软盘）或 3（硬盘），也不为 0（取系统默认设备），则显示出错信息并退出。
    // 终端的标准输出被定向到文件 Image，因此被用于输出保存内核代码数据，生成内核映像文件。
    fprintf(stderr, "Root device is (%d, %d)\n", major_root, minor_root);
    fprintf(stderr, "Swap device is (%d, %d)\n", major_swap, minor_swap);
    if ((major_root != 2) && (major_root != 3) &&
        (major_root != 0))
    {
        fprintf(stderr, "Illegal root device (major = %d)\n",
                major_root);
        die("Bad root device --- major #");
    }
    if (major_swap && major_swap != 3)
    {
        fprintf(stderr, "Illegal swap device (major = %d)\n",
                major_swap);
        die("Bad root device --- major #");
    }
    // 下面开始执行读取各个文件内容并进行相应的复制处理。首先初始化 1KB 的复制缓冲区，置全 0。
    // 然后以只读方式打开参数 1 指定的文件（bootsect）。从中读取 32 字节的 MINIX 执行文件头结构
    // 内容（参见列表后说明）到缓冲区 buf 中。
    for (i = 0; i < sizeof buf; i++)
        buf[i] = 0;
    if ((id = open(argv[1], O_RDONLY, 0)) < 0)
        die("Unable to open 'boot'");
    if (read(id, buf, MINIX_HEADER) != MINIX_HEADER)
        die("Unable to read header of 'boot'");
    // 接下来根据 MINIX 头部结构判断 bootsect 是否为一个有效的 MINIX 执行文件。若是，则从文件中
    // 读取 512 字节的引导扇区代码和数据。
    // 0x0301 - MINIX 头部 a_magic 魔数；0x10 - a_flag 可执行；0x04 - a_cpu, Intel 8086 机器码。
    if (((long *)buf)[0] != 0x04100301)
        die("Non-Minix header of 'boot'");
    // 判断头部长度字段 a_hdrlen（字节）是否正确（32 字节）。（后三字节正好没有用，是 0）
    if (((long *)buf)[1] != MINIX_HEADER)
        die("Non-Minix header of 'boot'");
    // 判断数据段长 a_data 字段(long)内容是否为 0。
    if (((long *)buf)[3] != 0)
        die("Illegal data segment in 'boot'");
    // 判断堆 a_bss 字段(long)内容是否为 0。
    if (((long *)buf)[4] != 0)
        die("Illegal bss in 'boot'");
    // 判断执行点 a_entry 字段(long)内容是否为 0。
    if (((long *)buf)[5] != 0)
        die("Non-Minix header of 'boot'");
    // 判断符号表长字段 a_sym 的内容是否为 0。
    if (((long *)buf)[7] != 0)
        die("Illegal symbol table in 'boot'");
    // 在上述判断都正确的条件下读取文件中随后的实际代码数据，应该返回读取字节数为 512 字节。
    // 因为 bootsect 文件中包含的是 1 个扇区的引导扇区代码和数据，并且最后 2 字节应该是可引导
    // 标志 0xAA55。
    i = read(id, buf, sizeof buf);
    fprintf(stderr, "Boot sector %d bytes.\n", i);
    if (i != 512)
        die("Boot block must be exactly 512 bytes");
    if ((*(unsigned short *)(buf + 510)) != 0xAA55)
        die("Boot block hasn't got boot flag (0xAA55)");
    // 引导扇区的 506、507 偏移处需存放交换设备号，508、509 偏移处需存放根设备号。
    buf[506] = (char)minor_swap;
    buf[507] = (char)major_swap;
    buf[508] = (char)minor_root;
    buf[509] = (char)major_root;
    // 然后将该 512 字节的数据写到标准输出 stdout，若写出字节数不对，则显示出错信息并退出。
    // 在 linux/Makefile 中，build 程序标准输出被重定向到内核映像文件名 Image 上，因此引导
    // 扇区代码和数据会被写到 Image 开始的 512 字节处。最后关闭 bootsect 模块文件。
    i = write(1, buf, 512);
    if (i != 512)
        die("Write call failed");
    close(id);

    // 下面以只读方式打开参数 2 指定的文件（setup）。从中读取 32 字节的 MINIX 执行文件头结构
    // 内容到缓冲区 buf 中。处理方式与上面相同。首先以只读方式打开指定的文件 setup。从中读
    // 取 32 字节的 MINIX 执行文件头结构内容到缓冲区 buf 中。
    if ((id = open(argv[2], O_RDONLY, 0)) < 0)
        die("Unable to open 'setup'");
    if (read(id, buf, MINIX_HEADER) != MINIX_HEADER)
        die("Unable to read header of 'setup'");
    // 接下来根据 MINIX 头部结构判断 setup 是否为一个有效的 MINIX 执行文件。若是，则从文件中
    // 读取 512 字节的引导扇区代码和数据。
    // 0x0301- MINIX 头部 a_magic 魔数；0x10- a_flag 可执行；0x04- a_cpu, Intel 8086 机器码。
    if (((long *)buf)[0] != 0x04100301)
        die("Non-Minix header of 'setup'");
    // 判断头部长度字段 a_hdrlen（字节）是否正确（32 字节）。（后三字节正好没有用，是 0）
    if (((long *)buf)[1] != MINIX_HEADER)
        die("Non-Minix header of 'setup'");
    // 判断数据段长字段 a_data、堆字段 a_bss、起始执行点字段 a_entry 和符号表字段 a_sym 的内容
    // 是否为 0。必须都为 0。
    if (((long *)buf)[3] != 0) // 数据段长 a_data 字段。
        die("Illegal data segment in 'setup'");
    if (((long *)buf)[4] != 0) // 堆 a_bss 字段。
        die("Illegal bss in 'setup'");
    if (((long *)buf)[5] != 0) // 执行起始点 a_entry 字段。
        die("Non-Minix header of 'setup'");
    if (((long *)buf)[7] != 0)
        die("Illegal symbol table in 'setup'");
    // 在上述判断都正确的条件下读取文件中随后的实际代码数据，并且写到终端标准输出。同时统计
    // 写的长度（i），并在操作结束后关闭 setup 文件。之后判断一下利用 setup 执行写操作的代码
    // 和数据长度值，该值不能大于(SETUP_SECTS * 512)字节，否则就得重新修改 build、bootsect
    // 和 setup 程序中设定的 setup 所占扇区数并重新编译内核。若一切正常就显示 setup 实际长度值。
    for (i = 0; (c = read(id, buf, sizeof buf)) > 0; i += c)
        if (write(1, buf, c) != c)
            die("Write call failed");
    close(id); //关闭 setup 模块文件。
    if (i > SETUP_SECTS * 512)
        die("Setup exceeds " STRINGIFY(SETUP_SECTS) " sectors - rewrite build/boot/setup");
    fprintf(stderr, "Setup is %d bytes.\n", i);
    // 在将缓冲区 buf 清零之后，判断实际写的 setup 长度与(SETUP_SECTS4*512)的数值差，若 setup
    // 长度小于该长度（4*512 字节），则用 NULL 字符将 setup 填足为 4*512 字节。
    for (c = 0; c < sizeof(buf); c++)
        buf[c] = '\0';
    while (i < SETUP_SECTS * 512)
    {
        c = SETUP_SECTS * 512 - i;
        if (c > sizeof(buf))
            c = sizeof(buf);
        if (write(1, buf, c) != c)
            die("Write call failed");
        i += c;
    }

    // 下面开始处理 system 模块文件。该文件使用 gas 编译，因此具有 GNU a.out 目标文件格式。
    // 首先以只读方式打开文件，并读取其中 a.out 格式头部结构信息（1KB 长度）。在判断 system
    // 是一个有效的 a.out 格式文件之后，就把该文件随后的所有数据都写到标准输出（Image 文件）
    // 中，并关闭该文件。然后显示 system 模块的长度。若 system 代码和数据长度超过 SYS_SIZE 节
    // （即 128KB 字节），则显示出错信息并退出。若无错，则返回 0，表示正常退出。
    if ((id = open(argv[3], O_RDONLY, 0)) < 0)
        die("Unable to open 'system'");
    if (read(id, buf, GCC_HEADER) != GCC_HEADER)
        die("Unable to read header of 'system'");
    if (((long *)buf)[5] != 0) // 执行入口点字段 a_entry 值应为 0。
        die("Non-GCC header of 'system'");
    for (i = 0; (c = read(id, buf, sizeof buf)) > 0; i += c)
        if (write(1, buf, c) != c)
            die("Write call failed");
    close(id);
    fprintf(stderr, "System is %d bytes.\n", i);
    if (i > SYS_SIZE * 16)
        die("System is too big");
    return (0);
}
