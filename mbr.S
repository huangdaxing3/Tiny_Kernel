; ; 主引导程序 
; ; ------------------------------------------------------------
; %include "boot.inc"
; SECTION MBR vstart=0x7c00 ;起始地址编译在0x7c00
;     mov ax,cs
;     mov ds,ax
;     mov es,ax
;     mov ss,ax
;     mov fs,ax
;     mov sp,0x7c00
;     mov ax,0xb800  ; ax为文本信号起始区
;     mov gs,ax      ; gs = ax 充当段基址的作用
    
;     		   ; ah = 0x06 al = 0x00 想要调用int 0x06的BIOS提供的中断对应的函数 
;     		   ; 即向上移动即完成清屏功能
;     		   ; cx dx 分别存储左上角与右下角的左边 详情看int 0x06函数调用
;     mov ax,0x600
;     mov bx,0x700
;     mov cx,0
;     mov dx,0x184f
    
;     ;调用BIOS中断
;     int 0x10 

;     		   ;新增功能 直接操作显存部分
;     		   ;低位字节储存ascii字符 小端储存内存顺序相反
;     mov byte [gs:0x00],'K' 
    
;     		   ;背景储存在第二个字节 含字符与背景属性
;     mov byte [gs:0x01],0xA4    
    
;     mov byte [gs:0x02],'Y' 
;     mov byte [gs:0x03],0xA4
    
;     mov byte [gs:0x04],'A' 
;     mov byte [gs:0x05],0xA4
    
;     mov byte [gs:0x06],'N' 
;     mov byte [gs:0x07],0xA4
    
;     mov byte [gs:0x08],'I' 
;     mov byte [gs:0x09],0xA4
    
;     mov byte [gs:0x0A],' ' 
;     mov byte [gs:0x0B],0xA4
    
;     mov byte [gs:0x0C],'O' 
;     mov byte [gs:0x0D],0xA4
    
;     mov byte [gs:0x0E],'S' 
;     mov byte [gs:0x0F],0xA4
    
;                    ; 思考一下 在输出完“Love 6OS后 按照书上的逻辑是要把磁盘读入 
;                    ; 先把配置信息给送到寄存器中”
    
;     		   ; 为什么要送到 eax中呢 因为IN OUT IO接口 
;     		   ; 规定的就是dx里面存放的是端口号 ax是需要或者输送的信息
;     mov eax,LOADER_START_SECTOR    
;     mov bx,LOADER_BASE_ADDR ;把要目标内存位置放进去 bx常作地址储存
;     mov cx,4;读取磁盘数 cx常作计数
;     call rd_disk_m_16

;     jmp LOADER_BASE_ADDR ; 直接当跳跳熊 开跳0x600
; ;------------------------------------------------------------------------
; ;读取第二块硬盘
; rd_disk_m_16:
; ;------------------------------------------------------------------------
; ;1 写入待操作磁盘数
; ;2 写入LBA 低24位寄存器 确认扇区
; ;3 device 寄存器 第4位主次盘 第6位LBA模式 改为1
; ;4 command 写指令
; ;5 读取status状态寄存器 判断是否完成工作
; ;6 完成工作 取出数据
 
;  ;;;;;;;;;;;;;;;;;;;;;
;  ;1 写入待操作磁盘数
;  ;;;;;;;;;;;;;;;;;;;;;
;     mov esi,eax   ; !!! 备份eax
;     mov di,cx     ; !!! 备份cx
    
;     mov dx,0x1f2  ; 0x1F2为Sector Count 端口号 送到dx寄存器中
;     mov al,cl     ; !!! 忘了只能由ax al传递数据
;     out dx,al     ; !!! 这里修改了 原out dx,cl
    
;     mov eax,esi   ; !!!袄无! 原来备份是这个用 前面需要ax来传递数据 麻了
    
; ;;;;;;;;;;;;;;;;;;;;;
; ;2 写入LBA 24位寄存器 确认扇区
; ;;;;;;;;;;;;;;;;;;;;;
;     mov dx,0x1f3  ; LBA low
;     out dx,al 

