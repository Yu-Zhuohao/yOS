# yOS – A Purely Assembly Operating System

[English](#english) | [中文](#chinese)

---

<a id="english"></a>
## English

### Introduction
yOS is a hobby operating system kernel written entirely in x86 assembly (NASM). It boots from real mode, switches to 32-bit protected mode, and provides a command-line interface with basic file system, disk management, and simple TUI applications.

### Features
- 32-bit protected mode with basic paging (2 MB identity mapping)
- FAT12 and FAT32 file system support (read/write)
- MBR partition table management (up to 4 partitions per disk)
- IDE PIO disk driver (primary/secondary, master/slave)
- Keyboard driver with Shift key support
- Simple process management (8 slots, round-robin scheduling)
- Memory bitmap allocator (2 MB physical memory)
- Text-mode VGA console (80×25) with color support
- Built-in command-line shell
- Several TUI (Text User Interface) applications:
  - File Manager (copy/paste/delete/rename)
  - Notepad (undo/redo, file I/O)
  - Calculator (integer arithmetic)
  - Calendar (RTC)
  - Disk Manager (partition and format)
  - Games (Guess Number, Tic-Tac-Toe)
- Basic system commands: reboot, shutdown, time, date, memory info, etc.

### Commands

#### System Commands
| Command | Description |
|---------|-------------|
| `cls` | Clear the screen |
| `time` | Show current time (from RTC) |
| `date` | Show current date |
| `shutdown` | Hard shutdown |
| `reboot` | Reboot the system |
| `output <text>` | Print the given text |
| `color <bg><fg>` | Set console color (two hex digits, e.g., `color 0f`) |
| `mem` | Show memory usage and process list |
| `ver` | Show system version |
| `devinfo` | Show hardware information |
| `help [n]` | Show help page (n=1..3) |

#### Disk and Partition Commands
| Command | Description |
|---------|-------------|
| `disk list` | List all present disks |
| `disk sel <n>` | Select disk (1..4) |
| `disk part [-size MB]` | Partition the selected disk (create one partition with optional size in MB) |
| `disk del allpart` | Delete all partitions on the selected disk |
| `part list` | List partitions on the selected disk |
| `part sel <n>` | Select a partition (1..4) |
| `part fm [-fs fat12/fat32]` | Format the selected partition (default FAT12) |
| `part del` | Delete the selected partition |
| `dl list` | List all mounted drive letters |

#### File System Commands
| Command | Description |
|---------|-------------|
| `ls` | List files in current directory |
| `cd <path>` | Change directory (absolute or relative) |
| `write <text> -2 <file>` | Write text to a file |
| `read <file>` | Display the content of a file |
| `crdir <name>` | Create a directory |
| `dedir <name>` | Delete a directory (wildcard `*` supported) |
| `del <name>` | Delete a file (wildcard `*` supported) |
| `copy <src> <dst>` | Copy a file or directory (wildcard `*` supported) |
| `mov <src> <dst>` | Move a file or directory (wildcard `*` supported) |

#### TUI Applications
| Command | Description |
|---------|-------------|
| `tui` | Enter the Text User Interface |

### Building & Running

**Prerequisites**: [NASM](https://www.nasm.us/) assembler, an x86 emulator (e.g., [QEMU](https://www.qemu.org/)) or real hardware.

```bash
# Assemble boot sector and kernel
nasm -f bin boot.asm -o boot.bin
nasm -f bin kernel.asm -o kernel.bin

# Create a disk image (e.g., 4MB)

#Linux：
dd if=/dev/zero of=disk.vhd bs=1M count=4

#Windows：
DISKPART> create vdisk file="C:\Users\Download\yOS\src\disk.vhd" maximum=4 type=fixed

# Write boot sector
dd if=boot.bin of=disk.vhd bs=512 count=1 conv=notrunc

# Write kernel (255 sectors, starting at sector 1)
dd if=kernel.bin of=disk.vhd bs=512 count=255 seek=1 conv=notrunc
```

Alternatively, run `build.bat` (Windows) to automate the process.

**Run with QEMU**:
```bash
qemu-system-i386 -drive file=disk.vhd,format=raw -m 64M
```

### Known Issues

Unknown

### License & Credits

Developed independently by **YuZhuohao**.

- Version: `snapshot_0.62`
- Language: Pure x86 Assembly
- License: GPL-3.0


---

<a id="chinese"></a>
## 中文

### 简介
yOS 是一个完全用 x86 汇编语言（NASM 语法）编写的操作系统内核。它从实模式启动，切换到 32 位保护模式，提供命令行界面，并支持基本的文件系统、磁盘管理和简单的 TUI（文本用户界面）应用程序。

### 功能特性
- 32 位保护模式，支持基本分页（2 MB 恒等映射）
- FAT12 和 FAT32 文件系统（读写支持）
- MBR 分区表管理（支持最多 4 个分区）
- IDE PIO 磁盘驱动（主/从，主/次通道）
- 键盘驱动（支持 Shift 键）
- 简单进程管理（8 个槽位，轮询调度）
- 内存位图分配器（2 MB 物理内存）
- 文本模式 VGA 控制台（80×25），支持颜色
- 内置命令行 Shell
- 多个 TUI 应用程序：
  - 文件管理器（复制/粘贴/删除/重命名）
  - 记事本（撤销/重做，文件读写）
  - 计算器（整数运算）
  - 日历（RTC）
  - 磁盘管理器（分区和格式化）
  - 游戏（猜数字、井字棋）
- 基本系统命令：重启、关机、时间、日期、内存信息等

### 命令

#### 系统命令
| 命令 | 说明 |
|------|------|
| `cls` | 清屏 |
| `time` | 显示当前时间（从 RTC 读取） |
| `date` | 显示当前日期 |
| `shutdown` | 硬关机 |
| `reboot` | 重启系统 |
| `output <文本>` | 输出指定文本 |
| `color <背景><前景>` | 设置控制台颜色（两位十六进制，例如 `color 0f`） |
| `mem` | 显示内存使用情况和进程列表 |
| `ver` | 显示系统版本 |
| `devinfo` | 显示硬件信息 |
| `help [n]` | 显示帮助页（n=1..3） |

#### 磁盘与分区命令
| 命令 | 说明 |
|------|------|
| `disk list` | 列出所有磁盘 |
| `disk sel <n>` | 选择磁盘（1..4） |
| `disk part [-size MB]` | 对当前磁盘分区（创建一个分区，可选指定大小 MB） |
| `disk del allpart` | 删除当前磁盘的所有分区 |
| `part list` | 列出当前磁盘的分区 |
| `part sel <n>` | 选择分区（1..4） |
| `part fm [-fs fat12/fat32]` | 格式化当前分区（默认 FAT12） |
| `part del` | 删除当前分区 |
| `dl list` | 列出所有已挂载的盘符 |

#### 文件系统命令
| 命令 | 说明 |
|------|------|
| `ls` | 列出当前目录内容 |
| `cd <路径>` | 切换目录（绝对或相对） |
| `write <文本> -2 <文件>` | 将文本写入文件 |
| `read <文件>` | 显示文件内容 |
| `crdir <名称>` | 创建目录 |
| `dedir <名称>` | 删除目录（支持通配符 `*`） |
| `del <名称>` | 删除文件（支持通配符 `*`） |
| `copy <源> <目标>` | 复制文件或目录（支持通配符 `*`） |
| `mov <源> <目标>` | 移动文件或目录（支持通配符 `*`） |

#### TUI 应用程序
| 命令 | 说明 |
|------|------|
| `tui` | 进入文本用户界面 |

### 构建与运行

**前置条件**：[NASM](https://www.nasm.us/) 汇编器，x86 模拟器（如 [QEMU](https://www.qemu.org/)）或真实硬件。

```bash
# 汇编引导扇区和内核
nasm -f bin boot.asm -o boot.bin
nasm -f bin kernel.asm -o kernel.bin

## 创建磁盘镜像（例如 4MB）

#Linux：
dd if=/dev/zero of=disk.vhd bs=1M count=4

#Windows：
DISKPART> create vdisk file="C:\Users\Download\yOS\src\disk.vhd" maximum=4 type=fixed

# 写入引导扇区
dd if=boot.bin of=disk.vhd bs=512 count=1 conv=notrunc

# 写入内核（255 个扇区，从扇区 1 开始）
dd if=kernel.bin of=disk.vhd bs=512 count=255 seek=1 conv=notrunc
```

或者运行 `build.bat`（Windows）自动完成。

**使用 QEMU 运行**：
```bash
qemu-system-i386 -drive file=disk.vhd,format=raw -m 64M
```

### 已知问题

未知

### 许可与致谢

由 **YuZhuohao** 个人独立开发

- 版本：`snapshot_0.62`
- 语言：纯 x86 汇编
- 协议：GPL-3.0