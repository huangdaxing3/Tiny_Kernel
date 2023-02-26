# Tiny_Kernel

## 项目描述:
    本项目先加载BIOS，然后跳转到MBR引导接下来的程序Loader，从实模式进入保护模式，建立全局描述符表，启用内存分页机制，之后加载内核。逐步实现了线程调度, 内存管理, 进程管理。线程调度的本质是CPU定时将就绪队列中的任务切换, 这就需要实现中断定时器。锁采⽤信号量实现。内存管理采⽤位图管理, 为每个任务维护⼀个虚拟内存池。

## 开发环境
* 操作系统: Arch Linux 
* 类型: 64位
* 编译器版本: GCC 12.2.1
* nasm 版本: 2.15.05
* bochs 版本: 2.7   [安装方法](https://blog.csdn.net/weixin_51259834/article/details/128336021?spm=1001.2014.3001.5502)<br /> 

## 使用说明
* 安装gcc , bochs , dd , nasm , bximage
* 在主目录运行 **make all** 命令
* 在终端运行 **bochs -f bochsrc**命令

## 运行截图
![image](https://github.com/huangdaxing3/Tiny_Kernel/blob/master/%E8%BF%90%E8%A1%8C.png)

## 参考
* 《操作系统真相还原》