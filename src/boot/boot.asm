[org 0x7c00]
[bits 16]

start:
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7c00
    mov si, loading_msg
    call print16
    xor ah, ah
    mov dl, 0x80
    int 0x13
    mov ax, 0x1000
    mov es, ax
    xor bx, bx
    mov ah, 0x02
    mov al, 128
    mov ch, 0
    mov cl, 2
    mov dh, 0
    mov dl, 0x80
    int 0x13
    jc read_error
    jmp 0x1000:0x0000

read_error:
    mov si, error_msg
    call print16
    jmp $

print16:
    lodsb
    or al, al
    jz .done
    mov ah, 0x0e
    int 0x10
    jmp print16
.done:
    ret

loading_msg   db 'Loading yOS...', 0x0d, 0x0a, 0
error_msg     db 'Read error! System halted.', 0

times 510-($-$$) db 0
dw 0xaa55
