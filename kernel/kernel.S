[bits 32]
%define ERROR_CODE nop      ;若在相关的异常中 CPU 已经自动压入了,错误码，为保持栈中格式统一，这里不做操作
%define ZERO push 0         ;若在相关的异常中 CPU 没有压入错误码,为了统一栈中格式，就手工压入一个 0

extern put_str              ;声明外部函数

section .data
intr_str db "interrupt occur!", 0xa, 0
global intr_entry_table
intr_entry_table:

%macro VECTOR 2
section .text
intr%1entry:    ;每个中断处理程序都要压入中断向量号,所以一个中断类型一个中断处理程序,自己知道自己的中断向量号是多少
    %2
    push intr_str
    call put_str
    add esp, 4      ; 跳过参数

    ;如果是从片上进入的中断，除了往从片上发送 EOI 外，还要往主片上发送 EOI
    mov al, 0x20    ;中断结束命令 EOI
    out 0xa0, al    ;向从片发送
    out 0x20, al    ;向主片发送

    add esp, 4      ;跨过 error_code
    iret            ;从中断返回，32 位下等同指令 iretd

section .data
    dd intr%1entry  ;存储各个中断入口程序的地址,形成 intr_entry_table 数组
%endmacro

VECTOR 0X00, ZERO
VECTOR 0X01, ZERO
VECTOR 0X02, ZERO
VECTOR 0X03, ZERO
VECTOR 0X04, ZERO
VECTOR 0X05, ZERO
VECTOR 0X06, ZERO
VECTOR 0X07, ZERO
VECTOR 0X08, ZERO
VECTOR 0X09, ZERO
VECTOR 0X0a, ZERO
VECTOR 0X0b, ZERO
VECTOR 0X0c, ZERO
VECTOR 0X0d, ZERO
VECTOR 0X0e, ZERO
VECTOR 0X0f, ZERO
VECTOR 0X10, ZERO
VECTOR 0X11, ZERO
VECTOR 0X12, ZERO
VECTOR 0X13, ZERO
VECTOR 0X14, ZERO
VECTOR 0X15, ZERO
VECTOR 0X16, ZERO
VECTOR 0X17, ZERO
VECTOR 0X18, ZERO
VECTOR 0X19, ZERO
VECTOR 0X1a, ZERO
VECTOR 0X1b, ZERO
VECTOR 0X1c, ZERO
VECTOR 0X1d, ZERO
VECTOR 0X1e, ERROR_CODE
VECTOR 0X1f, ZERO
VECTOR 0X20, ZERO