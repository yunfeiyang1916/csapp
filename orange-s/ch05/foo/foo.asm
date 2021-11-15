;编译链接方法
  
;导入比较函数
extern choose
;数据区
[section .data]
    num1st              dd      5
    num2nd              dd      4

;代码区
[section .text]
    global _start   ;导出入口，以便让链接器识别
    global myprint  ;导出函数，以便让bar.c使用

    _start:
        push dword [num2nd] ;参数入栈，后面的参数先入栈
        push dword [num1st]
        call choose         ;choose(num1st,num2nd)
        add esp,8

        mov ebx,0
        mov eax,1
        int     0x80            ; 系统调用

    ; void myprint(char* msg, int len)
    myprint:
        mov     edx, [esp + 8]  ; len
        mov     ecx, [esp + 4]  ; msg
        mov     ebx, 1
        mov     eax, 4          ; sys_write
        int     0x80            ; 系统调用
        ret