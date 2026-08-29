[org 0x7c00]
[bits 16]
KERNEL_SECTORS_DEFAULT equ 256
CHUNK_SIZE equ 32
start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7c00
    sti
    mov [boot_drive], dl
    mov si, loading_msg
    call print16
    mov ah, 0x41
    mov bx, 0x55aa
    mov dl, [boot_drive]
    int 0x13
    jc disk_error
    cmp bx, 0xaa55
    jne disk_error
    test cx, 1
    jz disk_error
    mov dword [dap_lba], 1
    mov dword [dap_lba + 4], 0
    mov word [dap_segment], 0x1000
    mov word [dap_offset], 0
    mov cx, [0x7c00 + 508]
    cmp cx, 0
    jne read_loop
    mov cx, KERNEL_SECTORS_DEFAULT
read_loop:
    cmp cx, 0
    je read_done
    mov ax, CHUNK_SIZE
    cmp cx, ax
    jge check_boundary
    mov ax, cx
check_boundary:
    push ax
    mov bx, 512
    mul bx
    add ax, [dap_offset]
    adc dx, 0
    pop ax
    cmp dx, 0
    jz set_count
    mov ax, [dap_offset]
    neg ax
    xor dx, dx
    mov bx, 512
    div bx
    cmp ax, 0
    jg set_count
    mov ax, 1
set_count:
    mov [dap_count], ax
    mov si, dap
    mov ah, 0x42
    mov dl, [boot_drive]
    int 0x13
    jc disk_error
    mov ax, [dap_count]
    add [dap_lba], ax
    adc word [dap_lba + 2], 0
    adc word [dap_lba + 4], 0
    adc word [dap_lba + 6], 0
    sub cx, ax
    mov ax, [dap_count]
    mov bx, 512
    mul bx
    add [dap_offset], ax
    jnc read_loop
    add word [dap_segment], 0x1000
    jmp read_loop
read_done:
    jmp 0x1000:0x0000
disk_error:
    mov si, error_msg
    call print16
halt:
    cli
    hlt
    jmp halt
print16:
    lodsb
    test al, al
    jz print16_done
    push si
    mov ah, 0x0e
    mov bh, 0x00
    mov bl, 0x07
    int 0x10
    pop si
    jmp print16
print16_done:
    ret
boot_drive:
    db 0
dap:
    db 0x10
    db 0x00
dap_count:
    dw 0
dap_offset:
    dw 0
dap_segment:
    dw 0
dap_lba:
    dq 0
loading_msg:
    db 'Loading yOS...', 0x0d, 0x0a, 0
error_msg:
    db 'Disk read error.', 0x0d, 0x0a, 0
times 508-($-$$) db 0
kernel_sectors_count dw 0
dw 0xaa55
