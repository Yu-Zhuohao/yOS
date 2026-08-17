yOS - A Purely Assembly Operating System

yOS is an experimental operating system project written in pure x86 assembly. It demonstrates core operating system concepts including bootloading, real-mode to protected-mode transition, IDE disk I/O, FAT12 file system support, memory management, process scheduling, and a command-line shell interface.

Key Features

· Dual-mode Operation: Starts in 16-bit real mode, transitions to 32-bit protected mode
· IDE Disk Support: Full IDE driver with LBA addressing, disk detection, and partition management
· FAT12 File System: Complete implementation supporting file read/write, directory navigation, creation, and deletion
· Command Shell: Interactive shell with built-in commands for file system and system management
· Memory Management: Basic page-based allocation with 4KB granularity and process memory tracking
· Process Scheduling: Simple round-robin scheduler with process state management

Commands

Command     Description

·cln #Clear screen

·time #Show current system time

·shutdown #Soft shutdown

·reboot #Reboot the system

·output <text> #Print text

·dl list #List assigned drive letters

·disk list #List physical disk drives

·disk sel <n> #Select disk drive

·disk part #Partition selected disk

·part list #List partitions

·part sel <n> #Select partition

·part fm #Format partition as FAT12

·ls #List directory contents

·cd <path> #Change directory

·write <text> -2 <file> #Write content to file

·read <file> #Display file contents

·crdir <name> #Create directory

·dedir <name> #Delete directory

·del <file> #Delete file

·mem #Show memory usage and process list

·copy <src> <dst> #Copy file

·cut <src> <dst> #Move file

·help #Show command list

File Structure

```
yOS/
├── build.bat   → Build script
└── src/
      ├── boot/
      │    └── boot.asm   → Load the kernel from disk
      └── kernel/
            ├── kernel.asm → Real mode entry, switch to protected mode
            ├── io.asm     → VGA text output, keyboard input
            ├── fs.asm     → IDE drive, FAT12 file system
            ├── mem.asm    → Pagination, memory allocator, PCB management
            └── shell.asm  → Command interpreter
```

Build Requirements

· NASM assembler
· x86 emulator (QEMU recommended or VMware) or real hardware

Building

```bash
nasm -f bin boot.asm -o boot.bin
nasm -f bin kernel.asm -o kernel.bin

dd if=boot.bin of=disk.vhd bs=512 count=1 conv=notrunc
dd if=kernel.bin of=disk.vhd bs=512 count=64 seek=1 conv=notrunc
```
Or
```bash
.\build.bat
```

Known BUGs:

1. to a directory with too many levels and then returning to the parent level may cause an error (subdirectories might disappear). It's recommended not to create directories deeper than 4 levels.

2. Disk drives won't be recognized after a system restart (the dl list command won't show drive letters).

3. There are issues with the copy/paste commands.

Project Information:

· Name: yOS

· Version: snapshot_0.21

About

Developed independently by YuZhuohao

-----以下是中文版-----

yOS - 一个纯汇编操作系统

yOS 是一个使用纯 x86 汇编编写的实验性操作系统项目。它展示了核心操作系统概念，包括引导加载、实模式到保护模式切换、IDE磁盘I/O、FAT12文件系统支持、内存管理、进程调度以及命令行Shell界面。

主要特性

· 双模式运行：从16位实模式启动，切换到32位保护模式
· IDE磁盘支持：完整的IDE驱动，支持LBA寻址、磁盘检测和分区管理
· FAT12文件系统：完整实现，支持文件读写、目录导航、创建和删除
· 命令行Shell：交互式Shell，内置文件和系统管理命令
· 内存管理：基于分页的内存分配，4KB粒度，支持进程内存跟踪
· 进程调度：简单的轮转调度器，支持进程状态管理

命令列表

命令     说明
·cln #清屏

·time #显示当前时间

·shutdown #软关机

·reboot #重启系统

·output <文本> #打印文本

·dl list #列出盘符

·disk list #列出物理磁盘

·disk sel <n> #选择磁盘

·disk part #分区当前磁盘

·part list #列出分区

·part sel <n> #选择分区

·part fm #格式化为FAT12

·ls #列出目录内容

·cd <路径> #切换目录

·write <文本> -2 <文件> #写入文件

·read <文件> #显示文件内容

·crdir <名称> #创建目录

·dedir <名称> #删除目录

·del <文件> #删除文件

·mem #显示内存和进程信息

·copy <源> <目标> #复制文件

·cut <源> <目标> #移动文件

·help #显示命令列表

文件结构

```
yOS/
├── build.bat   → 构建脚本
└── src/
      ├── boot/
      │    └── boot.asm   → 从磁盘加载内核
      └── kernel/
            ├── kernel.asm → 实模式入口，切换到保护模式
            ├── io.asm     → VGA文本输出，键盘输入
            ├── fs.asm     → IDE驱动，FAT12文件系统
            ├── mem.asm    → 分页，内存分配器，PCB管理
            └── shell.asm  → 命令解释器
```

构建要求

· NASM 汇编器
· x86仿真器（推荐QEMU或VMware）或真实硬件

构建

```bash
nasm -f bin boot.asm -o boot.bin
nasm -f bin kernel.asm -o kernel.bin

dd if=boot.bin of=disk.vhd bs=512 count=1 conv=notrunc
dd if=kernel.bin of=disk.vhd bs=512 count=64 seek=1 conv=notrunc
```
或者
```bash
.\build.bat
```

已知BUGs:

1.当进入层数过多的目录并返回上一级时可能会出错(下一级目录可能会消失)，建议不要创建超过4层的目录

2.系统重启后不会识别到磁盘驱动器(使用dl list 命令无法列出盘符)

3.复制/剪切命令有问题

项目信息:

· 名称 : yOS

· 版本 : snapshot_0.21

关于

#由YuZhuohao个人独立开发
