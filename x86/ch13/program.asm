;用户程序

;--------用户程序头部段-----------------------------------------------------------------------
section header vstart=0
    program_length dd program_end       ;[0x00]程序总长度，双字，32位
    head_len dd header_end              ;[0x04]头部段长度，也用于接收头部段选择子
    stack_seg dd 0                      ;[0x08]用于接收用户栈段选择子，栈的创建由内核程序为何
    stack_len dd 1                      ;[0x0c]用户栈的长度，单位为4kb，由用户程序定义，内核会读取该值
    code_entry dd start                 ;[0x10]代码段入口
    code_seg dd section.code.start      ;[0x14]代码段偏移地址，也用于接收代码段选择子
    code_len dd code_end                ;[0x18]代码段长度
    data_seg dd section.data.start      ;[0x1c]数据段偏移地址
    data_len dd data_end                ;[0x20]数据段长度

    ;以下是符号地址检索表，也就是导出的内核函数库
    salt_items dd (header_end-salt)/256 ;[0x24]导出函数数量，每个函数256字节     

    salt:   
        PrintString dd '@PrintString'   ;[0x28]
            times 256-($-PrintString) db 0  ;每个函数长度为256字节，不足256的用0补充
         TerminateProgram db  '@TerminateProgram'   ;终止用户程序
            times 256-($-TerminateProgram) db 0           
         ReadDiskData     db  '@ReadDiskData'
            times 256-($-ReadDiskData) db 0

    header_end:

;--------数据段段-----------------------------------------------------------------------
section data vstart=0
    buffer times 1024 db  0         ;缓冲区
    ;运行提示
    message_1       db  0x0d,0x0a,0x0d,0x0a
                    db  '**********User program is runing**********'
                    db  0x0d,0x0a,0
    
    message_2       db  '  Disk data:',0x0d,0x0a,0
    data_end:
[bits 32]
;--------代码段-----------------------------------------------------------------------
section code vstart=0
    start:
        mov eax,ds
        mov fs,eax          ;使fs段也指向头部段

        mov eax,[stack_seg]
        mov ss,eax
        mov esp,0           ;设置用户程序栈

        mov eax,[data_seg]
        mov ds,eax          ;设置用户数据段

        mov ebx,message_1
        call far [fs:PrintString]   ;调用内核通用代码库

        mov eax,100         ;逻辑扇区100
        mov ebx,buffer      ;缓冲区
        call far [fs:ReadDiskData]  ;读取磁盘

        mov ebx,message_2
        call far [fs:PrintString]

        mov ebx,buffer
        call far [fs:PrintString]   ;输出磁盘数据

        jmp far [fs:TerminateProgram]   ;结束用户程序，将控制权交给内核
    code_end:

;--------尾部段-----------------------------------------------------------------------
section trail align=16
    program_end:                    ;程序结尾标号，因为段没有定义vstart,所以该标号的偏移地址是从程序头开始的