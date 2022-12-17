#include "io.h"
#include "print.h"
#include "timer.h"

#define IRQ0_FREQUENCY 	    100         // 时钟中断的频率 100Hz
#define INPUT_FREQUENCY     1193180     // 计数器 0 的工作脉冲信号频率
#define COUNTER0_VALUE		INPUT_FREQUENCY / IRQ0_FREQUENCY    // 计数器 0 的计数初值
#define COUNTER0_PORT		0X40        // 计数器 0 的端口号 0x40
#define COUNTER0_NO 		0           // 在控制字中选择计数器的号码，其值为 0，代表计数器 0
#define COUNTER_MODE		2           // 工作模式的代码，其值为 2，即方式 2: 比率发生器
#define READ_WRITE_LATCH	3           // 读写方式 3 表示先读写低 8 位，再读写高 8 位
#define PIT_COUNTROL_PORT	0x43        // 控制字寄存器的端口

/* 把操作的计数器 counter_no､ 读写锁属性 rwl､ 计数器模式counter_mode 写入模式控制寄存器并赋予初始值 counter_value */
static void frequency_set(uint8_t counter_port, uint8_t counter_no, uint8_t rwl, uint8_t counter_mode, uint16_t counter_value)
{
    /* 往控制字寄存器端口 0x43 中写入控制字 */
    outb(PIT_COUNTROL_PORT, (uint8_t) (counter_no << 6 | rwl << 4 | counter_mode << 1));
    /* 先写入 counter_value 的低 8 位 */
    outb(counter_port, (uint8_t)counter_value);
    /* 再写入 counter_value 的高 8 位 */
    outb(counter_port, (uint8_t)counter_value >> 8);
    // return;
} 

/* 初始化 PIT8253 */
void timer_init(void)
{
    put_str("timer_init start!\n");
    /* 设置 8253 的定时周期，也就是发中断的周期 */
    frequency_set(COUNTER0_PORT,       // 是计数器的端口号，用来指定初值 counter_value 的目的端口号
                  COUNTER0_NO,         // 在控制字中指定所使用的计数器号码，对应于控制字中的 SC1 和 SC2 位
                  READ_WRITE_LATCH,    // 来设置计数器的读/写/锁存方式，对应于控制字中的 RW1 和 RW0 位
                  COUNTER_MODE,        // 设置计数器的工作方式，对应于控制字中的 M2～M0 位
                  COUNTER0_VALUE);     // 设置计数器的计数初值
    put_str("timer_init done!\n");
    // return;
}
