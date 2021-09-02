;硬盘主引导扇区代码
;测试

section code        ;代码段
    start:
        mov ax,0x7c0
        mov ds,ax

        mov ax,start
        mov ax,section.data.start
        mov ax,section.header.start
        mov ax,[program_length]
        mov ax,[code_entry]    
        mov ax,[code_entry+2]
        mov ax,[realloc_tbl_len]
        mov ax,[code_segment]
        mov ax,[data_segment]
        mov ax,program_end
    jmp $
section data 
    ;数据段
    message db '1234567890'
    data_end:
section header
    program_length dd program_end   ;[0x00]程序总长度，双字，32位
    ;用户程序入口点
    code_entry dw start             ;[0x04]偏移地址
               dd section.code.start;[0x06]段地址
    
    realloc_tbl_len dw (header_end-realloc_begin)/4 ;段重定位表项个数[0x0a]
    
    realloc_begin:
    ;段重定位表           
        code_segment    dd section.code.start   ;[0x0c]
        data_segment    dd section.data.start   ;[0x14]

    header_end:                      ;段结束标号 

    program_end:
    times 510-72      db  0;剩余的字节数用0填充，'$$'表示当前段的起始地址，'$-$$'正好是当前程序的字节大小
                      db  0x55,0xaa;引导扇区结束标识
