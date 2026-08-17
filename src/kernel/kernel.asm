[org 0x10000]
[bits 16]

start_real:
    mov ax, 0x1000
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7000
    mov si, kernel_loaded_msg
    call print16_real
    mov si, welcome_msg
    call print16_real
    lgdt [gdt_desc]
    mov si, gdt_ok_msg
    call print16_real
    mov ax, 0x2401
    int 0x15
    mov si, a20_ok_msg
    call print16_real
    cli
    mov eax, cr0
    or eax, 1
    mov cr0, eax
    db 0x66, 0xEA
    dd 0x00010200
    dw 0x08

print16_real:
    lodsb
    or al, al
    jz .done
    mov ah, 0x0e
    int 0x10
    jmp print16_real
.done:
    ret

kernel_loaded_msg db 'Kernel loaded!',0x0d,0x0a,0
welcome_msg       db 'Welcome to yOS!',0x0d,0x0a,'by YuZhuohao',0x0d,0x0a,0
gdt_ok_msg        db 'GDT loaded.',0x0d,0x0a,0
a20_ok_msg        db 'A20 enabled.',0x0d,0x0a,0

gdt_start:
    dd 0, 0
    dw 0xFFFF
    dw 0x0000
    db 0x00
    db 0x9A
    db 0xCF
    db 0x00
    dw 0xFFFF
    dw 0x0000
    db 0x00
    db 0x92
    db 0xCF
    db 0x00
gdt_end:

gdt_desc:
    dw gdt_end - gdt_start - 1
    dd gdt_start

times 512-($-start_real) db 0

[bits 32]

IDE_DATA        equ 0
IDE_SECT_CNT    equ 2
IDE_LBA_LOW     equ 3
IDE_LBA_MID     equ 4
IDE_LBA_HIGH    equ 5
IDE_DRIVE       equ 6
IDE_STATUS      equ 7
IDE_CMD         equ 7
CMD_READ      equ 0x20
CMD_WRITE     equ 0x30
CMD_IDENTIFY  equ 0xEC
SECTOR_SIZE   equ 512
DIRS_PER_SECT equ 16
BYTES_PER_DIR equ 32
MAX_DRIVES    equ 16

prot_start:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov esp, 0x17FF0
    call keyboard_init
    call clear_screen
    mov esi, welcome_msg_pm
    call print32
    mov dx, 0x3F6
    mov al, 0x04
    out dx, al
    mov ecx, 10000
.rst_delay:
    loop .rst_delay
    mov al, 0x00
    out dx, al
    mov dx, 0x376
    mov al, 0x04
    out dx, al
    mov ecx, 10000
.rst_delay3:
    loop .rst_delay3
    mov al, 0x00
    out dx, al
    mov ecx, 100000
.rst_delay2:
    loop .rst_delay2
    call detect_disks
    cmp byte [disk_present], 0
    jne .has_disk
    mov byte [disk_present], 1
.has_disk:
    call init_drive_table
    call mem_init
    call paging_init
    call proc_init
    call cmd_loop
    jmp $

%include "io.asm"
%include "fs.asm"
%include "mem.asm"
%include "shell.asm"

times 32768-($-prot_start) db 0
