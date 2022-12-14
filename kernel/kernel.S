[bits 32]
%define ERROR_CODE nop      ;若在相关的异常中 CPU 已经自动压入了,错误码，为保持栈中格式统一，这里不做操作
%define ZERO push 0         ;若在相关的异常中 CPU 没有压入错误码,为了统一栈中格式，就手工压入一个 0
extern put_str              ;声明外部函数
extern idt_table            ;idt_table 是 C 中注册的中断处理程序数组

section .data
global intr_entry_table
intr_entry_table:

%macro VECTOR 2
section .text
intr%1entry:    ;每个中断处理程序都要压入中断向量号,所以一个中断类型一个中断处理程序,自己知道自己的中断向量号是多少

    %2              ; 中断若有错误码会压在 eip 后面
    ; 以下是保存上下文环境
    push ds 
    push es 
    push fs 
    push gs 
    pushad ; PUSHAD 指令压入 32 位寄存器，其入栈顺序是：EAX,ECX,EDX,EBX,ESP,EBP,ESI,EDI,EAX 最先入栈

    ;如果是从片上进入的中断,除了往从片上发送 EOI 外，还要往主片上发送 EOI
    mov al,0x20 ; 中断结束命令 EOI 
    out 0xa0,al ; 向从片发送
    out 0x20,al ; 向主片发送

    push %1 ;不管 idt_table 中的目标程序是否需要参数,都一律压入中断向量号，调试时很方便
    call [idt_table + %1*4] ; 调用 idt_table 中的 C 版本中断处理函数
    jmp intr_exit

section .data
    dd intr%1entry  ;存储各个中断入口程序的地址,形成 intr_entry_table 数组
%endmacro

section .text 
global intr_exit 
intr_exit: 
    ; 以下是恢复上下文环境
    add esp, 4      ; 跳过中断号
    popad 
    pop gs 
    pop fs
    pop es 
    pop ds 
    add esp, 4      ; 跳过 error_code 
    iretd

VECTOR 0X00, ZERO
VECTOR 0X01, ZERO
VECTOR 0X02, ZERO
VECTOR 0X03, ZERO
VECTOR 0X04, ZERO
VECTOR 0X05, ZERO
VECTOR 0X06, ZERO
VECTOR 0X07, ZERO
VECTOR 0X08, ERROR_CODE
VECTOR 0X09, ZERO
VECTOR 0X0a, ERROR_CODE
VECTOR 0X0b, ERROR_CODE
VECTOR 0X0c, ERROR_CODE
VECTOR 0X0d, ERROR_CODE
VECTOR 0X0e, ERROR_CODE
VECTOR 0X0f, ZERO
VECTOR 0X10, ZERO
VECTOR 0X11, ERROR_CODE
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
VECTOR 0x20,ZERO ;时钟中断对应的入口
VECTOR 0x21,ZERO ;键盘中断对应的入口
VECTOR 0x22,ZERO ;级联用的
VECTOR 0x23,ZERO ;串口 2 对应的入口
VECTOR 0x24,ZERO ;串口 1 对应的入口
VECTOR 0x25,ZERO ;并口 2 对应的入口
VECTOR 0x26,ZERO ;软盘对应的入口
VECTOR 0x27,ZERO ;并口 1 对应的入口
VECTOR 0x28,ZERO ;实时时钟对应的入口
VECTOR 0x29,ZERO ;重定向
VECTOR 0x2a,ZERO ;保留
VECTOR 0x2b,ZERO ;保留
VECTOR 0x2c,ZERO ;ps/2 鼠标
VECTOR 0x2d,ZERO ;fpu 浮点单元异常
VECTOR 0x2e,ZERO ;硬盘
VECTOR 0x2f,ZERO ;保留