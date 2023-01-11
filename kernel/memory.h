#ifndef __KERNEL_MEMORY_H 
#define __KERNEL_MEMORY_H 
#include "stdint.h" 
#include "bitmap.h"

/* 虚拟地址池，用于虚拟地址管理 */ 
struct virtual_addr { 
    struct bitmap vaddr_bitmap; // 虚拟地址用到的位图结构
    uint32_t vaddr_start; // 虚拟地址起始地址
}; 

/* 内存池标记，用于判断用哪个内存池 */ 
enum pool_flags { 
    PF_KERNEL = 1,  // 内核内存池
    PF_USER = 2     // 用户内存池
}; 

#define PG_P_1 1    // 此页内存已存在
#define PG_P_0 0    // 此页内存不存在
#define PG_RW_R 0   // 此页内存允许读/执行
#define PG_RW_W 2   // 此页内存允许读/写/执行
#define PG_US_S 0   // 系统级, 只允许特权级别为 0、1、2 的程序访问此页内存，3 特权级程序不被允许
#define PG_US_U 4   // 用户级, 允许所有特权级别程序访问此页内存

extern struct pool kernel_pool,user_pool;
void* vaddr_get(enum pool_flags pf,uint32_t pg_cnt);
uint32_t* pte_ptr(uint32_t vaddr);
uint32_t* pde_ptr(uint32_t vaddr);
void* palloc(struct pool* m_pool);
void page_table_add(void* _vaddr,void* _page_phyaddr);
void* malloc_page(enum pool_flags pf,uint32_t pg_cnt);
void* get_kernel_pages(uint32_t pg_cnt);
void* get_user_pages(uint32_t pg_cnt);
void* get_a_page(enum pool_flags pf,uint32_t vaddr);
uint32_t addr_v2p(uint32_t vaddr);
void mem_pool_init(uint32_t all_mem);
void mem_init(void);

#endif