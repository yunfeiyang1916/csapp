; 两种系统调用的使用方式
section .data
; 使用库函数调用显示的提示字符
str_c_lib db "c lib call:hello world!",0xa
str_c_lib_len equ $-str_c_lib 

; 使用中断调用显示的提示字符
str_syscall db "syscall:hello world!",0xa
str_syscall_len equ $-str_syscall

section .text
global _start
_start:
    ; 1、模拟c语言中使用库函数调用
    push str_c_lib_len      ; 按照c语言约定入栈
    push str_c_lib
    push 1                  ; 1为标准输出的文件描述符
    call .simu_write
    add esp,12              ; 回收栈空间

    ; 2、跨过库函数，直接使用中断调用
    mov eax,4
    mov ebx,1
    mov ecx,str_syscall
    mov edx,str_syscall_len
    int 0x80

    ; 退出程序
    mov eax,1               ; 功能化1为exit退出函数
    int 0x80


; 模拟c库函数的内部实现
.simu_write:
    push ebp
    mov ebp,esp
    mov eax,4               ; 第4号子功能为write函数
    mov ebx,[ebp+8]         ; 第一个参数，文件描述符
    mov ecx,[ebp+12]        ; 第二个参数，字符串
    mov edx,[ebp+16]        ; 第三个参数，字符串大小
    int 0x80                ; 发起中断
    pop ebp
    ret