%include "boot.inc"
SECTION loader vstart=LOADER_BASE_ADDR
LOADER_STACK_TOP equ LOADER_BASE_ADDR 
jmp loader_start

;构建 gdt 及其内部的描述符
GDT_BASE: dd 0x00000000 
        dd 0x00000000 

;代码段描述符
CODE_DESC: dd 0x0000FFFF 
        dd DESC_CODE_HIGH4 
           
;数据段和栈段描述符
DATA_STACK_DESC: dd 0x0000FFFF  ;低 2 字节的 FFFF 是段界限的第 0～15 位，高 2 字节的 0000 是段基址的第 0～15 位
                dd DESC_DATA_HIGH4
                 
;显存段描述符
VIDEO_DESC: dd 0x80000007           ;limit=(0xbffff-0xb8000)/4k=0x7 
            dd DESC_VIDEO_HIGH4     ;此时 dpl 为 0 

GDT_SIZE equ $ - GDT_BASE
GDT_LIMIT equ GDT_SIZE - 1
times 59 dq 0               ; 此处预留 60 个描述符的空位
times 5 db 0
SELECTOR_CODE equ (0x0001<<3) + TI_GDT + RPL0   ; 相当于(CODE_DESC - GDT_BASE)/8 + TI_GDT + RPL0 
SELECTOR_DATA equ (0x0002<<3) + TI_GDT + RPL0   ; 同上
SELECTOR_VIDEO equ (0x0003<<3) + TI_GDT + RPL0  ; 同上

; total_mem_bytes 用于保存内存容量，以字节为单位，此位置比较好记
; 当前偏移 loader.bin 文件头 0x200 字节
; loader.bin 的加载地址是 0x900 
; 故 total_mem_bytes 内存中的地址是 0xb00 
; 将来在内核中咱们会引用此地址
total_mem_bytes dd 0 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;以下是 gdt 的指针，前 2 字节是 gdt 界限，后 4 字节是 gdt 起始地址

gdt_ptr dw GDT_LIMIT 
        dd GDT_BASE 

; ;人工对齐:total_mem_bytes4+gdt_ptr6+ards_buf244+ards_nr2，共 256 字节
ards_buf times 244 db 0 
ards_nr dw 0 ;用于记录 ARDS 结构体数量

; loadermsg db '2 loader in real.' 
    
loader_start:
    
    mov sp,LOADER_BASE_ADDR                                   ;先初始化了栈指针
    xor ebx,ebx                                               ;异或自己 即等于0
    mov ax,0                                       
    mov es,ax                                                 ;心有不安 还是把es给初始化一下
    mov di,ards_buf                                           ;di指向缓冲区位置
.e820_mem_get_loop:
    mov eax,0x0000E820                                            ;每次都需要初始化
    mov ecx,0x14                       ;ARDS 地址范围描述符结构大小是 20 字节
    mov edx,0x534d4150
    
    int 0x15                                                  ;调用了0x15中断
    jc  .e820_failed_so_try_e801       ;若 cf 位为 1 则有错误发生，尝试 0xe801 子功能
    add di,cx			       ;使 di 增加 20 字节指向缓冲区中新的 ARDS 结构位置
    inc word [ards_nr]                 ;记录 ARDS 数量
    cmp ebx,0                          ;若 ebx 为 0 且 cf 不为 1，这说明 ards 全部返回
    jne .e820_mem_get_loop             ;直至读取完全结束 则进入下面的处理时间
    
    ;在所有 ards 结构中
    ;找出(base_add_low + length_low)的最大值，即内存的容量
    mov cx,[ards_nr]
    ;遍历每一个 ARDS 结构体,循环次数是 ARDS 的数量
    mov ebx,ards_buf
    xor edx,edx         ;edx 为最大的内存容量，在此先清 0 
.find_max_mem_area:
    ;无需判断 type 是否为 1,最大的内存块一定是可被使用的
    mov eax,[ebx]	;base_add_low
    add eax,[ebx+8]     ;length_low
    add ebx,20    	;指向缓冲区中下一个 ARDS 结构
    cmp edx,eax
    ;冒泡排序,找出最大,edx 寄存器始终是最大的内存容量
    jge .next_ards
    mov edx,eax         ;edx 为总内存大小

.next_ards:
    loop .find_max_mem_area
    jmp .mem_get_ok

