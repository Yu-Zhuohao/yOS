# yOS – A Purely Assembly Operating System

[English](#english) | [中文](#chinese)

---

<a id="english"></a>
## English Version

**yOS** is an experimental operating system written entirely in x86 assembly language. It demonstrates core operating system concepts including bootloading, real‑to‑protected mode transition, IDE disk I/O, FAT12 file system support, memory management, process scheduling, and a command‑line shell with graphical TUI applications.

###  Key Features

- **Dual‑mode Execution** – Starts in 16‑bit real mode, then switches to 32‑bit protected mode with paging enabled.
- **Complete IDE Driver** – Supports LBA addressing, disk detection, MBR partition table parsing, and sector read/write operations.
- **FAT12 File System** – Full implementation with subdirectory support, file/directory create, read, write, delete, and navigation.
- **Interactive Shell** – Built‑in commands for system control, file management, and disk/partition operations.
- **Memory Management** – 4KB page‑based bitmap allocator with per‑process memory usage tracking.
- **Process Scheduling** – Simple round‑robin scheduler with process control blocks (PCBs) and states (READY/RUNNING).
- **TUI Desktop** – Graphical text‑mode menu with a **Calculator** and a **Notepad** (including file open/save dialogs).
- **CMOS RTC Support** – Read current time and date from the hardware clock.
- **Drive Letter Assignment** – Automatically mounts FAT12 partitions and assigns drive letters (A, B, …).

###  Command Reference

| Command                | Description |
|------------------------|-------------|
| `cln`                  | Clear the screen |
| `time`                 | Show current system time (HH:MM:SS) |
| `date`                 | Show current date (YYYY‑MM‑DD) |
| `shutdown`             | Soft shutdown (via ACPI) |
| `reboot`               | Reboot the system |
| `output <text>`        | Print arbitrary text to the console |
| `help [page]`          | Display command list (with paging) |
| `dl list`              | List assigned drive letters |
| `disk list`            | List physical IDE disks (primary/secondary master/slave) |
| `disk sel <n>`         | Select a physical disk |
| `disk part`            | Partition the selected disk (single FAT12 partition) |
| `part list`            | List partitions on the selected disk |
| `part sel <n>`         | Select a partition |
| `part fm`              | Format the selected partition as FAT12 |
| `ls`                   | List current directory contents |
| `cd <path>`            | Change directory (absolute or relative, e.g. `A/subdir`) |
| `write <text> -2 <file>` | Write text to a file (overwrites if exists) |
| `read <file>`          | Display file contents |
| `crdir <name>`         | Create a directory |
| `dedir <name>`         | Delete an empty directory |
| `del <file>`           | Delete a file |
| `del *`                | Delete all files in the current directory |
| `mem`                  | Show memory usage and process list (PID, status, memory, name) |
| `copy <src> <dst>`     | Copy a file or wildcard (`*`) to a destination directory |
| `mov <src> <dst>`      | Move (cut and paste) a file or wildcard |
| `color <bg><fg>`       | Set console color (two hex digits, e.g. `color 0f` for white on black) |
| `tui`                  | Enter the graphical TUI desktop |

###  TUI Applications

The `tui` command launches a text‑mode graphical environment with keyboard navigation:

- **Desktop Menu** – Lists applications and system actions.
- **Calculator** – Performs basic arithmetic (+, −, ×, ÷) with button or keyboard input. Supports digit entry, operators, clear, and backspace.[Please note that this feature is still in the testing phase and may have bugs]
- **Notepad** – A basic text editor with:
  - Insert/delete characters, arrow‑key cursor movement.
  - Undo/Redo (up to 4 levels).
  - Save/Open file dialogs with directory browsing.
  - File list and filename input.

###  File System & Storage

- **Partitioning**: Creates a single MBR partition on the selected disk.
- **Formatting**: Formats a partition as FAT12 with a valid boot sector, two FAT copies, and a root directory.
- **Drive Letters**: Automatically assigned to every valid FAT12 partition found during boot or after formatting. Use `dl list` to see current mappings.
- **Navigation**: Supports absolute paths (e.g., `A/subdir/file.txt`) and relative paths. Drive switching is done via `cd A` (or `cd A/`).

###  Memory & Process Management

- **Allocator**: Bitmap‑based, allocating 4KB pages from a 2MB pool (0x200000 – 0x3FFFFF).
- **PCBs**: Stored at 0x110000, each 64 bytes, holding PID, state, stack pointer, memory size, parent PID, and name.
- **Scheduler**: Round‑robin, switching between processes with states READY and RUNNING.
- **`mem` command** shows real‑time memory usage and a list of all processes (including idle and shell).

###  Building & Running

**Prerequisites**: [NASM](https://www.nasm.us/) assembler, an x86 emulator (e.g., [QEMU](https://www.qemu.org/)) or real hardware.

'''
# Assemble boot sector and kernel
nasm -f bin boot.asm -o boot.bin
nasm -f bin kernel.asm -o kernel.bin

# Create a disk image (e.g., 4MB)
dd if=/dev/zero of=disk.vhd bs=1M count=4

# Write boot sector
dd if=boot.bin of=disk.vhd bs=512 count=1 conv=notrunc

# Write kernel (128 sectors, starting at sector 1)
dd if=kernel.bin of=disk.vhd bs=512 count=128 seek=1 conv=notrunc
'''

Alternatively, run `build.bat` (Windows) to automate the process.

**Run with QEMU**:
'''
qemu-system-i386 -drive file=disk.vhd,format=raw -m 64M
'''

###  Known Bugs / Limitations

1. **TUI's computer problem** – Can't use it properly

###  License & Credits

Developed independently by **YuZhuohao** as a personal project.

- Version: `snapshot_0.27`
- Language: Pure x86 Assembly


---

<a id="chinese"></a>
## 中文版本

**yOS** 是一个使用纯 x86 汇编编写的实验性操作系统。它展示了从引导、实模式到保护模式切换、IDE 磁盘驱动、FAT12 文件系统、内存管理、进程调度以及带有图形化 TUI 应用程序的命令行 Shell 等核心操作系统概念。

###  主要特性

- **双模式运行** – 从 16 位实模式启动，切换到 32 位保护模式并启用分页。
- **完整 IDE 驱动** – 支持 LBA 寻址、磁盘检测、MBR 分区表解析和扇区读写。
- **FAT12 文件系统** – 完整实现，支持子目录、文件/目录的创建、读写、删除和导航。
- **交互式 Shell** – 内置系统控制、文件管理和磁盘/分区操作命令。
- **内存管理** – 基于 4KB 页面的位图分配器，可显示每个进程的内存使用情况。
- **进程调度** – 轮转调度器，使用进程控制块（PCB）管理进程状态（就绪/运行）。
- **TUI 桌面** – 图形化菜单，内置**计算器**和**记事本**（含文件打开/保存对话框）。
- **CMOS RTC 支持** – 读取当前时间和日期。
- **盘符分配** – 自动挂载 FAT12 分区并分配盘符（A、B …）。

###  命令参考

| 命令                   | 说明 |
|------------------------|------|
| `cln`                  | 清屏 |
| `time`                 | 显示当前时间（时:分:秒） |
| `date`                 | 显示当前日期（年-月-日） |
| `shutdown`             | 硬关机 |
| `reboot`               | 重启系统 |
| `output <文本>`        | 打印任意文本 |
| `help [页码]`          | 显示命令列表（支持分页） |
| `dl list`              | 列出已分配的盘符 |
| `disk list`            | 列出物理 IDE 磁盘 |
| `disk sel <n>`         | 选择物理磁盘 |
| `disk part`            | 对所选磁盘分区（ FAT12 分区） |
| `part list`            | 列出所选磁盘上的分区 |
| `part sel <n>`         | 选择分区 |
| `part fm`              | 将所选分区格式化为 FAT12 |
| `ls`                   | 列出当前目录内容 |
| `cd <路径>`            | 切换目录（绝对/相对，如 `A/子目录`） |
| `write <文本> -2 <文件>` | 将文本写入文件（覆盖） |
| `read <文件>`          | 显示文件内容 |
| `crdir <名称>`         | 创建目录 |
| `dedir <名称>`         | 删除空目录 |
| `del <文件>`           | 删除文件 |
| `del *`                | 删除当前目录下所有文件 |
| `mem`                  | 显示内存使用和进程列表 |
| `copy <源> <目标>`     | 复制文件或通配符（`*`）到目标目录 |
| `mov <源> <目标>`      | 移动（剪切）文件或通配符 |
| `color <背景><前景>`   | 设置控制台颜色（两位十六进制，如 `color 0f`） |
| `tui`                  | 进入图形化 TUI 桌面 |

###  TUI 应用程序

`tui` 命令启动文本模式图形化环境，使用键盘导航：

- **桌面菜单** – 列出应用程序和系统操作。
- **计算器** – 基本算术（+、−、×、÷），支持按钮或键盘输入，包括数字、运算符、清除和退格。[请注意，该功能目前仍处于测试阶段，有BUG]
- **记事本** – 文本编辑器，功能包括：
  - 插入/删除字符，方向键移动光标。
  - 撤销/重做（最多 4 级）。
  - 打开/保存文件对话框，支持目录浏览。
  - 文件列表和文件名输入。

###  文件系统与存储

- **分区**：在所选磁盘上创建一个 MBR 分区，支持自定义大小。
- **格式化**：将分区格式化为 FAT12。
- **盘符**：启动或格式化后自动为每个有效的 FAT12 分区分配盘符。使用 `dl list` 查看当前映射。
- **导航**：支持绝对路径（如 `A/子目录/文件.txt`）和相对路径。切换盘符使用 `cd A`（或 `cd A/`）。

###  内存与进程管理

- **分配器**：基于位图，从 2MB 内存池（0x200000 – 0x3FFFFF）分配 4KB 页面。
- **PCB**：存储在 0x110000，每个 64 字节，包含 PID、状态、栈指针、内存大小、父 PID 和名称。
- **调度器**：轮转调度，在就绪和运行状态间切换。
- **`mem` 命令**显示实时内存使用情况和所有进程列表（包括空闲和 Shell 进程）。

###  构建与运行

**前置条件**：[NASM](https://www.nasm.us/) 汇编器，x86 模拟器（如 [QEMU](https://www.qemu.org/)）或真实硬件。

'''
# 汇编引导扇区和内核
nasm -f bin boot.asm -o boot.bin
nasm -f bin kernel.asm -o kernel.bin

# 创建磁盘镜像（例如 4MB）
dd if=/dev/zero of=disk.vhd bs=1M count=4

# 写入引导扇区
dd if=boot.bin of=disk.vhd bs=512 count=1 conv=notrunc

# 写入内核（128 个扇区，从扇区 1 开始）
dd if=kernel.bin of=disk.vhd bs=512 count=128 seek=1 conv=notrunc
'''

或者运行 `build.bat`（Windows）自动完成。

**使用 QEMU 运行**：
'''
qemu-system-i386 -drive file=disk.vhd,format=raw -m 64M
'''

###  已知BUGs

1. **TUI的计算机问题** – 无法正常使用

###  许可与致谢

由 **YuZhuohao** 个人独立开发。

- 版本：`snapshot_0.27`
- 语言：纯 x86 汇编