;     mov cl,0x8    ; shr 右移8位 把24位给送到 LBA low mid high 寄存器中
;     shr eax,cl    ; eax为32位 ax为16位 eax的低位字节 右移8位即8~15
;     mov dx,0x1f4  ; LBA mid
;     out dx,al
    
;     shr eax,cl
;     mov dx,0x1f5
;     out dx,al
    
; ;;;;;;;;;;;;;;;;;;;;;
; ;3 device 寄存器 第4位主次盘 第6位LBA模式 改为1
; ;;;;;;;;;;;;;;;;;;;;;

    		 
;     		  ; 24 25 26 27位 尽管我们知道ax只有2 但还是需要按规矩办事 
;     		  ; 把除了最后四位的其他位置设置成0
;     shr eax,cl
    
;     and al,0x0f 
;     or al,0xe0   ;!!! 把第四-七位设置成0111 转换为LBA模式
;     mov dx,0x1f6 ; 参照硬盘控制器端口表 Device 
;     out dx,al

; ;;;;;;;;;;;;;;;;;;;;;
; ;4 向Command写操作 Status和Command一个寄存器
; ;;;;;;;;;;;;;;;;;;;;;

;     mov dx,0x1f7 ; Status寄存器端口号
;     mov al,0x20  ; 0x20是读命令
;     out dx,al
    
; ;;;;;;;;;;;;;;;;;;;;;
; ;5 向Status查看是否准备好惹 
; ;;;;;;;;;;;;;;;;;;;;;
    
; 		   ;设置不断读取重复 如果不为1则一直循环
;   .not_ready:     
;     nop           ; !!! 空跳转指令 在循环中达到延时目的
;     in al,dx      ; 把寄存器中的信息返还出来
;     and al,0x88   ; !!! 0100 0100 0x88
;     cmp al,0x08
;     jne .not_ready ; !!! jump not equal == 0
    
; ;;;;;;;;;;;;;;;;;;;;;
; ;6 读取数据
; ;;;;;;;;;;;;;;;;;;;;;

;     mov ax,di      ;把 di 储存的cx 取出来
;     mov dx,256
;     mul dx        ;与di 与 ax 做乘法 计算一共需要读多少次 方便作循环 低16位放ax 高16位放dx
;     mov cx,ax      ;loop 与 cx相匹配 cx-- 当cx == 0即跳出循环
;     mov dx,0x1f0
;  .go_read_loop:
;     in ax,dx      ;两字节dx 一次读两字
;     mov [bx],ax
;     add bx,2
;     loop .go_read_loop
    
;     ret ;与call 配对返回原来的位置 跳转到call下一条指令
        
;     times 510 - ($ - $$) db 0 
;     db 0x55,0xaa

; 主引导程序
 ;
 ; LOADER_BASE_ADDR equ 0xA000
 ; LOADER_START_SECTOR equ 0x2
 ;------------------------------------------------------------ 
 %include "boot.inc"
 SECTION MBR vstart=0x7c00 
    mov ax,cs 
    mov ds,ax 
    mov es,ax 
    mov ss,ax 
    mov fs,ax 
    mov sp,0x7c00 
    mov ax,0xb800      ; 显存文本模式中，其内存地址是 0xb8000
    mov gs,ax
 
; 清屏
; 利用 0x06 号功能,上卷全部行,则可清屏｡
; ----------------------------------------------------------- 
; INT 0x10   功能号:0x06   功能描述:上卷窗口
;------------------------------------------------------ 
; 输入: 
; AH 功能号= 0x06 
; AL = 上卷的行数(如果为 0,表示全部) 
; BH = 上卷行属性
;(CL,CH) = 窗口左上角的(X,Y)位置
; (DL,DH) = 窗口右下角的(X,Y)位置
; 无返回值: 
    mov ax, 0x600 
    mov bx, 0x700 
    mov cx, 0         ; 左上角: (0, 0) 
    mov dx, 0x184f    ; 右下角: (80,25), 
                      ; VGA 文本模式中,一行只能容纳 80 个字符,共 25 行｡
                      ; 下标从 0 开始,所以 0x18=24,0x4f=79 
    int 10h           ; int 0x10  