;------ int 15h ax = E801h 获取内存大小，最大支持 4G ------ 
; 返回后, ax cx 值一样,以 KB 为单位，bx dx 值一样，以 64KB 为单位
; 在 ax 和 cx 寄存器中为低 16MB，在 bx 和 dx 寄存器中为 16MB 到 4GB 
.e820_failed_so_try_e801:
    int 0x15                            ; 76
    jc .e801_failed_so_try_88           ;若当前 e801 方法失败，就尝试 0x88 方法
   
; 1 先算出来低15MB的内存    
; ax 和 cx 中是以 KB 为单位的内存数量，将其转换为以 byte 为单位
    mov cx,0x400                ;cx 和 ax 值一样，cx 用作乘数
    mul cx                      ;低位放在ax 高位放在了dx
    shl edx,16                  ;dx把低位的16位以上的书往上面抬 变成正常的数
    and eax,0x0000FFFF          ;把除了16位以下的 16位以上的数清零 防止影响
    or edx,eax                  ;15MB以下的数 暂时放到了edx中
    add edx,0x100000            ;ax 只是 15MB，故要加 1MB
    mov esi,edx                 ;先把低 15MB 的内存容量存入 esi 寄存器备份
    
; 2 接着算16MB以上的内存转换为 byte 为单位
; 寄存器 bx 和 dx 中是以 64KB 为单位的内存数量
    xor eax,eax
    mov ax,bx
    mov ecx,0x10000            ;0x10000为64KB  64*1024  
    mul ecx                    ;32 位乘法，默认的被乘数是 eax，积为 64 位
    mov edx,esi
    add edx,eax                ;edx 为总内存大小
    jmp .mem_get_ok

;----- int 15h ah = 0x88 获取内存大小，只能获取 64MB 之内 ----- 
.e801_failed_so_try_88:
    ;int 15 后，ax 存入的是以 KB 为单位的内存容量
     mov ah,0x88
     int 0x15
     jc .error_hlt
     and eax,0x0000FFFF
     ;16 位乘法，被乘数是 ax，积为 32 位。积的高 16 位在 dx 中 ;积的低 16 位在 ax 中
     mov cx,0x400       ;0x400 等于 1024,将 ax 中的内存容量换为以 byte 为单位
     mul cx
     shl edx,16         ;把 dx 移到高 16 位
     or edx,eax         ;把积的低 16 位组合到 edx，为 32 位的积
     add edx,0x100000   ;0x88 子功能只会返回 1MB 以上的内存

.error_hlt:
     jmp $

;将内存换为 byte 单位后存入 total_mem_bytes 处
.mem_get_ok:
     mov [total_mem_bytes],edx
; --------------------------------- 设置进入保护模式 -----------------------------
; 1 打开A20 gate
; 2 加载gdt
; 3 将cr0 的 pe位置1

;----------------- 打开 A20 ----------------     
    in al,0x92                 ;端口号0x92 中 第1位变成1即可
    or al,0000_0010b
    out 0x92,al
   

;----------------- 加载 GDT ----------------
    lgdt [gdt_ptr]
    

;----------------- cr0 第 0 位置 1 ----------------
    mov eax,cr0                ;cr0寄存器第0位设置位1
    or  eax,0x00000001              
    mov cr0,eax
      
;-------------------------------- 已经打开保护模式 ---------------------------------------
    jmp dword SELECTOR_CODE:p_mode_start          ;刷新流水线
 
 [bits 32]
 p_mode_start: 
    mov ax,SELECTOR_DATA
    mov ds,ax
    mov es,ax
    mov ss,ax
    mov esp,LOADER_STACK_TOP
    mov ax,SELECTOR_VIDEO
    mov gs,ax
    
    mov byte [gs:160],'P'

