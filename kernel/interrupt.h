#ifndef __KERNEL_INTERRUPT_H
#define __KERNEL_INTERRUPT_H
#include "stdint.h"
typedef void* intr_handler;

//中断门描述符结构体
struct gate_desc;

extern uint32_t syscall_handler(void);

//初始化中断描述符
void idt_desc_init(void);
//初始化可编程中断控制器
void pic_init(void);

//完成有关中断的所有初始化工作
void idt_init(void);
void general_intr_handler(uint8_t vec_nr);
void exception_init(void);
void register_handler(uint8_t vector_no, intr_handler function);

/* 定义中断的两种状态: 
 * INTR_OFF 值为 0，表示关中断
 * INTR_ON 值为 1，表示开中断 */ 
enum intr_status {      // 中断状态
    INTR_OFF,       // 中断关闭
    INTR_ON         // 中断打开
}; 

enum intr_status intr_get_status(void); 
enum intr_status intr_set_status (enum intr_status); 
enum intr_status intr_enable (void); 
enum intr_status intr_disable (void);
#endif