; 输出背景色绿色，前景色红色，并且跳动的字符串"1 MBR"
    ; 把字符 1 的 ASCII 码写入以 gs：0x00 为起始，大小为 1 字节的内存中。word、dword 分别表示 2 字节和 4 字节
    mov byte [gs:0x00],'1'  ; 往以 gs 为数据段基址，以 0 为偏移地址的内存中写入字符 1 的 ASCII 码
    mov byte [gs:0x01],0xA4 ; A 表示绿色背景闪烁，4 表示前景色为红色

    mov byte [gs:0x02],' '
    mov byte [gs:0x03],0xA4

    mov byte [gs:0x04],'M'
    mov byte [gs:0x05],0xA4

    mov byte [gs:0x06],'B' 
    mov byte [gs:0x07],0xA4

    mov byte [gs:0x08],'R'
    mov byte [gs:0x09],0xA4

    mov eax,LOADER_START_SECTOR   ; 起始扇区 lba 地址
    mov bx,LOADER_BASE_ADDR       ; 写入的地址
    mov cx,4                      ; 待读入的扇区数
    call rd_disk_m_16             ; 在 16 位模式下读硬盘 ; 以下读取程序的起始部分(一个扇区)

    jmp LOADER_BASE_ADDR  + 0x300

;------------------------------------------------------------------------------- 
; 功能:读取硬盘 n 个扇区
rd_disk_m_16: 
;------------------------------------------------------------------------------- 
; eax=LBA 扇区号
; bx=将数据写入的内存地址
; cx=读入的扇区数

    mov esi,eax      ;备份 eax
    mov di,cx        ;备份cx
; 读写硬盘:
; 第 1 步:设置要读取的扇区数
    mov dx,0x1f2 
    mov al,cl 
    out dx,al        ;读取的扇区数
    
    mov eax,esi      ;恢复 ax

; 第 2 步:将 LBA 地址存入 0x1f3 ～ 0x1f6
    ; LBA 地址 7～0 位写入端口 0x1f3
    mov dx,0x1f3
    out dx,al

    ; LBA 地址 15～8 位写入端口 0x1f4
    mov cl,8
    shr eax,cl
    mov dx,0x1f4
    out dx,al

    ; LBA 地址 23～16 位写入端口 0x1f5
    shr eax,cl
    mov dx,0x1f5
    out dx,al

    shr eax,cl 
    and al,0x0f         ; lba 第 24～27 位
    or al,0xe0          ; 设置 7～4 位为 1110,表示 lba 模式
    mov dx,0x1f6 
    out dx,al 

; 第 3 步:向 0x1f7 端口写入读命令,0x20 
    mov dx,0x1f7 
    mov al,0x20 
    out dx,al  

; 第 4 步:检测硬盘状态
  .not_ready: 
    ;同一端口,写时表示写入命令字,读时表示读入硬盘状态
    nop 
    in al,dx 
    and al,0x88     ;第 4 位为 1 表示硬盘控制器已准备好数据传输
                    ;第 7 位为 1 表示硬盘忙
    cmp al,0x08 
    jnz .not_ready  ;ZF若等于 0，则 status 寄存器的第 4 位为 1，这表示可以读数据了 
                    ;若不等于 0，说明 status 寄存器的第 4 位为 0，表示硬盘正忙（此时 status 寄存器第 7 位肯定为 1）
                    ;若未准备好,继续等
                    ;.not_ready是个标号，于是跳回去继续判断硬盘状态，直到硬盘把数据准备好才跳出这个循环
    
; 第 5 步:从 0x1f0 端口读数据
    mov ax, di 
    mov dx, 256 
    mul dx 
    mov cx, ax 
    ; di 为要读取的扇区数,一个扇区有 512 字节,每次读入一个字
    ; 共需 di*512/2 次,所以 di*256 
    mov dx, 0x1f0 
  .go_on_read: 
    in ax,dx 
    mov [bx],ax 
    add bx,2 
    loop .go_on_read 
    ret
 
; message db "1 MBR" 
times 510-($-$$) db 0 
db 0x55,0xaa