;------------------------------- 加载内核到缓冲区 -------------------------------------------------

    mov eax, KERNEL_START_SECTOR
    mov ebx, KERNEL_BIN_BASE_ADDR
    
    mov ecx,200
    call rd_disk_m_32

    ; 创建页目录及页表并初始化页内存位图
    call setup_page 
    ;要将描述符表地址及偏移量写入内存 gdt_ptr，一会儿用新地址重新加载
    sgdt [gdt_ptr] ; 存储到原来 gdt 所有的位置
    
    ;将 gdt 描述符中视频段描述符中的段基址+0xc0000000 
    mov ebx, [gdt_ptr + 2] 
    or dword [ebx + 0x18 + 4], 0xc0000000 
    ;视频段是第 3 个段描述符，每个描述符是 8 字节，故 0x18 
    ;段描述符的高 4 字节的最高位是段基址的第 31～24 位

    ;将 gdt 的基址加上 0xc0000000 使其成为内核所在的高地址
    add dword [gdt_ptr + 2], 0xc0000000 
    
    add esp, 0xc0000000 ; 将栈指针同样映射到内核地址
    
    ; 把页目录地址赋给 cr3 
    mov eax, PAGE_DIR_TABLE_POS 
    mov cr3, eax 
    
    ; 打开 cr0 的 pg 位（第 31 位）
    mov eax, cr0 
    or eax, 0x80000000 
    mov cr0, eax 
    
    ;在开启分页后，用 gdt 新的地址重新加载
    lgdt [gdt_ptr] ; 重新加载

    mov byte [gs:160], 'V' 
    
;---------跳转到内核区-----------    
    jmp SELECTOR_CODE:enter_kernel

enter_kernel:
    call kernel_init					          ;根据我们的1M以下的内存分布区 综合考虑出的数据
    mov  esp,0xc009f000
    jmp  KERNEL_ENTRY_POINT
    
    jmp $

setup_page:
;先把页目录项占用的空间逐字节清0
    mov ecx, 4096
    mov esi, 0
.clear_page_dir:
    mov byte [PAGE_DIR_TABLE_POS + esi], 0
    inc esi
    loop .clear_page_dir

;开始创建页目录项
.create_pde:             ; 创建 Page Directory Entry
    mov eax, PAGE_DIR_TABLE_POS
    add eax, 0x1000      ;此时 eax 为第一个页表的位置及属性
    mov ebx, eax         ;此处为 ebx 赋值，是为.create_pte 做准备，ebx 为基址

    ; 下面将页目录项 0 和 0xc00 都存为第一个页表的地址，每个页表表示 4MB 内存
    ; 这样 0xc03fffff 以下的地址和 0x003fffff 以下的地址都指向相同的页表
    ; 这是为将地址映射为内核地址做准备
    ; 页目录项的属性位
    or eax, PG_US_U | PG_RW_W | PG_P
    ; 页目录项的属性 RW 和 P 位为 1，US 为 1，表示用户属性，所有特权级别都可以访问
    ; 页目录项0和0xc00都存入第一个也标的地址, 每个页表表示4MB内存
    mov [PAGE_DIR_TABLE_POS + 0x0], eax   ; 第一个目录项
    ; 在页目录表中的第 1 个目录项写入第一个页表的位置(0x101000)及属性(7)
    mov [PAGE_DIR_TABLE_POS + 0xc00], eax

    ; 一个页表项占用 4 字节
    ; 0xc00 表示第 768 个页表占用的目录项，0xc00 以上的目录项用于内核空间
    ;也就是页表的 0xc0000000～0xffffffff 共计 1G 属于内核
    ; 0x0～0xbfffffff 共计 3G 属于用户进程
    ;最后一个页目录项指向页目录表自己
    sub eax, 0x1000
    mov [PAGE_DIR_TABLE_POS + 4092], eax

    ;创建页表项,将物理内存低端的1M内存映射到的第一张页表,
    ;这张页表的地址在前面也同时映射在页目录项的0和0xc00处
    mov ecx, 256    ; 1M 低端内存 / 每页大小 4k = 256
    mov esi, 0
    mov edx, PG_US_U | PG_RW_W | PG_P   ; 属性为 7，US=1，RW=1，P=1
.create_pte:
    mov [ebx + esi * 4], edx
    ; 此时的 ebx 已经在上面通过 eax 赋值为 0x101000，也就是第一个页表的地址
    add edx, 4096
    inc esi
    loop .create_pte

    ;为内核空间创建所有的页目录项, 分配其余254个页表,最后一个自己的物理地址
    ;实现用户进程共享内核空间
    mov eax, PAGE_DIR_TABLE_POS
    add eax, 0x2000    ; 此时 eax 为第二个页表的位置
    or eax, PG_US_U | PG_RW_W | PG_P   ; 页目录项的属性 US､ RW 和 P 位都为 1
    mov ebx, PAGE_DIR_TABLE_POS
    mov ecx, 254      ; 范围为第 769～1022 的所有目录项数量
    mov esi, 769 ;0xc00 / 4

.create_kernel_pde:
    mov [ebx + esi * 4], eax
    inc esi
    add eax, 0x1000
    loop .create_kernel_pde
    ret

;------------将kernel.bin中的segment拷贝到编译的地址-------------
kernel_init:
    xor eax, eax
    xor ebx, ebx    ;ebx记录程序头表地址
    xor ecx, ecx    ;cx记录程序头表中的program headers, e_phnum段的个数
    xor edx, edx    ;dx记录program header尺寸, 即e_phentsize

    mov dx, [KERNEL_BIN_BASE_ADDR + 42] 
    mov ebx, [KERNEL_BIN_BASE_ADDR + 28]

    add ebx, KERNEL_BIN_BASE_ADDR
    mov cx, [KERNEL_BIN_BASE_ADDR + 44]

.each_segment:
    cmp byte [ebx + 0], PT_NULL ; 若 p_type 等于 PT_NULL，说明此 program header 未使用
    je .PTNULL

    ; 为函数 memcpy 压入参数，参数是从右往左依然压入
    ; 函数原型类似于 memcpy（dst，src，size）
    push dword [ebx + 16]           ;ebx+16 p_filesz, 本段在文件中的大小

    mov eax, [ebx + 4]              ;p_offset本段在文件内的起始偏移地址
    add eax, KERNEL_BIN_BASE_ADDR   ;加上 kernel.bin 被加载到的物理地址，eax 为该段的物理地址
    push eax                        ;压入memcpy的第二个参数,源地址               
    push dword [ebx + 8]            ;p_vaddr本段在内存中的起始虚拟地址
                                    ;压入memcpy的第一个参数,目的地址
    
    ;完成段复制
    call mem_cpy        
    add esp, 12                     ;清理压入栈中的参数

.PTNULL:
    add ebx, edx                    ;edx 为 program header 大小，即 e_phentsize, 使ebx指向下一个program header

    
    loop .each_segment
    ret

;---------- 逐字节拷贝 mem_cpy（dst，src，size） ------------ 
;输入:栈中三个参数（dst，src，size）
;输出:无
;---------------------------------------------------------
mem_cpy:
    cld
    push ebp
    mov ebp, esp
    push ecx            ; rep 指令用到了 ecx
                        ; 但 ecx 对于外层段的循环还有用，故先入栈备份
    mov edi, [ebp + 8]  ; dst
    mov esi, [ebp + 12] ; src
    mov ecx, [ebp + 16] ; size          
    rep movsb                       ;逐字节拷贝 

    ; 恢复环境
    pop ecx
    pop ebp
    ret

;----------------------------------------------------------
rd_disk_m_32: 
                        ;eax=LBA扇区号
                        ;ebx=将数据写入的内存地址
                        ;ecx=读入的扇区数
    mov esi, eax ;
    mov di, cx

    mov dx, 0x1f2
    mov al,cl
    out dx, al

    mov eax, esi

    ;0x173, 0x174, 0x175表示LBA模式的0~23位 
    mov dx, 0x1f3
    out dx, al

    mov cl, 8
    shr eax, cl
    mov dx, 0x1f4
    out dx, al

    shr eax, cl
    mov dx, 0x1f5
    out dx, al

    shr eax, cl
    and al, 0x0f         ;0x1f6端口0~3位表示LBA模式的24~27位
    or al, 0xe0          ;第5,7位为1, 第4位dev(主盘或从盘), 第6位MOD位(寻址模式LBA:!, CHS:0)
    mov dx, 0x1f6
    out dx, al

    mov dx, 0x1f7        ;0x1f7端口写操作时commmand寄存器,0x20,即读硬盘
    mov al, 0x20
    out dx, al

.not_ready:
    nop
    in al, dx            ;同一端口,写时表示写入命令字,读时表示读入硬盘状态
    and al, 0x88         ;第三位为1表示硬盘控制器已准备好数据传输
                         ;第7位为1表示硬盘忙
    cmp al, 0x08
    jnz .not_ready

;第五步:从0x1f0端口读数据
    mov ax, di
    mov dx, 256
    mul dx         ;dx:ax<-dx*ax
    mov cx, ax     
;di为要读取的扇区数,一个扇区有512字节,每次读入一个字
    mov dx, 0x1f0

.go_on_read:
    in ax, dx
    mov [ebx], ax
    add ebx, 2
    loop .go_on_read
    ret