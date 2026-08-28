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
    mov eax, gdt_start
    mov [gdt_desc + 2], eax
    lgdt [gdt_desc]
    mov si, gdt_ok_msg
    call print16_real
    mov ax, 0x2401
    int 0x15
    call enable_a20_kbd
    mov si, a20_ok_msg
    call print16_real
    cli
    mov eax, cr0
    or eax, 1
    mov cr0, eax
    jmp dword 0x08:prot_start
enable_a20_kbd:
    pusha
    cli
    call .wait_cmd
    mov al, 0xAD
    out 0x64, al
    call .wait_cmd
    mov al, 0xD0
    out 0x64, al
    call .wait_data
    in al, 0x60
    push eax
    call .wait_cmd
    mov al, 0xD1
    out 0x64, al
    call .wait_cmd
    pop eax
    or al, 2
    out 0x60, al
    call .wait_cmd
    mov al, 0xAE
    out 0x64, al
    call .wait_cmd
    sti
    popa
    ret
.wait_cmd:
    in al, 0x64
    test al, 2
    jnz .wait_cmd
    ret
.wait_data:
    in al, 0x64
    test al, 1
    jz .wait_data
    ret
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
    dd 0
times 512-($-start_real) db 0
align 4
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
    mov esp, 0x80000
    call setup_idt
    lidt [idt_desc]
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
    call auto_mount
    call mem_init
    call paging_init
    call proc_init
    call cmd_loop
    jmp $
;=============================================================================
; Screen I/O - Text mode display functions
;=============================================================================

clear_screen:
    ; Clear entire screen with current color
    pusha
    mov edi, 0xB8000
    mov ecx, 80*25
    mov ah, [current_color]
    mov al, 0x20
    rep stosw
    mov dword [cursor_pos], 0
    call update_cursor
    popa
    ret
align 16
idt_start:
    times 256 dq 0
idt_end:
idt_desc:
    dw idt_end - idt_start - 1
    dd idt_start
isr_stub_table:
    dd isr0,isr1,isr2,isr3,isr4,isr5,isr6,isr7
    dd isr8,isr9,isr10,isr11,isr12,isr13,isr14,isr15
    dd isr16,isr17,isr18,isr19,isr20,isr21,isr22,isr23
    dd isr24,isr25,isr26,isr27,isr28,isr29,isr30,isr31
exception_names:
    db 'Divide by Zero',0
    db 'Debug',0
    db 'NMI Interrupt',0
    db 'Breakpoint',0
    db 'Overflow',0
    db 'Bound Range Exceeded',0
    db 'Invalid Opcode',0
    db 'Device Not Available',0
    db 'Double Fault',0
    db 'Coprocessor Segment Overrun',0
    db 'Invalid TSS',0
    db 'Segment Not Present',0
    db 'Stack-Segment Fault',0
    db 'General Protection Fault',0
    db 'Page Fault',0
    db 'Reserved',0
    db 'x87 FPU Error',0
    db 'Alignment Check',0
    db 'Machine Check',0
    db 'SIMD FPU Error',0
    db 'Reserved',0,'Reserved',0,'Reserved',0,'Reserved',0
    db 'Reserved',0,'Reserved',0,'Reserved',0,'Reserved',0
    db 'Reserved',0,'Reserved',0,'Reserved',0,'Reserved',0
bs_int_num dd 0
bs_err_code dd 0
bs_eip dd 0
bs_cs dd 0
bs_eflags dd 0
bs_esp dd 0
bs_ss dd 0
bs_cr0 dd 0
bs_cr2 dd 0
bs_cr3 dd 0
isr0:
    push byte 0
    push byte 0
    jmp isr_common
isr1:
    push byte 0
    push byte 1
    jmp isr_common
isr2:
    push byte 0
    push byte 2
    jmp isr_common
isr3:
    push byte 0
    push byte 3
    jmp isr_common
isr4:
    push byte 0
    push byte 4
    jmp isr_common
isr5:
    push byte 0
    push byte 5
    jmp isr_common
isr6:
    push byte 0
    push byte 6
    jmp isr_common
isr7:
    push byte 0
    push byte 7
    jmp isr_common
isr8:
    push byte 8
    jmp isr_common
isr9:
    push byte 0
    push byte 9
    jmp isr_common
isr10:
    push byte 10
    jmp isr_common
isr11:
    push byte 11
    jmp isr_common
isr12:
    push byte 12
    jmp isr_common
isr13:
    push byte 13
    jmp isr_common
isr14:
    push byte 14
    jmp isr_common
isr15:
    push byte 0
    push byte 15
    jmp isr_common
isr16:
    push byte 0
    push byte 16
    jmp isr_common
isr17:
    push byte 17
    jmp isr_common
isr18:
    push byte 0
    push byte 18
    jmp isr_common
isr19:
    push byte 0
    push byte 19
    jmp isr_common
isr20:
    push byte 0
    push byte 20
    jmp isr_common
isr21:
    push byte 0
    push byte 21
    jmp isr_common
isr22:
    push byte 0
    push byte 22
    jmp isr_common
isr23:
    push byte 0
    push byte 23
    jmp isr_common
isr24:
    push byte 0
    push byte 24
    jmp isr_common
isr25:
    push byte 0
    push byte 25
    jmp isr_common
isr26:
    push byte 0
    push byte 26
    jmp isr_common
isr27:
    push byte 0
    push byte 27
    jmp isr_common
isr28:
    push byte 0
    push byte 28
    jmp isr_common
isr29:
    push byte 0
    push byte 29
    jmp isr_common
isr30:
    push byte 0
    push byte 30
    jmp isr_common
isr31:
    push byte 0
    push byte 31
    jmp isr_common
setup_idt:
    pusha
    mov ecx, 32
    mov esi, isr_stub_table
    mov edi, idt_start
.sloop:
    mov eax, [esi]
    mov [edi], ax
    mov word [edi+2], 0x08
    mov byte [edi+4], 0
    mov byte [edi+5], 0x8E
    shr eax, 16
    mov [edi+6], ax
    add esi, 4
    add edi, 8
    dec ecx
    jnz .sloop
    popa
    ret
isr_common:
    mov eax, esp
    add eax, 20
    mov [bs_esp], eax
    mov ax, ss
    mov [bs_ss], eax
    pop eax
    mov [bs_int_num], eax
    pop eax
    mov [bs_err_code], eax
    pop eax
    mov [bs_eip], eax
    pop eax
    mov [bs_cs], eax
    pop eax
    mov [bs_eflags], eax
    mov eax, cr0
    mov [bs_cr0], eax
    mov eax, cr2
    mov [bs_cr2], eax
    mov eax, cr3
    mov [bs_cr3], eax
    cli
    call blue_screen
.halt:
    hlt
    jmp .halt
bs_put_str:
    pusha
    mov edi, [bs_cursor]
.loop:
    lodsb
    cmp al, 0
    je .done
    mov [edi], al
    mov byte [edi+1], 0x1F
    add edi, 2
    jmp .loop
.done:
    mov [bs_cursor], edi
    popa
    ret
bs_newline:
    pusha
    mov eax, [bs_cursor]
    sub eax, 0xB8000
    mov ecx, 80*2
    xor edx, edx
    div ecx
    inc eax
    mul ecx
    add eax, 0xB8000
    mov [bs_cursor], eax
    popa
    ret
bs_put_hex8:
    pusha
    mov ecx, 2
    jmp bs_put_hex_common
bs_put_hex32:
    pusha
    mov ecx, 8
bs_put_hex_common:
    mov edx, eax
.loop:
    mov eax, edx
    dec ecx
    shl ecx, 2
    shr eax, cl
    shr ecx, 2
    inc ecx
    and al, 0x0F
    cmp al, 10
    jl .digit
    add al, 7
.digit:
    add al, '0'
    mov edi, [bs_cursor]
    mov [edi], al
    mov byte [edi+1], 0x1F
    add dword [bs_cursor], 2
    dec ecx
    jnz .loop
    popa
    ret
blue_screen:
    pusha
    mov edi, 0xB8000
    mov ecx, 80*25
    mov ax, 0x1F20
    rep stosw
    mov dword [bs_cursor], 0xB8000 + 2*80*2
    mov esi, bs_title
    call bs_put_str
    call bs_newline
    call bs_newline
    mov esi, bs_exc_str
    call bs_put_str
    mov eax, [bs_int_num]
    call bs_put_hex8
    mov esi, bs_space
    call bs_put_str
    mov eax, [bs_int_num]
    mov esi, exception_names
    mov ecx, eax
.name_loop:
    cmp ecx, 0
    je .name_found
    .skip_name:
    lodsb
    cmp al, 0
    jne .skip_name
    dec ecx
    jmp .name_loop
.name_found:
    call bs_put_str
    call bs_newline
    mov esi, bs_err_str
    call bs_put_str
    mov eax, [bs_err_code]
    call bs_put_hex32
    call bs_newline
    call bs_newline
    mov esi, bs_reg_title
    call bs_put_str
    call bs_newline
    mov esi, bs_eip_str
    call bs_put_str
    mov eax, [bs_eip]
    call bs_put_hex32
    call bs_newline
    mov esi, bs_cs_str
    call bs_put_str
    mov eax, [bs_cs]
    call bs_put_hex32
    call bs_newline
    mov esi, bs_eflags_str
    call bs_put_str
    mov eax, [bs_eflags]
    call bs_put_hex32
    call bs_newline
    mov esi, bs_esp_str
    call bs_put_str
    mov eax, [bs_esp]
    call bs_put_hex32
    call bs_newline
    mov esi, bs_ss_str
    call bs_put_str
    mov eax, [bs_ss]
    call bs_put_hex32
    call bs_newline
    call bs_newline
    mov esi, bs_cr_title
    call bs_put_str
    call bs_newline
    mov esi, bs_cr0_str
    call bs_put_str
    mov eax, [bs_cr0]
    call bs_put_hex32
    call bs_newline
    mov esi, bs_cr2_str
    call bs_put_str
    mov eax, [bs_cr2]
    call bs_put_hex32
    call bs_newline
    mov esi, bs_cr3_str
    call bs_put_str
    mov eax, [bs_cr3]
    call bs_put_hex32
    call bs_newline
    call bs_newline
    mov esi, bs_mem_title
    call bs_put_str
    call bs_newline
    mov esi, bs_mem_str
    call bs_put_str
    mov eax, 0x80000
    call bs_put_hex32
    mov esi, bs_mem_str2
    call bs_put_str
    call bs_newline
    call bs_newline
    mov esi, bs_halt_str
    call bs_put_str
    popa
    ret
bs_cursor dd 0
bs_title db '*** yOS Fatal Error - System Halted ***',0
bs_exc_str db 'Exception: 0x',0
bs_space db '  ',0
bs_err_str db 'Error Code: 0x',0
bs_reg_title db '--- Registers ---',0
bs_eip_str db 'EIP:    0x',0
bs_cs_str db 'CS:     0x',0
bs_eflags_str db 'EFLAGS: 0x',0
bs_esp_str db 'ESP:    0x',0
bs_ss_str db 'SS:     0x',0
bs_cr_title db '--- Control Registers ---',0
bs_cr0_str db 'CR0: 0x',0
bs_cr2_str db 'CR2: 0x',0
bs_cr3_str db 'CR3: 0x',0
bs_mem_title db '--- Memory ---',0
bs_mem_str db 'Stack Top: 0x',0
bs_mem_str2 db ' (512KB)',0
bs_halt_str db 'System halted. Press Ctrl+Alt+Del to restart.',0
scroll_screen:
    pusha
    cld
    mov esi, 0xB8000 + 160
    mov edi, 0xB8000
    mov ecx, 960
    rep movsd
    mov edi, 0xB8000 + 80*24*2
    mov ecx, 80
    mov ah, [current_color]
    mov al, 0x20
    rep stosw
    mov dword [cursor_pos], 80*24
    popa
    ret
check_scroll:
    pusha
    cmp dword [cursor_pos], 80*25
    jl .done
    call scroll_screen
.done:
    popa
    ret
update_cursor:
    pusha
    mov eax, [cursor_pos]
    mov ebx, eax
    mov dx, 0x3D4
    mov al, 0x0E
    out dx, al
    inc dx
    mov al, bh
    out dx, al
    dec dx
    mov al, 0x0F
    out dx, al
    inc dx
    mov al, bl
    out dx, al
    popa
    ret
print32:
    pusha
    mov edi, 0xB8000
    mov eax, [cursor_pos]
    shl eax, 1
    add edi, eax
.loop:
    lodsb
    or al, al
    jz .done
    cmp al, 0x0d
    je .cr
    cmp al, 0x0a
    je .lf
    mov ah, [current_color]
    stosw
    inc dword [cursor_pos]
    call check_scroll
    jmp .loop
.cr:
    mov eax, [cursor_pos]
    xor edx, edx
    mov ebx, 80
    div ebx
    mul ebx
    mov [cursor_pos], eax
    jmp .loop
.lf:
    mov eax, [cursor_pos]
    add eax, 80
    mov ebx, 80
    xor edx, edx
    div ebx
    mul ebx
    mov [cursor_pos], eax
    call check_scroll
    jmp .loop
.done:
    call update_cursor
    popa
    ret
print_char:
    pusha
    movzx eax, al
    mov ah, [current_color]
    mov edi, 0xB8000
    mov ebx, [cursor_pos]
    shl ebx, 1
    add edi, ebx
    stosw
    inc dword [cursor_pos]
    call check_scroll
    call update_cursor
    popa
    ret
print_number:
    pusha
    mov ebx, 10
    mov ecx, 0
    cmp eax, 0
    jne .loop
    mov al, '0'
    call print_char
    jmp .done
.loop:
    xor edx, edx
    div ebx
    add dl, '0'
    push dx
    inc ecx
    cmp eax, 0
    jne .loop
.write:
    pop dx
    mov al, dl
    call print_char
    dec ecx
    jnz .write
.done:
    popa
    ret
count_digits:
    push ebx
    push ecx
    push edx
    mov ecx, 0
    cmp eax, 0
    jne .loop
    mov ecx, 1
    jmp .done
.loop:
    xor edx, edx
    mov ebx, 10
    div ebx
    inc ecx
    cmp eax, 0
    jne .loop
.done:
    mov eax, ecx
    pop edx
    pop ecx
    pop ebx
    ret
print_hex_byte:
    pusha
    mov bl, al
    shr al, 4
    cmp al, 10
    jl .digit1
    add al, 'A' - 10
    jmp .print1
.digit1:
    add al, '0'
.print1:
    call print_char
    mov al, bl
    and al, 0x0F
    cmp al, 10
    jl .digit2
    add al, 'A' - 10
    jmp .print2
.digit2:
    add al, '0'
.print2:
    call print_char
    popa
    ret
print_bcd:
    pusha
    movzx eax, al
    mov bl, al
    shr al, 4
    add al, '0'
    call print_char
    mov al, bl
    and al, 0x0F
    add al, '0'
    call print_char
    popa
    ret
;=============================================================================
; Keyboard Driver - Scancode to ASCII conversion with shift support
;=============================================================================

keyboard_init:
    ; Initialize keyboard controller
    pusha
.wait1:
    in al, 0x64
    test al, 0x02
    jnz .wait1
    mov al, 0xAE
    out 0x64, al
.flush:
    in al, 0x64
    test al, 0x01
    jz .done
    in al, 0x60
    jmp .flush
.done:
    popa
    ret
wait_key:
    in al, 0x64
    test al, 0x01
    jz wait_key
    ret
read_scancode:
    call wait_key
    in al, 0x60
    ret
scancode_to_ascii:
    push ebx
    cmp al, 0x02
    je .num1
    cmp al, 0x03
    je .num2
    cmp al, 0x04
    je .num3
    cmp al, 0x05
    je .num4
    cmp al, 0x06
    je .num5
    cmp al, 0x07
    je .num6
    cmp al, 0x08
    je .num7
    cmp al, 0x09
    je .num8
    cmp al, 0x0A
    je .num9
    cmp al, 0x0B
    je .num0
    cmp al, 0x0C
    je .minus
    cmp al, 0x0D
    je .equals
    cmp al, 0x10
    je .q
    cmp al, 0x11
    je .w
    cmp al, 0x12
    je .e
    cmp al, 0x13
    je .r
    cmp al, 0x14
    je .t
    cmp al, 0x15
    je .y
    cmp al, 0x16
    je .u
    cmp al, 0x17
    je .i
    cmp al, 0x18
    je .o
    cmp al, 0x19
    je .p
    cmp al, 0x1A
    je .lbracket
    cmp al, 0x1B
    je .rbracket
    cmp al, 0x1E
    je .a
    cmp al, 0x1F
    je .s
    cmp al, 0x20
    je .d
    cmp al, 0x21
    je .f
    cmp al, 0x22
    je .g
    cmp al, 0x23
    je .h
    cmp al, 0x24
    je .j
    cmp al, 0x25
    je .k
    cmp al, 0x26
    je .l
    cmp al, 0x27
    je .semicolon
    cmp al, 0x28
    je .quote
    cmp al, 0x29
    je .backtick
    cmp al, 0x2B
    je .backslash
    cmp al, 0x2C
    je .z
    cmp al, 0x2D
    je .x
    cmp al, 0x2E
    je .c
    cmp al, 0x2F
    je .v
    cmp al, 0x30
    je .b
    cmp al, 0x31
    je .n
    cmp al, 0x32
    je .m
    cmp al, 0x33
    je .comma
    cmp al, 0x34
    je .dot
    cmp al, 0x35
    je .slash
    cmp al, 0x39
    je .space
    xor al, al
    jmp .done
.num1:
    cmp byte [shift_pressed], 0
    jne .num1_shift
    mov al, '1'
    jmp .done
.num1_shift:
    mov al, '!'
    jmp .done
.num2:
    cmp byte [shift_pressed], 0
    jne .num2_shift
    mov al, '2'
    jmp .done
.num2_shift:
    mov al, '@'
    jmp .done
.num3:
    cmp byte [shift_pressed], 0
    jne .num3_shift
    mov al, '3'
    jmp .done
.num3_shift:
    mov al, '#'
    jmp .done
.num4:
    cmp byte [shift_pressed], 0
    jne .num4_shift
    mov al, '4'
    jmp .done
.num4_shift:
    mov al, '$'
    jmp .done
.num5:
    cmp byte [shift_pressed], 0
    jne .num5_shift
    mov al, '5'
    jmp .done
.num5_shift:
    mov al, '%'
    jmp .done
.num6:
    cmp byte [shift_pressed], 0
    jne .num6_shift
    mov al, '6'
    jmp .done
.num6_shift:
    mov al, '^'
    jmp .done
.num7:
    cmp byte [shift_pressed], 0
    jne .num7_shift
    mov al, '7'
    jmp .done
.num7_shift:
    mov al, '&'
    jmp .done
.num8:
    cmp byte [shift_pressed], 0
    jne .num8_shift
    mov al, '8'
    jmp .done
.num8_shift:
    mov al, '*'
    jmp .done
.num9:
    cmp byte [shift_pressed], 0
    jne .num9_shift
    mov al, '9'
    jmp .done
.num9_shift:
    mov al, '('
    jmp .done
.num0:
    cmp byte [shift_pressed], 0
    jne .num0_shift
    mov al, '0'
    jmp .done
.num0_shift:
    mov al, ')'
    jmp .done
.minus:
    cmp byte [shift_pressed], 0
    jne .minus_shift
    mov al, '-'
    jmp .done
.minus_shift:
    mov al, '_'
    jmp .done
.equals:
    cmp byte [shift_pressed], 0
    jne .equals_shift
    mov al, '='
    jmp .done
.equals_shift:
    mov al, '+'
    jmp .done
.lbracket:
    cmp byte [shift_pressed], 0
    jne .lbracket_shift
    mov al, '['
    jmp .done
.lbracket_shift:
    mov al, '{'
    jmp .done
.rbracket:
    cmp byte [shift_pressed], 0
    jne .rbracket_shift
    mov al, ']'
    jmp .done
.rbracket_shift:
    mov al, '}'
    jmp .done
.semicolon:
    cmp byte [shift_pressed], 0
    jne .semicolon_shift
    mov al, ';'
    jmp .done
.semicolon_shift:
    mov al, ':'
    jmp .done
.quote:
    cmp byte [shift_pressed], 0
    jne .quote_shift
    mov al, 0x27
    jmp .done
.quote_shift:
    mov al, '"'
    jmp .done
.backtick:
    cmp byte [shift_pressed], 0
    jne .backtick_shift
    mov al, '`'
    jmp .done
.backtick_shift:
    mov al, '~'
    jmp .done
.backslash:
    cmp byte [shift_pressed], 0
    jne .backslash_shift
    mov al, '\'
    jmp .done
.backslash_shift:
    mov al, '|'
    jmp .done
.comma:
    cmp byte [shift_pressed], 0
    jne .comma_shift
    mov al, ','
    jmp .done
.comma_shift:
    mov al, '<'
    jmp .done
.dot:
    cmp byte [shift_pressed], 0
    jne .dot_shift
    mov al, '.'
    jmp .done
.dot_shift:
    mov al, '>'
    jmp .done
.slash:
    cmp byte [shift_pressed], 0
    jne .slash_shift
    mov al, '/'
    jmp .done
.slash_shift:
    mov al, '?'
    jmp .done
.a:
    cmp byte [shift_pressed], 0
    jne .a_shift
    mov al, 'a'
    jmp .done
.a_shift:
    mov al, 'A'
    jmp .done
.s:
    cmp byte [shift_pressed], 0
    jne .s_shift
    mov al, 's'
    jmp .done
.s_shift:
    mov al, 'S'
    jmp .done
.d:
    cmp byte [shift_pressed], 0
    jne .d_shift
    mov al, 'd'
    jmp .done
.d_shift:
    mov al, 'D'
    jmp .done
.f:
    cmp byte [shift_pressed], 0
    jne .f_shift
    mov al, 'f'
    jmp .done
.f_shift:
    mov al, 'F'
    jmp .done
.g:
    cmp byte [shift_pressed], 0
    jne .g_shift
    mov al, 'g'
    jmp .done
.g_shift:
    mov al, 'G'
    jmp .done
.h:
    cmp byte [shift_pressed], 0
    jne .h_shift
    mov al, 'h'
    jmp .done
.h_shift:
    mov al, 'H'
    jmp .done
.j:
    cmp byte [shift_pressed], 0
    jne .j_shift
    mov al, 'j'
    jmp .done
.j_shift:
    mov al, 'J'
    jmp .done
.k:
    cmp byte [shift_pressed], 0
    jne .k_shift
    mov al, 'k'
    jmp .done
.k_shift:
    mov al, 'K'
    jmp .done
.l:
    cmp byte [shift_pressed], 0
    jne .l_shift
    mov al, 'l'
    jmp .done
.l_shift:
    mov al, 'L'
    jmp .done
.z:
    cmp byte [shift_pressed], 0
    jne .z_shift
    mov al, 'z'
    jmp .done
.z_shift:
    mov al, 'Z'
    jmp .done
.x:
    cmp byte [shift_pressed], 0
    jne .x_shift
    mov al, 'x'
    jmp .done
.x_shift:
    mov al, 'X'
    jmp .done
.c:
    cmp byte [shift_pressed], 0
    jne .c_shift
    mov al, 'c'
    jmp .done
.c_shift:
    mov al, 'C'
    jmp .done
.v:
    cmp byte [shift_pressed], 0
    jne .v_shift
    mov al, 'v'
    jmp .done
.v_shift:
    mov al, 'V'
    jmp .done
.b:
    cmp byte [shift_pressed], 0
    jne .b_shift
    mov al, 'b'
    jmp .done
.b_shift:
    mov al, 'B'
    jmp .done
.n:
    cmp byte [shift_pressed], 0
    jne .n_shift
    mov al, 'n'
    jmp .done
.n_shift:
    mov al, 'N'
    jmp .done
.m:
    cmp byte [shift_pressed], 0
    jne .m_shift
    mov al, 'm'
    jmp .done
.m_shift:
    mov al, 'M'
    jmp .done
.q:
    cmp byte [shift_pressed], 0
    jne .q_shift
    mov al, 'q'
    jmp .done
.q_shift:
    mov al, 'Q'
    jmp .done
.w:
    cmp byte [shift_pressed], 0
    jne .w_shift
    mov al, 'w'
    jmp .done
.w_shift:
    mov al, 'W'
    jmp .done
.e:
    cmp byte [shift_pressed], 0
    jne .e_shift
    mov al, 'e'
    jmp .done
.e_shift:
    mov al, 'E'
    jmp .done
.r:
    cmp byte [shift_pressed], 0
    jne .r_shift
    mov al, 'r'
    jmp .done
.r_shift:
    mov al, 'R'
    jmp .done
.t:
    cmp byte [shift_pressed], 0
    jne .t_shift
    mov al, 't'
    jmp .done
.t_shift:
    mov al, 'T'
    jmp .done
.y:
    cmp byte [shift_pressed], 0
    jne .y_shift
    mov al, 'y'
    jmp .done
.y_shift:
    mov al, 'Y'
    jmp .done
.u:
    cmp byte [shift_pressed], 0
    jne .u_shift
    mov al, 'u'
    jmp .done
.u_shift:
    mov al, 'U'
    jmp .done
.i:
    cmp byte [shift_pressed], 0
    jne .i_shift
    mov al, 'i'
    jmp .done
.i_shift:
    mov al, 'I'
    jmp .done
.o:
    cmp byte [shift_pressed], 0
    jne .o_shift
    mov al, 'o'
    jmp .done
.o_shift:
    mov al, 'O'
    jmp .done
.p:
    cmp byte [shift_pressed], 0
    jne .p_shift
    mov al, 'p'
    jmp .done
.p_shift:
    mov al, 'P'
    jmp .done
.space:
    mov al, ' '
    jmp .done
.done:
    pop ebx
    ret
read_line:
    pusha
    mov edi, input_buf
    xor ecx, ecx
    mov byte [shift_pressed], 0
    mov dword [input_len], 0
    mov dword [cursor_pos_in_buf], 0
    mov dword [history_pos], 0
    mov eax, [cursor_pos]
    mov [input_start], eax
    mov ebx, 80
    xor edx, edx
    div ebx
    cmp eax, 24
    jl .has_space
    call scroll_screen
    sub dword [input_start], 80
    mov eax, [input_start]
    mov [cursor_pos], eax
    call update_cursor
.has_space:
.read_loop:
    call read_scancode
    cmp al, 0x1C
    je .enter
    cmp al, 0x0E
    je .backspace
    cmp al, 0x2A
    je .shift_down
    cmp al, 0x36
    je .shift_down
    cmp al, 0xAA
    je .shift_up
    cmp al, 0xB6
    je .shift_up
    cmp al, 0x4B
    je .left_arrow
    cmp al, 0x4D
    je .right_arrow
    cmp al, 0x48
    je .up_arrow
    cmp al, 0x50
    je .down_arrow
    test al, 0x80
    jnz .read_loop
    call scancode_to_ascii
    cmp al, 0
    jz .read_loop
    cmp al, 0x20
    jb .read_loop
    cmp al, 0x7E
    ja .read_loop
    mov dword [history_pos], 0
    mov ebx, [cursor_pos_in_buf]
    push edi
    mov esi, input_buf
    add esi, [input_len]
    mov edi, input_buf
    add edi, [input_len]
    inc edi
    std
    mov ecx, [input_len]
    sub ecx, ebx
    inc ecx
    rep movsb
    cld
    pop edi
    mov esi, input_buf
    add esi, ebx
    mov [esi], al
    inc dword [input_len]
    inc dword [cursor_pos_in_buf]
    call refresh_line
    jmp .read_loop
.up_arrow:
    mov eax, [history_pos]
    cmp eax, [history_count]
    jge .read_loop
    cmp eax, 0
    jne .load_history
    mov esi, input_buf
    mov edi, history_temp
    mov ecx, 128
    cld
    rep movsb
.load_history:
    inc dword [history_pos]
    mov eax, [history_count]
    sub eax, [history_pos]
    mov ebx, 128
    mul ebx
    mov esi, history_buf
    add esi, eax
    mov edi, input_buf
    mov ecx, 128
    cld
    rep movsb
    mov esi, input_buf
    call str_len
    mov [input_len], eax
    mov [cursor_pos_in_buf], eax
    call refresh_line
    jmp .read_loop
.down_arrow:
    cmp dword [history_pos], 0
    je .read_loop
    dec dword [history_pos]
    cmp dword [history_pos], 0
    je .restore_temp
    mov eax, [history_count]
    sub eax, [history_pos]
    mov ebx, 128
    mul ebx
    mov esi, history_buf
    add esi, eax
    mov edi, input_buf
    mov ecx, 128
    cld
    rep movsb
    mov esi, input_buf
    call str_len
    mov [input_len], eax
    mov [cursor_pos_in_buf], eax
    call refresh_line
    jmp .read_loop
.restore_temp:
    mov esi, history_temp
    mov edi, input_buf
    mov ecx, 128
    cld
    rep movsb
    mov esi, input_buf
    call str_len
    mov [input_len], eax
    mov [cursor_pos_in_buf], eax
    call refresh_line
    jmp .read_loop
.left_arrow:
    cmp dword [cursor_pos_in_buf], 0
    je .read_loop
    dec dword [cursor_pos_in_buf]
    call refresh_line
    jmp .read_loop
.right_arrow:
    mov ebx, [cursor_pos_in_buf]
    cmp ebx, [input_len]
    jge .read_loop
    inc dword [cursor_pos_in_buf]
    call refresh_line
    jmp .read_loop
.shift_down:
    mov byte [shift_pressed], 1
    jmp .read_loop
.shift_up:
    mov byte [shift_pressed], 0
    jmp .read_loop
.backspace:
    cmp dword [cursor_pos_in_buf], 0
    je .read_loop
    mov ebx, [cursor_pos_in_buf]
    dec ebx
    mov esi, input_buf
    add esi, ebx
    mov edi, esi
    inc edi
    mov ecx, [input_len]
    sub ecx, ebx
    cld
    rep movsb
    dec dword [input_len]
    dec dword [cursor_pos_in_buf]
    call refresh_line
    jmp .read_loop
.enter:
    mov ebx, [cursor_pos_in_buf]
    mov byte [input_buf + ebx], 0
    mov esi, input_buf
    call str_len
    mov [input_len], eax
    cmp eax, 0
    je .no_history
    mov ebx, [history_count]
    cmp ebx, 0
    je .add_history
    dec ebx
    mov eax, ebx
    mov ecx, 128
    mul ecx
    mov esi, history_buf
    add esi, eax
    mov edi, input_buf
    mov ecx, 128
    call str_compare
    cmp eax, 1
    je .no_history
.add_history:
    cmp dword [history_count], 8
    jl .no_shift
    mov esi, history_buf + 128
    mov edi, history_buf
    mov ecx, 128 * 7
    cld
    rep movsb
    dec dword [history_count]
.no_shift:
    mov eax, [history_count]
    mov ecx, 128
    mul ecx
    mov esi, input_buf
    mov edi, history_buf
    add edi, eax
    mov ecx, 128
    cld
    rep movsb
    inc dword [history_count]
.no_history:
    mov dword [history_pos], 0
    mov eax, [cursor_pos]
    add eax, 80
    mov ebx, 80
    xor edx, edx
    div ebx
    mul ebx
    mov [cursor_pos], eax
    call check_scroll
    call update_cursor
    popa
    ret
refresh_line:
    pusha
    mov edi, 0xB8000
    mov eax, [input_start]
    shl eax, 1
    add edi, eax
    mov ecx, 160
    mov ah, [current_color]
    mov al, 0x20
    rep stosw
    mov edi, 0xB8000
    mov eax, [input_start]
    shl eax, 1
    add edi, eax
    mov esi, input_buf
    mov ecx, [input_len]
    jecxz .set_cursor
    mov ah, [current_color]
.print_loop:
    lodsb
    stosw
    loop .print_loop
.set_cursor:
    mov eax, [input_start]
    add eax, [cursor_pos_in_buf]
    mov [cursor_pos], eax
    call update_cursor
    popa
    ret
set_cursor_pos:
    pusha
    mov [cursor_pos], eax
    call update_cursor
    popa
    ret
;=============================================================================
; String and Number Utilities
;=============================================================================

cmd_match:
    ; Case-insensitive command matching
    ; Input: esi = input string, edi = command to match
    ; Output: eax = 1 if match, 0 if not
    push esi
    push edi
    push ecx
    xor eax, eax
.match_loop:
    mov bl, [edi]
    cmp bl, 0
    je .check_input
    mov al, [esi]
    cmp al, bl
    je .next
    cmp al, 'A'
    jb .diff
    cmp al, 'Z'
    ja .try_lower
    add al, 32
    jmp .cmp_after
.try_lower:
    cmp al, 'a'
    jb .diff
    cmp al, 'z'
    ja .diff
    sub al, 32
.cmp_after:
    cmp al, bl
    jne .diff
.next:
    inc esi
    inc edi
    jmp .match_loop
.check_input:
    mov al, [esi]
    cmp al, 0
    je .success
    cmp al, ' '
    je .success
    cmp al, 0x09
    je .success
    jmp .diff
.success:
    mov eax, 1
    jmp .done
.diff:
    xor eax, eax
.done:
    pop ecx
    pop edi
    pop esi
    ret
str_cmp:
    push esi
    push edi
    push ecx
    xor eax, eax
.loop:
    mov al, [esi]
    mov dl, [edi]
    cmp al, dl
    jne .diff
    cmp al, 0
    je .same
    inc esi
    inc edi
    jmp .loop
.diff:
    xor eax, eax
    jmp .done
.same:
    mov eax, 1
.done:
    pop ecx
    pop edi
    pop esi
    ret
str_copy:
    pusha
.loop:
    cmp ecx, 0
    je .done
    mov al, [esi]
    mov [edi], al
    inc esi
    inc edi
    dec ecx
    cmp al, 0
    je .done
    jmp .loop
.done:
    popa
    ret
str_len:
    push esi
    xor eax, eax
.loop:
    cmp byte [esi], 0
    je .done
    inc esi
    inc eax
    jmp .loop
.done:
    pop esi
    ret
str_compare:
    pusha
    xor eax, eax
.cmp_loop:
    cmp ecx, 0
    je .equal
    mov al, [esi]
    mov bl, [edi]
    cmp al, bl
    jne .not_equal
    cmp al, 0
    je .equal
    inc esi
    inc edi
    dec ecx
    jmp .cmp_loop
.equal:
    popa
    mov eax, 1
    ret
.not_equal:
    popa
    xor eax, eax
    ret
parse_number:
    push ebx
    push ecx
    xor eax, eax
    xor ebx, ebx
.loop:
    mov bl, [esi]
    cmp bl, '0'
    jb .done
    cmp bl, '9'
    ja .done
    sub bl, '0'
    mov ecx, 10
    mul ecx
    add eax, ebx
    inc esi
    jmp .loop
.done:
    pop ecx
    pop ebx
    ret
skip_spaces_esi:
    push eax
.loop:
    mov al, [esi]
    cmp al, ' '
    je .skip
    cmp al, 0x09
    je .skip
    jmp .done
.skip:
    inc esi
    jmp .loop
.done:
    pop eax
    ret
copy_token:
    pusha
.loop:
    mov al, [esi]
    cmp al, 0
    je .done
    cmp al, ' '
    je .done
    mov [edi], al
    inc esi
    inc edi
    jmp .loop
.done:
    mov byte [edi], 0
    popa
    ret
cursor_pos dd 0
shift_pressed db 0
input_buf times 128 db 0
newline db 0x0d,0x0a,0
input_len dd 0
cursor_pos_in_buf dd 0
input_start dd 0
current_color db 0x0F
;=============================================================================
; IDE Disk Driver - Low-level disk I/O
;=============================================================================

ide_select_disk:
    ; Select IDE disk based on disk number in al
    ; Sets ide_base_port and ide_drive_bit
    push eax
    test al, 2
    jz .primary
    mov word [ide_base_port], 0x170
    jmp .drv
.primary:
    mov word [ide_base_port], 0x1F0
.drv:
    and al, 1
    shl al, 4
    mov [ide_drive_bit], al
    pop eax
    ret
pit_delay_ms:
    pusha
    mov ecx, eax
    mov eax, 1193
    mul ecx
    mov ecx, eax
    mov al, 0xB0
    out 0x43, al
    mov ax, cx
    out 0x42, al
    mov al, ah
    out 0x42, al
    in al, 0x61
    or al, 1
    out 0x61, al
.pit_wait:
    in al, 0x61
    test al, 0x20
    jz .pit_wait
    in al, 0x61
    and al, 0xFE
    out 0x61, al
    popa
    ret
ide_wait_ready:
    push eax
    push edx
    mov dx, [ide_base_port]
    add dx, IDE_STATUS
.wait:
    in al, dx
    test al, 0x80
    jnz .wait
    pop edx
    pop eax
    ret
ide_wait_drq:
    push eax
    push edx
    mov dx, [ide_base_port]
    add dx, IDE_STATUS
.wait:
    in al, dx
    test al, 0x80
    jnz .wait
    test al, 0x08
    jz .wait
    pop edx
    pop eax
    ret
ide_read_sectors:
    pusha
    mov [tmp_lba], eax
    mov [tmp_count], ecx
    mov [tmp_buffer], edi
    mov al, [selected_disk]
    call ide_select_disk
.read_loop:
    cmp dword [tmp_count], 0
    je .done
    mov eax, [tmp_lba]
    mov ebx, eax
    shr ebx, 24
    and bl, 0x0F
    or bl, 0xE0
    or bl, byte [ide_drive_bit]
    mov dx, [ide_base_port]
    add dx, IDE_DRIVE
    mov al, bl
    out dx, al
    mov dx, [ide_base_port]
    add dx, IDE_SECT_CNT
    mov al, 1
    out dx, al
    mov eax, [tmp_lba]
    mov dx, [ide_base_port]
    add dx, IDE_LBA_LOW
    out dx, al
    mov eax, [tmp_lba]
    shr eax, 8
    mov dx, [ide_base_port]
    add dx, IDE_LBA_MID
    out dx, al
    mov eax, [tmp_lba]
    shr eax, 16
    mov dx, [ide_base_port]
    add dx, IDE_LBA_HIGH
    out dx, al
    call ide_wait_ready
    mov dx, [ide_base_port]
    add dx, IDE_CMD
    mov al, CMD_READ
    out dx, al
    call ide_wait_drq
    mov dx, [ide_base_port]
    add dx, IDE_DATA
    mov ecx, 256
    mov edi, [tmp_buffer]
    rep insw
    inc dword [tmp_lba]
    dec dword [tmp_count]
    add dword [tmp_buffer], 512
    jmp .read_loop
.done:
    popa
    ret
ide_write_sectors:
    pusha
    mov [tmp_lba], eax
    mov [tmp_count], ecx
    mov [tmp_buffer], esi
    mov al, [selected_disk]
    call ide_select_disk
.write_loop:
    cmp dword [tmp_count], 0
    je .done
    mov eax, [tmp_lba]
    mov ebx, eax
    shr ebx, 24
    and bl, 0x0F
    or bl, 0xE0
    or bl, byte [ide_drive_bit]
    mov dx, [ide_base_port]
    add dx, IDE_DRIVE
    mov al, bl
    out dx, al
    mov dx, [ide_base_port]
    add dx, IDE_SECT_CNT
    mov al, 1
    out dx, al
    mov eax, [tmp_lba]
    mov dx, [ide_base_port]
    add dx, IDE_LBA_LOW
    out dx, al
    mov eax, [tmp_lba]
    shr eax, 8
    mov dx, [ide_base_port]
    add dx, IDE_LBA_MID
    out dx, al
    mov eax, [tmp_lba]
    shr eax, 16
    mov dx, [ide_base_port]
    add dx, IDE_LBA_HIGH
    out dx, al
    call ide_wait_ready
    mov dx, [ide_base_port]
    add dx, IDE_CMD
    mov al, CMD_WRITE
    out dx, al
    call ide_wait_drq
    mov dx, [ide_base_port]
    add dx, IDE_DATA
    mov ecx, 256
    mov esi, [tmp_buffer]
    rep outsw
    mov dx, [ide_base_port]
    add dx, IDE_CMD
    mov al, 0xE7
    out dx, al
    call ide_wait_ready
    inc dword [tmp_lba]
    dec dword [tmp_count]
    add dword [tmp_buffer], 512
    jmp .write_loop
.done:
    popa
    ret
detect_disks:
    pusha
    mov ecx, 4
    mov edi, disk_present
    xor ebx, ebx
.detect_loop:
    push ecx
    push ebx
    test ebx, 2
    jz .primary
    mov word [ide_base_port], 0x170
    jmp .drv_sel
.primary:
    mov word [ide_base_port], 0x1F0
.drv_sel:
    mov eax, ebx
    and al, 1
    shl al, 4
    or al, 0xA0
    mov dx, [ide_base_port]
    add dx, IDE_DRIVE
    out dx, al
    mov ecx, 500000
.delay1:
    in al, dx
    loop .delay1
    mov dx, [ide_base_port]
    add dx, IDE_STATUS
    in al, dx
    cmp al, 0xFF
    je .no_disk
    cmp al, 0x00
    je .no_disk
    cmp al, 0x50
    je .has_disk
    cmp al, 0x40
    je .has_disk
    test al, 0x40
    jnz .has_disk
    jmp .no_disk
.has_disk:
    mov dx, [ide_base_port]
    add dx, IDE_SECT_CNT
    xor al, al
    out dx, al
    mov dx, [ide_base_port]
    add dx, IDE_LBA_LOW
    out dx, al
    mov dx, [ide_base_port]
    add dx, IDE_LBA_MID
    out dx, al
    mov dx, [ide_base_port]
    add dx, IDE_LBA_HIGH
    out dx, al
    mov dx, [ide_base_port]
    add dx, IDE_CMD
    mov al, CMD_IDENTIFY
    out dx, al
    mov ecx, 2000000
.wait_status:
    mov dx, [ide_base_port]
    add dx, IDE_STATUS
    in al, dx
    test al, 0x80
    jz .status_ready
    loop .wait_status
    jmp .no_disk
.status_ready:
    test al, 0x01
    jnz .no_disk
    test al, 0x08
    jz .no_disk
    mov byte [edi], 1
    jmp .next
.no_disk:
    mov byte [edi], 0
.next:
    pop ebx
    pop ecx
    inc edi
    inc ebx
    dec ecx
    jnz .detect_loop
    popa
    ret
get_disk_size:
    pusha
    mov al, [selected_disk]
    call ide_select_disk
    mov al, 0xA0
    or al, byte [ide_drive_bit]
    mov dx, [ide_base_port]
    add dx, IDE_DRIVE
    out dx, al
    mov dx, [ide_base_port]
    add dx, IDE_CMD
    mov al, CMD_IDENTIFY
    out dx, al
    call ide_wait_drq
    mov dx, [ide_base_port]
    add dx, IDE_DATA
    mov edi, identify_buffer
    mov ecx, 256
    rep insw
    mov ax, [identify_buffer + 120]
    mov bx, [identify_buffer + 122]
    shl ebx, 16
    or eax, ebx
    mov [disk_size_sectors], eax
    popa
    ret
;=============================================================================
; MBR Partition Table Management
;=============================================================================

read_mbr:
    ; Read MBR and parse partition table entries
    ; Stores active partitions in partition_table
    pusha
    xor eax, eax
    mov ecx, 1
    mov edi, sector_buffer
    call ide_read_sectors
    mov ax, [sector_buffer + 510]
    cmp ax, 0xAA55
    jne .no_mbr
    mov esi, sector_buffer + 446
    mov edi, partition_table
    mov ecx, 4
.parse_loop:
    push ecx
    mov al, [esi + 4]
    mov [edi + 4], al
    mov eax, [esi + 8]
    mov [edi + 8], eax
    mov eax, [esi + 12]
    mov [edi + 12], eax
    cmp eax, 0
    je .inactive
    mov byte [edi], 1
    jmp .next_entry
.inactive:
    mov byte [edi], 0
.next_entry:
    add esi, 16
    add edi, 16
    pop ecx
    dec ecx
    jnz .parse_loop
    popa
    ret
.no_mbr:
    mov ecx, 4
    mov edi, partition_table
.clear_loop:
    mov byte [edi], 0
    add edi, 16
    dec ecx
    jnz .clear_loop
    popa
    ret
write_mbr_single:
    pusha
    call read_mbr
    mov ecx, 4
    xor edx, edx
    mov dword [mbr_free_entry], -1
    mov dword [mbr_max_end], 1
.scan_loop:
    mov eax, edx
    shl eax, 4
    mov edi, partition_table
    add edi, eax
    cmp byte [edi], 0
    je .empty_entry
    mov eax, [edi + 8]
    add eax, [edi + 12]
    cmp eax, [mbr_max_end]
    jle .scan_next
    mov [mbr_max_end], eax
    jmp .scan_next
.empty_entry:
    cmp dword [mbr_free_entry], -1
    jne .scan_next
    mov [mbr_free_entry], edx
.scan_next:
    inc edx
    dec ecx
    jnz .scan_loop
    cmp dword [mbr_free_entry], -1
    je .no_free
    mov eax, [mbr_max_end]
    mov [mbr_new_start], eax
    cmp ebx, 0
    jne .use_custom
    mov eax, [disk_size_sectors]
    sub eax, [mbr_new_start]
    jmp .set_size
.use_custom:
    mov eax, ebx
.set_size:
    mov [mbr_new_size], eax
    mov edx, [mbr_free_entry]
    mov eax, edx
    shl eax, 4
    mov edi, partition_table
    add edi, eax
    mov byte [edi], 1
    mov byte [edi + 4], 0x01
    mov eax, [mbr_new_start]
    mov [edi + 8], eax
    mov eax, [mbr_new_size]
    mov [edi + 12], eax
    call write_mbr_from_table
    jmp .done
.no_free:
    mov esi, msg_no_free_part
    call print32
.done:
    popa
    ret
write_mbr_from_table:
    pusha
    mov edi, sector_buffer
    mov ecx, 512
    xor al, al
    rep stosb
    mov ecx, 4
    xor edx, edx
.convert_loop:
    mov eax, edx
    shl eax, 4
    mov esi, partition_table
    add esi, eax
    mov edi, sector_buffer + 446
    add edi, eax
    cmp byte [esi], 0
    je .convert_skip
    mov byte [edi], 0x80
    mov byte [edi + 1], 0x01
    mov byte [edi + 2], 0x01
    mov byte [edi + 3], 0x00
    mov al, [esi + 4]
    mov [edi + 4], al
    mov byte [edi + 5], 0xFE
    mov byte [edi + 6], 0xFF
    mov byte [edi + 7], 0xFF
    mov eax, [esi + 8]
    mov [edi + 8], eax
    mov eax, [esi + 12]
    mov [edi + 12], eax
.convert_skip:
    inc edx
    dec ecx
    jnz .convert_loop
    mov word [sector_buffer + 510], 0xAA55
    xor eax, eax
    mov ecx, 1
    mov esi, sector_buffer
    call ide_write_sectors
    popa
    ret
;=============================================================================
; FAT12/FAT32 Filesystem Functions
;=============================================================================

load_boot_sector:
    ; Read boot sector and calculate filesystem layout
    ; Sets: fat1_start, root_dir_start, data_area_start
    pusha
    mov eax, [selected_partition_start]
    mov ecx, 1
    mov edi, sector_buffer
    call ide_read_sectors
    mov ax, [sector_buffer + 11]
    mov [fat_bytes_per_sector], ax
    mov al, [sector_buffer + 13]
    mov [fat_sectors_per_cluster], al
    mov ax, [sector_buffer + 14]
    mov [fat_reserved_sectors], ax
    mov al, [sector_buffer + 16]
    mov [fat_num_fats], al
    mov ax, [sector_buffer + 17]
    mov [fat_root_entries], ax
    mov ax, [sector_buffer + 22]
    mov [fat_sectors_per_fat], ax
    mov ax, [sector_buffer + 19]
    mov [fat_total_sectors], ax
    mov eax, [sector_buffer + 32]
    test eax, eax
    jz .use_small
    mov [fat_total_sectors], eax
.use_small:
    movzx eax, word [fat_reserved_sectors]
    add eax, [selected_partition_start]
    mov [fat1_start], eax
    movzx eax, word [fat_sectors_per_fat]
    movzx ebx, byte [fat_num_fats]
    mul ebx
    add eax, [fat1_start]
    mov [root_dir_start], eax
    movzx eax, word [fat_root_entries]
    mov ebx, 32
    mul ebx
    mov ebx, 512
    add eax, ebx
    dec eax
    xor edx, edx
    div ebx
    add eax, [root_dir_start]
    mov [data_area_start], eax
    mov eax, [fat1_start]
    movzx ecx, word [fat_sectors_per_fat]
    mov edi, fat_buffer
    call ide_read_sectors
    popa
    ret
write_fat:
    pusha
    mov eax, [fat1_start]
    movzx ecx, word [fat_sectors_per_fat]
    mov esi, fat_buffer
    call ide_write_sectors
    movzx eax, word [fat_sectors_per_fat]
    add eax, [fat1_start]
    movzx ecx, word [fat_sectors_per_fat]
    mov esi, fat_buffer
    call ide_write_sectors
    popa
    ret
write_dir_sector:
    pusha
    cmp dword [current_dir_cluster], 0
    jne .one_sector
    movzx eax, word [fat_root_entries]
    mov ecx, 32
    mul ecx
    mov ecx, 512
    add eax, ecx
    dec eax
    xor edx, edx
    div ecx
    mov ecx, eax
    jmp .do_write
.one_sector:
    mov ecx, 1
.do_write:
    mov eax, [current_dir_sector]
    mov esi, dir_buffer
    call ide_write_sectors
    popa
    ret
format_fat12:
    pusha
    mov edi, sector_buffer
    mov ecx, 512
    xor al, al
    rep stosb
    mov byte [sector_buffer], 0xEB
    mov byte [sector_buffer + 1], 0x3C
    mov byte [sector_buffer + 2], 0x90
    mov dword [sector_buffer + 3], 0x2020594D
    mov word [sector_buffer + 11], 512
    mov byte [sector_buffer + 13], 1
    mov word [sector_buffer + 14], 1
    mov byte [sector_buffer + 16], 2
    mov word [sector_buffer + 17], 224
    mov word [sector_buffer + 19], 0
    mov byte [sector_buffer + 21], 0xF0
    mov word [sector_buffer + 22], 9
    mov word [sector_buffer + 24], 18
    mov word [sector_buffer + 26], 2
    mov dword [sector_buffer + 28], 0
    mov dword [sector_buffer + 32], 0
    mov byte [sector_buffer + 36], 0x80
    mov byte [sector_buffer + 38], 0x29
    mov dword [sector_buffer + 39], 0x12345678
    mov dword [sector_buffer + 54], 0x20544146
    mov dword [sector_buffer + 58], 0x20223132
    mov dword [sector_buffer + 62], 0x20202020
    mov word [sector_buffer + 510], 0xAA55
    mov eax, [disk_size_sectors]
    dec eax
    mov [sector_buffer + 32], eax
    mov eax, [selected_partition_start]
    mov ecx, 1
    mov esi, sector_buffer
    call ide_write_sectors
    mov edi, fat_buffer
    mov ecx, 4608
    xor al, al
    rep stosb
    mov byte [fat_buffer], 0xF0
    mov byte [fat_buffer + 1], 0xFF
    mov byte [fat_buffer + 2], 0xFF
    call write_fat
    mov edi, dir_buffer
    mov ecx, 512 * 14
    xor al, al
    rep stosb
    mov eax, [selected_partition_start]
    add eax, 1
    add eax, 18
    mov [root_dir_start], eax
    mov ecx, 14
    mov esi, dir_buffer
    call ide_write_sectors
    mov eax, [selected_partition_start]
    add eax, 33
    mov [fmt_zero_lba], eax
    mov eax, [selected_partition_size]
    sub eax, 33
    jle .zero_done
    mov [fmt_zero_count], eax
    mov edi, dir_buffer
    mov ecx, 7168
    xor al, al
    rep stosb
    mov esi, fmt_msg
    call print32
.zero_loop:
    cmp dword [fmt_zero_count], 0
    jle .zero_done
    mov eax, [fmt_zero_lba]
    mov ecx, 14
    cmp [fmt_zero_count], ecx
    jge .zero_write
    mov ecx, [fmt_zero_count]
.zero_write:
    push ecx
    mov esi, dir_buffer
    call ide_write_sectors
    pop ecx
    add [fmt_zero_lba], ecx
    sub [fmt_zero_count], ecx
    jmp .zero_loop
.zero_done:
    call load_boot_sector
    mov eax, [root_dir_start]
    mov [current_dir_cluster], dword 0
    mov [current_dir_sector], eax
    popa
    ret
format_fat32:
    ; Format partition as FAT32 with low-level zero fill
    pusha
    ; Clear sector buffer
    mov edi, sector_buffer
    mov ecx, 512
    xor al, al
    rep stosb
    ; Build FAT32 boot sector
    mov byte [sector_buffer], 0xEB
    mov byte [sector_buffer + 1], 0x58
    mov byte [sector_buffer + 2], 0x90
    mov dword [sector_buffer + 3], 0x2020594D  ; "MY  "
    mov word [sector_buffer + 11], 512         ; Bytes per sector
    mov byte [sector_buffer + 13], 1           ; Sectors per cluster
    mov word [sector_buffer + 14], 32          ; Reserved sectors
    mov byte [sector_buffer + 16], 2           ; Number of FATs
    mov word [sector_buffer + 17], 0           ; Root entries (0 for FAT32)
    mov word [sector_buffer + 19], 0           ; Total sectors (16-bit, 0 for FAT32)
    mov byte [sector_buffer + 21], 0xF8        ; Media descriptor
    mov word [sector_buffer + 22], 0           ; Sectors per FAT (0 for FAT32)
    mov word [sector_buffer + 24], 63          ; Sectors per track
    mov word [sector_buffer + 26], 255         ; Number of heads
    mov dword [sector_buffer + 28], 0          ; Hidden sectors
    mov dword [sector_buffer + 32], 0          ; Total sectors (32-bit, filled below)
    mov dword [sector_buffer + 36], 0          ; Sectors per FAT (32-bit, filled below)
    mov word [sector_buffer + 40], 0           ; Flags
    mov word [sector_buffer + 42], 0           ; Version
    mov dword [sector_buffer + 44], 2          ; Root directory cluster
    mov word [sector_buffer + 48], 1           ; FSInfo sector
    mov word [sector_buffer + 50], 6           ; Backup boot sector
    mov byte [sector_buffer + 36], 0x80        ; Drive number
    mov byte [sector_buffer + 38], 0x29        ; Signature
    mov dword [sector_buffer + 39], 0x12345678 ; Volume serial
    mov dword [sector_buffer + 54], 0x20544146  ; "FAT"
    mov dword [sector_buffer + 58], 0x20323332 ; "32  "
    mov dword [sector_buffer + 62], 0x20202020 ; "    "
    mov word [sector_buffer + 510], 0xAA55     ; Boot signature
    ; Calculate total sectors and FAT size
    mov eax, [selected_partition_size]
    dec eax
    mov [sector_buffer + 32], eax              ; Total sectors (32-bit)
    ; Calculate FAT size (approximate: 1 sector per 128 clusters)
    mov ebx, eax
    shr ebx, 7                                 ; FAT sectors = total_sectors / 128
    cmp ebx, 0
    jne .fat_size_ok
    mov ebx, 1
.fat_size_ok:
    mov [sector_buffer + 36], ebx              ; FAT size (32-bit)
    ; Write boot sector
    mov eax, [selected_partition_start]
    mov ecx, 1
    mov esi, sector_buffer
    call ide_write_sectors
    ; Clear FAT buffer
    mov edi, fat_buffer
    mov ecx, 4608
    xor al, al
    rep stosb
    ; Initialize FAT32 root entries
    mov byte [fat_buffer], 0xF8
    mov byte [fat_buffer + 1], 0xFF
    mov byte [fat_buffer + 2], 0xFF
    mov byte [fat_buffer + 3], 0x0F
    mov byte [fat_buffer + 4], 0xFF
    mov byte [fat_buffer + 5], 0xFF
    mov byte [fat_buffer + 6], 0xFF
    mov byte [fat_buffer + 7], 0x0F
    mov byte [fat_buffer + 8], 0xFF
    mov byte [fat_buffer + 9], 0xFF
    mov byte [fat_buffer + 10], 0xFF
    mov byte [fat_buffer + 11], 0x0F
    ; Write FAT tables
    call write_fat
    ; Clear root directory
    mov edi, dir_buffer
    mov ecx, 512 * 14
    xor al, al
    rep stosb
    ; Write root directory
    mov eax, [selected_partition_start]
    add eax, 32                                 ; Reserved sectors
    add eax, [sector_buffer + 36]              ; FAT1 start
    add eax, [sector_buffer + 36]              ; FAT2 start
    mov [root_dir_start], eax
    mov ecx, 1                                  ; 1 cluster
    mov esi, dir_buffer
    call ide_write_sectors
    ; Zero fill data area (low-level format)
    mov eax, [selected_partition_start]
    add eax, 32                                 ; Reserved sectors
    add eax, [sector_buffer + 36]              ; FAT1 size
    add eax, [sector_buffer + 36]              ; FAT2 size
    mov [fmt_zero_lba], eax
    mov eax, [selected_partition_size]
    sub eax, 32                                 ; Reserved sectors
    sub eax, [sector_buffer + 36]              ; FAT1 size
    sub eax, [sector_buffer + 36]              ; FAT2 size
    jle .zero_done
    mov [fmt_zero_count], eax
    mov edi, dir_buffer
    mov ecx, 7168
    xor al, al
    rep stosb
    mov esi, fmt_msg
    call print32
.zero_loop:
    cmp dword [fmt_zero_count], 0
    jle .zero_done
    mov eax, [fmt_zero_lba]
    mov ecx, 14
    cmp [fmt_zero_count], ecx
    jge .zero_write
    mov ecx, [fmt_zero_count]
.zero_write:
    push ecx
    mov esi, dir_buffer
    call ide_write_sectors
    pop ecx
    add [fmt_zero_lba], ecx
    sub [fmt_zero_count], ecx
    jmp .zero_loop
.zero_done:
    call load_boot_sector
    mov eax, [root_dir_start]
    mov [current_dir_cluster], dword 0
    mov [current_dir_sector], eax
    popa
    ret
    pusha
    cmp dword [current_dir_cluster], 0
    jne .one_sector
    movzx eax, word [fat_root_entries]
    mov ecx, 32
    mul ecx
    mov ecx, 512
    add eax, ecx
    dec eax
    xor edx, edx
    div ecx
    mov ecx, eax
    jmp .do_read
.one_sector:
    mov ecx, 1
.do_read:
    mov eax, [current_dir_sector]
    mov edi, dir_buffer
    call ide_read_sectors
    popa
    ret
cluster_to_lba:
    push ebx
    sub eax, 2
    movzx ebx, byte [fat_sectors_per_cluster]
    mul ebx
    add eax, [data_area_start]
    pop ebx
    ret
get_next_cluster:
    push ebx
    push ecx
    push edx
    mov ebx, eax
    shl eax, 1
    add eax, ebx
    shr eax, 1
    movzx ecx, word [fat_buffer + eax]
    test ebx, 1
    jz .even
    shr ecx, 4
    jmp .done
.even:
    and ecx, 0x0FFF
.done:
    mov eax, ecx
    pop edx
    pop ecx
    pop ebx
    ret
set_next_cluster:
    pusha
    mov ecx, eax
    shl eax, 1
    add eax, ecx
    shr eax, 1
    test ecx, 1
    jz .even
    movzx ecx, word [fat_buffer + eax]
    and ecx, 0x000F
    shl ebx, 4
    or ecx, ebx
    mov [fat_buffer + eax], cx
    jmp .done
.even:
    movzx ecx, word [fat_buffer + eax]
    and ecx, 0xF000
    and ebx, 0x0FFF
    or ecx, ebx
    mov [fat_buffer + eax], cx
.done:
    popa
    ret
find_free_cluster:
    push ebx
    push ecx
    mov ecx, 2
.search_loop:
    mov eax, ecx
    call get_next_cluster
    cmp eax, 0
    je .found
    inc ecx
    cmp ecx, 4085
    jl .search_loop
    xor eax, eax
    jmp .done
.found:
    mov eax, ecx
.done:
    pop ecx
    pop ebx
    ret
allocate_cluster:
    push ebx
    call find_free_cluster
    cmp eax, 0
    je .done
    mov ebx, 0x0FFF
    call set_next_cluster
.done:
    pop ebx
    ret
find_dir_entry:
    push ebx
    push ecx
    push edx
    push esi
    push edi
    mov ecx, [fat_root_entries]
    cmp dword [current_dir_cluster], 0
    jne .data_dir
    mov ecx, [fat_root_entries]
    jmp .search
.data_dir:
    mov ecx, DIRS_PER_SECT
.search:
    xor ebx, ebx
.loop:
    cmp ebx, ecx
    jge .not_found
    mov edi, dir_buffer
    mov eax, ebx
    mov edx, BYTES_PER_DIR
    mul edx
    add edi, eax
    cmp byte [edi], 0xE5
    je .next
    cmp byte [edi], 0
    je .not_found
    push esi
    push edi
    mov ecx, 11
    repe cmpsb
    pop edi
    pop esi
    je .found
.next:
    inc ebx
    jmp .loop
.not_found:
    mov eax, -1
    jmp .done
.found:
    mov eax, ebx
    shl eax, 5
.done:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret
find_free_dir_entry:
    push ebx
    push ecx
    push edx
    mov ecx, [fat_root_entries]
    cmp dword [current_dir_cluster], 0
    jne .data_dir
    mov ecx, [fat_root_entries]
    jmp .search
.data_dir:
    mov ecx, DIRS_PER_SECT
.search:
    xor ebx, ebx
.loop:
    cmp ebx, ecx
    jge .full
    mov eax, ebx
    mov edx, BYTES_PER_DIR
    mul edx
    cmp byte [dir_buffer + eax], 0xE5
    je .found
    cmp byte [dir_buffer + eax], 0
    je .found
    inc ebx
    jmp .loop
.full:
    mov eax, -1
    jmp .done
.found:
.done:
    pop edx
    pop ecx
    pop ebx
    ret
filename_to_83:
    pusha
    cmp esi, edi
    jne .proceed
    push edi
    mov ecx, 12
    mov esi, edi
    mov edi, tmp_component
    cld
    rep movsb
    pop edi
    mov esi, tmp_component
.proceed:
    mov ecx, 11
    push edi
    mov al, ' '
    rep stosb
    pop edi
    mov ecx, 8
.name_loop:
    cmp byte [esi], 0
    je .done
    cmp byte [esi], '.'
    je .extension
    cmp byte [esi], ' '
    je .skip
    mov al, [esi]
    mov [edi], al
    inc edi
    inc esi
    dec ecx
    jnz .name_loop
.skip_to_dot:
    cmp byte [esi], 0
    je .done
    cmp byte [esi], '.'
    je .extension
    inc esi
    jmp .skip_to_dot
.skip:
    inc esi
    jmp .name_loop
.extension:
    inc esi
    add edi, ecx
    mov ecx, 3
.ext_loop:
    cmp byte [esi], 0
    je .done
    cmp byte [esi], ' '
    je .done
    mov al, [esi]
    mov [edi], al
    inc edi
    inc esi
    dec ecx
    jnz .ext_loop
.done:
    popa
    ret
;=============================================================================
; File Operations - Read, write, create, delete files
;=============================================================================

read_dir_sector:
    pusha
    cmp dword [current_dir_cluster], 0
    jne .one_sector
    movzx eax, word [fat_root_entries]
    mov ecx, 32
    mul ecx
    mov ecx, 512
    add eax, ecx
    dec eax
    xor edx, edx
    div ecx
    mov ecx, eax
    jmp .do_read
.one_sector:
    mov ecx, 1
.do_read:
    mov eax, [current_dir_sector]
    mov edi, dir_buffer
    call ide_read_sectors
    popa
    ret

list_directory:
    ; List all files in current directory
    pusha
    call read_dir_sector
    mov esi, ls_header
    call print32
    mov ecx, [fat_root_entries]
    cmp dword [current_dir_cluster], 0
    jne .data_dir
    mov ecx, [fat_root_entries]
    jmp .list
.data_dir:
    mov ecx, DIRS_PER_SECT
.list:
    xor ebx, ebx
.loop:
    cmp ebx, ecx
    jge .done
    mov eax, ebx
    mov edx, BYTES_PER_DIR
    mul edx
    mov edi, dir_buffer
    add edi, eax
    cmp byte [edi], 0xE5
    je .next
    cmp byte [edi], 0
    je .done
    mov al, [edi + 11]
    test al, 0x08
    jnz .next
    push ebx
    push ecx
    xor edx, edx
    mov esi, edi
    mov ecx, 8
.name_part:
    lodsb
    cmp al, ' '
    je .name_skip
    call print_char
    inc edx
.name_skip:
    loop .name_part
    mov al, [edi + 8]
    cmp al, ' '
    je .no_ext
    mov al, '.'
    call print_char
    inc edx
    mov ecx, 3
    lea esi, [edi + 8]
.ext_part:
    lodsb
    cmp al, ' '
    je .ext_skip
    call print_char
    inc edx
.ext_skip:
    loop .ext_part
.no_ext:
    mov eax, 14
    sub eax, edx
    jle .name_pad_done
    mov ecx, eax
.name_pad_loop:
    mov al, ' '
    call print_char
    loop .name_pad_loop
.name_pad_done:
    mov al, [edi + 11]
    test al, 0x10
    jz .file_type
    mov esi, type_dir
    call print32
    jmp .after_type
.file_type:
    mov esi, type_file
    call print32
.after_type:
    mov al, ' '
    call print_char
    mov al, ' '
    call print_char
    mov eax, [edi + 28]
    mov ecx, 1024
    xor edx, edx
    div ecx
    push eax
    call count_digits
    mov ecx, 6
    sub ecx, eax
    jle .size_pad_done
.size_pad_loop:
    mov al, ' '
    call print_char
    loop .size_pad_loop
.size_pad_done:
    pop eax
    call print_number
    mov esi, newline
    call print32
    pop ecx
    pop ebx
.next:
    inc ebx
    jmp .loop
.done:
    popa
    ret
read_file:
    pusha
    mov edi, tmp_filename
    call filename_to_83
    mov esi, tmp_filename
    call find_dir_entry
    cmp eax, -1
    je .not_found
    mov edi, dir_buffer
    add edi, eax
    mov al, [edi + 11]
    test al, 0x10
    jnz .is_dir
    movzx eax, word [edi + 26]
.read_loop:
    cmp eax, 0x0FF8
    jae .done_read
    cmp eax, 2
    jb .done_read
    push eax
    call cluster_to_lba
    mov ecx, 1
    mov edi, sector_buffer
    call ide_read_sectors
    mov esi, sector_buffer
    mov ecx, 512
.print_loop:
    lodsb
    cmp al, 0
    je .skip_null
    call print_char
.skip_null:
    loop .print_loop
    pop eax
    call get_next_cluster
    jmp .read_loop
.done_read:
    mov esi, newline
    call print32
    popa
    ret
.not_found:
    mov esi, msg_file_not_found
    call print32
    popa
    ret
.is_dir:
    mov esi, msg_is_directory
    call print32
    popa
    ret
write_file:
    pusha
    push esi
    mov esi, edi
    mov edi, tmp_filename
    call filename_to_83
    pop esi
    push esi
    mov esi, tmp_filename
    call find_dir_entry
    pop esi
    cmp eax, -1
    je .create_new
    mov edi, dir_buffer
    add edi, eax
    movzx ebx, word [edi + 26]
.find_last:
    mov eax, ebx
    call get_next_cluster
    cmp eax, 0x0FF8
    jae .found_last
    mov ebx, eax
    jmp .find_last
.found_last:
    call find_free_cluster
    cmp eax, 0
    je .disk_full
    push eax
    mov eax, ebx
    mov ebx, [esp]
    call set_next_cluster
    pop eax
    push eax
    mov ebx, 0x0FFF
    call set_next_cluster
    pop eax
    call write_fat
    call cluster_to_lba
    mov ecx, 1
    mov edi, sector_buffer
    call copy_content_to_sector
    mov esi, sector_buffer
    call ide_write_sectors
    push esi
    mov esi, tmp_filename
    call find_dir_entry
    pop esi
    cmp eax, -1
    je .done
    mov edi, dir_buffer
    add edi, eax
    mov eax, [edi + 28]
    push eax
    call str_len
    pop ebx
    add eax, ebx
    mov [edi + 28], eax
    call write_dir_sector
    jmp .done
.create_new:
    call find_free_cluster
    cmp eax, 0
    je .disk_full
    mov ebx, eax
    push ebx
    mov eax, ebx
    mov ebx, 0x0FFF
    call set_next_cluster
    pop ebx
    call write_fat
    call find_free_dir_entry
    cmp eax, -1
    je .dir_full
    mov edi, dir_buffer
    add edi, eax
    push esi
    mov esi, tmp_filename
    mov ecx, 11
    rep movsb
    pop esi
    mov byte [edi - 11 + 11], 0x00
    mov word [edi - 11 + 26], bx
    mov dword [edi - 11 + 28], 0
    call write_dir_sector
    mov eax, ebx
    call cluster_to_lba
    mov ecx, 1
    mov edi, sector_buffer
    call copy_content_to_sector
    mov esi, sector_buffer
    call ide_write_sectors
    push esi
    mov esi, tmp_filename
    call find_dir_entry
    pop esi
    cmp eax, -1
    je .done
    mov edi, dir_buffer
    add edi, eax
    call str_len
    mov [edi + 28], eax
    call write_dir_sector
    jmp .done
.disk_full:
    mov esi, msg_disk_full
    call print32
    jmp .done
.dir_full:
    mov esi, msg_dir_full
    call print32
.done:
    popa
    ret
copy_content_to_sector:
    pusha
    push edi
    mov ecx, 512
    xor al, al
    rep stosb
    pop edi
.copy_loop:
    mov al, [esi]
    cmp al, 0
    je .done
    mov [edi], al
    inc esi
    inc edi
    jmp .copy_loop
.done:
    popa
    ret
create_directory:
    pusha
    mov edi, tmp_filename
    call filename_to_83
    call find_free_cluster
    cmp eax, 0
    je .disk_full
    mov ebx, eax
    push ebx
    mov eax, ebx
    mov ebx, 0x0FFF
    call set_next_cluster
    pop ebx
    call write_fat
    call find_free_dir_entry
    cmp eax, -1
    je .dir_full
    mov edi, dir_buffer
    add edi, eax
    push esi
    mov esi, tmp_filename
    mov ecx, 11
    rep movsb
    pop esi
    mov byte [edi - 11 + 11], 0x10
    mov word [edi - 11 + 26], bx
    mov dword [edi - 11 + 28], 0
    call write_dir_sector
    mov eax, ebx
    call cluster_to_lba
    mov ecx, 1
    mov edi, sector_buffer
    call ide_read_sectors
    mov edi, sector_buffer
    mov ecx, 512
    xor al, al
    rep stosb
    mov byte [sector_buffer], '.'
    mov ecx, 10
    mov edi, sector_buffer + 1
.fill_dot:
    mov al, ' '
    stosb
    loop .fill_dot
    mov byte [sector_buffer + 11], 0x10
    mov word [sector_buffer + 26], bx
    mov byte [sector_buffer + 32], '.'
    mov byte [sector_buffer + 33], '.'
    mov ecx, 9
    mov edi, sector_buffer + 34
.fill_dotdot:
    mov al, ' '
    stosb
    loop .fill_dotdot
    mov byte [sector_buffer + 43], 0x10
    mov eax, [current_dir_cluster]
    mov word [sector_buffer + 58], ax
    mov esi, sector_buffer
    call ide_write_sectors
    popa
    ret
.disk_full:
    mov esi, msg_disk_full
    call print32
    popa
    ret
.dir_full:
    mov esi, msg_dir_full
    call print32
    popa
    ret
delete_directory:
    pusha
    mov edi, tmp_filename
    call filename_to_83
    mov esi, tmp_filename
    call find_dir_entry
    cmp eax, -1
    je .not_found
    mov edi, dir_buffer
    add edi, eax
    mov al, [edi + 11]
    test al, 0x10
    jz .not_dir
    movzx ebx, word [edi + 26]
.free_loop:
    cmp ebx, 0x0FF8
    jae .free_done
    cmp ebx, 2
    jb .free_done
    mov eax, ebx
    call get_next_cluster
    push eax
    mov eax, ebx
    mov ebx, 0
    call set_next_cluster
    pop ebx
    jmp .free_loop
.free_done:
    call write_fat
    mov byte [edi], 0xE5
    call write_dir_sector
    popa
    ret
.not_found:
    mov esi, msg_not_found
    call print32
    popa
    ret
.not_dir:
    mov esi, msg_not_directory
    call print32
    popa
    ret
delete_file:
    pusha
    mov edi, tmp_filename
    call filename_to_83
    mov esi, tmp_filename
    call find_dir_entry
    cmp eax, -1
    je .not_found
    mov edi, dir_buffer
    add edi, eax
    mov al, [edi + 11]
    test al, 0x10
    jnz .is_dir
    movzx ebx, word [edi + 26]
.free_loop:
    cmp ebx, 0x0FF8
    jae .free_done
    cmp ebx, 2
    jb .free_done
    mov eax, ebx
    call get_next_cluster
    push eax
    mov eax, ebx
    mov ebx, 0
    call set_next_cluster
    pop ebx
    jmp .free_loop
.free_done:
    call write_fat
    mov byte [edi], 0xE5
    call write_dir_sector
    popa
    ret
.not_found:
    mov esi, msg_file_not_found
    call print32
    popa
    ret
.is_dir:
    mov esi, msg_is_directory
    call print32
    popa
    ret
;=============================================================================
; Drive Letter Management
;=============================================================================

init_drive_table:
    ; Initialize drive table with default system drive A:
    pusha
    mov edi, drive_table
    mov ecx, MAX_DRIVES * 16
    xor al, al
    rep stosb
    mov byte [drive_table], 1
    mov byte [drive_table + 1], 'A'
    mov byte [drive_table + 2], 0xFF
    mov byte [drive_table + 3], 0xFF
    mov dword [drive_table + 4], 0xFFFFFFFF
    mov byte [current_drive], 0
    mov byte [current_path], 'A'
    mov byte [current_path + 1], '/'
    mov byte [current_path + 2], 0
    popa
    ret
assign_drive_letter:
    pusha
    mov ecx, 1
.find_loop:
    cmp ecx, MAX_DRIVES
    jge .done
    mov eax, ecx
    shl eax, 4
    cmp byte [drive_table + eax], 0
    je .found_slot
    inc ecx
    jmp .find_loop
.found_slot:
    mov ebx, ecx
    shl ebx, 4
    mov byte [drive_table + ebx], 1
    mov eax, ecx
    add eax, 'A'
    mov byte [drive_table + ebx + 1], al
    mov al, [selected_disk]
    mov byte [drive_table + ebx + 2], al
    mov al, [selected_partition]
    mov byte [drive_table + ebx + 3], al
    mov eax, [selected_partition_start]
    mov dword [drive_table + ebx + 4], eax
    mov esi, msg_drive_assigned
    call print32
    mov al, [drive_table + ebx + 1]
    call print_char
    mov esi, newline
    call print32
    mov al, [drive_table + ebx + 1]
    call switch_drive
.done:
    popa
    ret
switch_drive:
    pusha
    mov [tmp_drive_letter], al
    cmp al, 'a'
    jb .upper
    cmp al, 'z'
    ja .upper
    sub al, 32
    mov [tmp_drive_letter], al
.upper:
    mov ecx, 0
.find_loop:
    cmp ecx, MAX_DRIVES
    jge .not_found
    mov ebx, ecx
    shl ebx, 4
    cmp byte [drive_table + ebx], 0
    je .next
    mov dl, [drive_table + ebx + 1]
    cmp dl, [tmp_drive_letter]
    je .found
.next:
    inc ecx
    jmp .find_loop
.found:
    mov [current_drive], cl
    cmp byte [tmp_drive_letter], 'A'
    je .is_a
    mov al, [drive_table + ebx + 2]
    mov [selected_disk], al
    mov al, [drive_table + ebx + 3]
    mov [selected_partition], al
    mov eax, [drive_table + ebx + 4]
    mov [selected_partition_start], eax
    call load_boot_sector
    mov eax, [root_dir_start]
    mov dword [current_dir_cluster], 0
    mov dword [current_dir_sector], eax
    jmp .set_path
.is_a:
    mov byte [selected_disk], 0xFF
    mov byte [selected_partition], 0xFF
    mov dword [selected_partition_start], 0
.set_path:
    mov al, [tmp_drive_letter]
    mov byte [current_path], al
    mov byte [current_path + 1], '/'
    mov byte [current_path + 2], 0
    jmp .done
.not_found:
    mov esi, msg_drive_not_found
    call print32
.done:
    popa
    ret
restore_current_drive_state:
    pusha
    movzx ebx, byte [current_drive]
    shl ebx, 4
    cmp byte [drive_table + ebx], 0
    je .invalid
    cmp byte [drive_table + ebx + 2], 0xFF
    je .invalid
    mov al, [drive_table + ebx + 2]
    mov [selected_disk], al
    mov al, [drive_table + ebx + 3]
    mov [selected_partition], al
    mov eax, [drive_table + ebx + 4]
    mov [selected_partition_start], eax
    call load_boot_sector
    popa
    xor eax, eax
    ret
.invalid:
    popa
    mov eax, -1
    ret
dl_list_cmd:
    pusha
    mov esi, msg_drive_list
    call print32
    mov ecx, 0
.loop:
    cmp ecx, MAX_DRIVES
    jge .done
    mov ebx, ecx
    shl ebx, 4
    cmp byte [drive_table + ebx], 0
    je .next
    mov al, [drive_table + ebx + 1]
    call print_char
    mov al, ' '
    call print_char
    mov al, '-'
    call print_char
    mov al, ' '
    call print_char
    mov al, [drive_table + ebx + 2]
    cmp al, 0xFF
    je .system_drive
    mov esi, msg_drive_part
    call print32
    movzx eax, byte [drive_table + ebx + 2]
    inc eax
    call print_number
    mov al, '/'
    call print_char
    movzx eax, byte [drive_table + ebx + 3]
    inc eax
    call print_number
    jmp .print_newline
.system_drive:
    mov esi, msg_drive_system
    call print32
.print_newline:
    mov esi, newline
    call print32
.next:
    inc ecx
    jmp .loop
.done:
    popa
    ret
cd_to_root:
    pusha
    cmp byte [selected_partition], 0xFF
    je .set_path_only
    mov eax, [root_dir_start]
    mov dword [current_dir_cluster], 0
    mov dword [current_dir_sector], eax
.set_path_only:
    mov ebx, 0
    mov bl, [current_drive]
    shl ebx, 4
    mov al, [drive_table + ebx + 1]
    mov byte [current_path], al
    mov byte [current_path + 1], '/'
    mov byte [current_path + 2], 0
    popa
    ret
is_alpha:
    cmp al, 'A'
    jb .no
    cmp al, 'Z'
    jbe .yes
    cmp al, 'a'
    jb .no
    cmp al, 'z'
    ja .no
.yes:
    mov al, 1
    ret
.no:
    mov al, 0
    ret
update_path_down:
    pusha
    mov esi, current_path
.find_end:
    cmp byte [esi], 0
    je .append
    inc esi
    jmp .find_end
.append:
    cmp esi, current_path
    je .no_slash
    mov al, [esi - 1]
    cmp al, '/'
    je .no_slash
    mov byte [esi], '/'
    inc esi
.no_slash:
    mov edi, tmp_filename
    mov ecx, 8
.copy_name:
    cmp byte [edi], ' '
    je .name_done
    cmp byte [edi], 0
    je .name_done
    mov al, [edi]
    mov [esi], al
    inc esi
    inc edi
    loop .copy_name
.name_done:
    mov byte [esi], 0
    popa
    ret
update_path_up:
    pusha
    mov esi, current_path
.find_end:
    cmp byte [esi], 0
    je .do_remove
    inc esi
    jmp .find_end
.do_remove:
    cmp esi, current_path + 2
    jb .done
    dec esi
.find_slash:
    cmp byte [esi], '/'
    je .check_root
    dec esi
    cmp esi, current_path
    jb .done
    jmp .find_slash
.check_root:
    cmp esi, current_path + 1
    je .keep_root
    inc esi
    mov byte [esi], 0
    jmp .done
.keep_root:
    mov byte [current_path + 2], 0
.done:
    popa
    ret
cd_directory:
    pusha
    cmp byte [esi], '.'
    jne .not_dotdot
    cmp byte [esi + 1], '.'
    jne .not_dotdot
    mov eax, [current_dir_cluster]
    cmp eax, 0
    je .done
    call read_dir_sector
    mov esi, dir_buffer + 32
    movzx eax, word [esi + 26]
    mov [current_dir_cluster], eax
    cmp eax, 0
    je .to_root
    call cluster_to_lba
    mov [current_dir_sector], eax
    call update_path_up
    jmp .done
.to_root:
    mov eax, [root_dir_start]
    mov [current_dir_sector], eax
    mov ebx, 0
    mov bl, [current_drive]
    shl ebx, 4
    mov al, [drive_table + ebx + 1]
    mov byte [current_path], al
    mov byte [current_path + 1], '/'
    mov byte [current_path + 2], 0
    jmp .done
.not_dotdot:
    mov edi, tmp_filename
    call filename_to_83
    mov esi, tmp_filename
    call find_dir_entry
    cmp eax, -1
    je .not_found
    mov edi, dir_buffer
    add edi, eax
    mov al, [edi + 11]
    test al, 0x10
    jz .not_dir
    movzx eax, word [edi + 26]
    mov [current_dir_cluster], eax
    cmp eax, 0
    je .root_cluster
    call cluster_to_lba
    jmp .set_sector
.root_cluster:
    mov eax, [root_dir_start]
.set_sector:
    mov [current_dir_sector], eax
    call update_path_down
    jmp .done
.not_found:
    mov esi, msg_not_found
    call print32
    jmp .done
.not_dir:
    mov esi, msg_not_directory
    call print32
.done:
    popa
    ret
disk_list:
    pusha
    mov esi, msg_disk_list
    call print32
    mov ecx, 4
    xor ebx, ebx
.loop:
    cmp byte [disk_present + ebx], 0
    je .next
    mov eax, ebx
    inc eax
    call print_number
    mov al, ' '
    call print_char
    mov al, '-'
    call print_char
    mov al, ' '
    call print_char
    mov esi, disk_names
    mov eax, ebx
    mov edx, 7
    mul edx
    add esi, eax
    call print32
    mov esi, newline
    call print32
.next:
    inc ebx
    dec ecx
    jnz .loop
    popa
    ret
disk_select:
    pusha
    mov esi, input_buf
    add esi, 8
    call skip_spaces_esi
    cmp byte [esi], 0
    je .no_arg
    call parse_number
    cmp eax, 0
    je .invalid
    cmp eax, 4
    ja .invalid
    dec eax
    cmp byte [disk_present + eax], 0
    je .not_present
    mov [selected_disk], al
    mov [selected_partition], byte 0xFF
    mov [selected_partition_start], dword 0
    mov esi, msg_disk_selected
    call print32
    movzx eax, byte [selected_disk]
    inc eax
    call print_number
    mov esi, newline
    call print32
    call get_disk_size
    call read_mbr
    popa
    ret
.no_arg:
    mov esi, msg_no_disk_num
    call print32
    popa
    ret
.invalid:
    mov esi, msg_invalid_disk
    call print32
    popa
    ret
.not_present:
    mov esi, msg_disk_not_present
    call print32
    popa
    ret
disk_partition:
    pusha
    cmp byte [selected_disk], 0xFF
    je .no_disk
    call get_disk_size
    mov esi, input_buf
    mov ebx, 0
.find_size:
    lodsb
    cmp al, 0
    je .do_partition
    cmp al, '-'
    jne .find_size
    push esi
    mov ecx, 4
    mov edi, .size_str
.check_size:
    lodsb
    cmp al, [edi]
    jne .not_size
    inc edi
    dec ecx
    jnz .check_size
    add esp, 4
    call skip_spaces_esi
    call parse_number
    cmp eax, 0
    je .do_partition
    mov ecx, 2048
    mul ecx
    mov ebx, eax
    jmp .do_partition
.not_size:
    pop esi
    jmp .find_size
.do_partition:
    call write_mbr_single
    mov esi, msg_partitioned
    call print32
    call read_mbr
    popa
    ret
.no_disk:
    mov esi, msg_no_disk_selected
    call print32
    popa
    ret
.size_str db 'size',0
disk_del_allpart:
    pusha
    cmp byte [selected_disk], 0xFF
    je .no_disk
    mov edi, partition_table
    mov ecx, 64
    xor al, al
    rep stosb
    call write_mbr_from_table
    mov esi, msg_all_part_deleted
    call print32
    call read_mbr
    mov byte [selected_partition], 0xFF
    mov dword [selected_partition_start], 0
    popa
    ret
.no_disk:
    mov esi, msg_no_disk_selected
    call print32
    popa
    ret
part_list:
    pusha
    cmp byte [selected_disk], 0xFF
    je .no_disk
    call get_disk_size
    call read_mbr
    mov dword [pl_part_count], 0
    mov ecx, 4
    xor ebx, ebx
.collect:
    mov eax, ebx
    shl eax, 4
    cmp byte [partition_table + eax], 0
    je .collect_next
    mov edx, [pl_part_count]
    shl edx, 4
    mov esi, ebx
    shl esi, 4
    movzx eax, byte [partition_table + esi + 4]
    mov [sector_buffer + edx], eax
    mov eax, [partition_table + esi + 8]
    mov [sector_buffer + edx + 4], eax
    add eax, [partition_table + esi + 12]
    mov [sector_buffer + edx + 8], eax
    inc dword [pl_part_count]
.collect_next:
    inc ebx
    dec ecx
    jnz .collect
    mov eax, [pl_part_count]
    dec eax
    mov [pl_outer_count], eax
.outer_loop:
    cmp dword [pl_outer_count], 0
    jle .sort_done
    mov ecx, [pl_outer_count]
    xor ebx, ebx
.inner_loop:
    mov esi, ebx
    shl esi, 4
    mov eax, [sector_buffer + esi + 4]
    mov edx, [sector_buffer + esi + 20]
    cmp eax, edx
    jle .no_swap
    mov eax, [sector_buffer + esi]
    mov ecx, [sector_buffer + esi + 4]
    mov edx, [sector_buffer + esi + 8]
    mov [pl_swap_t1], eax
    mov [pl_swap_t2], ecx
    mov [pl_swap_t3], edx
    mov eax, [sector_buffer + esi + 16]
    mov ecx, [sector_buffer + esi + 20]
    mov edx, [sector_buffer + esi + 24]
    mov [sector_buffer + esi], eax
    mov [sector_buffer + esi + 4], ecx
    mov [sector_buffer + esi + 8], edx
    mov eax, [pl_swap_t1]
    mov ecx, [pl_swap_t2]
    mov edx, [pl_swap_t3]
    mov [sector_buffer + esi + 16], eax
    mov [sector_buffer + esi + 20], ecx
    mov [sector_buffer + esi + 24], edx
    mov ecx, [pl_outer_count]
.no_swap:
    inc ebx
    dec ecx
    jnz .inner_loop
    dec dword [pl_outer_count]
    jmp .outer_loop
.sort_done:
    mov esi, msg_part_list
    call print32
    mov ecx, [pl_part_count]
    xor ebx, ebx
.print_loop:
    cmp ecx, 0
    je .print_done
    push ecx
    push ebx
    mov esi, ebx
    shl esi, 4
    mov eax, ebx
    inc eax
    call print_number
    mov al, ' '
    call print_char
    mov al, '-'
    call print_char
    mov al, ' '
    call print_char
    mov eax, [sector_buffer + esi]
    call print_hex_byte
    mov al, ' '
    call print_char
    mov eax, [sector_buffer + esi + 4]
    call print_number
    mov al, ' '
    call print_char
    mov al, 't'
    call print_char
    mov al, 'o'
    call print_char
    mov al, ' '
    call print_char
    mov eax, [sector_buffer + esi + 8]
    call print_number
    mov al, ' '
    call print_char
    mov eax, [sector_buffer + esi + 8]
    sub eax, [sector_buffer + esi + 4]
    mov ecx, 2048
    xor edx, edx
    div ecx
    call print_number
    mov esi, .mb_str
    call print32
    pop ebx
    pop ecx
    inc ebx
    dec ecx
    jnz .print_loop
.print_done:
    mov esi, .free_header
    call print32
    mov eax, 1
    mov ebx, 0
.free_loop:
    cmp ebx, [pl_part_count]
    jge .free_after_last
    mov esi, ebx
    shl esi, 4
    mov edx, [sector_buffer + esi + 4]
    cmp eax, edx
    jl .has_free_gap
    mov eax, [sector_buffer + esi + 8]
    inc ebx
    jmp .free_loop
.has_free_gap:
    push edx
    push eax
    call print_number
    mov al, ' '
    call print_char
    mov al, 't'
    call print_char
    mov al, 'o'
    call print_char
    mov al, ' '
    call print_char
    mov eax, [esp + 4]
    call print_number
    mov al, ' '
    call print_char
    pop eax
    pop edx
    push edx
    sub edx, eax
    mov eax, edx
    mov ecx, 2048
    xor edx, edx
    div ecx
    call print_number
    mov esi, .mb_str
    call print32
    pop edx
    mov esi, ebx
    shl esi, 4
    mov eax, [sector_buffer + esi + 8]
    inc ebx
    jmp .free_loop
.free_after_last:
    mov edx, [disk_size_sectors]
    cmp eax, edx
    jge .free_done
    push edx
    push eax
    call print_number
    mov al, ' '
    call print_char
    mov al, 't'
    call print_char
    mov al, 'o'
    call print_char
    mov al, ' '
    call print_char
    mov eax, [esp + 4]
    call print_number
    mov al, ' '
    call print_char
    pop eax
    pop edx
    sub edx, eax
    mov eax, edx
    mov ecx, 2048
    xor edx, edx
    div ecx
    call print_number
    mov esi, .mb_str
    call print32
.free_done:
    popa
    ret
.no_disk:
    mov esi, msg_no_disk_selected
    call print32
    popa
    ret
.mb_str db 'MB', 0x0d, 0x0a, 0
.free_header db 'Free Space:', 0x0d, 0x0a, 0
part_select:
    pusha
    cmp byte [selected_disk], 0xFF
    je .no_disk
    mov esi, input_buf
    add esi, 8
    call skip_spaces_esi
    cmp byte [esi], 0
    je .no_arg
    call parse_number
    cmp eax, 0
    je .invalid
    cmp eax, 4
    ja .invalid
    dec eax
    mov ebx, eax
    shl ebx, 4
    cmp byte [partition_table + ebx], 0
    je .not_found
    mov [selected_partition], al
    mov eax, [partition_table + ebx + 8]
    mov [selected_partition_start], eax
    mov eax, [partition_table + ebx + 12]
    mov [selected_partition_size], eax
    mov esi, msg_part_selected
    call print32
    movzx eax, byte [selected_partition]
    inc eax
    call print_number
    mov esi, newline
    call print32
    call load_boot_sector
    mov eax, [root_dir_start]
    mov [current_dir_cluster], dword 0
    mov [current_dir_sector], eax
    popa
    ret
.no_disk:
    mov esi, msg_no_disk_selected
    call print32
    popa
    ret
.no_arg:
    mov esi, msg_no_part_num
    call print32
    popa
    ret
.invalid:
    mov esi, msg_invalid_part
    call print32
    popa
    ret
.not_found:
    mov esi, msg_part_not_found
    call print32
    popa
    ret
part_format:
    ; Format selected partition
    ; Usage: part fm [-fs fat12|fat32]
    ; Default filesystem is FAT12 if -fs not specified
    pusha
    cmp byte [selected_partition], 0xFF
    je .no_part
    ; Parse command line for -fs parameter
    mov esi, input_buf
    add esi, 7                                  ; Skip "part fm"
    mov byte [fmt_filesystem], 0                ; Default: FAT12
.find_fs:
    lodsb
    cmp al, 0
    je .do_format
    cmp al, '-'
    jne .find_fs
    ; Check for "fs" after '-'
    cmp byte [esi], 'f'
    jne .find_fs
    cmp byte [esi + 1], 's'
    jne .find_fs
    add esi, 2                                  ; Skip "fs"
    ; Skip spaces
.skip_spaces:
    cmp byte [esi], ' '
    jne .check_fs
    inc esi
    jmp .skip_spaces
.check_fs:
    ; Check for "fat12" or "fat32"
    cmp dword [esi], 0x31746166                  ; "fat1" (little-endian)
    jne .check_fat32
    cmp byte [esi + 4], '2'
    jne .check_fat32
    mov byte [fmt_filesystem], 0                ; FAT12
    jmp .do_format
.check_fat32:
    cmp dword [esi], 0x33746166                  ; "fat3" (little-endian)
    jne .do_format
    cmp byte [esi + 4], '2'
    jne .do_format
    mov byte [fmt_filesystem], 1                ; FAT32
.do_format:
    cmp byte [fmt_filesystem], 0
    je .format_fat12
    call format_fat32
    jmp .format_done
.format_fat12:
    call format_fat12
.format_done:
    mov esi, msg_formatted
    call print32
    call assign_drive_letter
    popa
    ret
.no_part:
    mov esi, msg_no_part_selected
    call print32
    popa
    ret
fmt_filesystem db 0                             ; 0=FAT12, 1=FAT32
part_del:
    pusha
    cmp byte [selected_disk], 0xFF
    je .no_disk
    cmp byte [selected_partition], 0xFF
    je .no_part
    movzx eax, byte [selected_partition]
    shl eax, 4
    mov byte [partition_table + eax], 0
    mov byte [partition_table + eax + 4], 0
    mov dword [partition_table + eax + 8], 0
    mov dword [partition_table + eax + 12], 0
    call write_mbr_from_table
    mov esi, msg_part_deleted
    call print32
    call read_mbr
    mov byte [selected_partition], 0xFF
    mov dword [selected_partition_start], 0
    popa
    ret
.no_disk:
    mov esi, msg_no_disk_selected
    call print32
    popa
    ret
.no_part:
    mov esi, msg_no_part_selected
    call print32
    popa
    ret
ls_cmd:
    pusha
    call restore_current_drive_state
    cmp eax, -1
    je .no_part
    call read_dir_sector
    call list_directory
    popa
    ret
.no_part:
    mov esi, msg_no_part_selected
    call print32
    popa
    ret
cd_cmd:
    pusha
    mov esi, input_buf
    add esi, 2
    call skip_spaces_esi
    cmp byte [esi], 0
    je .no_arg
    mov al, [esi]
    call is_alpha
    cmp al, 1
    jne .check_slash_start
    cmp byte [esi + 1], 0
    jne .check_abs
    mov al, [esi]
    call switch_drive
    jmp .done
.check_abs:
    cmp byte [esi + 1], '/'
    jne .relative
    mov al, [esi]
    call switch_drive
    add esi, 2
    mov [path_parse_pos], esi
    jmp .parse_loop
.check_slash_start:
    cmp byte [esi], '/'
    jne .relative
    call cd_to_root
    inc esi
    mov [path_parse_pos], esi
    jmp .parse_loop
.relative:
    mov [path_parse_pos], esi
.parse_loop:
    mov esi, [path_parse_pos]
    cmp byte [esi], 0
    je .done
    cmp byte [esi], '/'
    je .skip_slash
    mov edi, tmp_component
.comp_loop:
    mov al, [esi]
    cmp al, 0
    je .comp_done
    cmp al, '/'
    je .comp_done
    mov [edi], al
    inc esi
    inc edi
    jmp .comp_loop
.comp_done:
    mov byte [edi], 0
    mov [path_parse_pos], esi
    cmp byte [selected_partition], 0xFF
    je .done
    call read_dir_sector
    mov esi, tmp_component
    call cd_directory
    jmp .parse_loop
.skip_slash:
    inc esi
    mov [path_parse_pos], esi
    jmp .parse_loop
.no_arg:
    mov esi, msg_no_path
    call print32
.done:
    popa
    ret
write_cmd:
    pusha
    call restore_current_drive_state
    cmp eax, -1
    je .no_part
    mov esi, input_buf
    add esi, 5
    call skip_spaces_esi
    cmp byte [esi], 0
    je .no_arg
    mov edi, esi
.find_sep:
    cmp byte [edi], 0
    je .no_arg
    cmp byte [edi], '-'
    jne .next_char
    cmp byte [edi + 1], '2'
    jne .next_char
    cmp byte [edi + 2], ' '
    je .found_sep
.next_char:
    inc edi
    jmp .find_sep
.found_sep:
    mov byte [edi], 0
    inc edi
    inc edi
    inc edi
.skip_edi_spaces:
    cmp byte [edi], ' '
    je .edi_skip
    cmp byte [edi], 0x09
    je .edi_skip
    jmp .edi_done
.edi_skip:
    inc edi
    jmp .skip_edi_spaces
.edi_done:
    cmp byte [edi], 0
    je .no_arg
    mov ebx, edi
    call read_dir_sector
    mov edi, ebx
    call write_file
    mov esi, msg_written
    call print32
    popa
    ret
.no_part:
    mov esi, msg_no_part_selected
    call print32
    popa
    ret
.no_arg:
    mov esi, msg_write_usage
    call print32
    popa
    ret
read_cmd:
    pusha
    call restore_current_drive_state
    cmp eax, -1
    je .no_part
    mov esi, input_buf
    add esi, 4
    call skip_spaces_esi
    cmp byte [esi], 0
    je .no_arg
    call read_dir_sector
    mov edi, esi
    call read_file
    popa
    ret
.no_part:
    mov esi, msg_no_part_selected
    call print32
    popa
    ret
.no_arg:
    mov esi, msg_no_filename
    call print32
    popa
    ret
crdir_cmd:
    pusha
    call restore_current_drive_state
    cmp eax, -1
    je .no_part
    mov esi, input_buf
    add esi, 5
    call skip_spaces_esi
    cmp byte [esi], 0
    je .no_arg
    call read_dir_sector
    call create_directory
    popa
    ret
.no_part:
    mov esi, msg_no_part_selected
    call print32
    popa
    ret
.no_arg:
    mov esi, msg_no_dirname
    call print32
    popa
    ret
dedir_cmd:
    pusha
    call restore_current_drive_state
    cmp eax, -1
    je .no_part
    mov esi, input_buf
    add esi, 5
    call skip_spaces_esi
    cmp byte [esi], 0
    je .no_arg
    cmp byte [esi], '*'
    jne .single_dir
    cmp byte [esi + 1], 0
    jne .single_dir
    call read_dir_sector
    mov ecx, [fat_root_entries]
    cmp dword [current_dir_cluster], 0
    jne .wc_data_dir
    mov ecx, [fat_root_entries]
    jmp .wc_loop_prep
.wc_data_dir:
    mov ecx, 16
.wc_loop_prep:
    xor ebx, ebx
.wc_entry_loop:
    cmp ebx, ecx
    jge .wc_done
    mov eax, ebx
    mov edx, 32
    mul edx
    mov edi, dir_buffer
    add edi, eax
    cmp byte [edi], 0
    je .wc_done
    cmp byte [edi], 0xE5
    je .wc_next_entry
    mov al, [edi + 11]
    test al, 0x10
    jz .wc_next_entry
    test al, 0x08
    jnz .wc_next_entry
    cmp byte [edi], '.'
    jne .wc_not_dot
    cmp byte [edi + 1], ' '
    je .wc_next_entry
    cmp byte [edi + 1], '.'
    je .wc_next_entry
.wc_not_dot:
    push ebx
    push ecx
    mov esi, edi
    mov edi, tmp_filename
    mov ecx, 11
    cld
    rep movsb
    mov byte [tmp_filename + 11], 0
    mov esi, tmp_filename
    call delete_directory
    pop ecx
    pop ebx
.wc_next_entry:
    inc ebx
    jmp .wc_entry_loop
.wc_done:
    popa
    ret
.single_dir:
    call read_dir_sector
    call delete_directory
    popa
    ret
.no_part:
    mov esi, msg_no_part_selected
    call print32
    popa
    ret
.no_arg:
    mov esi, msg_no_dirname
    call print32
    popa
    ret
del_cmd:
    pusha
    call restore_current_drive_state
    cmp eax, -1
    je .no_part
    mov esi, input_buf
    add esi, 3
    call skip_spaces_esi
    cmp byte [esi], 0
    je .no_arg
    cmp byte [esi], '*'
    jne .single_file
    cmp byte [esi + 1], 0
    jne .single_file
    call read_dir_sector
    mov ecx, [fat_root_entries]
    cmp dword [current_dir_cluster], 0
    jne .wc_data_dir
    mov ecx, [fat_root_entries]
    jmp .wc_loop_prep
.wc_data_dir:
    mov ecx, 16
.wc_loop_prep:
    xor ebx, ebx
.wc_entry_loop:
    cmp ebx, ecx
    jge .wc_done
    mov eax, ebx
    mov edx, 32
    mul edx
    mov edi, dir_buffer
    add edi, eax
    cmp byte [edi], 0
    je .wc_done
    cmp byte [edi], 0xE5
    je .wc_next_entry
    mov al, [edi + 11]
    test al, 0x10
    jnz .wc_next_entry
    test al, 0x08
    jnz .wc_next_entry
    cmp byte [edi], '.'
    jne .wc_not_dot
    cmp byte [edi + 1], ' '
    je .wc_next_entry
    cmp byte [edi + 1], '.'
    je .wc_next_entry
.wc_not_dot:
    push ebx
    push ecx
    mov esi, edi
    mov edi, tmp_filename
    mov ecx, 11
    cld
    rep movsb
    mov byte [tmp_filename + 11], 0
    mov esi, tmp_filename
    call delete_file
    pop ecx
    pop ebx
.wc_next_entry:
    inc ebx
    jmp .wc_entry_loop
.wc_done:
    popa
    ret
.single_file:
    call read_dir_sector
    call delete_file
    popa
    ret
.no_part:
    mov esi, msg_no_part_selected
    call print32
    popa
    ret
.no_arg:
    mov esi, msg_no_filename
    call print32
    popa
    ret
;=============================================================================
; Path Resolution and Directory Navigation
;=============================================================================

resolve_path_to_dir:
    ; Resolve a path string to directory location
    ; Input: [ebp+8] = path string pointer
    ; Output: eax = 0 on success, -1 on failure
    push ebp
    mov ebp, esp
    sub esp, 160
    mov dword [ebp - 4], 0
    movzx eax, byte [selected_disk]
    mov [ebp - 8], eax
    movzx eax, byte [selected_partition]
    mov [ebp - 12], eax
    mov eax, [selected_partition_start]
    mov [ebp - 16], eax
    mov eax, [current_dir_cluster]
    mov [ebp - 20], eax
    mov eax, [current_dir_sector]
    mov [ebp - 24], eax
    lea edi, [ebp - 152]
    mov esi, current_path
    mov ecx, 128
    cld
    rep movsb
    mov esi, [ebp + 8]
    mov al, [esi]
    call is_alpha
    cmp al, 1
    jne .check_slash_start
    cmp byte [esi + 1], '/'
    jne .relative
    mov al, [esi]
    call switch_drive
    add esi, 2
    mov [path_parse_pos], esi
    jmp .parse_loop
.check_slash_start:
    cmp byte [esi], '/'
    jne .relative
    call cd_to_root
    inc esi
    mov [path_parse_pos], esi
    jmp .parse_loop
.relative:
    mov [path_parse_pos], esi
.parse_loop:
    mov esi, [path_parse_pos]
    cmp byte [esi], 0
    je .empty_path
    cmp byte [esi], '/'
    je .skip_slash
    mov edi, tmp_component
.comp_loop:
    mov al, [esi]
    cmp al, 0
    je .comp_done
    cmp al, '/'
    je .comp_done
    mov [edi], al
    inc esi
    inc edi
    jmp .comp_loop
.comp_done:
    mov byte [edi], 0
    mov edi, esi
.find_next_slash:
    cmp byte [edi], '/'
    je .has_more
    cmp byte [edi], 0
    je .is_last
    inc edi
    jmp .find_next_slash
.has_more:
    mov [path_parse_pos], esi
    cmp byte [selected_partition], 0xFF
    je .parse_loop
    call read_dir_sector
    mov esi, tmp_component
    call cd_directory
    jmp .parse_loop
.is_last:
    mov esi, tmp_component
    mov edi, tmp_filename
    call filename_to_83
    jmp .success
.skip_slash:
    inc esi
    mov [path_parse_pos], esi
    jmp .parse_loop
.empty_path:
    mov dword [ebp - 4], -1
    jmp .restore
.success:
    mov dword [ebp - 4], 0
.restore:
    mov eax, [ebp - 8]
    mov [selected_disk], al
    mov eax, [ebp - 12]
    mov [selected_partition], al
    mov eax, [ebp - 16]
    mov [selected_partition_start], eax
    mov eax, [ebp - 20]
    mov [current_dir_cluster], eax
    mov eax, [ebp - 24]
    mov [current_dir_sector], eax
    lea esi, [ebp - 152]
    mov edi, current_path
    mov ecx, 128
    cld
    rep movsb
    mov eax, [ebp - 4]
    mov esp, ebp
    pop ebp
    ret
;=============================================================================
; Auto-Mount - Detect and mount all partitions on boot
;=============================================================================

auto_mount:
    ; Scan all disks and partitions, assign drive letters
    pusha
    mov byte [selected_disk], 0
.mount_disk_loop:
    movzx eax, byte [selected_disk]
    cmp al, 4
    jge .done
    movzx ebx, al
    cmp byte [disk_present + ebx], 0
    je .next_disk
    mov al, [selected_disk]
    call ide_select_disk
    call get_disk_size
    call read_mbr
    mov byte [selected_partition], 0
.mount_part_loop:
    movzx eax, byte [selected_partition]
    cmp al, 4
    jge .next_disk
    movzx ebx, al
    shl ebx, 4
    cmp byte [partition_table + ebx], 0
    je .next_part
    mov eax, [partition_table + ebx + 8]
    mov [selected_partition_start], eax
    call load_boot_sector
    cmp word [fat_bytes_per_sector], 512
    jne .next_part
    cmp byte [fat_sectors_per_cluster], 0
    je .next_part
    cmp word [fat_reserved_sectors], 0
    je .next_part
    call assign_drive_letter
.next_part:
    inc byte [selected_partition]
    jmp .mount_part_loop
.next_disk:
    inc byte [selected_disk]
    jmp .mount_disk_loop
.done:
    mov byte [selected_disk], 0xFF
    mov byte [selected_partition], 0xFF
    mov dword [selected_partition_start], 0
    mov dword [current_dir_cluster], 0
    mov dword [current_dir_sector], 0
    popa
    ret
disk_present         times 4 db 0
disk_names           db 'PriMst', 0, 'PriSlv', 0, 'SecMst', 0, 'SecSlv', 0
selected_disk        db 0xFF
selected_partition   db 0xFF
disk_size_sectors    dd 0
selected_partition_start dd 0
selected_partition_size dd 0
fmt_zero_lba         dd 0
fmt_zero_count       dd 0
fmt_msg              db 'Formatting...', 0x0d, 0x0a, 0
ide_base_port        dw 0x1F0
ide_drive_bit        db 0
partition_table      times 64 db 0
fat_bytes_per_sector     dw 0
fat_sectors_per_cluster  db 0
fat_reserved_sectors     dw 0
fat_num_fats             db 0
fat_root_entries         dw 0
fat_sectors_per_fat      dw 0
fat_total_sectors        dd 0
fat1_start               dd 0
root_dir_start           dd 0
data_area_start          dd 0
current_dir_cluster      dd 0
current_dir_sector       dd 0
sector_buffer        times 512 db 0
dir_buffer           times 7168 db 0
fat_buffer           times 4608 db 0
identify_buffer      times 512 db 0
tmp_filename         times 12 db 0
current_path         times 128 db 0
tmp_lba              dd 0
tmp_count            dd 0
tmp_buffer           dd 0
ls_header            db 'Name          Type  Size(KB)', 0x0d, 0x0a, 0
type_dir             db 'DIR ', 0
type_file            db 'FILE', 0
drive_table          times 256 db 0
current_drive        db 0
tmp_drive_letter     db 0
tmp_component        times 16 db 0
path_parse_pos       dd 0
msg_disk_list        db 'Disks:', 0x0d, 0x0a, 0
msg_disk_selected    db 'Disk selected: ', 0
msg_partitioned      db 'Disk partitioned.', 0x0d, 0x0a, 0
msg_no_free_part     db 'No free partition entry.', 0x0d, 0x0a, 0
mbr_free_entry       dd 0
mbr_max_end          dd 0
mbr_new_start        dd 0
mbr_new_size         dd 0
pl_part_count        dd 0
pl_swap_t1           dd 0
pl_swap_t2           dd 0
pl_swap_t3           dd 0
pl_outer_count        dd 0
msg_part_list        db 'Partitions:', 0x0d, 0x0a, 0
msg_part_selected    db 'Partition selected: ', 0
msg_formatted        db 'Partition formatted as FAT12.', 0x0d, 0x0a, 0
msg_no_disk_num      db 'Usage: disk sel <number>', 0x0d, 0x0a, 0
msg_invalid_disk     db 'Invalid disk number.', 0x0d, 0x0a, 0
msg_disk_not_present db 'Disk not present.', 0x0d, 0x0a, 0
msg_no_disk_selected db 'No disk selected.', 0x0d, 0x0a, 0
msg_no_part_num      db 'Usage: part sel <number>', 0x0d, 0x0a, 0
msg_invalid_part     db 'Invalid partition number.', 0x0d, 0x0a, 0
msg_part_not_found   db 'Partition not found.', 0x0d, 0x0a, 0
msg_part_deleted     db 'Partition deleted.', 0x0d, 0x0a, 0
msg_all_part_deleted db 'All partitions deleted.', 0x0d, 0x0a, 0
msg_no_part_selected db 'No partition selected.', 0x0d, 0x0a, 0
msg_no_path          db 'Usage: cd <path>', 0x0d, 0x0a, 0
msg_write_usage      db 'Usage: write <text> -2 <file>', 0x0d, 0x0a, 0
msg_no_filename      db 'Usage: read <file>', 0x0d, 0x0a, 0
msg_no_dirname       db 'Usage: crdir <name>', 0x0d, 0x0a, 0
msg_file_not_found   db 'File not found.', 0x0d, 0x0a, 0
msg_is_directory     db 'Is a directory.', 0x0d, 0x0a, 0
msg_not_found        db 'Not found.', 0x0d, 0x0a, 0
msg_not_directory    db 'Not a directory.', 0x0d, 0x0a, 0
msg_disk_full        db 'Disk full.', 0x0d, 0x0a, 0
msg_dir_full         db 'Directory full.', 0x0d, 0x0a, 0
msg_written          db 'File written.', 0x0d, 0x0a, 0
msg_drive_assigned   db 'Drive assigned: ', 0
msg_drive_not_found  db 'Drive not found.', 0x0d, 0x0a, 0
msg_drive_list       db 'Drives:', 0x0d, 0x0a, 0
msg_drive_part       db 'Disk ', 0
msg_drive_system     db 'System VHD', 0
;=============================================================================
; Memory Management - Bitmap allocator for page frames
;=============================================================================

mem_init:
    ; Initialize memory bitmap (512 pages = 2MB)
    pusha
    mov edi, 0x120000
    mov ecx, 512
    xor al, al
    rep stosb
    mov ecx, 9
    xor esi, esi
.mark_pages:
    mov edi, esi
    shr edi, 3
    add edi, 0x120000
    mov al, [edi]
    mov edx, esi
    and edx, 7
    bts ax, dx
    mov [edi], al
    inc esi
    loop .mark_pages
    mov dword [total_kb], 2048
    mov dword [used_kb], 36
    mov dword [free_kb], 2012
    popa
    ret
mem_alloc:
    push ebx
    push ecx
    push edx
    push esi
    push edi
    mov eax, ecx
    mov ebx, 4096
    add eax, ebx
    dec eax
    xor edx, edx
    div ebx
    mov ebx, eax
    test ebx, ebx
    jnz .search
    mov ebx, 1
.search:
    mov ecx, 0
    mov edx, 0
    xor esi, esi
.bitloop:
    cmp esi, 512
    jge .fail
    mov edi, esi
    shr edi, 3
    mov al, [edi + 0x120000]
    mov edi, esi
    and edi, 7
    bt ax, di
    jc .used
    inc ecx
    cmp ecx, ebx
    je .found
    jmp .next
.used:
    mov ecx, 0
    lea edx, [esi + 1]
.next:
    inc esi
    jmp .bitloop
.found:
    mov eax, edx
    add eax, ecx
    sub eax, ebx
    mov edx, eax
.mark:
    mov esi, edx
    mov ecx, ebx
.mark_loop:
    jecxz .done_mark
    push ecx
    mov edi, esi
    shr edi, 3
    add edi, 0x120000
    mov al, [edi]
    mov ecx, esi
    and ecx, 7
    bts ax, cx
    mov [edi], al
    pop ecx
    inc esi
    dec ecx
    jmp .mark_loop
.done_mark:
    mov eax, edx
    shl eax, 12
    add eax, 0x200000
    shl ebx, 2
    add [used_kb], ebx
    sub [free_kb], ebx
    jmp .done
.fail:
    xor eax, eax
.done:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret
mem_free:
    pusha
    cmp esi, 0x200000
    jb .exit
    cmp esi, 0x3FFFFF
    ja .exit
    sub esi, 0x200000
    shr esi, 12
    mov eax, ecx
    mov ebx, 4096
    add eax, ebx
    dec eax
    xor edx, edx
    div ebx
    mov ebx, eax
    test ebx, ebx
    jnz .start
    mov ebx, 1
.start:
    mov ecx, ebx
.free_loop:
    jecxz .done_free
    push ecx
    mov edi, esi
    shr edi, 3
    add edi, 0x120000
    mov al, [edi]
    mov ecx, esi
    and ecx, 7
    btr ax, cx
    mov [edi], al
    pop ecx
    inc esi
    dec ecx
    jmp .free_loop
.done_free:
    shl ebx, 2
    sub [used_kb], ebx
    add [free_kb], ebx
.exit:
    popa
    ret
paging_init:
    pusha
    mov edi, 0x200000
    mov cr3, edi
    mov ecx, 1024
    xor eax, eax
    rep stosd
    mov edi, 0x201000
    mov ecx, 1024 * 8
    mov eax, 0x00000003
.build_pt:
    stosd
    add eax, 0x1000
    loop .build_pt
    mov dword [0x200000 + 0*4], 0x201000 + 0x03
    mov dword [0x200000 + 1*4], 0x202000 + 0x03
    mov dword [0x200000 + 2*4], 0x203000 + 0x03
    mov dword [0x200000 + 3*4], 0x204000 + 0x03
    mov dword [0x200000 + 4*4], 0x205000 + 0x03
    mov dword [0x200000 + 5*4], 0x206000 + 0x03
    mov dword [0x200000 + 6*4], 0x207000 + 0x03
    mov dword [0x200000 + 7*4], 0x208000 + 0x03
    mov eax, cr0
    or eax, 0x80000000
    mov cr0, eax
    popa
    ret
;=============================================================================
; Process Management - PCB initialization and scheduling
;=============================================================================

proc_init:
    ; Initialize process control blocks (8 slots)
    ; Slot 0: idle process, Slot 1: shell process
    pusha
    mov edi, 0x110000
    mov ecx, 128
    xor eax, eax
    rep stosd
    mov dword [0x110000 + 0], 0
    mov dword [0x110000 + 4], 1
    mov dword [0x110000 + 8], 0x17000
    mov dword [0x110000 + 12], 0x1000
    mov dword [0x110000 + 16], 4096
    mov dword [0x110000 + 20], 0xFFFFFFFF
    mov esi, proc_name_idle
    lea edi, [0x110000 + 24]
    mov ecx, 5
    rep movsb
    mov byte [edi], 0
    mov dword [0x110000 + 64 + 0], 1
    mov dword [0x110000 + 64 + 4], 2
    mov dword [0x110000 + 64 + 8], 0x18000
    mov dword [0x110000 + 64 + 12], 0x2000
    mov dword [0x110000 + 64 + 16], 8192
    mov dword [0x110000 + 64 + 20], 0
    mov esi, proc_name_shell
    lea edi, [0x110000 + 64 + 24]
    mov ecx, 5
    rep movsb
    mov byte [edi], 0
    mov dword [current_pid], 1
    popa
    ret
proc_name_idle  db 'idle',0
proc_name_shell db 'shell',0
proc_create:
    push ebx
    push ecx
    push edx
    push esi
    push edi
    mov ecx, 0
.search_slot:
    cmp ecx, 8
    jge .fail
    mov eax, ecx
    shl eax, 6
    cmp dword [eax + 0x110000 + 4], 0
    je .found
    inc ecx
    jmp .search_slot
.found:
    mov edx, ecx
    shl edx, 6
    mov [edx + 0x110000 + 0], ecx
    mov dword [edx + 0x110000 + 4], 1
    lea edi, [edx + 0x110000 + 24]
.copy_name:
    lodsb
    stosb
    or al, al
    jz .name_done
    mov eax, edx
    add eax, 24 + 15
    cmp edi, eax
    jl .copy_name
.name_done:
    mov byte [edi - 1], 0
    mov eax, ecx
    shl eax, 14
    add eax, 0x1A000
    mov [edx + 0x110000 + 8], eax
    mov eax, ebx
    shl eax, 10
    mov [edx + 0x110000 + 12], eax
    mov eax, [esp + 12]
    shl eax, 10
    mov [edx + 0x110000 + 16], eax
    mov eax, [current_pid]
    mov [edx + 0x110000 + 20], eax
    mov eax, ecx
    jmp .done
.fail:
    mov eax, -1
.done:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret
proc_schedule:
    pusha
    mov ebx, [current_pid]
    mov eax, ebx
    shl eax, 6
    cmp dword [eax + 0x110000 + 4], 2
    jne .find_next
    mov dword [eax + 0x110000 + 4], 1
.find_next:
    mov ecx, ebx
    inc ecx
.search_loop:
    cmp ecx, 8
    jl .check_slot
    mov ecx, 0
.check_slot:
    mov eax, ecx
    shl eax, 6
    cmp dword [eax + 0x110000 + 4], 1
    je .select
    inc ecx
    cmp ecx, ebx
    je .done
    jmp .search_loop
.select:
    mov dword [eax + 0x110000 + 4], 2
    mov [current_pid], ecx
.done:
    popa
    ret
mem_update_stats:
    pusha
    xor ebx, ebx
    xor esi, esi
.scan_loop:
    cmp esi, 512
    jge .finish
    mov edi, esi
    shr edi, 3
    mov al, [edi + 0x120000]
    mov edi, esi
    and edi, 7
    bt ax, di
    jnc .not_used
    inc ebx
.not_used:
    inc esi
    jmp .scan_loop
.finish:
    shl ebx, 2
    mov [used_kb], ebx
    mov eax, [total_kb]
    sub eax, ebx
    mov [free_kb], eax
    popa
    ret
total_kb    dd 0
used_kb     dd 0
free_kb     dd 0
current_pid dd 0
output_handler:
    pusha
    mov esi, input_buf
    add esi, 6
.skip_spaces:
    mov al, [esi]
    cmp al, ' '
    je .is_space
    cmp al, 0x09
    je .is_space
    cmp al, 0
    je .done
    jmp .loop
.is_space:
    inc esi
    jmp .skip_spaces
.loop:
    mov al, [esi]
    cmp al, 0
    je .done
    call print_char
    inc esi
    jmp .loop
.done:
    mov esi, newline
    call print32
    popa
    ret
reboot_pc:
    pusha
    mov esi, reboot_msg
    call print32
    mov al, 0xFE
    out 0x64, al
    cli
    hlt
    jmp $
    popa
    ret
shutdown_pc:
    pusha
    mov esi, shutdown_msg
    call print32
    mov ax, 2001h
    mov dx, 1004h
    out dx, ax
    cli
    hlt
    jmp $
    popa
    ret
show_time:
    pusha
    mov esi, time_prefix
    call print32
    mov al, 0x04
    out 0x70, al
    in al, 0x71
    call print_bcd
    mov al, ':'
    call print_char
    mov al, 0x02
    out 0x70, al
    in al, 0x71
    call print_bcd
    mov al, ':'
    call print_char
    mov al, 0x00
    out 0x70, al
    in al, 0x71
    call print_bcd
    mov esi, newline
    call print32
    popa
    ret
date_cmd:
    pusha
    mov esi, date_prefix
    call print32
    mov al, 0x32
    out 0x70, al
    in al, 0x71
    call print_bcd
    mov al, 0x09
    out 0x70, al
    in al, 0x71
    call print_bcd
    mov al, '-'
    call print_char
    mov al, 0x08
    out 0x70, al
    in al, 0x71
    call print_bcd
    mov al, '-'
    call print_char
    mov al, 0x07
    out 0x70, al
    in al, 0x71
    call print_bcd
    mov esi, newline
    call print32
    popa
    ret
help_page1_sys:
    db 'cls        - Clear screen',0
    db 'time       - Show current time',0
    db 'date       - Show current date',0
    db 'shutdown   - Soft shutdown',0
    db 'reboot     - Reboot the system',0
    db 'output     - Print text',0
    db 'color      - Set console color',0
    db 'tui        - Enter TUI mode',0
    db 'gui        - Enter GUI mode',0
    db 'mem        - Show memory usage',0
    db 'ver        - Show system version',0
    db 'devinfo    - Show hardware info',0
    db 'help [n]   - Show help page n',0
help_page1_count equ 13
help_page2_disk:
    db 'dl list    - List drive letters',0
    db 'disk list  - List disk drives',0
    db 'disk sel   - Select disk drive',0
    db 'disk part  - Partition disk (-size MB)',0
    db 'disk del allpart - Delete all partitions',0
    db 'part list  - List partitions',0
    db 'part sel   - Select partition',0
    db 'part fm    - Format partition (-fs fat12|fat32)',0
    db 'part del   - Delete partition',0
help_page2_count equ 9
help_page3_file:
    db 'ls         - List directory',0
    db 'cd         - Change directory',0
    db 'write      - Write file',0
    db 'read       - Read file',0
    db 'crdir      - Create directory',0
    db 'dedir      - Delete directory',0
    db 'del        - Delete file',0
    db 'copy       - Copy file',0
    db 'mov        - Move file',0
help_page3_count equ 9
help_total_pages equ 3
help_cmd:
    pusha
    mov esi, input_buf
    add esi, 4
    call skip_spaces_esi
    cmp byte [esi], 0
    je .page1
    call parse_number
    cmp eax, 0
    je .page1
    mov ecx, eax
    jmp .show_page
.page1:
    mov ecx, 1
.show_page:
    cmp ecx, help_total_pages
    jg .invalid_page
    cmp ecx, 1
    jl .invalid_page
    cmp ecx, 1
    je .use_page1
    cmp ecx, 2
    je .use_page2
    jmp .use_page3
.use_page1:
    mov esi, help_page1_sys
    mov ecx, help_page1_count
    jmp .print_page
.use_page2:
    mov esi, help_page2_disk
    mov ecx, help_page2_count
    jmp .print_page
.use_page3:
    mov esi, help_page3_file
    mov ecx, help_page3_count
.print_page:
    jecxz .done
.print_loop:
    push ecx
    call print32
.advance:
    lodsb
    cmp al, 0
    jne .advance
    push esi
    mov esi, newline
    call print32
    pop esi
    pop ecx
    dec ecx
    jnz .print_loop
    jmp .done
.invalid_page:
    mov esi, msg_invalid_page
    call print32
.done:
    popa
    ret
msg_invalid_page db 'Invalid page number.', 0x0d, 0x0a, 0
color_cmd:
    pusha
    mov esi, input_buf
    add esi, 5
    call skip_spaces_esi
    cmp byte [esi], 0
    je .default
    mov al, [esi]
    call hex_to_nibble
    cmp al, 0xFF
    je .usage
    mov bl, al
    inc esi
    mov al, [esi]
    call hex_to_nibble
    cmp al, 0xFF
    je .usage
    shl bl, 4
    or bl, al
    mov [current_color], bl
    jmp .done
.default:
    mov byte [current_color], 0x0F
    jmp .done
.usage:
    mov esi, color_usage_msg
    call print32
.done:
    popa
    ret
hex_to_nibble:
    cmp al, '0'
    jb .invalid
    cmp al, '9'
    jbe .digit
    cmp al, 'A'
    jb .invalid
    cmp al, 'F'
    jbe .upper
    cmp al, 'a'
    jb .invalid
    cmp al, 'f'
    jbe .lower
.invalid:
    mov al, 0xFF
    ret
.digit:
    sub al, '0'
    ret
.upper:
    sub al, 'A'
    add al, 10
    ret
.lower:
    sub al, 'a'
    add al, 10
    ret
color_usage_msg db 'Usage: color [bg][fg] (hex digits, e.g. color 0f)', 0x0d, 0x0a, 0
;=============================================================================
; TUI (Text User Interface) - Main menu and application launcher
;=============================================================================

tui_cmd:
    ; Enter TUI mode - main menu with application icons
    cli
    call clear_screen
    pusha
    mov byte [tui_focus], 0
    mov byte [tui_exit], 0
    call tui_draw_main
.tui_loop:
    mov eax, 50
    call pit_delay_ms
    call tui_calibrate_rtc
    mov al, [tui_calc_sec]
    cmp al, [tui_last_sec]
    je .no_second
    mov [tui_last_sec], al
    call tui_refresh_time
.no_second:
    call tui_poll_event
    cmp al, 0
    je .tui_loop
    call tui_handle_main
    cmp byte [tui_exit], 1
    je .exit
    call tui_draw_main
    jmp .tui_loop
.exit:
    call clear_screen
    popa
    ret
tui_refresh_time:
    pusha
    mov edi, 0xB8000 + 24*80*2 + 61*2
    mov ecx, 19
    mov ax, 0x7020
    rep stosw
    mov edi, 0xB8000 + 24*80*2 + 61*2
    mov ah, 0x70
    call tui_draw_datetime
    popa
    ret
tui_draw_main:
    pusha
    mov edi, 0xB8000
    mov ecx, 80*24
    mov ax, 0x1F20
    rep stosw
    mov edi, 0xB8000 + 160 + 60
    mov esi, tui_str_filemgr
    mov ah, 0x1F
    call tui_put_str
    mov edi, 0xB8000 + 3*80*2 + 30*2
    mov esi, tui_str_notepad
    call tui_put_str
    mov edi, 0xB8000 + 5*80*2 + 30*2
    mov esi, tui_str_calc
    call tui_put_str
    mov edi, 0xB8000 + 7*80*2 + 30*2
    mov esi, tui_str_calendar
    call tui_put_str
    mov edi, 0xB8000 + 9*80*2 + 30*2
    mov esi, tui_str_settings
    call tui_put_str
    mov edi, 0xB8000 + 11*80*2 + 30*2
    mov esi, tui_str_game
    call tui_put_str
    mov edi, 0xB8000 + 13*80*2 + 30*2
    mov esi, tui_str_reboot
    call tui_put_str
    mov edi, 0xB8000 + 15*80*2 + 30*2
    mov esi, tui_str_shutdown
    call tui_put_str
    mov edi, 0xB8000 + 24*80*2
    mov ecx, 80
    mov ax, 0x7020
    rep stosw
    mov edi, 0xB8000 + 24*80*2 + 1*2
    mov esi, tui_str_menu
    mov ah, 0x70
    call tui_put_str
    mov edi, 0xB8000 + 24*80*2 + 61*2
    mov ah, 0x70
    call tui_draw_datetime
    cmp byte [tui_focus], 0xFF
    jne .no_bottom_focus
    mov edi, 0xB8000 + 24*80*2 + 1*2
    mov esi, tui_str_menu_f
    mov ah, 0x3F
    call tui_put_str
.no_bottom_focus:
    mov al, [tui_focus]
    cmp al, 0
    je .focus_filemgr
    cmp al, 1
    je .focus_notepad
    cmp al, 2
    je .focus_calc
    cmp al, 3
    je .focus_calendar
    cmp al, 4
    je .focus_sysinfo
    cmp al, 5
    je .focus_game
    cmp al, 6
    je .focus_reboot
    cmp al, 7
    je .focus_shutdown
    jmp .done
.focus_filemgr:
    mov edi, 0xB8000 + 160 + 60
    mov esi, tui_str_filemgr_f
    mov ah, 0x3F
    call tui_put_str
    jmp .done
.focus_notepad:
    mov edi, 0xB8000 + 3*80*2 + 30*2
    mov esi, tui_str_notepad_f
    mov ah, 0x3F
    call tui_put_str
    jmp .done
.focus_calc:
    mov edi, 0xB8000 + 5*80*2 + 30*2
    mov esi, tui_str_calc_f
    mov ah, 0x3F
    call tui_put_str
    jmp .done
.focus_calendar:
    mov edi, 0xB8000 + 7*80*2 + 30*2
    mov esi, tui_str_calendar_f
    mov ah, 0x3F
    call tui_put_str
    jmp .done
.focus_sysinfo:
    mov edi, 0xB8000 + 9*80*2 + 30*2
    mov esi, tui_str_settings_f
    mov ah, 0x3F
    call tui_put_str
    jmp .done
.focus_game:
    mov edi, 0xB8000 + 11*80*2 + 30*2
    mov esi, tui_str_game_f
    mov ah, 0x3F
    call tui_put_str
    jmp .done
.focus_reboot:
    mov edi, 0xB8000 + 13*80*2 + 30*2
    mov esi, tui_str_reboot_f
    mov ah, 0x3F
    call tui_put_str
    jmp .done
.focus_shutdown:
    mov edi, 0xB8000 + 15*80*2 + 30*2
    mov esi, tui_str_shutdown_f
    mov ah, 0x3F
    call tui_put_str
    jmp .done
.done:
    popa
    ret
tui_poll_event:
    pusha
    in al, 0x64
    test al, 0x01
    jz .no_key
    popa
    in al, 0x60
    ret
.no_key:
    popa
    xor al, al
    ret
tui_handle_main:
    pusha
    cmp al, 0x0F
    je .next
    cmp al, 0x4B
    je .prev
    cmp al, 0x48
    je .prev
    cmp al, 0x4D
    je .next
    cmp al, 0x50
    je .next
    cmp al, 0x1C
    je .enter
    cmp al, 0x01
    je .esc
    jmp .done
.next:
    cmp byte [tui_focus], 0xFF
    je .next_bottom
    inc byte [tui_focus]
    cmp byte [tui_focus], 8
    jne .done
    mov byte [tui_focus], 0xFF
    jmp .done
.next_bottom:
    mov byte [tui_focus], 0
    jmp .done
.prev:
    dec byte [tui_focus]
    cmp byte [tui_focus], 0xFF
    jne .done
    mov byte [tui_focus], 7
    jmp .done
.enter:
    cmp byte [tui_focus], 0xFF
    je .do_back_cli
    mov al, [tui_focus]
    cmp al, 0
    je .do_filemgr
    cmp al, 1
    je .do_notepad
    cmp al, 2
    je .do_calc
    cmp al, 3
    je .do_calendar
    cmp al, 4
    je .do_sysinfo
    cmp al, 5
    je .do_game
    cmp al, 6
    je .do_reboot
    cmp al, 7
    je .do_shutdown
    jmp .done
.do_filemgr:
    call file_mgr_app
    jmp .done
.do_notepad:
    call notepad_app
    jmp .done
.do_calc:
    call calculator_app
    jmp .done
.do_calendar:
    call calendar_app
    jmp .done
.do_sysinfo:
    call settings_app
    jmp .done
.do_game:
    call game_menu_app
    jmp .done
.do_reboot:
    call reboot_pc
    jmp .done
.do_shutdown:
    call shutdown_pc
    jmp .done
.do_back_cli:
    mov byte [tui_exit], 1
    jmp .done

    mov byte [tui_exit], 1
    jmp .done
.esc:
    mov byte [tui_exit], 1
.done:
    popa
    ret
tui_menu_popup:
    pusha
    mov byte [menu_focus], 0
    mov byte [menu_exit], 0
.menu_loop:
    call tui_draw_main
    call menu_draw
    call menu_handle
    cmp byte [menu_exit], 1
    je .exit
    jmp .menu_loop
.exit:
    popa
    ret
menu_draw:
    pusha
    mov ebx, 8
.menu_row:
    mov edi, 0xB8000
    mov eax, ebx
    mov ecx, 80
    mul ecx
    shl eax, 1
    add edi, eax
    add edi, 28*2
    mov ecx, 24
    mov ax, 0x7020
    rep stosw
    inc ebx
    cmp ebx, 17
    jl .menu_row
    mov edi, 0xB8000 + 8*80*2 + 28*2
    mov ecx, 24
    mov ax, 0x1F20
    rep stosw
    mov edi, 0xB8000 + 8*80*2 + 29*2
    mov esi, menu_str_title
    mov ah, 0x1F
    call tui_put_str
    mov edi, 0xB8000 + 10*80*2 + 31*2
    mov esi, menu_str_back
    mov ah, 0x70
    call tui_put_str
    mov edi, 0xB8000 + 12*80*2 + 31*2
    mov esi, menu_str_reboot
    call tui_put_str
    mov edi, 0xB8000 + 14*80*2 + 31*2
    mov esi, menu_str_shutdown
    call tui_put_str
    mov al, [menu_focus]
    cmp al, 0
    je .mf_back
    cmp al, 1
    je .mf_reboot
    cmp al, 2
    je .mf_shutdown
    jmp .menu_done
.mf_back:
    mov edi, 0xB8000 + 10*80*2 + 31*2
    mov esi, menu_str_back
    mov ah, 0x1F
    call tui_put_str
    jmp .menu_done
.mf_reboot:
    mov edi, 0xB8000 + 12*80*2 + 31*2
    mov esi, menu_str_reboot
    mov ah, 0x1F
    call tui_put_str
    jmp .menu_done
.mf_shutdown:
    mov edi, 0xB8000 + 14*80*2 + 31*2
    mov esi, menu_str_shutdown
    mov ah, 0x1F
    call tui_put_str
.menu_done:
    popa
    ret
menu_handle:
    pusha
    call read_scancode
    cmp al, 0x48
    je .up
    cmp al, 0x50
    je .down
    cmp al, 0x1C
    je .enter
    cmp al, 0x01
    je .esc
    jmp .done
.up:
    dec byte [menu_focus]
    cmp byte [menu_focus], 0xFF
    jne .done
    mov byte [menu_focus], 2
    jmp .done
.down:
    inc byte [menu_focus]
    cmp byte [menu_focus], 3
    jne .done
    mov byte [menu_focus], 0
    jmp .done
.enter:
    mov al, [menu_focus]
    cmp al, 0
    je .do_back
    cmp al, 1
    je .do_reboot
    cmp al, 2
    je .do_shutdown
    jmp .done
.do_back:
    mov byte [menu_exit], 1
    jmp .done
.do_reboot:
    call reboot_pc
    jmp .done
.do_shutdown:
    call shutdown_pc
    jmp .done
.esc:
    mov byte [menu_exit], 1
.done:
    popa
    ret
calculator_app:
    pusha
    call clear_screen
    mov edi, 0xB8000
    mov ecx, 2000
    mov ax, 0x4F20
    rep stosw
    mov dword [calc_num1], 0
    mov dword [calc_num2], 0
    mov byte [calc_op], 0
    mov byte [calc_state], 0
    mov byte [calc_focus], 5
    mov byte [calc_exit], 0
    mov byte [calc_decimal], 0
    mov byte [calc_frac_digits], 0
.calc_loop:
    call calc_draw
    call read_scancode
    cmp al, 0x01
    je .calc_exit
    cmp al, 0x1C
    je .calc_enter
    cmp al, 0x48
    je .calc_up
    cmp al, 0x50
    je .calc_down
    cmp al, 0x4B
    je .calc_left
    cmp al, 0x4D
    je .calc_right
    jmp .calc_loop
.calc_up:
    mov al, [calc_focus]
    sub al, 4
    cmp al, 0
    jl .calc_loop
    mov [calc_focus], al
    jmp .calc_loop
.calc_down:
    mov al, [calc_focus]
    add al, 4
    cmp al, 20
    jge .calc_loop
    mov [calc_focus], al
    jmp .calc_loop
.calc_left:
    mov al, [calc_focus]
    dec al
    cmp al, 0
    jl .calc_loop
    mov [calc_focus], al
    jmp .calc_loop
.calc_right:
    mov al, [calc_focus]
    inc al
    cmp al, 20
    jge .calc_loop
    mov [calc_focus], al
    jmp .calc_loop
.calc_enter:
    movzx ebx, byte [calc_focus]
    mov al, [calc_btn_chars + ebx]
    cmp al, 0
    je .calc_loop
    cmp al, 'C'
    je .calc_clear
    cmp al, 'X'
    je .calc_back
    cmp al, '/'
    je .calc_div
    cmp al, '*'
    je .calc_mul
    cmp al, '-'
    je .calc_sub
    cmp al, '+'
    je .calc_add
    cmp al, '='
    je .calc_equals
    cmp al, '.'
    je .calc_dot
    sub al, '0'
    movzx ebx, al
    cmp byte [calc_state], 0
    jne .calc_n2
    cmp byte [calc_decimal], 1
    je .calc_n1f
    mov eax, [calc_num1]
    xor edx, edx
    mov ecx, 1000
    div ecx
    imul eax, 10
    add eax, ebx
    imul eax, 1000
    mov [calc_num1], eax
    jmp .calc_loop
.calc_n1f:
    cmp byte [calc_frac_digits], 3
    jge .calc_loop
    mov eax, ebx
    mov cl, [calc_frac_digits]
    cmp cl, 0
    je .calc_n1f1
    imul eax, 100
    jmp .calc_n1fa
.calc_n1f1:
    imul eax, 100
.calc_n1fa:
    mov cl, [calc_frac_digits]
.calc_n1fp:
    cmp cl, 0
    je .calc_n1fd
    xor edx, edx
    mov ecx, 10
    div ecx
    dec cl
    jmp .calc_n1fp
.calc_n1fd:
    add [calc_num1], eax
    inc byte [calc_frac_digits]
    jmp .calc_loop
.calc_n2:
    cmp byte [calc_decimal], 1
    je .calc_n2f
    mov eax, [calc_num2]
    xor edx, edx
    mov ecx, 1000
    div ecx
    imul eax, 10
    add eax, ebx
    imul eax, 1000
    mov [calc_num2], eax
    jmp .calc_loop
.calc_n2f:
    cmp byte [calc_frac_digits], 3
    jge .calc_loop
    mov eax, ebx
    imul eax, 100
    mov cl, [calc_frac_digits]
.calc_n2fp:
    cmp cl, 0
    je .calc_n2fd
    xor edx, edx
    mov ecx, 10
    div ecx
    dec cl
    jmp .calc_n2fp
.calc_n2fd:
    add [calc_num2], eax
    inc byte [calc_frac_digits]
    jmp .calc_loop
.calc_dot:
    mov byte [calc_decimal], 1
    mov byte [calc_frac_digits], 0
    jmp .calc_loop
.calc_add:
    mov byte [calc_op], '+'
    mov byte [calc_state], 1
    mov byte [calc_decimal], 0
    mov byte [calc_frac_digits], 0
    jmp .calc_loop
.calc_sub:
    mov byte [calc_op], '-'
    mov byte [calc_state], 1
    mov byte [calc_decimal], 0
    mov byte [calc_frac_digits], 0
    jmp .calc_loop
.calc_mul:
    mov byte [calc_op], '*'
    mov byte [calc_state], 1
    mov byte [calc_decimal], 0
    mov byte [calc_frac_digits], 0
    jmp .calc_loop
.calc_div:
    mov byte [calc_op], '/'
    mov byte [calc_state], 1
    mov byte [calc_decimal], 0
    mov byte [calc_frac_digits], 0
    jmp .calc_loop
.calc_clear:
    mov dword [calc_num1], 0
    mov dword [calc_num2], 0
    mov byte [calc_op], 0
    mov byte [calc_state], 0
    mov byte [calc_decimal], 0
    mov byte [calc_frac_digits], 0
    jmp .calc_loop
.calc_back:
    cmp byte [calc_state], 0
    jne .calc_back2
    mov eax, [calc_num1]
    xor edx, edx
    mov ebx, 10
    div ebx
    mov [calc_num1], eax
    jmp .calc_loop
.calc_back2:
    mov eax, [calc_num2]
    xor edx, edx
    mov ebx, 10
    div ebx
    mov [calc_num2], eax
    jmp .calc_loop
.calc_equals:
    cmp byte [calc_op], '+'
    je .calc_do_add
    cmp byte [calc_op], '-'
    je .calc_do_sub
    cmp byte [calc_op], '*'
    je .calc_do_mul
    cmp byte [calc_op], '/'
    je .calc_do_div
    jmp .calc_loop
.calc_do_add:
    mov eax, [calc_num1]
    add eax, [calc_num2]
    mov [calc_result], eax
    jmp .calc_show_res
.calc_do_sub:
    mov eax, [calc_num1]
    sub eax, [calc_num2]
    mov [calc_result], eax
    jmp .calc_show_res
.calc_do_mul:
    mov eax, [calc_num1]
    imul dword [calc_num2]
    mov ecx, 1000
    xor edx, edx
    div ecx
    mov [calc_result], eax
    jmp .calc_show_res
.calc_do_div:
    cmp dword [calc_num2], 0
    je .calc_div_zero
    mov eax, [calc_num1]
    imul eax, 1000
    xor edx, edx
    div dword [calc_num2]
    mov [calc_result], eax
    jmp .calc_show_res
.calc_div_zero:
    mov dword [calc_result], -1
.calc_show_res:
    mov eax, [calc_result]
    mov [calc_num1], eax
    mov dword [calc_num2], 0
    mov byte [calc_state], 0
    mov byte [calc_op], 0
    mov byte [calc_decimal], 0
    mov byte [calc_frac_digits], 0
    jmp .calc_loop
.calc_exit:
    call clear_screen
    popa
    ret
calc_draw:
    pusha
    mov edi, 0xB8000
    mov ecx, 2000
    mov ax, 0x1F20
    rep stosw
    mov edi, 0xB8000 + 1*160 + 30*2
    mov esi, calc_str_title
    mov ah, 0x1F
    call tui_put_str
    mov edi, 0xB8000 + 2*160 + 12*2
    mov ecx, 56
    mov ax, 0x7020
    rep stosw
    mov edi, 0xB8000 + 4*160 + 12*2
    mov ecx, 56
    mov ax, 0x7020
    rep stosw
    mov edi, 0xB8000 + 3*160 + 12*2
    mov byte [edi], 0xB3
    mov byte [edi+1], 0x70
    mov edi, 0xB8000 + 3*160 + 67*2
    mov byte [edi], 0xB3
    mov byte [edi+1], 0x70
    mov edi, 0xB8000 + 3*160 + 14*2
    mov ecx, 52
    mov ax, 0x0F20
    rep stosw
    cmp byte [calc_state], 0
    jne .cd_show2
    mov eax, [calc_num1]
    jmp .cd_show
.cd_show2:
    mov eax, [calc_num2]
.cd_show:
    mov ebx, 1000
    xor edx, edx
    div ebx
    push edx
    mov edi, calc_display
    call int_to_string_fm
    mov esi, calc_display
    call str_len
    mov edi, 0xB8000 + 3*160 + 64*2
    sub edi, eax
    sub edi, eax
    mov esi, calc_display
    mov ah, 0x0F
    call tui_put_str
    add edi, eax
    add edi, eax
    pop edx
    cmp byte [calc_decimal], 1
    jne .cd_nodot
    cmp edx, 0
    je .cd_nodot
    mov byte [edi], '.'
    mov byte [edi+1], 0x0F
    add edi, 2
    mov eax, edx
    mov edi, calc_display
    call int_to_string_fm
    mov esi, calc_display
    mov ah, 0x0F
    call tui_put_str
.cd_nodot:
    xor ebx, ebx
.cd_btn:
    cmp ebx, 20
    jge .cd_done
    mov eax, ebx
    mov ecx, 4
    xor edx, edx
    div ecx
    push edx
    mov ecx, 4
    mul ecx
    add eax, 5
    mov ecx, 160
    mul ecx
    mov edi, 0xB8000
    add edi, eax
    pop edx
    mov eax, edx
    mov ecx, 10
    mul ecx
    add edi, eax
    add edi, 20
    cmp bl, [calc_focus]
    jne .cd_nf
    mov ah, 0x3F
    jmp .cd_b
.cd_nf:
    mov ah, 0x70
.cd_b:
    mov byte [edi], 0xDA
    mov [edi+1], ah
    mov byte [edi+2], 0xC4
    mov [edi+3], ah
    mov byte [edi+4], 0xC4
    mov [edi+5], ah
    mov byte [edi+6], 0xC4
    mov [edi+7], ah
    mov byte [edi+8], 0xBF
    mov [edi+9], ah
    add edi, 160
    mov byte [edi], 0xB3
    mov [edi+1], ah
    mov byte [edi+2], 0x20
    mov [edi+3], ah
    mov al, [calc_btn_chars + ebx]
    mov [edi+4], al
    mov [edi+5], ah
    mov byte [edi+6], 0x20
    mov [edi+7], ah
    mov byte [edi+8], 0xB3
    mov [edi+9], ah
    add edi, 160
    mov byte [edi], 0xC0
    mov [edi+1], ah
    mov byte [edi+2], 0xC4
    mov [edi+3], ah
    mov byte [edi+4], 0xC4
    mov [edi+5], ah
    mov byte [edi+6], 0xC4
    mov [edi+7], ah
    mov byte [edi+8], 0xD9
    mov [edi+9], ah
    inc ebx
    jmp .cd_btn
.cd_done:
    popa
    ret
bcd_to_bin:
    push ebx
    mov bl, al
    shr bl, 4          ; bl = tens digit
    and al, 0x0F       ; al = ones digit
    mov cl, 10
    xchg al, bl        ; al = tens, bl = ones
    mul cl             ; ax = tens * 10
    add al, bl         ; al = tens*10 + ones
    and eax, 0xFF
    pop ebx
    ret

;=============================================================================
; Calendar Application - Perpetual Calendar with RTC support
;=============================================================================

calendar_app:
    pusha
    call clear_screen
    call tui_read_date
    mov al, [tui_calc_mon]
    call bcd_to_bin
    mov [cal_month], al
    mov al, [tui_calc_year]
    call bcd_to_bin
    add ax, 2000
    mov [cal_year], ax
.cal_loop:
    call cal_draw_final
    call read_scancode
    cmp al, 0x01
    je .cal_exit
    cmp al, 0x4B
    je .cal_prev
    cmp al, 0x4D
    je .cal_next
    jmp .cal_loop
.cal_prev:
    dec byte [cal_month]
    cmp byte [cal_month], 0
    jg .cal_loop
    mov byte [cal_month], 12
    dec word [cal_year]
    jmp .cal_loop
.cal_next:
    inc byte [cal_month]
    cmp byte [cal_month], 12
    jle .cal_loop
    mov byte [cal_month], 1
    inc word [cal_year]
    jmp .cal_loop
.cal_exit:
    call clear_screen
    popa
    ret
cal_draw_final:
    pusha
    mov edi, 0xB8000
    mov ecx, 2000
    mov ax, 0x1F20
    rep stosw

    ; Draw title: "Month Year" centered
    mov edi, 0xB8000 + 1*160 + 20*2
    movzx eax, byte [cal_month]
    dec eax
    mov ebx, 11
    mul ebx
    mov esi, cal_month_names
    add esi, eax
    mov ah, 0x1F
    call tui_put_str
    mov edi, 0xB8000 + 1*160 + 32*2
    mov ax, [cal_year]
    call print_dec

    ; Draw weekday header
    mov edi, 0xB8000 + 3*160 + 10*2
    mov esi, cal_str_weekdays
    mov ah, 0x1F
    call tui_put_str

    ; Calculate first day of month and days in month
    movzx eax, byte [cal_month]
    movzx ebx, word [cal_year]
    call cal_calc_first_day
    mov [cal_first_day], eax
    movzx eax, byte [cal_month]
    movzx ebx, word [cal_year]
    call cal_days_in_month
    mov [cal_days], eax

    ; Draw calendar grid and days
    mov byte [cal_v2_row], 5
    mov byte [cal_v2_col], 10
    movzx ecx, byte [cal_first_day]
.cdf_pad:
    cmp ecx, 0
    je .cdf_days_start
    add byte [cal_v2_col], 8
    dec ecx
    jmp .cdf_pad
.cdf_days_start:
    mov ecx, 1
.cdf_day_loop:
    cmp ecx, [cal_days]
    jg .cdf_done
    cmp byte [cal_v2_row], 22
    jg .cdf_done
    mov eax, ecx
    mov edi, cal_tmp
    call int_to_string_fm
    movzx eax, byte [cal_v2_row]
    mov ebx, 160
    mul ebx
    mov edi, 0xB8000
    add edi, eax
    movzx eax, byte [cal_v2_col]
    add edi, eax
    add edi, eax
    mov esi, cal_tmp
    cmp byte [cal_tmp + 1], 0
    jne .cdf_2digit
    mov byte [edi], ' '
    mov byte [edi+1], 0x1F
    add edi, 2
.cdf_2digit:
    mov ah, 0x1F
    call tui_put_str
    mov eax, [cal_first_day]
    add eax, ecx
    dec eax
    mov edx, 0
    mov ebx, 7
    div ebx
    cmp edx, 6
    jne .cdf_nl
    inc byte [cal_v2_row]
    mov byte [cal_v2_col], 10
    jmp .cdf_next
.cdf_nl:
    add byte [cal_v2_col], 8
.cdf_next:
    inc ecx
    jmp .cdf_day_loop
.cdf_done:
    mov edi, 0xB8000 + 24*160
    mov ecx, 80
    mov ax, 0x7020
    rep stosw
    mov edi, 0xB8000 + 24*160 + 2
    mov esi, cal_str_help
    mov ah, 0x70
    call tui_put_str
    popa
    ret
cal_v2_row         db 0
cal_v2_col         db 0

cal_calc_first_day:
    ; Zeller's congruence for Gregorian calendar
    ; Input: eax = month (1-12), ebx = year
    ; Output: eax = day of week (0=Sunday, 1=Monday, ..., 6=Saturday)
    pusha
    mov ecx, eax          ; ecx = month
    mov eax, ebx          ; eax = year
    ; If month is Jan or Feb, treat as month 13/14 of previous year
    cmp ecx, 3
    jge .ccf_no_adj
    dec eax               ; year--
    add ecx, 12           ; month += 12
.ccf_no_adj:
    ; eax = adjusted year, ecx = adjusted month
    mov [cal_tmp_year], eax
    mov [cal_tmp_month], ecx
    ; Calculate K = year % 100
    xor edx, edx
    mov ebx, 100
    div ebx
    mov [cal_tmp_year2], edx    ; K = year % 100
    mov [cal_tmp_century], eax  ; J = year / 100
    ; Zeller's formula: h = (1 + (13*(m+1))/5 + K + K/4 + J/4 - 2*J) mod 7
    ; where m is month (3-14), K is year%100, J is year/100
    mov eax, [cal_tmp_month]
    inc eax
    imul eax, 13
    mov ebx, 5
    xor edx, edx
    div ebx               ; eax = (13*(m+1))/5
    add eax, 1            ; h = 1 + (13*(m+1))/5
    add eax, [cal_tmp_year2]  ; h += K
    mov ebx, [cal_tmp_year2]
    shr ebx, 2            ; K/4
    add eax, ebx          ; h += K/4
    mov ebx, [cal_tmp_century]
    shr ebx, 2            ; J/4
    add eax, ebx          ; h += J/4
    mov ebx, [cal_tmp_century]
    shl ebx, 1            ; 2*J
    sub eax, ebx          ; h -= 2*J
    ; Make positive and mod 7
    mov ebx, 7
    xor edx, edx
    idiv ebx
    mov eax, edx
    cmp eax, 0
    jge .ccf_positive
    add eax, 7
.ccf_positive:
    ; Convert Zeller output (0=Sat,1=Sun,2=Mon,...) to (0=Sun,1=Mon,...,6=Sat)
    cmp eax, 0
    jne .ccf_not_sat
    mov eax, 6
    jmp .ccf_store
.ccf_not_sat:
    dec eax
.ccf_store:
    mov [cal_result_day], eax
    popa
    mov eax, [cal_result_day]
    ret
cal_days_in_month:
    pusha
    cmp eax, 2
    jne .cal_not_feb
    mov eax, [cal_year]
    mov ebx, 4
    xor edx, edx
    div ebx
    cmp edx, 0
    jne .cal_feb_28
    mov eax, [cal_year]
    mov ebx, 100
    xor edx, edx
    div ebx
    cmp edx, 0
    jne .cal_feb_29
    mov eax, [cal_year]
    mov ebx, 400
    xor edx, edx
    div ebx
    cmp edx, 0
    je .cal_feb_29
.cal_feb_28:
    mov dword [cal_days_result], 28
    jmp .cal_days_done
.cal_feb_29:
    mov dword [cal_days_result], 29
    jmp .cal_days_done
.cal_not_feb:
    cmp eax, 4
    je .cal_30
    cmp eax, 6
    je .cal_30
    cmp eax, 9
    je .cal_30
    cmp eax, 11
    je .cal_30
    mov dword [cal_days_result], 31
    jmp .cal_days_done
.cal_30:
    mov dword [cal_days_result], 30
.cal_days_done:
    popa
    mov eax, [cal_days_result]
    ret
settings_app:
    pusha
    call clear_screen
    mov edi, 0xB8000
    mov ecx, 2000
    mov ax, 0x6F20
    rep stosw
    mov byte [settings_focus], 0
    mov byte [settings_exit], 0
.sett_loop:
    call settings_draw
    call read_scancode
    cmp al, 0x01
    je .sett_exit
    cmp al, 0x48
    je .sett_up
    cmp al, 0x50
    je .sett_down
    cmp al, 0x1C
    je .sett_enter
    jmp .sett_loop
.sett_up:
    cmp byte [settings_focus], 0
    je .sett_loop
    dec byte [settings_focus]
    jmp .sett_loop
.sett_down:
    cmp byte [settings_focus], 3
    je .sett_loop
    inc byte [settings_focus]
    jmp .sett_loop
.sett_enter:
    mov al, [settings_focus]
    cmp al, 0
    je .sett_calibrate
    cmp al, 1
    je .sett_disk
    cmp al, 2
    je .sett_dev
    cmp al, 3
    je .sett_exit
    jmp .sett_loop
.sett_disk:
    call disk_mgr_app
    jmp .sett_loop
.sett_dev:
    call dev_mgr_app
    jmp .sett_loop
.sett_calibrate:
    call tui_read_date
    call tui_calibrate_rtc
    mov edi, 0xB8000 + 2400 + 50
    mov ecx, 30
    mov ax, 0x2F20
    rep stosw
    mov edi, 0xB8000 + 15*80*2 + 27*2
    mov esi, settings_str_done
    mov ah, 0x2F
    call tui_put_str
    mov eax, 100
    call pit_delay_ms
    jmp .sett_loop
.sett_exit:
    call clear_screen
    popa
    ret
;=============================================================================
; Disk Manager - Partition management with FAT12/FAT32 format support
;=============================================================================

disk_mgr_app:
    pusha
    call clear_screen
    mov byte [dm_side], 0
    mov byte [dm_disk_sel], 0
    mov byte [dm_part_sel], 0
    mov byte [dm_exit], 0
    mov byte [dm_act_sel], 0
    mov byte [dm_show_act], 0
    mov byte [dm_show_new], 0
    mov byte [dm_new_size], 16
    call dm_count_disks
    ; Resolve the drive-table slot for the selected disk (dm_disk_sel is a
    ; 0-based index into dm_disk_list, not a drive-table slot)
    movzx eax, byte [dm_disk_sel]
    mov al, [dm_disk_list + eax]
    shl eax, 4
    mov al, [drive_table + eax + 2]
    mov [selected_disk], al
    call get_disk_size
    mov eax, [disk_size_sectors]
    mov ebx, 2048
    xor edx, edx
    div ebx
    mov [dm_disk_size], al
    movzx eax, byte [dm_disk_sel]
    mov al, [dm_disk_list + eax]
    shl eax, 4
    mov al, [drive_table + eax + 3]
    mov [selected_partition], al
    movzx eax, byte [dm_disk_sel]
    mov al, [dm_disk_list + eax]
    shl eax, 4
    mov eax, [drive_table + eax + 4]
    mov [selected_partition_start], eax
    call read_mbr
.dm_loop:
    call dm_draw_final
    call read_scancode
    cmp al, 0x01
    je .dm_exit
    cmp byte [dm_show_new], 1
    je .dm_new_mode
    cmp byte [dm_show_act], 1
    je .dm_act_mode
    cmp al, 0x1C
    je .dm_enter
    cmp al, 0x4B
    je .dm_left
    cmp al, 0x4D
    je .dm_right
    cmp al, 0x48
    je .dm_up
    cmp al, 0x50
    je .dm_down
    jmp .dm_loop
.dm_new_mode:
    cmp al, 0x1C
    je .dm_new_confirm
    cmp al, 0x48
    je .dm_new_up
    cmp al, 0x50
    je .dm_new_down
    jmp .dm_loop
.dm_new_up:
    add byte [dm_new_size], 10
    jmp .dm_loop
.dm_new_down:
    cmp byte [dm_new_size], 10
    jle .dm_loop
    sub byte [dm_new_size], 10
    jmp .dm_loop
.dm_new_confirm:
    mov byte [dm_show_new], 0
    jmp .dm_loop
.dm_act_mode:
    cmp al, 0x1C
    je .dm_act_enter
    cmp al, 0x48
    je .dm_act_up
    cmp al, 0x50
    je .dm_act_down
    jmp .dm_loop
.dm_act_up:
    cmp byte [dm_act_sel], 0
    je .dm_loop
    dec byte [dm_act_sel]
    jmp .dm_loop
.dm_act_down:
    cmp byte [dm_act_sel], 2
    je .dm_loop
    inc byte [dm_act_sel]
    jmp .dm_loop
.dm_act_enter:
    mov byte [dm_show_act], 0
    jmp .dm_loop
.dm_left:
    mov byte [dm_side], 0
    jmp .dm_loop
.dm_right:
    cmp byte [dm_disk_count], 0
    je .dm_loop
    mov byte [dm_side], 1
    jmp .dm_loop
.dm_up:
    cmp byte [dm_side], 0
    jne .dm_up_part
    cmp byte [dm_disk_sel], 0
    je .dm_loop
    dec byte [dm_disk_sel]
    mov byte [dm_part_sel], 0
    jmp .dm_loop
.dm_up_part:
    cmp byte [dm_part_sel], 0
    je .dm_loop
    dec byte [dm_part_sel]
    jmp .dm_loop
.dm_down:
    cmp byte [dm_side], 0
    jne .dm_down_part
    mov al, [dm_disk_sel]
    inc al
    cmp al, [dm_disk_count]
    jge .dm_loop
    inc byte [dm_disk_sel]
    mov byte [dm_part_sel], 0
    jmp .dm_loop
.dm_down_part:
    cmp byte [dm_part_sel], 2
    je .dm_loop
    inc byte [dm_part_sel]
    jmp .dm_loop
.dm_enter:
    cmp byte [dm_side], 0
    je .dm_loop
    cmp byte [dm_part_sel], 2
    jne .dm_loop
    mov byte [dm_show_act], 1
    mov byte [dm_act_sel], 0
    jmp .dm_loop
.dm_exit:
    call clear_screen
    popa
    ret
dm_count_disks:
    pusha
    mov byte [dm_disk_count], 0
    xor ebx, ebx
.dcd_loop:
    cmp ebx, 4
    jge .dcd_done
    mov eax, ebx
    shl eax, 4
    cmp byte [drive_table + eax], 0
    je .dcd_next
    mov al, [drive_table + eax + 1]
    cmp al, 'A'
    je .dcd_next
    mov ecx, [dm_disk_count]
    mov [dm_disk_list + ecx], bl
    inc byte [dm_disk_count]
.dcd_next:
    inc ebx
    jmp .dcd_loop
.dcd_done:
    popa
    ret
dm_draw_final:
    pusha
    mov edi, 0xB8000
    mov ecx, 2000
    mov ax, 0x1F20
    rep stosw
    mov edi, 0xB8000 + 1*160 + 28*2
    mov esi, dm_str_title
    mov ah, 0x1F
    call tui_put_str
    mov edi, 0xB8000 + 3*160 + 2*2
    mov esi, dm_str_disk
    mov ah, 0x1F
    call tui_put_str
    mov edi, 0xB8000 + 3*160 + 22*2
    mov esi, dm_str_vol
    mov ah, 0x1F
    call tui_put_str
    mov ecx, 20
.ddf_vline:
    mov edi, 0xB8000
    mov eax, ecx
    add eax, 3
    mov ebx, 160
    mul ebx
    add edi, eax
    add edi, 20*2
    mov byte [edi], 0xB3
    mov byte [edi+1], 0x1F
    loop .ddf_vline
    xor ebx, ebx
.ddf_diskloop:
    mov [dm_loop_idx], ebx
    cmp bl, [dm_disk_count]
    jge .ddf_diskdone
    mov edi, 0xB8000
    mov eax, ebx
    add eax, 5
    mov ecx, 160
    mul ecx
    add edi, eax
    add edi, 2*2
    cmp byte [dm_side], 0
    jne .ddf_disknf
    cmp bl, [dm_disk_sel]
    jne .ddf_disknf
    mov ecx, 16
    mov ax, 0x3F20
    rep stosw
    jmp .ddf_diskdraw
.ddf_disknf:
    mov ecx, 16
    mov ax, 0x1F20
    rep stosw
.ddf_diskdraw:
    mov edi, 0xB8000
    mov eax, ebx
    add eax, 5
    mov ecx, 160
    mul ecx
    add edi, eax
    add edi, 2*2
    ; Get disk index from drive table
    movzx ecx, bl
    mov bl, [dm_disk_list + ecx]
    ; Display disk channel info: [ PriMst/PriSlv/SecMst/SecSlv ]
    mov eax, ebx
    shl eax, 4
    mov al, [drive_table + eax + 2]  ; Get disk number
    push ebx
    ; Get channel name
    mov esi, disk_names
    movzx eax, al
    mov ebx, 7
    mul ebx
    add esi, eax
    mov ah, 0x1F
    ; Write opening bracket
    mov byte [edi], '['
    mov byte [edi+1], 0x1F
    add edi, 2
    ; Write channel name
.ddf_chname:
    lodsb
    cmp al, 0
    je .ddf_chdone
    mov [edi], al
    mov byte [edi+1], 0x1F
    add edi, 2
    jmp .ddf_chname
.ddf_chdone:
    ; Write closing bracket and size
    mov byte [edi], ']'
    mov byte [edi+1], 0x1F
    add edi, 2
    mov byte [edi], ' '
    mov byte [edi+1], 0x1F
    add edi, 2
    ; Write size in MB
    pop ebx
    mov eax, ebx
    shl eax, 4
    mov al, [drive_table + eax + 2]
    mov [selected_disk], al
    call get_disk_size
    mov eax, [disk_size_sectors]
    mov ebx, 2048
    xor edx, edx
    div ebx
    call print_dec
    mov esi, dm_str_mb
    mov ah, 0x1F
    call tui_put_str
    mov ebx, [dm_loop_idx]
    inc ebx
    jmp .ddf_diskloop
.ddf_diskdone:
    mov edi, 0xB8000 + 5*160 + 22*2
    mov esi, dm_str_layout
    mov ah, 0x1F
    call tui_put_str
    mov edi, 0xB8000 + 7*160 + 22*2
    mov byte [edi], 0xDA
    mov byte [edi+1], 0x1F
    mov ecx, 52
.ddf_top:
    mov byte [edi+2], 0xC4
    mov byte [edi+3], 0x1F
    add edi, 2
    loop .ddf_top
    mov byte [edi+2], 0xBF
    mov byte [edi+3], 0x1F
    mov edi, 0xB8000 + 8*160 + 22*2
    mov byte [edi], 0xB3
    mov byte [edi+1], 0x1F
    mov ecx, 13
.ddf_p1:
    mov byte [edi+2], 0xDB
    mov byte [edi+3], 0x2F
    add edi, 2
    loop .ddf_p1
    mov ecx, 13
.ddf_p2:
    mov byte [edi+2], 0xDB
    mov byte [edi+3], 0x4F
    add edi, 2
    loop .ddf_p2
    mov ecx, 26
.ddf_free:
    mov byte [edi+2], 0xB0
    mov byte [edi+3], 0x8F
    add edi, 2
    loop .ddf_free
    mov byte [edi+2], 0xB3
    mov byte [edi+3], 0x1F
    mov edi, 0xB8000 + 9*160 + 22*2
    mov byte [edi], 0xC0
    mov byte [edi+1], 0x1F
    mov ecx, 52
.ddf_bot:
    mov byte [edi+2], 0xC4
    mov byte [edi+3], 0x1F
    add edi, 2
    loop .ddf_bot
    mov byte [edi+2], 0xD9
    mov byte [edi+3], 0x1F
    mov edi, 0xB8000 + 11*160 + 22*2
    cmp byte [dm_part_sel], 0
    jne .ddf_p1nf
    mov ah, 0x3F
    jmp .ddf_p1d
.ddf_p1nf:
    mov ah, 0x1F
.ddf_p1d:
    push ax
    mov esi, dm_str_p1
    call tui_put_str
    mov byte [edi], ' '
    pop ax
    mov byte [edi+1], ah
    add edi, 2
    movzx eax, byte [dm_part_sel]
    shl eax, 4
    mov eax, [partition_table + eax + 12]  ; Get partition size in sectors
    mov ebx, 2048
    xor edx, edx
    div ebx
    call print_dec
    mov esi, dm_str_mb
    mov ah, 0x1F
    call tui_put_str
    mov edi, 0xB8000 + 12*160 + 22*2
    cmp byte [dm_part_sel], 1
    jne .ddf_p2nf
    mov esi, dm_str_p2_f
    mov ah, 0x3F
    jmp .ddf_p2d
.ddf_p2nf:
    mov esi, dm_str_p2
    mov ah, 0x1F
.ddf_p2d:
    call tui_put_str
    mov edi, 0xB8000 + 13*160 + 22*2
    cmp byte [dm_part_sel], 2
    jne .ddf_freenf
    mov esi, dm_str_free_f
    mov ah, 0x3F
    jmp .ddf_freed
.ddf_freenf:
    mov esi, dm_str_free
    mov ah, 0x1F
.ddf_freed:
    call tui_put_str
    cmp byte [dm_show_act], 1
    jne .ddf_noact
    mov edi, 0xB8000 + 8*160 + 24*2
    mov ecx, 32
    mov ax, 0x7020
    rep stosw
    mov edi, 0xB8000 + 8*160 + 26*2
    mov esi, dm_str_act_title
    mov ah, 0x70
    call tui_put_str
    mov edi, 0xB8000 + 10*160 + 28*2
    mov esi, dm_str_act_new
    cmp byte [dm_act_sel], 0
    jne .dda_nf0
    mov ah, 0x3F
    jmp .dda_d0
.dda_nf0:
    mov ah, 0x70
.dda_d0:
    call tui_put_str
    mov edi, 0xB8000 + 12*160 + 28*2
    mov esi, dm_str_act_fmt
    cmp byte [dm_act_sel], 1
    jne .dda_nf1
    mov ah, 0x3F
    jmp .dda_d1
.dda_nf1:
    mov ah, 0x70
.dda_d1:
    call tui_put_str
    mov edi, 0xB8000 + 14*160 + 28*2
    mov esi, dm_str_act_back
    cmp byte [dm_act_sel], 2
    jne .dda_nf2
    mov ah, 0x3F
    jmp .dda_d2
.dda_nf2:
    mov ah, 0x70
.dda_d2:
    call tui_put_str
.ddf_noact:
    mov edi, 0xB8000 + 24*160
    mov ecx, 80
    mov ax, 0x7020
    rep stosw
    mov edi, 0xB8000 + 24*160 + 2
    mov esi, dm_str_help
    mov ah, 0x70
    call tui_put_str
    popa
    ret
dm_disk_size       db 64

dm_show_new        db 0
dm_new_size        db 16
dm_str_vol          db 'Volumes:',0
dm_str_disk_lbl    db 'Disk',0
dm_str_p1          db 'Partition 1',0
dm_str_p1_f        db '> (C:) 16MB NTFS <',0
dm_str_p2          db 'Partition 2',0
dm_str_p2_f        db '> (D:) 16MB FAT32 <',0
dm_str_free_f      db '> Unallocated 32MB <',0
dm_str_mb          db 'MB',0
dm_str_layout      db 'Disk Layout:',0

dm_count_parts:
    pusha
    mov byte [dm_part_count], 2
    popa
    ret
dm_side            db 0
dm_disk_sel        db 0
dm_part_sel        db 0
dm_disk_count      db 0
dm_part_count      db 0
dm_disk_list       times 4 db 0
dm_act_sel         db 0
dm_show_act        db 0
dm_tmp_str         times 16 db 0
dm_exit            db 0
dm_loop_idx        dd 0

dev_mgr_app:
    pusha
    call clear_screen
    mov edi, 0xB8000
    mov ecx, 2000
    mov ax, 0xAF20
    rep stosw
    mov byte [dev_exit], 0
    call dev_detect
.dev_loop:
    call dev_mgr_draw
    call read_scancode
    cmp al, 0x01
    je .dev_exit
    cmp al, 0x1C
    je .dev_exit
    jmp .dev_loop
.dev_exit:
    call clear_screen
    popa
    ret
dev_detect:
    pusha
    mov byte [dev_count], 0
    mov dword [dev_mem_base], 640
    mov eax, 1024
    mov [dev_mem_ext], eax
    mov byte [dev_cpu_count], 1
    mov byte [dev_disk_count], 0
    xor ebx, ebx
.dd_diskloop:
    cmp ebx, 4
    jge .dd_diskdone
    mov eax, ebx
    shl eax, 4
    cmp byte [drive_table + eax], 0
    je .dd_disknext
    inc byte [dev_disk_count]
.dd_disknext:
    inc ebx
    jmp .dd_diskloop
.dd_diskdone:
    popa
    ret
dev_mgr_draw:
    pusha
    mov edi, 0xB8000
    mov ecx, 2000
    mov ax, 0x1F20
    rep stosw
    mov edi, 0xB8000 + 1*160 + 24*2
    mov esi, dev_str_title
    mov ah, 0x1F
    call tui_put_str
    mov edi, 0xB8000 + 3*160 + 4*2
    mov esi, dev_str_cpu
    mov ah, 0x1F
    call tui_put_str
    mov edi, 0xB8000 + 3*160 + 40*2
    mov esi, dev_str_present
    mov ah, 0x2F
    call tui_put_str
    mov edi, 0xB8000 + 5*160 + 4*2
    mov esi, dev_str_mem
    mov ah, 0x1F
    call tui_put_str
    mov eax, [dev_mem_base]
    mov edi, dm_tmp_str
    call int_to_string_fm
    mov edi, 0xB8000 + 5*160 + 30*2
    mov esi, dm_tmp_str
    mov ah, 0x1F
    call tui_put_str
    mov edi, 0xB8000 + 5*160 + 36*2
    mov esi, dev_str_kb
    mov ah, 0x1F
    call tui_put_str
    mov eax, [dev_mem_ext]
    mov edi, dm_tmp_str
    call int_to_string_fm
    mov edi, 0xB8000 + 5*160 + 44*2
    mov esi, dm_tmp_str
    mov ah, 0x1F
    call tui_put_str
    mov edi, 0xB8000 + 5*160 + 52*2
    mov esi, dev_str_kb
    mov ah, 0x1F
    call tui_put_str
    mov edi, 0xB8000 + 7*160 + 4*2
    mov esi, dev_str_kbd
    mov ah, 0x1F
    call tui_put_str
    mov edi, 0xB8000 + 7*160 + 40*2
    mov esi, dev_str_present
    mov ah, 0x2F
    call tui_put_str
    mov edi, 0xB8000 + 9*160 + 4*2
    mov esi, dev_str_vga
    mov ah, 0x1F
    call tui_put_str
    mov edi, 0xB8000 + 9*160 + 40*2
    mov esi, dev_str_present
    mov ah, 0x2F
    call tui_put_str
    mov edi, 0xB8000 + 11*160 + 4*2
    mov esi, dev_str_fdc
    mov ah, 0x1F
    call tui_put_str
    mov edi, 0xB8000 + 11*160 + 40*2
    mov esi, dev_str_present
    mov ah, 0x2F
    call tui_put_str
    mov edi, 0xB8000 + 13*160 + 4*2
    mov esi, dev_str_ata
    mov ah, 0x1F
    call tui_put_str
    movzx eax, byte [dev_disk_count]
    mov edi, dm_tmp_str
    call int_to_string_fm
    mov edi, 0xB8000 + 13*160 + 40*2
    mov esi, dm_tmp_str
    mov ah, 0x2F
    call tui_put_str
    mov edi, 0xB8000 + 13*160 + 44*2
    mov esi, dev_str_drv
    mov ah, 0x1F
    call tui_put_str
    mov edi, 0xB8000 + 15*160 + 4*2
    mov esi, dev_str_rtc
    mov ah, 0x1F
    call tui_put_str
    mov edi, 0xB8000 + 15*160 + 40*2
    mov esi, dev_str_present
    mov ah, 0x2F
    call tui_put_str
    mov edi, 0xB8000 + 17*160 + 4*2
    mov esi, dev_str_pit
    mov ah, 0x1F
    call tui_put_str
    mov edi, 0xB8000 + 17*160 + 40*2
    mov esi, dev_str_present
    mov ah, 0x2F
    call tui_put_str
    mov edi, 0xB8000 + 24*160
    mov ecx, 80
    mov ax, 0x7020
    rep stosw
    mov edi, 0xB8000 + 24*160 + 2
    mov esi, dev_str_help
    mov ah, 0x70
    call tui_put_str
    popa
    ret

settings_draw:
    pusha
    mov edi, 0xB8000
    mov ecx, 80*25
    mov ax, 0x1F20
    rep stosw
    mov edi, 0xB8000 + 160 + 60
    mov esi, settings_str_title
    mov ah, 0x1F
    call tui_put_str
    mov edi, 0xB8000 + 800 + 56
    mov esi, settings_str_time
    cmp byte [settings_focus], 0
    jne .sd_no1
    mov ah, 0x3F
    jmp .sd_draw1
.sd_no1:
    mov ah, 0x70
.sd_draw1:
    call tui_put_str
    mov edi, 0xB8000 + 1120 + 56
    mov esi, settings_str_disk
    cmp byte [settings_focus], 1
    jne .sd_no2
    mov ah, 0x3F
    jmp .sd_draw2
.sd_no2:
    mov ah, 0x70
.sd_draw2:
    call tui_put_str
    mov edi, 0xB8000 + 1440 + 56
    mov esi, settings_str_dev
    cmp byte [settings_focus], 2
    jne .sd_no3
    mov ah, 0x3F
    jmp .sd_draw3
.sd_no3:
    mov ah, 0x70
.sd_draw3:
    call tui_put_str
    mov edi, 0xB8000 + 1760 + 56
    mov esi, settings_str_back
    cmp byte [settings_focus], 3
    jne .sd_no4
    mov ah, 0x3F
    jmp .sd_draw4
.sd_no4:
    mov ah, 0x70
.sd_draw4:
    call tui_put_str
    mov edi, 0xB8000 + 3680 + 40
    mov esi, settings_str_help
    mov ah, 0x70
    call tui_put_str
    popa
    ret

game_menu_app:
    pusha
    mov byte [game_menu_focus], 0
    mov byte [game_menu_exit], 0
    call tui_draw_main
    call game_menu_draw
.gm_loop:
    mov eax, 10
    call pit_delay_ms
    call tui_poll_event
    cmp al, 0
    je .gm_loop
    call game_menu_handle
    cmp byte [game_menu_exit], 1
    je .gm_exit
    call tui_draw_main
    call game_menu_draw
    jmp .gm_loop
.gm_exit:
    popa
    ret
game_menu_draw:
    pusha
    mov ebx, 7
.gm_row:
    mov edi, 0xB8000
    mov eax, ebx
    mov ecx, 80
    mul ecx
    shl eax, 1
    add edi, eax
    add edi, 26*2
    mov ecx, 28
    mov ax, 0x7020
    rep stosw
    inc ebx
    cmp ebx, 17
    jl .gm_row
    mov edi, 0xB8000 + 7*80*2 + 26*2
    mov ecx, 28
    mov ax, 0x1F20
    rep stosw
    mov edi, 0xB8000 + 7*80*2 + 34*2
    mov esi, tui_str_game_menu
    mov ah, 0x1F
    call tui_put_str
    mov edi, 0xB8000 + 9*80*2 + 32*2
    cmp byte [game_menu_focus], 0
    jne .gm_guess_nofocus
    mov esi, gm_str_guess_f
    mov ah, 0x3F
    jmp .gm_guess_draw
.gm_guess_nofocus:
    mov esi, gm_str_guess
    mov ah, 0x70
.gm_guess_draw:
    call tui_put_str
    mov edi, 0xB8000 + 11*80*2 + 32*2
    cmp byte [game_menu_focus], 1
    jne .gm_ttt_nofocus
    mov esi, tui_str_ttt_f
    mov ah, 0x3F
    jmp .gm_ttt_draw
.gm_ttt_nofocus:
    mov esi, tui_str_ttt
    mov ah, 0x70
.gm_ttt_draw:
    call tui_put_str
    mov edi, 0xB8000 + 13*80*2 + 32*2
    cmp byte [game_menu_focus], 2
    jne .gm_back_nofocus
    mov esi, gm_str_back_f
    mov ah, 0x3F
    jmp .gm_back_draw
.gm_back_nofocus:
    mov esi, gm_str_back
    mov ah, 0x70
.gm_back_draw:
    call tui_put_str
    popa
    ret
game_menu_handle:
    pusha
    cmp al, 0x48
    je .gm_up
    cmp al, 0x50
    je .gm_down
    cmp al, 0x1C
    je .gm_enter
    cmp al, 0x01
    je .gm_esc
    jmp .gm_done
.gm_up:
    cmp byte [game_menu_focus], 0
    je .gm_done
    dec byte [game_menu_focus]
    jmp .gm_done
.gm_down:
    cmp byte [game_menu_focus], 2
    je .gm_done
    inc byte [game_menu_focus]
    jmp .gm_done
.gm_enter:
    mov al, [game_menu_focus]
    cmp al, 0
    je .gm_guess
    cmp al, 1
    je .gm_ttt
    mov byte [game_menu_exit], 1
    jmp .gm_done
.gm_guess:
    call guess_game
    jmp .gm_done
.gm_ttt:
    call ttt_mode_menu
    jmp .gm_done
.gm_esc:
    mov byte [game_menu_exit], 1
.gm_done:
    popa
    ret
guess_game:
    pusha
    call clear_screen
    mov byte [guess_difficulty], 0
    mov byte [guess_exit], 0
.diff_loop:
    call guess_draw_diff
    call read_scancode
    cmp al, 0x01
    je .guess_exit
    cmp al, 0x48
    je .diff_up
    cmp al, 0x50
    je .diff_down
    cmp al, 0x1C
    je .diff_enter
    jmp .diff_loop
.diff_up:
    cmp byte [guess_difficulty], 0
    je .diff_loop
    dec byte [guess_difficulty]
    jmp .diff_loop
.diff_down:
    cmp byte [guess_difficulty], 2
    je .diff_loop
    inc byte [guess_difficulty]
    jmp .diff_loop
.diff_enter:
    mov al, [guess_difficulty]
    cmp al, 0
    je .diff_easy
    cmp al, 1
    je .diff_normal
    cmp al, 2
    je .diff_hard
    jmp .diff_loop
.diff_easy:
    mov byte [guess_difficulty], 1
    mov dword [guess_max], 50
    mov dword [guess_tries], 10
    jmp .start_game
.diff_normal:
    mov byte [guess_difficulty], 2
    mov dword [guess_max], 200
    mov dword [guess_tries], 6
    jmp .start_game
.diff_hard:
    mov byte [guess_difficulty], 3
    mov dword [guess_max], 500
    mov dword [guess_tries], 3
.start_game:
    rdtsc
    xor edx, edx
    mov ecx, [guess_max]
    inc ecx
    div ecx
    mov [guess_target], edx
    mov dword [guess_count], 0
    mov byte [guess_input_len], 0
    mov byte [guess_input], 0
.guess_loop:
    call guess_draw_game
    call read_scancode
    cmp al, 0x01
    je .guess_exit
    cmp al, 0x1C
    je .guess_submit
    cmp al, 0x0E
    je .guess_backspace
    call scancode_to_ascii
    cmp al, '0'
    jl .guess_loop
    cmp al, '9'
    jg .guess_loop
    movzx ebx, byte [guess_input_len]
    cmp ebx, 4
    jge .guess_loop
    mov byte [guess_input + ebx], al
    inc byte [guess_input_len]
    mov byte [guess_input + ebx + 1], 0
    jmp .guess_loop
.guess_backspace:
    cmp byte [guess_input_len], 0
    je .guess_loop
    dec byte [guess_input_len]
    movzx ebx, byte [guess_input_len]
    mov byte [guess_input + ebx], 0
    jmp .guess_loop
.guess_submit:
    cmp byte [guess_input_len], 0
    je .guess_loop
    mov esi, guess_input
    call parse_dec
    inc dword [guess_count]
    dec dword [guess_tries]
    cmp eax, [guess_target]
    je .guess_win
    jl .guess_low
    mov byte [guess_result], 1
    jmp .guess_check_tries
.guess_low:
    mov byte [guess_result], 2
.guess_check_tries:
    cmp dword [guess_tries], 0
    jg .guess_reset
    call guess_draw_gameover
.guess_wait_key:
    call read_scancode
    cmp al, 0x13
    je .guess_restart
    cmp al, 0x01
    je .guess_exit
    jmp .guess_wait_key
.guess_reset:
    mov byte [guess_input_len], 0
    mov byte [guess_input], 0
    jmp .guess_loop
.guess_win:
    mov byte [guess_result], 0
    call guess_draw_win
    jmp .guess_wait_key
.guess_restart:
    mov al, [guess_difficulty]
    cmp al, 1
    je .gr_easy
    cmp al, 2
    je .gr_normal
    jmp .gr_hard
.gr_easy:
    mov dword [guess_max], 50
    mov dword [guess_tries], 10
    jmp .gr_gen
.gr_normal:
    mov dword [guess_max], 200
    mov dword [guess_tries], 6
    jmp .gr_gen
.gr_hard:
    mov dword [guess_max], 500
    mov dword [guess_tries], 3
.gr_gen:
    mov eax, 0
    rdtsc
    mov ecx, [guess_max]
    inc ecx
    div ecx
    mov [guess_target], edx
    mov dword [guess_count], 0
    mov byte [guess_input_len], 0
    mov byte [guess_input], 0
    mov byte [guess_result], 0
    jmp .guess_loop
.guess_exit:
    call clear_screen
    popa
    ret
guess_draw_diff:
    pusha
    mov edi, 0xB8000
    mov ecx, 80*25
    mov ax, 0x1F20
    rep stosw
    mov edi, 0xB8000 + 320 + 50
    mov esi, guess_str_title
    mov ah, 0x1F
    call tui_put_str
    mov edi, 0xB8000 + 800 + 40
    mov esi, guess_str_sel_diff
    mov ah, 0x0F
    call tui_put_str
    mov edi, 0xB8000 + 1120 + 40
    cmp byte [guess_difficulty], 0
    jne .gdd_easy_nf
    mov esi, guess_str_easy_f
    mov ah, 0x3F
    jmp .gdd_easy_draw
.gdd_easy_nf:
    mov esi, guess_str_easy
    mov ah, 0x2F
.gdd_easy_draw:
    call tui_put_str
    mov edi, 0xB8000 + 1440 + 40
    cmp byte [guess_difficulty], 1
    jne .gdd_norm_nf
    mov esi, guess_str_normal_f
    mov ah, 0x3F
    jmp .gdd_norm_draw
.gdd_norm_nf:
    mov esi, guess_str_normal
    mov ah, 0x6F
.gdd_norm_draw:
    call tui_put_str
    mov edi, 0xB8000 + 1760 + 40
    cmp byte [guess_difficulty], 2
    jne .gdd_hard_nf
    mov esi, guess_str_hard_f
    mov ah, 0x3F
    jmp .gdd_hard_draw
.gdd_hard_nf:
    mov esi, guess_str_hard
    mov ah, 0x4F
.gdd_hard_draw:
    call tui_put_str
    mov edi, 0xB8000 + 2240 + 40
    mov esi, guess_str_press_enter
    mov ah, 0x0F
    call tui_put_str
    popa
    ret
guess_draw_game:
    pusha
    mov edi, 0xB8000
    mov ecx, 2000
    mov ax, 0x1F20
    rep stosw
    mov edi, 0xB8000 + 1*80*2 + 25*2
    mov esi, guess_str_title
    mov ah, 0x1F
    call tui_put_str
    mov edi, 0xB8000 + 3*80*2 + 10*2
    mov esi, guess_str_range2
    mov ah, 0x0F
    call tui_put_str
    mov edi, 0xB8000 + 3*80*2 + 18*2
    mov eax, 0
    call print_dec
    mov edi, 0xB8000 + 3*80*2 + 19*2
    mov al, '-'
    mov ah, 0x0F
    stosw
    mov edi, 0xB8000 + 3*80*2 + 20*2
    mov eax, [guess_max]
    call print_dec
    mov edi, 0xB8000 + 3*80*2 + 55*2
    mov esi, guess_str_tries
    mov ah, 0x0F
    call tui_put_str
    mov edi, 0xB8000 + 3*80*2 + 67*2
    mov eax, [guess_tries]
    call print_dec
    mov edi, 0xB8000 + 5*80*2 + 10*2
    mov esi, guess_str_prompt
    mov ah, 0x0F
    call tui_put_str
    mov edi, 0xB8000 + 5*80*2 + 22*2
    mov esi, guess_input
    mov ah, 0x0F
    call tui_put_str
    mov edi, 0xB8000 + 7*80*2 + 10*2
    mov ecx, 60
    mov ax, 0x1F20
    rep stosw
    cmp byte [guess_result], 0
    je .gdr_done
    cmp byte [guess_result], 1
    je .gdr_high
    mov edi, 0xB8000 + 7*80*2 + 10*2
    mov esi, guess_str_low
    mov ah, 0x1F
    call tui_put_str
    jmp .gdr_done
.gdr_high:
    mov edi, 0xB8000 + 7*80*2 + 10*2
    mov esi, guess_str_high
    mov ah, 0x4F
    call tui_put_str
.gdr_done:
    mov edi, 0xB8000 + 9*80*2 + 10*2
    mov esi, guess_str_guesses2
    mov ah, 0x0F
    call tui_put_str
    mov edi, 0xB8000 + 9*80*2 + 25*2
    mov eax, [guess_count]
    call print_dec
    mov edi, 0xB8000 + 23*80*2 + 10*2
    mov esi, guess_str_help
    mov ah, 0x70
    call tui_put_str
    popa
    ret
guess_draw_win:
    pusha
    call guess_draw_game
    mov edi, 0xB8000 + 11*160 + 20
    mov ecx, 40
    mov ax, 0x2F20
    rep stosw
    mov edi, 0xB8000 + 11*160 + 40
    mov esi, guess_str_win
    mov ah, 0x2F
    call tui_put_str
    mov edi, 0xB8000 + 13*160 + 40
    mov esi, guess_str_guesses
    mov ah, 0x0F
    call tui_put_str
    mov eax, [guess_count]
    mov edi, 0xB8000 + 13*160 + 70
    call print_dec
    mov edi, 0xB8000 + 15*80*2 + 20*2
    mov esi, guess_str_press
    mov ah, 0x0F
    call tui_put_str
    popa
    ret
guess_draw_gameover:
    pusha
    call guess_draw_game
    mov edi, 0xB8000 + 11*160 + 20
    mov ecx, 40
    mov ax, 0x4F20
    rep stosw
    mov edi, 0xB8000 + 1760 + 40
    mov esi, guess_str_gameover
    mov ah, 0x4F
    call tui_put_str
    mov edi, 0xB8000 + 13*80*2 + 20*2
    mov esi, guess_str_answer
    mov ah, 0x0F
    call tui_put_str
    mov eax, [guess_target]
    mov edi, 0xB8000 + 13*80*2 + 50*2
    call print_dec
    mov edi, 0xB8000 + 15*80*2 + 20*2
    mov esi, guess_str_press
    mov ah, 0x0F
    call tui_put_str
    popa
    ret
parse_dec:
    pusha
    xor eax, eax
    xor ebx, ebx
.pd_loop:
    mov cl, [esi + ebx]
    cmp cl, 0
    je .pd_done
    cmp cl, '0'
    jl .pd_done
    cmp cl, '9'
    jg .pd_done
    sub cl, '0'
    imul eax, 10
    add al, cl
    inc ebx
    jmp .pd_loop
.pd_done:
    mov [pd_result], eax
    popa
    mov eax, [pd_result]
    ret

ttt_mode_menu:
    pusha
    mov byte [ttt_mode_focus], 0
    mov byte [ttt_mode_exit], 0
    call tui_draw_main
    call ttt_mode_draw
.tm_loop:
    mov eax, 10
    call pit_delay_ms
    call tui_poll_event
    cmp al, 0
    je .tm_loop
    call ttt_mode_handle
    cmp byte [ttt_mode_exit], 1
    je .tm_exit
    call tui_draw_main
    call ttt_mode_draw
    jmp .tm_loop
.tm_exit:
    popa
    ret
ttt_mode_draw:
    pusha
    mov ebx, 8
.tm_row:
    mov edi, 0xB8000
    mov eax, ebx
    mov ecx, 80
    mul ecx
    shl eax, 1
    add edi, eax
    add edi, 26*2
    mov ecx, 28
    mov ax, 0x7020
    rep stosw
    inc ebx
    cmp ebx, 15
    jl .tm_row
    mov edi, 0xB8000 + 8*80*2 + 26*2
    mov ecx, 28
    mov ax, 0x1F20
    rep stosw
    mov edi, 0xB8000 + 8*80*2 + 33*2
    mov esi, ttt_str_mode_title
    mov ah, 0x1F
    call tui_put_str
    mov edi, 0xB8000 + 10*80*2 + 30*2
    cmp byte [ttt_mode_focus], 0
    jne .tm_ai_nofocus
    mov esi, ttt_str_vs_ai_f
    mov ah, 0x3F
    jmp .tm_ai_draw
.tm_ai_nofocus:
    mov esi, ttt_str_vs_ai
    mov ah, 0x70
.tm_ai_draw:
    call tui_put_str
    mov edi, 0xB8000 + 12*80*2 + 31*2
    cmp byte [ttt_mode_focus], 1
    jne .tm_2p_nofocus
    mov esi, ttt_str_2p_f
    mov ah, 0x3F
    jmp .tm_2p_draw
.tm_2p_nofocus:
    mov esi, ttt_str_2p
    mov ah, 0x70
.tm_2p_draw:
    call tui_put_str
    mov edi, 0xB8000 + 14*80*2 + 35*2
    cmp byte [ttt_mode_focus], 2
    jne .tm_back_nofocus
    mov esi, gm_str_back_f
    mov ah, 0x3F
    jmp .tm_back_draw
.tm_back_nofocus:
    mov esi, gm_str_back
    mov ah, 0x70
.tm_back_draw:
    call tui_put_str
    popa
    ret
ttt_mode_handle:
    pusha
    cmp al, 0x48
    je .tm_up
    cmp al, 0x50
    je .tm_down
    cmp al, 0x1C
    je .tm_enter
    cmp al, 0x01
    je .tm_esc
    jmp .tm_done
.tm_up:
    cmp byte [ttt_mode_focus], 0
    je .tm_done
    dec byte [ttt_mode_focus]
    jmp .tm_done
.tm_down:
    cmp byte [ttt_mode_focus], 2
    je .tm_done
    inc byte [ttt_mode_focus]
    jmp .tm_done
.tm_enter:
    cmp byte [ttt_mode_focus], 0
    je .tm_enter_ai
    cmp byte [ttt_mode_focus], 1
    je .tm_enter_2p
    mov byte [ttt_mode_exit], 1
    jmp .tm_done
.tm_enter_ai:
    mov byte [ttt_mode], 0
    call ttt_game
    mov byte [ttt_mode_exit], 1
    jmp .tm_done
.tm_enter_2p:
    mov byte [ttt_mode], 1
    call ttt_game
    mov byte [ttt_mode_exit], 1
    jmp .tm_done
.tm_esc:
    mov byte [ttt_mode_exit], 1
.tm_done:
    popa
    ret
ttt_draw:
    pusha
    mov edi, 0xB8000
    mov ecx, 80*25
    mov ax, 0x1F20
    rep stosw
    mov edi, 0xB8000 + 160 + 60
    mov esi, ttt_str_title
    mov ah, 0x1F
    call tui_put_str
    mov ebx, 0
.ttt_border_row:
    cmp ebx, 4
    jge .ttt_border_done
    mov edi, 0xB8000
    mov eax, ebx
    imul eax, 2
    add eax, 4
    mov esi, 80
    mul esi
    shl eax, 1
    add edi, eax
    add edi, 30*2
    mov ecx, 3
.ttt_border_cell:
    mov al, '+'
    mov ah, 0x1F
    stosw
    mov al, '-'
    stosw
    stosw
    stosw
    dec ecx
    jnz .ttt_border_cell
    mov al, '+'
    stosw
    inc ebx
    jmp .ttt_border_row
.ttt_border_done:
    mov ebx, 0
.ttt_content_row:
    cmp ebx, 3
    jge .ttt_content_done
    mov edi, 0xB8000
    mov eax, ebx
    imul eax, 2
    add eax, 5
    mov esi, 80
    mul esi
    shl eax, 1
    add edi, eax
    add edi, 30*2
    mov ecx, 3
.ttt_content_cell:
    mov al, '|'
    mov ah, 0x1F
    stosw
    mov edx, ebx
    imul edx, 3
    add edx, 3
    sub edx, ecx
    push ecx
    push edx
    mov eax, edx
    cmp al, [ttt_cursor]
    jne .ttt_no_cursor_cell
    mov al, ' '
    mov ah, 0x3F
    stosw
    mov al, [ttt_board + edx]
    cmp al, 0
    je .ttt_cell_empty_cur
    cmp al, 1
    je .ttt_cell_x_cur
    mov al, 'O'
    jmp .ttt_cell_put_cur
.ttt_cell_x_cur:
    mov al, 'X'
    jmp .ttt_cell_put_cur
.ttt_cell_empty_cur:
    mov al, ' '
.ttt_cell_put_cur:
    mov ah, 0x3F
    stosw
    mov al, ' '
    stosw
    jmp .ttt_cell_done_cur
.ttt_no_cursor_cell:
    mov al, ' '
    mov ah, 0x1F
    stosw
    mov al, [ttt_board + edx]
    cmp al, 0
    je .ttt_cell_empty
    cmp al, 1
    je .ttt_cell_x
    mov al, 'O'
    jmp .ttt_cell_put
.ttt_cell_x:
    mov al, 'X'
    jmp .ttt_cell_put
.ttt_cell_empty:
    mov al, ' '
.ttt_cell_put:
    mov ah, 0x1F
    stosw
    mov al, ' '
    stosw
.ttt_cell_done_cur:
    pop edx
    pop ecx
    dec ecx
    jnz .ttt_content_cell
    mov al, '|'
    mov ah, 0x1F
    stosw
    inc ebx
    jmp .ttt_content_row
.ttt_content_done:
    mov edi, 0xB8000 + 12*80*2 + 20*2
    cmp byte [ttt_status], 0
    jne .ttt_status_msg
    cmp byte [ttt_mode], 1
    je .ttt_2p_mode
    cmp byte [ttt_turn], 0
    je .ttt_your_turn
    mov esi, ttt_str_ai_turn
    jmp .ttt_draw_status
.ttt_your_turn:
    mov esi, ttt_str_your_turn
    jmp .ttt_draw_status
.ttt_2p_mode:
    cmp byte [ttt_turn], 0
    je .ttt_p1_turn
    mov esi, ttt_str_p2_turn
    jmp .ttt_draw_status
.ttt_p1_turn:
    mov esi, ttt_str_p1_turn
    jmp .ttt_draw_status
.ttt_status_msg:
    cmp byte [ttt_status], 3
    je .ttt_draw_msg
    cmp byte [ttt_mode], 1
    je .ttt_2p_result
    cmp byte [ttt_status], 1
    je .ttt_win
    mov esi, ttt_str_lose
    jmp .ttt_draw_status
.ttt_win:
    mov esi, ttt_str_win
    jmp .ttt_draw_status
.ttt_2p_result:
    cmp byte [ttt_status], 1
    je .ttt_p1_win
    mov esi, ttt_str_p2_win
    jmp .ttt_draw_status
.ttt_p1_win:
    mov esi, ttt_str_p1_win
    jmp .ttt_draw_status
.ttt_draw_msg:
    mov esi, ttt_str_draw
.ttt_draw_status:
    mov ah, 0x1F
    call tui_put_str
    mov edi, 0xB8000 + 14*80*2 + 28*2
    mov esi, ttt_str_help
    mov ah, 0x1F
    call tui_put_str
    popa
    ret
ttt_game:
    pusha
    mov ecx, 9
    mov edi, ttt_board
    mov al, 0
    rep stosb
    mov byte [ttt_cursor], 4
    mov byte [ttt_turn], 0
    mov byte [ttt_status], 0
    call ttt_draw
.ttt_loop:
    cmp byte [ttt_status], 0
    jne .ttt_wait_end
    cmp byte [ttt_turn], 0
    je .ttt_wait_input
    cmp byte [ttt_mode], 1
    je .ttt_wait_input
    call ttt_ai
    call ttt_draw
    jmp .ttt_loop
.ttt_wait_input:
    mov eax, 10
    call pit_delay_ms
    call tui_poll_event
    cmp al, 0
    je .ttt_wait_input
    call ttt_handle
    call ttt_draw
    jmp .ttt_loop
.ttt_wait_end:
    mov eax, 10
    call pit_delay_ms
    call tui_poll_event
    cmp al, 0
    je .ttt_wait_end
    cmp al, 0x1C
    je .ttt_exit
    cmp al, 0x01
    je .ttt_exit
    jmp .ttt_wait_end
.ttt_exit:
    popa
    ret
ttt_handle:
    pusha
    cmp al, 0x48
    je .ttt_up
    cmp al, 0x50
    je .ttt_down
    cmp al, 0x4B
    je .ttt_left
    cmp al, 0x4D
    je .ttt_right
    cmp al, 0x1C
    je .ttt_place
    cmp al, 0x01
    je .ttt_quit
    jmp .ttt_h_done
.ttt_up:
    mov al, [ttt_cursor]
    sub al, 3
    jl .ttt_h_done
    mov [ttt_cursor], al
    jmp .ttt_h_done
.ttt_down:
    mov al, [ttt_cursor]
    add al, 3
    cmp al, 9
    jge .ttt_h_done
    mov [ttt_cursor], al
    jmp .ttt_h_done
.ttt_left:
    mov al, [ttt_cursor]
    dec al
    jl .ttt_h_done
    mov [ttt_cursor], al
    jmp .ttt_h_done
.ttt_right:
    mov al, [ttt_cursor]
    inc al
    cmp al, 9
    jge .ttt_h_done
    mov [ttt_cursor], al
    jmp .ttt_h_done
.ttt_place:
    movzx eax, byte [ttt_cursor]
    cmp byte [ttt_board + eax], 0
    jne .ttt_h_done
    cmp byte [ttt_turn], 0
    je .ttt_place_x
    mov byte [ttt_board + eax], 2
    call ttt_check_win
    cmp byte [ttt_status], 0
    jne .ttt_h_done
    mov byte [ttt_turn], 0
    jmp .ttt_h_done
.ttt_place_x:
    mov byte [ttt_board + eax], 1
    call ttt_check_win
    cmp byte [ttt_status], 0
    jne .ttt_h_done
    mov byte [ttt_turn], 1
.ttt_h_done:
    popa
    ret
.ttt_quit:
    mov byte [ttt_status], 3
    popa
    ret
ttt_ai:
    pusha
    call ttt_check_win
    cmp byte [ttt_status], 0
    jne .ttt_ai_done
    mov byte [ttt_ai_move], -1
    mov ecx, 0
.ttt_ai_loop:
    cmp ecx, 9
    jge .ttt_ai_found
    cmp byte [ttt_board + ecx], 0
    jne .ttt_ai_next
    mov byte [ttt_board + ecx], 2
    call ttt_check_win_internal
    cmp byte [ttt_status], 2
    je .ttt_ai_win_move
    mov byte [ttt_board + ecx], 0
.ttt_ai_next:
    inc ecx
    jmp .ttt_ai_loop
.ttt_ai_win_move:
    mov [ttt_ai_move], ecx
    mov byte [ttt_board + ecx], 0
    mov byte [ttt_status], 0
    jmp .ttt_ai_place
.ttt_ai_found:
    mov ecx, 0
.ttt_ai_block_loop:
    cmp ecx, 9
    jge .ttt_ai_random
    cmp byte [ttt_board + ecx], 0
    jne .ttt_ai_block_next
    mov byte [ttt_board + ecx], 1
    call ttt_check_win_internal
    cmp byte [ttt_status], 1
    je .ttt_ai_block_move
    mov byte [ttt_board + ecx], 0
.ttt_ai_block_next:
    inc ecx
    jmp .ttt_ai_block_loop
.ttt_ai_block_move:
    mov [ttt_ai_move], ecx
    mov byte [ttt_board + ecx], 0
    mov byte [ttt_status], 0
    jmp .ttt_ai_place
.ttt_ai_random:
    mov ecx, 4
.ttt_ai_rand_loop:
    cmp byte [ttt_board + ecx], 0
    je .ttt_ai_rand_found
    inc ecx
    cmp ecx, 9
    jl .ttt_ai_rand_loop
    mov ecx, 0
.ttt_ai_rand_loop2:
    cmp byte [ttt_board + ecx], 0
    je .ttt_ai_rand_found
    inc ecx
    jmp .ttt_ai_rand_loop2
.ttt_ai_rand_found:
    mov [ttt_ai_move], ecx
.ttt_ai_place:
    mov ecx, [ttt_ai_move]
    mov byte [ttt_board + ecx], 2
    call ttt_check_win
    cmp byte [ttt_status], 0
    jne .ttt_ai_done
    mov byte [ttt_turn], 0
.ttt_ai_done:
    popa
    ret
ttt_check_win:
    pusha
    call ttt_check_win_internal
    popa
    ret
ttt_check_win_internal:
    pusha
    mov byte [ttt_status], 0
    mov esi, ttt_win_lines
    mov ecx, 8
.ttt_win_loop:
    mov al, [esi]
    mov bl, [ttt_board + eax]
    cmp bl, 0
    je .ttt_win_next
    mov al, [esi + 1]
    cmp bl, [ttt_board + eax]
    jne .ttt_win_next
    mov al, [esi + 2]
    cmp bl, [ttt_board + eax]
    jne .ttt_win_next
    mov [ttt_status], bl
    jmp .ttt_win_done
.ttt_win_next:
    add esi, 3
    dec ecx
    jnz .ttt_win_loop
    mov ecx, 9
    mov al, 0
.ttt_draw_check:
    cmp byte [ttt_board + ecx - 1], 0
    je .ttt_win_done
    dec ecx
    jnz .ttt_draw_check
    mov byte [ttt_status], 3
.ttt_win_done:
    popa
    ret
notepad_app:
    jmp notepad_app_body
file_mgr_app:
    pusha
    call restore_current_drive_state
    mov byte [fm_exit], 0
    mov byte [fm_mode], 0
    mov dword [fm_selected], 0
    mov dword [fm_scroll], 0
    mov byte [fm_clipboard], 0
    cmp byte [current_path], 0
    jne .path_ok
    mov byte [current_path], 65
    mov byte [current_path + 1], 47
    mov byte [current_path + 2], 0
.path_ok:
.fm_loop:
    call fm_scan_dir
    call fm_draw
    call fm_handle
    cmp byte [fm_exit], 1
    je .fm_exit
    jmp .fm_loop
.fm_exit:
    popa
    ret

fm_scan_dir:
    pusha
    call read_dir_sector
    mov dword [fm_file_count], 0
    cmp dword [current_dir_cluster], 0
    je .no_dotdot
    mov edi, fm_entries
    mov byte [edi], '.'
    mov byte [edi + 1], '.'
    mov byte [edi + 2], ' '
    mov byte [edi + 3], ' '
    mov byte [edi + 4], ' '
    mov byte [edi + 5], ' '
    mov byte [edi + 6], ' '
    mov byte [edi + 7], ' '
    mov byte [edi + 8], ' '
    mov byte [edi + 9], ' '
    mov byte [edi + 10], ' '
    mov byte [edi + 11], 0x10
    mov dword [edi + 12], 0
    mov dword [edi + 16], 0
    mov dword [edi + 20], 0
    mov dword [edi + 24], 0
    mov dword [edi + 28], 0
    inc dword [fm_file_count]
.no_dotdot:
    mov ecx, [fat_root_entries]
    cmp dword [current_dir_cluster], 0
    jne .data_dir
    mov ecx, [fat_root_entries]
    jmp .scan
.data_dir:
    mov ecx, DIRS_PER_SECT
.scan:
    xor ebx, ebx
.scan_loop:
    cmp ebx, ecx
    jge .scan_done
    mov eax, ebx
    mov edx, BYTES_PER_DIR
    mul edx
    mov edi, dir_buffer
    add edi, eax
    cmp byte [edi], 0xE5
    je .scan_next
    cmp byte [edi], 0
    je .scan_done
    mov al, [edi + 11]
    test al, 0x08
    jnz .scan_next
    cmp byte [edi], '.'
    jne .not_dot
    cmp byte [edi + 1], '.'
    je .scan_next
    cmp byte [edi + 1], 0x20
    je .scan_next
.not_dot:
    mov edx, [fm_file_count]
    cmp dword [fm_file_count], 64
    jge .scan_done
    mov eax, edx
    mov esi, 32
    mul esi
    mov esi, edi
    mov edi, fm_entries
    add edi, eax
    push ecx
    mov ecx, 32
    cld
    rep movsb
    pop ecx
    cmp dword [fm_file_count], 64
    jge .scan_done
    inc dword [fm_file_count]
.scan_next:
    inc ebx
    jmp .scan_loop
.scan_done:
    mov eax, [fm_file_count]
    cmp [fm_selected], eax
    jl .clamp_ok
    mov dword [fm_selected], 0
    mov dword [fm_scroll], 0
.clamp_ok:
    popa
    ret

fm_draw:
    pusha
    mov edi, 0xB8000
    mov ecx, 80*25
    mov ax, 0x1F20
    rep stosw
    mov edi, 0xB8000
    mov esi, fm_str_title
    mov ah, 0x1F
    call tui_put_str
    mov edi, 0xB8000 + 1*80*2
    mov esi, current_path
    mov ah, 0x1F
    call tui_put_str
    mov edi, 0xB8000 + 2*80*2 + 1*2
    mov esi, fm_str_name
    mov ah, 0x3F
    call tui_put_str
    mov edi, 0xB8000 + 2*80*2 + 20*2
    mov esi, fm_str_type
    mov ah, 0x3F
    call tui_put_str
    mov edi, 0xB8000 + 2*80*2 + 30*2
    mov esi, fm_str_size
    mov ah, 0x3F
    call tui_put_str
    mov ecx, 18
    xor ebx, ebx
.list_row:
    mov eax, [fm_scroll]
    add eax, ebx
    cmp eax, [fm_file_count]
    jge .list_done
    mov edx, eax
    shl edx, 5
    mov esi, fm_entries
    add esi, edx
    mov edi, 0xB8000
    mov eax, ebx
    add eax, 3
    mov edx, 80*2
    mul edx
    add edi, eax
    mov eax, [fm_scroll]
    add eax, ebx
    cmp eax, [fm_selected]
    jne .normal_color
    mov ah, 0x70
    jmp .draw_entry
.normal_color:
    mov ah, 0x1F
.draw_entry:
    push ebx
    push ecx
    mov [fm_draw_color], ah
    push edi
    mov ecx, 8
    xor edx, edx
.name_loop:
    lodsb
    cmp al, ' '
    je .name_skip
    mov [edi], al
    mov ah, [fm_draw_color]
    mov [edi+1], ah
    add edi, 2
    inc edx
.name_skip:
    loop .name_loop
    mov al, [esi]
    cmp al, ' '
    je .no_ext
    mov al, '.'
    mov [edi], al
    mov ah, [fm_draw_color]
    mov [edi+1], ah
    add edi, 2
    inc edx
    mov ecx, 3
.ext_loop:
    lodsb
    cmp al, ' '
    je .ext_skip
    mov [edi], al
    mov ah, [fm_draw_color]
    mov [edi+1], ah
    add edi, 2
    inc edx
.ext_skip:
    loop .ext_loop
    jmp .name_pad
.no_ext:
    add esi, 3
.name_pad:
    mov al, 14
    sub al, dl
    jle .name_done
    movzx ecx, al
.pad_loop:
    mov al, ' '
    mov [edi], al
    mov ah, [fm_draw_color]
    mov [edi+1], ah
    add edi, 2
    loop .pad_loop
.name_done:
    pop edi
    add edi, 20*2
    mov ah, [fm_draw_color]
    mov al, [esi]
    test al, 0x10
    jz .is_file
    mov al, 'D'
    mov [edi], al
    mov [edi+1], ah
    add edi, 2
    mov al, 'I'
    mov [edi], al
    mov [edi+1], ah
    add edi, 2
    mov al, 'R'
    mov [edi], al
    mov [edi+1], ah
    jmp .type_done
.is_file:
    mov al, 'F'
    mov [edi], al
    mov [edi+1], ah
    add edi, 2
    mov al, 'I'
    mov [edi], al
    mov [edi+1], ah
    add edi, 2
    mov al, 'L'
    mov [edi], al
    mov [edi+1], ah
    add edi, 2
    mov al, 'E'
    mov [edi], al
    mov [edi+1], ah
.type_done:
    mov edi, 0xB8000
    mov eax, ebx
    add eax, 3
    mov edx, 80*2
    mul edx
    add edi, eax
    add edi, 30*2
    mov eax, [fm_scroll]
    add eax, ebx
    mov edx, eax
    shl edx, 5
    mov esi, fm_entries
    add esi, edx
    mov eax, [esi + 28]
    push edi
    mov edi, fm_tmp_str
    call int_to_string_fm
    pop edi
    push esi
    mov esi, fm_tmp_str
    call str_len
    pop esi
    mov ah, [fm_draw_color]
    mov ecx, 10
    sub ecx, eax
    jle .size_no_pad
.size_pad:
    mov al, ' '
    mov [edi], al
    mov [edi+1], ah
    add edi, 2
    loop .size_pad
.size_no_pad:
    mov esi, fm_tmp_str
.size_print:
    lodsb
    cmp al, 0
    je .size_done
    mov [edi], al
    mov [edi+1], ah
    add edi, 2
    jmp .size_print
.size_done:
    pop ecx
    pop ebx
.list_next:
    inc ebx
    dec ecx
    jnz .list_row
.list_done:
    mov edi, 0xB8000 + 22*80*2
    mov ecx, 80
    mov ax, 0x7020
    rep stosw
    mov edi, 0xB8000 + 22*80*2 + 1*2
    mov esi, fm_str_status
    mov ah, 0x70
    call tui_put_str
    mov eax, [fm_selected]
    cmp eax, [fm_file_count]
    jge .no_sel
    mov edx, eax
    shl edx, 5
    mov esi, fm_entries
    add esi, edx
    mov edi, 0xB8000 + 22*80*2 + 10*2
    mov ah, 0x70
    mov ecx, 8
.sel_name:
    lodsb
    cmp al, ' '
    je .sel_name_skip
    mov [edi], al
    mov [edi+1], ah
    add edi, 2
.sel_name_skip:
    loop .sel_name
.no_sel:
    mov edi, 0xB8000 + 23*80*2
    mov ecx, 80
    mov ax, 0x2F20
    rep stosw
    mov edi, 0xB8000 + 23*80*2 + 1*2
    mov esi, fm_str_keys1
    mov ah, 0x2F
    call tui_put_str
    mov edi, 0xB8000 + 24*80*2
    mov ecx, 80
    mov ax, 0x2F20
    rep stosw
    mov edi, 0xB8000 + 24*80*2 + 1*2
    mov esi, fm_str_keys2
    mov ah, 0x2F
    call tui_put_str
    cmp byte [fm_mode], 1
    jne .draw_done
    mov edi, 0xB8000 + 21*80*2
    mov ecx, 80
    mov ax, 0x4F20
    rep stosw
    mov edi, 0xB8000 + 21*80*2 + 1*2
    mov esi, fm_input_prompt
    mov ah, 0x4F
    call tui_put_str
    mov esi, fm_input_prompt
    call str_len
    mov edi, 0xB8000 + 21*80*2 + 1*2
    add edi, eax
    add edi, eax
    mov esi, fm_input_buf
    mov ah, 0x4F
    call tui_put_str
.draw_done:
    popa
    ret

fm_handle:
    pusha
    cmp byte [fm_mode], 1
    je .input_mode
    call read_scancode
    cmp al, 0x1D
    je .ctrl_down
    cmp al, 0x9D
    je .ctrl_up
    cmp al, 0x48
    je .key_up
    cmp al, 0x50
    je .key_down
    cmp al, 0x1C
    je .key_enter
    cmp al, 0x0E
    je .key_back
    cmp al, 0x01
    je .key_esc
    cmp al, 0x3B
    je .key_f1
    cmp al, 0x3C
    je .key_f2
    cmp al, 0x3D
    je .key_f3
    cmp al, 0x3E
    je .key_f4
    cmp al, 0x42
    je .key_f8
    cmp al, 0x44
    je .key_esc
    cmp al, 0x57
    je .key_f11
    cmp al, 0x58
    je .key_f12
    cmp al, 0x2E
    je .key_ctrl_c
    cmp al, 0x2F
    je .key_ctrl_v
    cmp al, 0x20
    je .key_ctrl_d
    cmp al, 0x13
    je .key_ctrl_r
    jmp .handle_done
.key_ctrl_c:
    cmp byte [fm_ctrl_pressed], 1
    jne .handle_done
    call fm_copy
    jmp .handle_done
.key_ctrl_v:
    cmp byte [fm_ctrl_pressed], 1
    jne .handle_done
    call fm_paste
    jmp .handle_done
.key_ctrl_d:
    cmp byte [fm_ctrl_pressed], 1
    jne .handle_done
    call fm_delete
    jmp .handle_done
.key_ctrl_r:
    cmp byte [fm_ctrl_pressed], 1
    jne .handle_done
    mov dword [fm_selected], 0
    mov dword [fm_scroll], 0
    jmp .handle_done
.ctrl_down:
    mov byte [fm_ctrl_pressed], 1
    jmp .handle_done
.ctrl_up:
    mov byte [fm_ctrl_pressed], 0
    jmp .handle_done
.key_up:
    cmp byte [fm_ctrl_pressed], 1
    je .key_ctrl_up
    cmp dword [fm_selected], 0
    je .handle_done
    dec dword [fm_selected]
    mov eax, [fm_selected]
    cmp eax, [fm_scroll]
    jge .handle_done
    dec dword [fm_scroll]
    jmp .handle_done
.key_ctrl_up:
    call fm_parent_dir
    jmp .handle_done
.key_down:
    mov eax, [fm_file_count]
    dec eax
    cmp [fm_selected], eax
    jge .handle_done
    inc dword [fm_selected]
    mov eax, [fm_selected]
    sub eax, [fm_scroll]
    cmp eax, 17
    jle .handle_done
    inc dword [fm_scroll]
    jmp .handle_done
.key_enter:
    call fm_enter_item
    jmp .handle_done
.key_back:
    call fm_parent_dir
    jmp .handle_done
.key_esc:
    mov byte [fm_exit], 1
    jmp .handle_done
.key_f1:
    call fm_help
    jmp .handle_done
.key_f2:
    call fm_rename
    jmp .handle_done
.key_f3:
    call fm_new_file
    jmp .handle_done
.key_f4:
    call fm_new_dir
    jmp .handle_done
.key_f8:
    call fm_view
    jmp .handle_done
.key_f11:
    call fm_select_disk
    jmp .handle_done
.key_f12:
    call fm_edit_file
    jmp .handle_done
.input_mode:
    call fm_input_handle
.handle_done:
    popa
    ret

fm_enter_item:
    pusha
    mov eax, [fm_selected]
    cmp eax, [fm_file_count]
    jge .enter_done
    mov edx, eax
    shl edx, 5
    mov esi, fm_entries
    add esi, edx
    mov al, [esi + 11]
    test al, 0x10
    jz .enter_file
    cmp byte [esi], '.'
    jne .enter_dir_normal
    cmp byte [esi + 1], '.'
    jne .enter_dir_normal
    call fm_parent_dir
    jmp .enter_done
.enter_dir_normal:
    mov eax, [current_dir_cluster]
    mov [fm_saved_parent_cluster], eax
    mov eax, [current_dir_sector]
    mov [fm_saved_parent_sector], eax
    movzx eax, word [esi + 26]
    mov [current_dir_cluster], eax
    cmp eax, 0
    je .enter_root_clust
    call cluster_to_lba
    jmp .enter_set_sec
.enter_root_clust:
    mov eax, [root_dir_start]
.enter_set_sec:
    mov [current_dir_sector], eax
    push esi
    mov esi, current_path
    call str_len
    mov edi, current_path
    add edi, eax
    cmp eax, 0
    je .add_slash
    mov al, [current_path + eax - 1]
    cmp al, '/'
    je .skip_slash
.add_slash:
    mov al, '/'
    stosb
.skip_slash:
    pop esi
    mov ecx, 8
.append_name:
    lodsb
    cmp al, ' '
    je .append_skip
    stosb
.append_skip:
    loop .append_name
    mov al, 0
    stosb
    mov dword [fm_selected], 0
    mov dword [fm_scroll], 0
    jmp .enter_done
.enter_file:
    call fm_view
.enter_done:
    popa
    ret

fm_parent_dir:
    pusha
    cmp dword [current_dir_cluster], 0
    je .parent_done
    call read_dir_sector
    movzx eax, word [dir_buffer + 32 + 26]
    mov [current_dir_cluster], eax
    cmp eax, 0
    je .parent_root
    call cluster_to_lba
    mov [current_dir_sector], eax
    jmp .parent_trim
.parent_root:
    mov eax, [root_dir_start]
    mov [current_dir_sector], eax
.parent_trim:
    mov esi, current_path
    call str_len
    mov edi, current_path
    add edi, eax
.trim_loop:
    cmp edi, current_path
    je .trim_done
    dec edi
    cmp byte [edi], '/'
    jne .trim_loop
    mov byte [edi], 0
.trim_done:
    mov dword [fm_selected], 0
    mov dword [fm_scroll], 0
.parent_done:
    popa
    ret

fm_new_file:
    pusha
    mov byte [fm_mode], 1
    mov byte [fm_input_type], 0
    mov byte [fm_input_buf], 0
    mov ecx, 32
    mov esi, fm_str_newfile
    mov edi, fm_input_prompt
    call str_copy
    popa
    ret

fm_new_dir:
    pusha
    mov byte [fm_mode], 1
    mov byte [fm_input_type], 1
    mov byte [fm_input_buf], 0
    mov ecx, 32
    mov esi, fm_str_newdir
    mov edi, fm_input_prompt
    call str_copy
    popa
    ret

fm_rename:
    pusha
    mov eax, [fm_selected]
    cmp eax, [fm_file_count]
    jge .rename_done
    mov byte [fm_mode], 1
    mov byte [fm_input_type], 2
    mov edx, eax
    shl edx, 5
    mov esi, fm_entries
    add esi, edx
    mov edi, fm_input_buf
    cld
    mov ecx, 8
.rename_copy:
    lodsb
    cmp al, ' '
    je .rename_skip
    stosb
.rename_skip:
    loop .rename_copy
    mov al, 0
    stosb
    mov ecx, 32
    mov esi, fm_str_rename
    mov edi, fm_input_prompt
    call str_copy
.rename_done:
    popa
    ret

fm_input_handle:
    pusha
    cld
    call read_scancode
    cmp al, 0x1C
    je .input_enter
    cmp al, 0x01
    je .input_cancel
    cmp al, 0x0E
    je .input_back
    cmp al, 0x2A
    je .input_shift_down
    cmp al, 0x36
    je .input_shift_down
    cmp al, 0xAA
    je .input_shift_up
    cmp al, 0xB6
    je .input_shift_up
    call scancode_to_ascii
    cmp al, 0
    je .input_done
    mov bl, al
    mov esi, fm_input_buf
    call str_len
    cmp eax, 12
    jge .input_done
    mov edi, fm_input_buf
    add edi, eax
    mov [edi], bl
    mov byte [edi + 1], 0
    jmp .input_done
.input_back:
    mov esi, fm_input_buf
    call str_len
    cmp eax, 0
    je .input_done
    mov byte [fm_input_buf + eax - 1], 0
    jmp .input_done
.input_shift_down:
    mov byte [shift_pressed], 1
    jmp .input_done
.input_shift_up:
    mov byte [shift_pressed], 0
    jmp .input_done
.input_cancel:
    mov byte [fm_mode], 0
    jmp .input_done
.input_enter:
    cmp byte [fm_input_buf], 0
    je .input_cancel
    cmp byte [fm_input_type], 0
    je .do_new_file
    cmp byte [fm_input_type], 1
    je .do_new_dir
    cmp byte [fm_input_type], 2
    je .do_rename
    jmp .input_cancel
.do_new_file:
    mov edi, fm_input_buf
    call write_file_empty
    mov byte [fm_mode], 0
    jmp .input_done
.do_new_dir:
    mov esi, fm_input_buf
    call create_directory
    mov byte [fm_mode], 0
    jmp .input_done
.do_rename:
    call fm_do_rename
    mov byte [fm_mode], 0
.input_done:
    popa
    ret

fm_copy:
    pusha
    mov eax, [fm_selected]
    cmp eax, [fm_file_count]
    jge .copy_done
    mov edx, eax
    shl edx, 5
    mov esi, fm_entries
    add esi, edx
    mov edi, fm_clipboard
    mov ecx, 32
    cld
    rep movsb
.copy_done:
    popa
    ret

fm_paste:
    pusha
    cmp byte [fm_clipboard], 0
    je .paste_done
    cmp byte [fm_clipboard], 0xE5
    je .paste_done
    mov dword [fm_paste_num], 0
.name_loop:
    mov esi, fm_clipboard
    mov edi, fm_tmp_name
    mov ecx, 11
    cld
    rep movsb
    mov byte [fm_tmp_name + 11], 0
    cmp dword [fm_paste_num], 0
    je .check_name
    mov eax, [fm_paste_num]
    mov edi, fm_paste_numstr
    call int_to_string_fm
    mov esi, fm_paste_numstr
    call str_len
    mov ecx, eax
    mov edi, fm_tmp_name + 7
    mov esi, fm_paste_numstr
    add esi, ecx
    dec esi
.insert_digit:
    cmp ecx, 0
    je .check_name
    mov al, [esi]
    mov [edi], al
    dec edi
    dec esi
    dec ecx
    jmp .insert_digit
.check_name:
    mov esi, fm_tmp_name
    call find_dir_entry
    cmp eax, -1
    je .name_found
    inc dword [fm_paste_num]
    cmp dword [fm_paste_num], 99
    jg .paste_done
    jmp .name_loop
.name_found:
    mov al, [fm_clipboard + 11]
    test al, 0x10
    jnz .do_dir
    mov esi, fm_clipboard
    mov edi, tmp_filename
    mov ecx, 11
    cld
    rep movsb
    mov byte [tmp_filename + 11], 0
    mov esi, tmp_filename
    call read_file_into_buf
    mov esi, fm_tmp_name
    mov edi, tmp_filename
    mov ecx, 11
    cld
    rep movsb
    mov byte [tmp_filename + 11], 0
    mov esi, tmp_filename
    call write_file_from_buf
    jmp .paste_done
.do_dir:
    mov esi, fm_tmp_name
    mov edi, tmp_filename
    mov ecx, 11
    cld
    rep movsb
    mov byte [tmp_filename + 11], 0
    mov esi, tmp_filename
    call create_directory
.paste_done:
    popa
    ret
fm_confirm_delete:
    pusha
    mov byte [fm_confirm_focus], 1
.cd_loop:
    call fm_confirm_draw
    call read_scancode
    cmp al, 0x0F
    je .cd_tab
    cmp al, 0x4B
    je .cd_left
    cmp al, 0x4D
    je .cd_right
    cmp al, 0x1C
    je .cd_enter
    cmp al, 0x01
    je .cd_no
    jmp .cd_loop
.cd_tab:
    xor byte [fm_confirm_focus], 1
    jmp .cd_loop
.cd_left:
    mov byte [fm_confirm_focus], 0
    jmp .cd_loop
.cd_right:
    mov byte [fm_confirm_focus], 1
    jmp .cd_loop
.cd_enter:
    cmp byte [fm_confirm_focus], 0
    je .cd_yes
    jmp .cd_no
.cd_yes:
    popa
    mov al, 1
    ret
.cd_no:
    popa
    mov al, 0
    ret
fm_confirm_draw:
    pusha
    mov edi, 0xB8000 + 9*80*2 + 12*2
    mov ecx, 56
    mov ax, 0x7020
    rep stosw
    mov edi, 0xB8000 + 10*80*2 + 12*2
    mov ecx, 56
    rep stosw
    mov edi, 0xB8000 + 11*80*2 + 12*2
    mov ecx, 56
    rep stosw
    mov edi, 0xB8000 + 12*80*2 + 12*2
    mov ecx, 56
    rep stosw
    mov edi, 0xB8000 + 13*80*2 + 12*2
    mov ecx, 56
    rep stosw
    mov edi, 0xB8000 + 10*80*2 + 18*2
    mov esi, fm_str_confirm_del
    mov ah, 0x70
    call tui_put_str
    mov edi, 0xB8000 + 12*80*2 + 20*2
    cmp byte [fm_confirm_focus], 0
    jne .cd_yes_nofocus
    mov esi, fm_str_yes_f
    mov ah, 0x3F
    jmp .cd_yes_draw
.cd_yes_nofocus:
    mov esi, fm_str_yes
    mov ah, 0x70
.cd_yes_draw:
    call tui_put_str
    mov edi, 0xB8000 + 12*80*2 + 38*2
    cmp byte [fm_confirm_focus], 1
    jne .cd_no_nofocus
    mov esi, fm_str_no_f
    mov ah, 0x3F
    jmp .cd_no_draw
.cd_no_nofocus:
    mov esi, fm_str_no
    mov ah, 0x70
.cd_no_draw:
    call tui_put_str
    popa
    ret
fm_delete:
    pusha
    mov eax, [fm_selected]
    cmp eax, [fm_file_count]
    jge .del_done
    call fm_confirm_delete
    cmp al, 1
    jne .del_done
    mov eax, [fm_selected]
    mov edx, eax
    shl edx, 5
    mov esi, fm_entries
    add esi, edx
    mov edi, tmp_filename
    push ecx
    mov ecx, 11
    cld
    rep movsb
    pop ecx
    mov byte [tmp_filename + 11], 0
    mov esi, tmp_filename
    call find_dir_entry
    cmp eax, -1
    je .del_done
    mov edi, dir_buffer
    add edi, eax
    movzx ebx, word [edi + 26]
.free_loop:
    cmp ebx, 0x0FF8
    jae .free_done
    cmp ebx, 2
    jb .free_done
    mov eax, ebx
    call get_next_cluster
    push eax
    mov eax, ebx
    mov ebx, 0
    call set_next_cluster
    pop ebx
    jmp .free_loop
.free_done:
    call write_fat
    mov byte [edi], 0xE5
    call write_dir_sector
.del_done:
    popa
    ret

fm_edit_file:
    pusha
    mov eax, [fm_selected]
    cmp eax, [fm_file_count]
    jge .edit_done
    mov edx, eax
    shl edx, 5
    mov esi, fm_entries
    add esi, edx
    mov al, [esi + 11]
    test al, 0x10
    jnz .edit_done
    mov edi, notepad_current_file
    mov ecx, 8
    cld
.copy_name:
    lodsb
    cmp al, ' '
    je .copy_name_done
    stosb
    loop .copy_name
.copy_name_done:
    mov al, '.'
    stosb
    mov ecx, 3
.copy_ext:
    lodsb
    cmp al, ' '
    je .copy_ext_done
    stosb
    loop .copy_ext
.copy_ext_done:
    mov byte [edi], 0
    mov esi, notepad_current_file
    mov edi, notepad_buf
    call notepad_read_file
    mov esi, notepad_buf
    call str_len
    mov [notepad_len], eax
    mov dword [notepad_cursor], 0
    mov byte [notepad_file_loaded], 1
    call notepad_app_body
    mov byte [notepad_file_loaded], 0
.edit_done:
    popa
    ret
fm_view:
    pusha
    mov eax, [fm_selected]
    cmp eax, [fm_file_count]
    jge .view_done
    mov edx, eax
    shl edx, 5
    mov esi, fm_entries
    add esi, edx
    mov al, [esi + 11]
    test al, 0x10
    jnz .view_done
    mov edi, tmp_filename
    push ecx
    mov ecx, 11
    cld
    rep movsb
    pop ecx
    mov esi, tmp_filename
    call read_file_into_buf
    call fm_viewer
.view_done:
    popa
    ret

fm_viewer:
    pusha
    mov byte [fm_view_exit], 0
    mov dword [fm_view_scroll], 0
.viewer_loop:
    call fm_viewer_draw
    call fm_viewer_handle
    cmp byte [fm_view_exit], 1
    je .viewer_exit
    jmp .viewer_loop
.viewer_exit:
    popa
    ret

fm_viewer_draw:
    pusha
    mov edi, 0xB8000
    mov ecx, 80*25
    mov ax, 0x1F20
    rep stosw
    mov edi, 0xB8000
    mov esi, fm_str_viewer
    mov ah, 0x1F
    call tui_put_str
    mov esi, fm_file_buf
    mov eax, [fm_view_scroll]
    mov ecx, eax
.skip_lines:
    cmp ecx, 0
    je .skip_done
    lodsb
    cmp al, 0
    je .skip_done
    cmp al, 0x0A
    je .skip_line
    jmp .skip_lines
.skip_line:
    dec ecx
    jmp .skip_lines
.skip_done:
    mov edi, 0xB8000 + 2*80*2
    mov ecx, 22
    mov ah, 0x1F
.viewer_line:
    push ecx
    mov ecx, 78
.viewer_char:
    lodsb
    cmp al, 0
    je .viewer_end
    cmp al, 0x0A
    je .viewer_newline
    cmp al, 0x0D
    je .viewer_char
    mov [edi], al
    mov [edi+1], ah
    add edi, 2
    loop .viewer_char
    jmp .viewer_nextline
.viewer_newline:
    mov eax, 78
    sub eax, ecx
    shl eax, 1
    add edi, eax
    jmp .viewer_nextline
.viewer_nextline:
    mov eax, 80
    sub eax, 78
    shl eax, 1
    add edi, eax
    pop ecx
    dec ecx
    jnz .viewer_line
    jmp .viewer_draw_done
.viewer_end:
    pop ecx
.viewer_draw_done:
    mov edi, 0xB8000 + 24*80*2
    mov ecx, 80
    mov ax, 0x7020
    rep stosw
    mov edi, 0xB8000 + 24*80*2 + 1*2
    mov esi, fm_str_viewer_hint
    mov ah, 0x70
    call tui_put_str
    popa
    ret

fm_viewer_handle:
    pusha
    call read_scancode
    cmp al, 0x01
    je .viewer_esc
    cmp al, 0x48
    je .viewer_up
    cmp al, 0x50
    je .viewer_down
    cmp al, 0x49
    je .viewer_pgup
    cmp al, 0x51
    je .viewer_pgdn
    jmp .viewer_handle_done
.viewer_esc:
    mov byte [fm_view_exit], 1
    jmp .viewer_handle_done
.viewer_up:
    cmp dword [fm_view_scroll], 0
    je .viewer_handle_done
    dec dword [fm_view_scroll]
    jmp .viewer_handle_done
.viewer_down:
    inc dword [fm_view_scroll]
    jmp .viewer_handle_done
.viewer_pgup:
    mov eax, [fm_view_scroll]
    sub eax, 10
    jge .viewer_set_scroll
    mov eax, 0
.viewer_set_scroll:
    mov [fm_view_scroll], eax
    jmp .viewer_handle_done
.viewer_pgdn:
    add dword [fm_view_scroll], 10
.viewer_handle_done:
    popa
    ret

fm_help:
    pusha
    mov byte [fm_help_exit], 0
.help_loop:
    call fm_help_draw
    call fm_help_handle
    cmp byte [fm_help_exit], 1
    je .help_exit
    jmp .help_loop
.help_exit:
    popa
    ret

fm_help_draw:
    pusha
    mov edi, 0xB8000
    mov ecx, 80*25
    mov ax, 0x1F20
    rep stosw
    mov edi, 0xB8000 + 320 + 50
    mov esi, fm_str_help_title
    mov ah, 0x3F
    call tui_put_str
    mov edi, 0xB8000 + 4*80*2 + 10*2
    mov esi, fm_str_help1
    mov ah, 0x1F
    call tui_put_str
    mov edi, 0xB8000 + 800 + 20
    mov esi, fm_str_help2
    call tui_put_str
    mov edi, 0xB8000 + 6*80*2 + 10*2
    mov esi, fm_str_help3
    call tui_put_str
    mov edi, 0xB8000 + 7*80*2 + 10*2
    mov esi, fm_str_help4
    call tui_put_str
    mov edi, 0xB8000 + 8*80*2 + 10*2
    mov esi, fm_str_help5
    call tui_put_str
    mov edi, 0xB8000 + 9*80*2 + 10*2
    mov esi, fm_str_help6
    call tui_put_str
    mov edi, 0xB8000 + 10*80*2 + 10*2
    mov esi, fm_str_help7
    call tui_put_str
    mov edi, 0xB8000 + 11*80*2 + 10*2
    mov esi, fm_str_help8
    call tui_put_str
    mov edi, 0xB8000 + 12*80*2 + 10*2
    mov esi, fm_str_help9
    call tui_put_str
    mov edi, 0xB8000 + 13*80*2 + 10*2
    mov esi, fm_str_help10
    call tui_put_str
    mov edi, 0xB8000 + 14*80*2 + 10*2
    mov esi, fm_str_help11
    call tui_put_str
    mov edi, 0xB8000 + 15*80*2 + 10*2
    mov esi, fm_str_help12
    call tui_put_str
    mov edi, 0xB8000 + 16*80*2 + 10*2
    mov esi, fm_str_help13
    call tui_put_str
    mov edi, 0xB8000 + 17*80*2 + 10*2
    mov esi, fm_str_help14
    call tui_put_str
    mov edi, 0xB8000 + 18*80*2 + 10*2
    mov esi, fm_str_help15
    call tui_put_str
    mov edi, 0xB8000 + 24*80*2 + 25*2
    mov esi, fm_str_help_exit
    mov ah, 0x70
    call tui_put_str
    popa
    ret

fm_help_handle:
    pusha
    call read_scancode
    cmp al, 0x01
    je .help_esc
    cmp al, 0x1C
    je .help_esc
    jmp .help_handle_done
.help_esc:
    mov byte [fm_help_exit], 1
.help_handle_done:
    popa
    ret

fm_select_disk:
    pusha
    mov byte [fm_disk_exit], 0
    mov byte [fm_disk_focus], 0
    call fm_collect_drives
.disk_loop:
    call fm_disk_draw
    call read_scancode
    cmp al, 0x48
    je .disk_up
    cmp al, 0x50
    je .disk_down
    cmp al, 0x1C
    je .disk_enter
    cmp al, 0x01
    je .disk_esc
    jmp .disk_loop
.disk_up:
    cmp byte [fm_disk_focus], 0
    je .disk_loop
    dec byte [fm_disk_focus]
    jmp .disk_loop
.disk_down:
    mov al, [fm_disk_focus]
    inc al
    cmp al, [fm_drive_count]
    jge .disk_loop
    inc byte [fm_disk_focus]
    jmp .disk_loop
.disk_enter:
    movzx eax, byte [fm_disk_focus]
    mov al, [fm_drive_list + eax]
    mov [current_drive], al
    movzx eax, byte [current_drive]
    shl eax, 4
    mov al, [drive_table + eax + 1]
    mov [current_path], al
    mov byte [current_path + 1], 47
    mov byte [current_path + 2], 0
    call restore_current_drive_state
    mov dword [current_dir_cluster], 0
    mov eax, [root_dir_start]
    mov [current_dir_sector], eax
    mov dword [fm_selected], 0
    mov dword [fm_scroll], 0
    mov byte [fm_disk_exit], 1
    jmp .disk_loop
.disk_esc:
    mov byte [fm_disk_exit], 1
.disk_loop_check:
    cmp byte [fm_disk_exit], 1
    je .disk_exit
    jmp .disk_loop
.disk_exit:
    popa
    ret
fm_collect_drives:
    pusha
    mov dword [fm_drive_count], 0
    mov ecx, MAX_DRIVES
    xor ebx, ebx
.cd_loop:
    cmp ebx, MAX_DRIVES
    jge .cd_done
    mov eax, ebx
    shl eax, 4
    cmp byte [drive_table + eax], 0
    je .cd_skip
    cmp byte [drive_table + eax + 2], 0xFF
    je .cd_skip
    mov edx, [fm_drive_count]
    mov [fm_drive_list + edx], bl
    inc dword [fm_drive_count]
.cd_skip:
    inc ebx
    jmp .cd_loop
.cd_done:
    popa
    ret
fm_disk_draw:
    pusha
    mov edi, 0xB8000
    mov ecx, 80*25
    mov ax, 0x1F20
    rep stosw
    mov edi, 0xB8000 + 2*80*2 + 28*2
    mov esi, fm_str_disk_title
    mov ah, 0x3F
    call tui_put_str
    mov ecx, [fm_drive_count]
    xor ebx, ebx
.dd_loop:
    cmp ebx, [fm_drive_count]
    jge .dd_done
    mov edi, 0xB8000
    mov eax, ebx
    add eax, 4
    mov edx, 80
    mul edx
    shl eax, 1
    add edi, eax
    add edi, 28*2
    movzx eax, byte [fm_drive_list + ebx]
    shl eax, 4
    mov dl, [drive_table + eax + 1]
    cmp bl, [fm_disk_focus]
    jne .dd_nofocus
    mov al, '>'
    mov ah, 0x3F
    stosw
    mov al, dl
    stosw
    mov al, ':'
    stosw
    mov al, ' '
    stosw
    mov al, '<'
    stosw
    jmp .dd_next
.dd_nofocus:
    mov al, ' '
    mov ah, 0x1F
    stosw
    mov al, dl
    stosw
    mov al, ':'
    stosw
    mov al, ' '
    stosw
    mov al, ' '
    stosw
.dd_next:
    inc ebx
    jmp .dd_loop
.dd_done:
    mov edi, 0xB8000 + 22*80*2 + 20*2
    mov esi, fm_str_disk_help
    mov ah, 0x1F
    call tui_put_str
    popa
    ret

fm_do_rename:
    pusha
    mov eax, [fm_selected]
    cmp eax, [fm_file_count]
    jge .rename_op_done
    mov edx, eax
    shl edx, 5
    mov esi, fm_entries
    add esi, edx
    push esi
    mov edi, tmp_filename
    push ecx
    mov ecx, 11
    cld
    rep movsb
    pop ecx
    pop esi
    mov edi, tmp_filename
    call find_dir_entry
    cmp eax, -1
    je .rename_op_done
    mov edi, dir_buffer
    add edi, eax
    push edi
    mov esi, fm_input_buf
    mov edi, tmp_filename
    call filename_to_83
    pop edi
    push edi
    mov esi, tmp_filename
    mov ecx, 11
    cld
    rep movsb
    pop edi
    call write_dir_sector
.rename_op_done:
    popa
    ret

write_file_empty:
    pusha
    push edi
    mov esi, edi
    mov edi, tmp_filename
    call filename_to_83
    pop esi
    mov esi, tmp_filename
    call find_dir_entry
    cmp eax, -1
    jne .empty_done
    call find_free_dir_entry
    cmp eax, -1
    je .empty_done
    mov edi, dir_buffer
    add edi, eax
    push esi
    mov esi, tmp_filename
    mov ecx, 11
    cld
    rep movsb
    pop esi
    mov byte [edi - 11 + 11], 0x20
    mov word [edi - 11 + 26], 0
    mov dword [edi - 11 + 28], 0
    call write_dir_sector
.empty_done:
    popa
    ret

read_file_into_buf:
    pusha
    mov byte [fm_file_buf], 0
    call find_dir_entry
    cmp eax, -1
    je .read_buf_done
    mov edi, dir_buffer
    add edi, eax
    movzx ebx, word [edi + 26]
    cmp ebx, 0
    je .read_buf_done
    mov eax, ebx
    call cluster_to_lba
    mov ecx, 1
    mov edi, fm_file_buf
    call ide_read_sectors
    mov byte [fm_file_buf + 512], 0
.read_buf_done:
    popa
    ret

write_file_from_buf:
    pusha
    call find_dir_entry
    cmp eax, -1
    jne .wfb_exists
    call find_free_cluster
    cmp eax, 0
    je .wfb_done
    mov ebx, eax
    push ebx
    mov eax, ebx
    mov ebx, 0x0FFF
    call set_next_cluster
    pop ebx
    call write_fat
    call find_free_dir_entry
    cmp eax, -1
    je .wfb_done
    mov edi, dir_buffer
    add edi, eax
    push esi
    mov esi, tmp_filename
    mov ecx, 11
    cld
    rep movsb
    pop esi
    mov byte [edi - 11 + 11], 0x20
    mov word [edi - 11 + 26], bx
    push esi
    mov esi, fm_file_buf
    call str_len
    mov [edi - 11 + 28], eax
    pop esi
    call write_dir_sector
    mov eax, ebx
    call cluster_to_lba
    mov ecx, 1
    mov esi, fm_file_buf
    call ide_write_sectors
    jmp .wfb_done
.wfb_exists:
    mov edi, dir_buffer
    add edi, eax
    movzx ebx, word [edi + 26]
    mov eax, ebx
    call cluster_to_lba
    mov ecx, 1
    mov esi, fm_file_buf
    call ide_write_sectors
    push esi
    mov esi, fm_file_buf
    call str_len
    mov [edi + 28], eax
    pop esi
    call write_dir_sector
.wfb_done:
    popa
    ret

int_to_string_fm:
    pusha
    mov ecx, 0
    cmp eax, 0
    jge .positive_fm
    mov byte [edi], '-'
    inc edi
    neg eax
.positive_fm:
    mov ebx, 10
.loop_fm:
    xor edx, edx
    div ebx
    add dl, '0'
    push dx
    inc ecx
    cmp eax, 0
    jne .loop_fm
.write_fm:
    pop dx
    mov al, dl
    stosb
    dec ecx
    jnz .write_fm
    mov byte [edi], 0
    popa
    ret

;=============================================================================
; Notepad Application - Text editor with undo/redo and file I/O
;=============================================================================

notepad_app_body:
    pusha
    call clear_screen
    mov dword [notepad_len], 0
    mov dword [notepad_cursor], 0
    mov dword [notepad_scroll], 0
    mov dword [notepad_undo_count], 0
    mov dword [notepad_redo_count], 0
    mov byte [notepad_buf], 0
    mov byte [notepad_exit], 0
    mov byte [ctrl_pressed], 0
    mov byte [shift_pressed], 0
.np_loop:
    call notepad_draw
    call notepad_handle
    cmp byte [notepad_exit], 1
    je .np_exit
    jmp .np_loop
.np_exit:
    call clear_screen
    popa
    ret
notepad_draw:
    pusha
    mov edi, 0xB8000
    mov ecx, 2000
    mov ax, 0x1F20
    rep stosw
    mov edi, 0xB8000
    mov ecx, 80
    mov ax, 0x1F20
    rep stosw
    mov edi, 0xB8000 + 2
    mov esi, notepad_str_title
    mov ah, 0x1F
    call tui_put_str
    mov esi, notepad_buf
    mov edi, 0xB8000 + 160
    xor ecx, ecx
    mov byte [np_row], 1
    mov byte [np_col], 0
.nd_loop:
    cmp ecx, [notepad_len]
    jge .nd_end
    cmp byte [np_row], 24
    jge .nd_end
    mov al, [esi + ecx]
    cmp al, 0x0D
    je .nd_skip
    cmp al, 0x0A
    je .nd_nl
    cmp byte [np_col], 79
    jge .nd_skip
    mov [edi], al
    mov byte [edi+1], 0x1F
    add edi, 2
    inc byte [np_col]
    jmp .nd_next
.nd_nl:
    inc byte [np_row]
    mov byte [np_col], 0
    movzx eax, byte [np_row]
    mov ebx, 160
    mul ebx
    mov edi, 0xB8000
    add edi, eax
.nd_skip:
.nd_next:
    inc ecx
    jmp .nd_loop
.nd_end:
    mov byte [np_cur_row], 1
    mov byte [np_cur_col], 0
    xor ecx, ecx
.nd_cur:
    cmp ecx, [notepad_cursor]
    jge .nd_cur_done
    mov al, [notepad_buf + ecx]
    cmp al, 0x0A
    je .nd_cur_nl
    cmp al, 0x0D
    je .nd_cur_skip
    inc byte [np_cur_col]
.nd_cur_skip:
    jmp .nd_cur_next
.nd_cur_nl:
    inc byte [np_cur_row]
    mov byte [np_cur_col], 0
.nd_cur_next:
    inc ecx
    jmp .nd_cur
.nd_cur_done:
    movzx eax, byte [np_cur_row]
    mov ebx, 80
    mul ebx
    movzx ebx, byte [np_cur_col]
    add eax, ebx
    mov [cursor_pos], eax
    call update_cursor
    mov edi, 0xB8000 + 24*160
    mov ecx, 80
    mov ax, 0x7020
    rep stosw
    mov edi, 0xB8000 + 24*160 + 2
    mov esi, notepad_str_help
    mov ah, 0x70
    call tui_put_str
    popa
    ret
notepad_handle:
    pusha
    call read_scancode
    cmp al, 0x1D
    je .nh_ctld
    cmp al, 0x9D
    je .nh_ctlu
    cmp al, 0x2A
    je .nh_shd
    cmp al, 0x36
    je .nh_shd
    cmp al, 0xAA
    je .nh_shu
    cmp al, 0xB6
    je .nh_shu
    cmp al, 0x01
    je .nh_esc
    cmp byte [ctrl_pressed], 1
    jne .nh_noctl
    cmp al, 0x1F
    je .nh_cs
    cmp al, 0x18
    je .nh_co
    cmp al, 0x2C
    je .nh_cz
    cmp al, 0x15
    je .nh_cy
    jmp .nh_done
.nh_noctl:
    cmp al, 0x1C
    je .nh_ent
    cmp al, 0x0E
    je .nh_bs
    cmp al, 0x4B
    je .nh_left
    cmp al, 0x4D
    je .nh_right
    cmp al, 0x48
    je .nh_up
    cmp al, 0x50
    je .nh_down
    test al, 0x80
    jnz .nh_done
    call scancode_to_ascii
    cmp al, 0
    je .nh_done
    cmp al, 0x20
    jb .nh_done
    cmp al, 0x7E
    ja .nh_done
    cmp byte [shift_pressed], 1
    jne .nh_ins
    cmp al, 'a'
    jl .nh_ins
    cmp al, 'z'
    jg .nh_ins
    sub al, 32
.nh_ins:
    call notepad_undo_push
    call notepad_insert_char
    jmp .nh_done
.nh_ctld:
    mov byte [ctrl_pressed], 1
    jmp .nh_done
.nh_ctlu:
    mov byte [ctrl_pressed], 0
    jmp .nh_done
.nh_shd:
    mov byte [shift_pressed], 1
    jmp .nh_done
.nh_shu:
    mov byte [shift_pressed], 0
    jmp .nh_done
.nh_esc:
    mov byte [notepad_exit], 1
    jmp .nh_done
.nh_ent:
    call notepad_undo_push
    mov al, 0x0A
    call notepad_insert_char
    jmp .nh_done
.nh_bs:
    cmp dword [notepad_cursor], 0
    je .nh_done
    call notepad_undo_push
    call notepad_delete_char
    jmp .nh_done
.nh_left:
    cmp dword [notepad_cursor], 0
    je .nh_done
    dec dword [notepad_cursor]
    jmp .nh_done
.nh_right:
    mov eax, [notepad_cursor]
    cmp eax, [notepad_len]
    jge .nh_done
    inc dword [notepad_cursor]
    jmp .nh_done
.nh_up:
    call notepad_cur_up
    jmp .nh_done
.nh_down:
    call notepad_cur_down
    jmp .nh_done
.nh_cs:
    call notepad_save_dialog
    jmp .nh_done
.nh_co:
    call notepad_open_dialog
    jmp .nh_done
.nh_cz:
    call notepad_undo
    jmp .nh_done
.nh_cy:
    call notepad_redo
    jmp .nh_done
.nh_done:
    popa
    ret
notepad_insert_char:
    pusha
    cmp dword [notepad_len], 2040
    jge .nic_done
    mov ebx, [notepad_cursor]
    mov esi, notepad_buf
    add esi, [notepad_len]
    mov edi, esi
    inc edi
    mov ecx, [notepad_len]
    sub ecx, ebx
    cmp ecx, 0
    jle .nic_ns
    std
    rep movsb
    cld
.nic_ns:
    mov byte [notepad_buf + ebx], al
    inc dword [notepad_len]
    inc dword [notepad_cursor]
.nic_done:
    popa
    ret
notepad_delete_char:
    pusha
    mov ebx, [notepad_cursor]
    dec ebx
    mov esi, notepad_buf
    add esi, ebx
    inc esi
    mov edi, esi
    dec edi
    mov ecx, [notepad_len]
    sub ecx, ebx
    cmp ecx, 0
    jle .ndc_ns
    cld
    rep movsb
.ndc_ns:
    dec dword [notepad_len]
    dec dword [notepad_cursor]
    mov ebx, [notepad_len]
    mov byte [notepad_buf + ebx], 0
    popa
    ret
notepad_cur_up:
    pusha
    mov eax, [notepad_cursor]
    cmp eax, 0
    je .ncu_done
    mov ebx, eax
.ncu_s1:
    cmp ebx, 0
    je .ncu_f1
    cmp byte [notepad_buf + ebx - 1], 0x0A
    je .ncu_f1
    dec ebx
    jmp .ncu_s1
.ncu_f1:
    cmp ebx, 0
    je .ncu_done
    mov edx, eax
    sub edx, ebx
    mov esi, ebx
    dec esi
.ncu_s2:
    cmp esi, 0
    je .ncu_f2
    cmp byte [notepad_buf + esi - 1], 0x0A
    je .ncu_f2
    dec esi
    jmp .ncu_s2
.ncu_f2:
    mov eax, esi
    add eax, edx
    cmp eax, ebx
    jl .ncu_set
    mov eax, ebx
    dec eax
.ncu_set:
    mov [notepad_cursor], eax
.ncu_done:
    popa
    ret
notepad_cur_down:
    pusha
    mov eax, [notepad_cursor]
    mov ecx, eax
.ncd_s:
    cmp ecx, [notepad_len]
    jge .ncd_done
    cmp byte [notepad_buf + ecx], 0x0A
    je .ncd_f
    inc ecx
    jmp .ncd_s
.ncd_f:
    mov ebx, ecx
    inc ebx
    mov edx, eax
    mov ecx, eax
.ncd_s2:
    cmp ecx, 0
    je .ncd_c
    cmp byte [notepad_buf + ecx - 1], 0x0A
    je .ncd_c
    dec ecx
    jmp .ncd_s2
.ncd_c:
    sub edx, ecx
    mov eax, ebx
    add eax, edx
    cmp eax, [notepad_len]
    jg .ncd_sl
    mov ecx, ebx
.ncd_chk:
    cmp ecx, eax
    jge .ncd_sc
    cmp byte [notepad_buf + ecx], 0x0A
    je .ncd_sh
    inc ecx
    jmp .ncd_chk
.ncd_sh:
    mov eax, ecx
.ncd_sc:
    mov [notepad_cursor], eax
    jmp .ncd_done
.ncd_sl:
    mov eax, [notepad_len]
    mov [notepad_cursor], eax
.ncd_done:
    popa
    ret
notepad_undo_push:
    pusha
    mov eax, [notepad_undo_count]
    cmp eax, 5
    jl .nup_ns
    mov esi, notepad_undo_stack + 2048
    mov edi, notepad_undo_stack
    mov ecx, 2048 * 4
    cld
    rep movsb
    dec dword [notepad_undo_count]
.nup_ns:
    mov eax, [notepad_undo_count]
    mov esi, notepad_buf
    mov edi, notepad_undo_stack
    mov ecx, 2048
    mul ecx
    add edi, eax
    mov ecx, 2048
    cld
    rep movsb
    inc dword [notepad_undo_count]
    mov dword [notepad_redo_count], 0
    popa
    ret
notepad_undo:
    pusha
    cmp dword [notepad_undo_count], 0
    je .nu_done
    dec dword [notepad_undo_count]
    mov eax, [notepad_undo_count]
    mov ebx, [notepad_redo_count]
    cmp ebx, 5
    jl .nu_rs
    mov esi, notepad_redo_stack + 2048
    mov edi, notepad_redo_stack
    mov ecx, 2048 * 4
    cld
    rep movsb
    dec dword [notepad_redo_count]
    mov ebx, [notepad_redo_count]
.nu_rs:
    mov eax, ebx
    mov esi, notepad_buf
    mov edi, notepad_redo_stack
    mov ecx, 2048
    mul ecx
    add edi, eax
    mov ecx, 2048
    cld
    rep movsb
    inc dword [notepad_redo_count]
    mov eax, [notepad_undo_count]
    mov esi, notepad_undo_stack
    mov edi, notepad_buf
    mov ecx, 2048
    mul ecx
    add esi, eax
    mov ecx, 2048
    cld
    rep movsb
    mov esi, notepad_buf
    call str_len
    mov [notepad_len], eax
    cmp eax, [notepad_cursor]
    jge .nu_done
    mov [notepad_cursor], eax
.nu_done:
    popa
    ret
notepad_redo:
    pusha
    cmp dword [notepad_redo_count], 0
    je .nr_done
    dec dword [notepad_redo_count]
    mov eax, [notepad_redo_count]
    mov ebx, [notepad_undo_count]
    cmp ebx, 5
    jl .nr_us
    mov esi, notepad_undo_stack + 2048
    mov edi, notepad_undo_stack
    mov ecx, 2048 * 4
    cld
    rep movsb
    dec dword [notepad_undo_count]
    mov ebx, [notepad_undo_count]
.nr_us:
    mov eax, ebx
    mov esi, notepad_buf
    mov edi, notepad_undo_stack
    mov ecx, 2048
    mul ecx
    add edi, eax
    mov ecx, 2048
    cld
    rep movsb
    inc dword [notepad_undo_count]
    mov eax, [notepad_redo_count]
    mov esi, notepad_redo_stack
    mov edi, notepad_buf
    mov ecx, 2048
    mul ecx
    add esi, eax
    mov ecx, 2048
    cld
    rep movsb
    mov esi, notepad_buf
    call str_len
    mov [notepad_len], eax
    cmp eax, [notepad_cursor]
    jge .nr_done
    mov [notepad_cursor], eax
.nr_done:
    popa
    ret

notepad_save_dialog:
    pusha
    mov byte [notepad_dlg_mode], 0
    call nfd_main
    cmp byte [nfd_result], 0
    je .nsd_cancel
    mov esi, notepad_buf
    call str_len
    mov [notepad_len], eax
    ; Copy the chosen filename/path with an explicit loop (str_copy relies on
    ; an indeterminate ecx here, so a manual copy is used instead)
    mov esi, nfd_filename
    mov edi, notepad_dlg_filename
.nsd_copy:
    mov al, [esi]
    mov [edi], al
    cmp al, 0
    je .nsd_copy_done
    inc esi
    inc edi
    jmp .nsd_copy
.nsd_copy_done:
    mov edi, notepad_dlg_filename
    call notepad_write_file
.nsd_cancel:
    popa
    ret
notepad_open_dialog:
    pusha
    mov byte [notepad_dlg_mode], 1
    call nfd_main
    cmp byte [nfd_result], 0
    je .nod_cancel
    mov esi, nfd_filename
    mov edi, notepad_dlg_filename
.nod_copy:
    mov al, [esi]
    mov [edi], al
    cmp al, 0
    je .nod_copy_done
    inc esi
    inc edi
    jmp .nod_copy
.nod_copy_done:
    mov esi, notepad_dlg_filename
    mov edi, notepad_buf
    call notepad_read_file
    mov esi, notepad_buf
    call str_len
    mov [notepad_len], eax
    mov [notepad_cursor], eax
.nod_cancel:
    popa
    ret
nfd_main:
    pusha
    mov byte [nfd_focus], 2
    mov byte [nfd_exit], 0
    mov byte [nfd_result], 0
    mov byte [nfd_drive_sel], 0
    mov dword [nfd_file_sel], 0
    mov byte [nfd_filename], 'u'
    mov byte [nfd_filename+1], 'n'
    mov byte [nfd_filename+2], 't'
    mov byte [nfd_filename+3], 'i'
    mov byte [nfd_filename+4], 't'
    mov byte [nfd_filename+5], 'l'
    mov byte [nfd_filename+6], 'e'
    mov byte [nfd_filename+7], 'd'
    mov byte [nfd_filename+8], '.'
    mov byte [nfd_filename+9], 't'
    mov byte [nfd_filename+10], 'x'
    mov byte [nfd_filename+11], 't'
    mov byte [nfd_filename+12], 0
    call nfd_init_drive
    call nfd_scan_dir
    call nfd_redraw
.nfd_loop:
    call read_scancode
    mov [nfd_last_key], al
    call nfd_process_key
    cmp byte [nfd_exit], 1
    je .nfd_done
    call nfd_redraw
    jmp .nfd_loop
.nfd_done:
    popa
    ret
nfd_init_drive:
    pusha
    mov byte [nfd_drive_sel], 0
.nid_loop:
    cmp byte [nfd_drive_sel], 4
    jge .nid_done
    movzx eax, byte [nfd_drive_sel]
    shl eax, 4
    cmp byte [drive_table + eax], 0
    je .nid_next
    mov al, [drive_table + eax + 1]
    cmp al, 'A'
    je .nid_next
    call switch_drive
    jmp .nid_done
.nid_next:
    inc byte [nfd_drive_sel]
    jmp .nid_loop
.nid_done:
    popa
    ret
nfd_scan_dir:
    pusha
    call read_dir_sector
    mov dword [nfd_file_count], 0
    mov dword [nfd_file_sel], 0
    cmp dword [current_dir_cluster], 0
    je .nsd_noparent
    mov dword [nfd_files], 0xFFFFFFFF
    inc dword [nfd_file_count]
.nsd_noparent:
    mov ecx, 224
    xor ebx, ebx
.nsd_loop:
    cmp ebx, ecx
    jge .nsd_done
    mov eax, ebx
    mov edx, 32
    mul edx
    mov edi, dir_buffer
    add edi, eax
    cmp byte [edi], 0xE5
    je .nsd_next
    cmp byte [edi], 0
    je .nsd_done
    mov al, [edi + 11]
    test al, 0x08
    jnz .nsd_next
    cmp byte [edi], '.'
    jne .nsd_notdot
    cmp byte [edi + 1], ' '
    je .nsd_next
.nsd_notdot:
    cmp dword [nfd_file_count], 40
    jge .nsd_done
    mov edx, [nfd_file_count]
    mov esi, nfd_files
    lea esi, [esi + edx*4]
    mov [esi], eax
    inc dword [nfd_file_count]
.nsd_next:
    inc ebx
    jmp .nsd_loop
.nsd_done:
    popa
    ret
nfd_redraw:
    pusha
    mov edi, 0xB8000
    mov ecx, 2000
    mov ax, 0x2F20
    rep stosw
    mov edi, 0xB8000 + 2*160 + 10
    mov ecx, 60
    mov ax, 0x1F20
    rep stosw
    mov edi, 0xB8000 + 2*160 + 14
    cmp byte [notepad_dlg_mode], 0
    je .nrd_save
    mov esi, dlg_str_open_title
    jmp .nrd_title
.nrd_save:
    mov esi, dlg_str_save_title
.nrd_title:
    mov ah, 0x1F
    call tui_put_str
    mov edi, 0xB8000 + 4*160 + 14
    mov esi, dlg_str_drives
    mov ah, 0x2F
    call tui_put_str
    xor ebx, ebx
    mov edx, 0
.nrd_drvloop:
    cmp ebx, 4
    jge .nrd_drvdone
    mov eax, ebx
    shl eax, 4
    cmp byte [drive_table + eax], 0
    je .nrd_drvnext
    mov al, [drive_table + eax + 1]
    cmp al, 'A'
    je .nrd_drvnext
    push ebx
    push edx
    mov edi, 0xB8000 + 4*160
    mov eax, edx
    mov ecx, 6
    mul ecx
    add edi, eax
    add edi, 26
    cmp byte [nfd_focus], 0
    jne .nrd_drvnf
    movzx ecx, byte [nfd_drive_sel]
    cmp ebx, ecx
    jne .nrd_drvnf
    mov ecx, 5
    mov ax, 0x7020
    rep stosw
    jmp .nrd_drvwrite
.nrd_drvnf:
    mov ecx, 5
    mov ax, 0x2F20
    rep stosw
.nrd_drvwrite:
    mov edi, 0xB8000 + 4*160
    mov eax, edx
    mov ecx, 6
    mul ecx
    add edi, eax
    add edi, 27
    mov eax, ebx
    shl eax, 4
    mov al, [drive_table + eax + 1]
    mov [edi], al
    mov byte [edi+1], 0x2F
    mov byte [edi+2], ':'
    mov byte [edi+3], 0x2F
    pop edx
    pop ebx
    inc edx
.nrd_drvnext:
    inc ebx
    jmp .nrd_drvloop
.nrd_drvdone:
    mov edi, 0xB8000 + 6*160 + 14
    mov esi, dlg_str_path
    mov ah, 0x2F
    call tui_put_str
    mov edi, 0xB8000 + 6*160 + 24
    mov esi, current_path
    mov ah, 0x2F
    call tui_put_str
    mov edi, 0xB8000 + 8*160 + 14
    mov esi, dlg_str_files
    mov ah, 0x2F
    call tui_put_str
    xor ebx, ebx
.nrd_flist:
    cmp ebx, [nfd_file_count]
    jge .nrd_fdone
    cmp ebx, 10
    jge .nrd_fdone
    mov edi, 0xB8000
    mov eax, ebx
    add eax, 9
    mov ecx, 160
    mul ecx
    add edi, eax
    add edi, 16
    cmp dword [nfd_file_sel], ebx
    jne .nrd_fnf
    cmp byte [nfd_focus], 1
    jne .nrd_fnf
    mov ecx, 48
    mov ax, 0x7020
    rep stosw
    jmp .nrd_fdraw
.nrd_fnf:
    mov ecx, 48
    mov ax, 0x2F20
    rep stosw
.nrd_fdraw:
    mov edi, 0xB8000
    mov eax, ebx
    add eax, 9
    mov ecx, 160
    mul ecx
    add edi, eax
    add edi, 18
    mov eax, ebx
    shl eax, 2
    mov esi, nfd_files
    add esi, eax
    mov eax, [esi]
    cmp eax, 0xFFFFFFFF
    jne .nrd_fnorm
    mov byte [edi], '.'
    mov byte [edi+1], 0x2F
    mov byte [edi+2], '.'
    mov byte [edi+3], 0x2F
    jmp .nrd_fentry
.nrd_fnorm:
    mov esi, dir_buffer
    add esi, eax
    mov ecx, 8
.nrd_fn:
    lodsb
    cmp al, ' '
    je .nrd_fns
    mov [edi], al
    mov byte [edi+1], 0x2F
    add edi, 2
.nrd_fns:
    loop .nrd_fn
    mov al, [esi + 8]
    cmp al, ' '
    je .nrd_fne
    mov byte [edi], '.'
    mov byte [edi+1], 0x2F
    add edi, 2
    lea esi, [esi + 8]
    mov ecx, 3
.nrd_fe:
    lodsb
    cmp al, ' '
    je .nrd_fes
    mov [edi], al
    mov byte [edi+1], 0x2F
    add edi, 2
.nrd_fes:
    loop .nrd_fe
.nrd_fne:
    mov al, [esi + 3]
    test al, 0x10
    jz .nrd_fentry
    mov byte [edi], '/'
    mov byte [edi+1], 0x2F
.nrd_fentry:
    inc ebx
    jmp .nrd_flist
.nrd_fdone:
    mov edi, 0xB8000 + 20*160 + 14
    mov esi, dlg_str_name
    mov ah, 0x2F
    call tui_put_str
    mov edi, 0xB8000 + 20*160 + 26
    mov ecx, 40
    mov ax, 0x7020
    rep stosw
    mov edi, 0xB8000 + 20*160 + 26
    mov esi, nfd_filename
    mov ah, 0x70
    call tui_put_str
    mov edi, 0xB8000 + 22*160 + 30
    cmp byte [notepad_dlg_mode], 0
    je .nrd_oksv
    mov esi, dlg_str_open
    jmp .nrd_okd
.nrd_oksv:
    mov esi, dlg_str_save
.nrd_okd:
    cmp byte [nfd_focus], 3
    jne .nrd_oknf
    mov ecx, 10
    mov ax, 0x7020
    rep stosw
    mov edi, 0xB8000 + 22*160 + 32
    mov ah, 0x70
    jmp .nrd_okdr
.nrd_oknf:
    mov ah, 0x2F
.nrd_okdr:
    call tui_put_str
    mov edi, 0xB8000 + 22*160 + 56
    mov esi, dlg_str_cancel
    cmp byte [nfd_focus], 4
    jne .nrd_cannf
    mov ecx, 10
    mov ax, 0x7020
    rep stosw
    mov edi, 0xB8000 + 22*160 + 58
    mov ah, 0x70
    jmp .nrd_candr
.nrd_cannf:
    mov ah, 0x2F
.nrd_candr:
    call tui_put_str
    popa
    ret
nfd_process_key:
    pusha
    mov al, [nfd_last_key]
    cmp al, 0x01
    je .npk_esc
    cmp al, 0x0F
    je .npk_tab
    cmp al, 0x1C
    je .npk_enter
    cmp al, 0x48
    je .npk_up
    cmp al, 0x50
    je .npk_down
    cmp byte [nfd_focus], 2
    jne .npk_done
    test al, 0x80
    jnz .npk_done
    cmp al, 0x0E
    je .npk_bs
    call scancode_to_ascii
    mov bl, al
    cmp bl, 0x20
    jb .npk_done
    cmp bl, 0x7E
    ja .npk_done
    mov esi, nfd_filename
    call str_len
    cmp eax, 28
    jge .npk_done
    mov byte [nfd_filename + eax], bl
    mov byte [nfd_filename + eax + 1], 0
    jmp .npk_done
.npk_bs:
    mov esi, nfd_filename
    call str_len
    cmp eax, 0
    je .npk_done
    mov byte [nfd_filename + eax - 1], 0
    jmp .npk_done
.npk_tab:
    inc byte [nfd_focus]
    cmp byte [nfd_focus], 5
    jne .npk_done
    mov byte [nfd_focus], 0
    jmp .npk_done
.npk_esc:
    mov byte [nfd_exit], 1
    jmp .npk_done
.npk_up:
    cmp byte [nfd_focus], 0
    je .npk_drvup
    cmp byte [nfd_focus], 1
    jne .npk_done
    cmp dword [nfd_file_sel], 0
    je .npk_done
    dec dword [nfd_file_sel]
    jmp .npk_done
.npk_drvup:
    cmp byte [nfd_drive_sel], 0
    je .npk_done
    dec byte [nfd_drive_sel]
    call nfd_switch_drive
    jmp .npk_done
.npk_down:
    cmp byte [nfd_focus], 0
    je .npk_drvdown
    cmp byte [nfd_focus], 1
    jne .npk_done
    mov eax, [nfd_file_sel]
    inc eax
    cmp eax, [nfd_file_count]
    jge .npk_done
    inc dword [nfd_file_sel]
    jmp .npk_done
.npk_drvdown:
    cmp byte [nfd_drive_sel], 3
    je .npk_done
    inc byte [nfd_drive_sel]
    call nfd_switch_drive
    jmp .npk_done
.npk_enter:
    mov al, [nfd_focus]
    cmp al, 0
    je .npk_edrv
    cmp al, 1
    je .npk_elist
    cmp al, 2
    je .npk_ename
    cmp al, 3
    je .npk_eok
    cmp al, 4
    je .npk_ecancel
    jmp .npk_done
.npk_edrv:
    movzx eax, byte [nfd_drive_sel]
    shl eax, 4
    cmp byte [drive_table + eax], 0
    je .npk_done
    mov al, [drive_table + eax + 1]
    cmp al, 'A'
    je .npk_done
    call switch_drive
    call nfd_scan_dir
    jmp .npk_done
.npk_elist:
    mov eax, [nfd_file_sel]
    cmp eax, [nfd_file_count]
    jge .npk_done
    mov edx, 4
    mul edx
    mov esi, nfd_files
    add esi, eax
    mov eax, [esi]
    cmp eax, 0xFFFFFFFF
    jne .npk_enp
    call fm_parent_dir
    call nfd_scan_dir
    jmp .npk_done
.npk_enp:
    mov esi, dir_buffer
    add esi, eax
    mov al, [esi + 11]
    test al, 0x10
    jnz .npk_edir
    mov edi, nfd_filename
    mov ecx, 8
.npk_cpn:
    lodsb
    cmp al, ' '
    je .npk_cps
    stosb
.npk_cps:
    loop .npk_cpn
    mov al, [esi]
    cmp al, ' '
    je .npk_cpne
    mov al, '.'
    stosb
    mov ecx, 3
.npk_cpe:
    lodsb
    cmp al, ' '
    je .npk_cpes
    stosb
.npk_cpes:
    loop .npk_cpe
.npk_cpne:
    mov byte [edi], 0
    jmp .npk_done
.npk_edir:
    mov edi, nfd_tmpname
    mov ecx, 8
.npk_cpd:
    lodsb
    cmp al, ' '
    je .npk_cpds
    stosb
.npk_cpds:
    loop .npk_cpd
    mov byte [edi], 0
    mov esi, nfd_tmpname
    call cd_directory
    call nfd_scan_dir
    jmp .npk_done
.npk_ename:
    mov byte [nfd_focus], 3
    jmp .npk_done
.npk_eok:
    cmp byte [nfd_filename], 0
    je .npk_done
    mov byte [nfd_result], 1
    mov byte [nfd_exit], 1
    jmp .npk_done
.npk_ecancel:
    mov byte [nfd_exit], 1
    jmp .npk_done
.npk_done:
    popa
    ret
nfd_switch_drive:
    ; Switch to the drive selected in nfd_drive_sel
    pusha
    movzx eax, byte [nfd_drive_sel]
    shl eax, 4
    cmp byte [drive_table + eax], 0
    je .nsd_done
    mov al, [drive_table + eax + 1]
    cmp al, 'A'
    je .nsd_done
    call switch_drive
    call nfd_scan_dir
.nsd_done:
    popa
    ret
nfd_focus          db 0
nfd_exit           db 0
nfd_result         db 0
nfd_drive_sel      db 0
nfd_file_sel       dd 0
nfd_file_count     dd 0
nfd_files          times 160 dd 0
nfd_filename       times 32 db 0
nfd_tmpname        times 16 db 0
nfd_last_key       db 0

notepad_collect_dir:
    pusha
    call read_dir_sector
    mov dword [notepad_dir_count], 0
    mov dword [notepad_dir_sel], 0
    cmp dword [current_dir_cluster], 0
    je .ncd_np
    mov dword [notepad_dir_entries], 0xFFFFFFFF
    inc dword [notepad_dir_count]
.ncd_np:
    mov ecx, 224
    xor ebx, ebx
.ncd_loop:
    cmp ebx, ecx
    jge .ncd_done
    mov eax, ebx
    mov edx, 32
    mul edx
    mov edi, dir_buffer
    add edi, eax
    cmp byte [edi], 0xE5
    je .ncd_next
    cmp byte [edi], 0
    je .ncd_done
    mov al, [edi + 11]
    test al, 0x08
    jnz .ncd_next
    cmp byte [edi], '.'
    jne .ncd_nd
    cmp byte [edi + 1], ' '
    je .ncd_next
    cmp byte [edi + 1], '.'
    je .ncd_next
.ncd_nd:
    cmp dword [notepad_dir_count], 32
    jge .ncd_done
    mov edx, [notepad_dir_count]
    mov esi, notepad_dir_entries
    add esi, edx
    add esi, edx
    add esi, edx
    add esi, edx
    mov [esi], eax
    inc dword [notepad_dir_count]
.ncd_next:
    inc ebx
    jmp .ncd_loop
.ncd_done:
    popa
    ret

notepad_read_file:
    pusha
    push edi
    mov edi, tmp_filename
    call filename_to_83
    mov esi, tmp_filename
    call find_dir_entry
    cmp eax, -1
    je .not_found
    mov edi, dir_buffer
    add edi, eax
    mov al, [edi + 11]
    test al, 0x10
    jnz .not_found
    movzx eax, word [edi + 26]
    pop edi
    push edi
    mov ecx, 0
.read_loop:
    cmp eax, 0x0FF8
    jae .read_done
    cmp eax, 2
    jb .read_done
    push eax
    push ecx
    call cluster_to_lba
    mov ecx, 1
    mov edi, sector_buffer
    call ide_read_sectors
    pop ecx
    pop eax
    mov esi, sector_buffer
    mov ebx, 0
.copy_sector:
    cmp ebx, 512
    jge .next_cluster
    mov al, [esi + ebx]
    cmp al, 0
    je .next_cluster
    pop edi
    mov [edi + ecx], al
    push edi
    inc ecx
    inc ebx
    jmp .copy_sector
.next_cluster:
    call get_next_cluster
    jmp .read_loop
.read_done:
    pop edi
    mov byte [edi + ecx], 0
    jmp .done
.not_found:
    pop edi
.done:
    popa
    ret
notepad_ensure_path:
    ; Input: esi = path string (e.g. "subdir/file.txt" or just "file.txt")
    ; Ensures every directory in the path exists (creating missing ones),
    ; navigates current_dir to the target directory, and stores the pointer
    ; to the final name component in nw_filename_ptr.
    pusha
    mov [nw_filename_ptr], esi
.seg_loop:
    mov edi, esi
.scan:
    mov al, [edi]
    cmp al, 0
    je .last_comp
    cmp al, '/'
    je .dir_comp
    inc edi
    jmp .scan
.dir_comp:
    ; Copy the directory component [esi..edi) into tmp_component (max 12)
    push esi
    push edi
    mov ecx, edi
    sub ecx, esi
    cmp ecx, 12
    jle .seg_len_ok
    mov ecx, 12
.seg_len_ok:
    mov edi, tmp_component
    cld
    rep movsb
    mov byte [edi], 0
    pop edi
    pop esi
    ; edi now points at the '/' separator
    push edi
    ; Ensure the directory exists (look it up as 8.3, create if missing)
    call read_dir_sector
    mov esi, tmp_component
    mov edi, tmp_filename
    call filename_to_83
    mov esi, tmp_filename
    call find_dir_entry
    cmp eax, -1
    jne .dir_ok
    mov esi, tmp_component
    call create_directory
.dir_ok:
    mov esi, tmp_component
    call cd_directory
    pop edi
    ; Advance past the '/' and continue with the next component
    inc edi
    mov esi, edi
    mov [nw_filename_ptr], esi
    jmp .seg_loop
.last_comp:
    mov [nw_filename_ptr], esi
    popa
    ret
notepad_write_file:
    ; Save notepad buffer to file
    ; Input: edi = pointer to filename/path string
    ; Missing subdirectories in the path are created automatically.
    pusha
    ; Navigate/auto-create any directories in the target path
    mov esi, edi
    call notepad_ensure_path
    call read_dir_sector          ; load the target directory into dir_buffer
    mov edi, [nw_filename_ptr]    ; edi = final file name component
    mov [nw_dir_offset], dword -1
    ; Convert filename to 8.3 format
    push edi
    mov esi, edi
    mov edi, tmp_filename
    call filename_to_83
    pop edi
    ; Check if file already exists
    mov esi, tmp_filename
    call find_dir_entry
    mov [nw_dir_offset], eax
    cmp eax, -1
    je .alloc_clusters
    ; File exists - free old clusters
    mov edi, dir_buffer
    add edi, eax
    movzx ebx, word [edi + 26]
.free_old:
    cmp ebx, 0
    je .free_old_done
    cmp ebx, 2
    jb .free_old_done
    cmp ebx, 0xFF8
    jae .free_old_done
    mov eax, ebx
    call get_next_cluster
    push eax
    mov eax, ebx
    mov ebx, 0
    call set_next_cluster
    pop ebx
    jmp .free_old
.free_old_done:
    call write_fat
.alloc_clusters:
    mov dword [nw_first_cluster], 0
    mov dword [nw_prev_cluster], 0
    mov dword [nw_bytes_written], 0
    ; Check if there's data to write
    mov eax, [notepad_len]
    cmp eax, 0
    je .write_dir_entry
.alloc_loop:
    mov eax, [nw_bytes_written]
    cmp eax, [notepad_len]
    jge .alloc_done
    call find_free_cluster
    cmp eax, 0
    je .alloc_done
    mov ebx, eax
    cmp dword [nw_first_cluster], 0
    jne .not_first
    mov [nw_first_cluster], eax
.not_first:
    cmp dword [nw_prev_cluster], 0
    je .no_link
    push eax
    mov eax, [nw_prev_cluster]
    mov ebx, [esp]
    call set_next_cluster
    pop eax
.no_link:
    mov [nw_prev_cluster], eax
    push eax
    mov eax, ebx
    mov ebx, 0x0FFF
    call set_next_cluster
    pop eax
    call cluster_to_lba
    mov [nw_cur_lba], eax
    ; Clear sector buffer
    mov edi, sector_buffer
    mov ecx, 512
    mov al, 0
    rep stosb
    ; Copy data from notepad buffer to sector buffer
    mov esi, notepad_buf
    add esi, [nw_bytes_written]
    mov edi, sector_buffer
    mov ecx, [notepad_len]
    sub ecx, [nw_bytes_written]
    cmp ecx, 512
    jle .copy_partial
    mov ecx, 512
.copy_partial:
    cmp ecx, 0
    jle .skip_copy
    cld
    rep movsb
.skip_copy:
    ; Write sector to disk
    mov eax, [nw_cur_lba]
    mov ecx, 1
    mov esi, sector_buffer
    call ide_write_sectors
    add dword [nw_bytes_written], 512
    jmp .alloc_loop
.alloc_done:
    call write_fat
.write_dir_entry:
    ; Create or update directory entry
    cmp dword [nw_dir_offset], -1
    jne .update_entry
    call find_free_dir_entry
    cmp eax, -1
    je .write_done
    mov [nw_dir_offset], eax
    mov edi, dir_buffer
    add edi, eax
    mov esi, tmp_filename
    mov ecx, 11
    cld
    rep movsb
    jmp .set_entry
.update_entry:
    mov edi, dir_buffer
    add edi, [nw_dir_offset]
.set_entry:
    mov byte [edi + 11], 0x20     ; regular file archive attribute
    movzx eax, word [nw_first_cluster]
    mov word [edi + 26], ax
    mov eax, [notepad_len]
    mov dword [edi + 28], eax
    call write_dir_sector
.write_done:
    popa
    ret
nw_first_cluster   dd 0
nw_prev_cluster    dd 0
nw_bytes_written   dd 0
nw_cur_lba         dd 0
nw_dir_offset      dd 0
nw_filename_ptr    dd 0
tui_put_str:
    pusha
.loop:
    lodsb
    cmp al, 0
    je .done
    mov [edi], al
    mov [edi+1], ah
    add edi, 2
    jmp .loop
.done:
    popa
    ret
print_dec:
    pusha
    mov ebx, 10
    mov ecx, 0
    cmp eax, 0
    jne .pd_loop
    mov byte [edi], '0'
    mov byte [edi+1], 0x0F
    add edi, 2
    jmp .pd_done
.pd_loop:
    xor edx, edx
    div ebx
    add dl, '0'
    push dx
    inc ecx
    cmp eax, 0
    jne .pd_loop
.pd_write:
    pop dx
    mov [edi], dl
    mov byte [edi+1], 0x0F
    add edi, 2
    dec ecx
    jnz .pd_write
.pd_done:
    popa
    ret
tui_draw_datetime:
    pusha
    push edi
    cmp byte [tui_time_calibrated], 0
    je .init_cal
    jmp .disp
.init_cal:
    call tui_calibrate_rtc
    call tui_read_date
    mov byte [tui_time_calibrated], 1
.disp:
    pop edi
    mov al, [tui_calc_hour]
    call tui_put_bcd
    mov al, ':'
    stosw
    mov al, [tui_calc_min]
    call tui_put_bcd
    mov al, ':'
    stosw
    mov al, [tui_calc_sec]
    call tui_put_bcd
    mov al, ' '
    stosw
    mov al, '2'
    stosw
    mov al, '0'
    stosw
    mov al, [tui_calc_year]
    call tui_put_bcd
    mov al, '-'
    stosw
    mov al, [tui_calc_mon]
    call tui_put_bcd
    mov al, '-'
    stosw
    mov al, [tui_calc_day]
    call tui_put_bcd
    popa
    ret
tui_calibrate_rtc:
    pusha
.wait_uip:
    mov al, 0x0A
    out 0x70, al
    in al, 0x71
    test al, 0x80
    jnz .wait_uip
    mov al, 0x04
    out 0x70, al
    in al, 0x71
    mov [tui_calc_hour], al
    mov al, 0x02
    out 0x70, al
    in al, 0x71
    mov [tui_calc_min], al
    mov al, 0x00
    out 0x70, al
    in al, 0x71
    mov [tui_calc_sec], al
    popa
    ret
tui_read_date:
    pusha
.wait_uip2:
    mov al, 0x0A
    out 0x70, al
    in al, 0x71
    test al, 0x80
    jnz .wait_uip2
    mov al, 0x07
    out 0x70, al
    in al, 0x71
    mov [tui_calc_day], al
    mov al, 0x08
    out 0x70, al
    in al, 0x71
    mov [tui_calc_mon], al
    mov al, 0x09
    out 0x70, al
    in al, 0x71
    mov [tui_calc_year], al
    popa
    ret
tui_put_bcd:
    push eax
    push ebx
    mov bl, al
    shr al, 4
    add al, '0'
    stosw
    mov al, bl
    and al, 0x0F
    add al, '0'
    stosw
    pop ebx
    pop eax
    ret
tui_str_menu      db '[ Back To CLI ]',0
tui_str_menu_f    db '> Back To CLI <',0
tui_str_calc      db '[ Calculator ]',0
tui_str_calc_f    db '> Calculator <',0
tui_str_calendar  db '[ Calendar ]',0
tui_str_calendar_f db '> Calendar <',0
tui_str_settings  db '[ Settings ]',0
tui_str_settings_f db '> Settings <',0
tui_str_filemgr      db '[ File Mgr ]',0
tui_str_filemgr_f   db '> File Mgr <',0
tui_str_notepad   db '[ Notepad ]',0
tui_str_notepad_f db '> Notepad <',0
tui_str_game      db '[ Game ]',0
tui_str_game_f    db '> Game <',0
tui_str_reboot    db '[ Reboot ]',0
tui_str_reboot_f  db '> Reboot <',0
tui_str_shutdown  db '[ Shutdown ]',0
tui_str_shutdown_f db '> Shutdown <',0
tui_str_ttt       db '[ Tic-Tac-Toe ]',0
tui_str_ttt_f     db '> Tic-Tac-Toe <',0
tui_str_game_menu db 'Game Menu',0
tui_focus         db 0
tui_exit          db 0
tui_time_calibrated db 0
tui_calc_sec      db 0
tui_calc_min      db 0
tui_calc_hour     db 0
tui_calc_day      db 0
tui_calc_mon      db 0
tui_calc_year     db 0
tui_pit_ticks     dd 0
tui_last_sec      db 0
game_menu_focus    db 0
game_menu_exit     db 0
guess_target       dd 0
guess_count        dd 0
guess_input        times 8 db 0
guess_input_len    db 0
guess_exit         db 0
guess_difficulty   db 0
guess_max          dd 0
guess_tries        dd 0
guess_result       db 0
pd_result          dd 0
calc_num1          dd 0
calc_num2          dd 0
calc_result        dd 0
calc_op            db 0
calc_state         db 0
calc_focus         db 0
calc_exit          db 0
cal_month          dd 0
cal_year           dd 0
cal_first_day      dd 0
cal_days           dd 0
cal_exit           db 0
cal_tmp            times 16 db 0
cal_tmp_year       dd 0
cal_tmp_month      dd 0
cal_tmp_century    dd 0
cal_tmp_year2      dd 0
cal_result_day     dd 0
cal_days_result    dd 0
ttt_board          db 0,0,0,0,0,0,0,0,0
ttt_cursor         db 4
ttt_turn           db 0
ttt_status         db 0
ttt_ai_move        dd 0
ttt_win_lines      db 0,1,2, 3,4,5, 6,7,8, 0,3,6, 1,4,7, 2,5,8, 0,4,8, 2,4,6
gm_str_back        db '[ Back ]',0
gm_str_back_f      db '> Back <',0
gm_str_guess       db '[ Guess Number ]',0
gm_str_guess_f     db '> Guess Number <',0
guess_str_title    db '=== NUMBER GUESSING GAME ===',0
guess_str_sel_diff db 'Select difficulty:',0
guess_str_easy     db '1. Easy   - 10 tries, 0-50',0
guess_str_normal   db '2. Normal - 6 tries, 0-200',0
guess_str_hard     db '3. Hard   - 3 tries, 0-500',0
guess_str_press_num db 'Press 1, 2 or 3 to select, ESC to quit',0
guess_str_press_enter db 'Up/Down:Select  Enter:OK  Esc:Exit',0
guess_str_easy_f    db '> Easy (10 tries, 0-50) <',0
guess_str_normal_f  db '> Normal (6 tries, 0-200) <',0
guess_str_hard_f    db '> Hard (3 tries, 0-500) <',0
guess_str_range2   db 'Range: ',0
guess_str_tries    db 'Tries left: ',0
guess_str_prompt   db 'Your guess: ',0
guess_str_high     db 'Too high!',0
guess_str_low      db 'Too low!',0
guess_str_win      db 'Correct! You got it!',0
guess_str_guesses  db 'Guesses used: ',0
guess_str_guesses2 db 'Guesses used: ',0
guess_str_gameover db 'Game Over! Out of tries.',0
guess_str_answer   db 'The answer was: ',0
guess_str_press    db 'Press any key to continue',0
guess_str_help     db 'Type number + Enter to guess, ESC to quit',0
calc_str_title     db '=== CALCULATOR ===',0
calc_display       times 32 db 0
calc_decimal       db 0
calc_frac_digits   db 0
calc_btn_chars     db 'C','X',0,'/','7','8','9','*','4','5','6','-','1','2','3','+',0,'0','.','='
settings_focus     db 0
settings_exit      db 0
settings_str_title db 'Settings - yOS',0
settings_str_time  db '[ Calibrate Time ]',0
settings_str_disk  db '[ Disk Mgr ]',0
settings_str_dev   db '[ Dev Mgr ]',0
settings_str_back  db '[ Back ]',0
settings_str_help  db 'Up/Down:Select  Enter:OK  Esc:Exit',0
dm_str_title       db 'Disk Management - yOS',0
dm_str_disk        db 'Physical Disks',0
dm_str_part        db 'Partitions',0
dm_str_drv         db 'Drive',0
dm_str_part_lbl    db 'Partition ',0
dm_str_free        db 'Free Space: Available',0
dm_str_help        db 'Left/Right:Switch  Up/Down:Select  Enter:Action  Esc:Exit',0
dm_str_act_title   db 'Partition Actions',0
dm_str_act_del     db '[ Delete Partition ]',0
dm_str_act_new     db '[ New Partition ]',0
dm_str_act_fmt     db '[ Format ]',0
dm_str_act_back    db '[ Back ]',0
dev_str_title      db 'Device Manager - yOS',0
dev_str_cpu        db 'Processor (CPU)',0
dev_str_mem        db 'Memory: Base ',0
dev_str_kbd        db 'Keyboard Controller (PS/2)',0
dev_str_vga        db 'Display Adapter (VGA)',0
dev_str_fdc        db 'Floppy Disk Controller',0
dev_str_ata        db 'ATA/IDE Controller: ',0
dev_str_rtc        db 'Real Time Clock (RTC)',0
dev_str_pit        db 'Programmable Interval Timer',0
dev_str_help       db 'Enter/Esc:Exit',0
dev_str_present    db '[ Present ]',0
dev_str_kb         db 'KB',0
dev_str_drv        db 'drives',0

dev_count          db 0
dev_mem_base       dd 0
dev_mem_ext        dd 0
dev_cpu_count      db 0
dev_disk_count     db 0
dev_exit           db 0
settings_str_done  db 'Time Calibrated!',0
cal_str_weekdays   db 'Sun     Mon     Tue     Wed     Thu     Fri     Sat',0
cal_str_help       db 'Left/Right to change month, ESC to exit',0
cal_month_names    db 'January   ',0,'February  ',0,'March     ',0,'April     ',0,'May       ',0,'June      ',0,'July      ',0,'August    ',0,'September ',0,'October   ',0,'November  ',0,'December  ',0
ttt_str_title      db 'Tic-Tac-Toe',0
ttt_str_your_turn  db 'Your turn (X) - Use arrows, Enter to place',0
ttt_str_ai_turn    db 'AI thinking...',0
ttt_str_p1_turn    db 'Player 1 (X) turn - Use arrows, Enter to place',0
ttt_str_p2_turn    db 'Player 2 (O) turn - Use arrows, Enter to place',0
ttt_str_win        db 'You Win! Press Enter to continue',0
ttt_str_lose       db 'You Lose! Press Enter to continue',0
ttt_str_p1_win     db 'Player 1 (X) Wins! Press Enter to continue',0
ttt_str_p2_win     db 'Player 2 (O) Wins! Press Enter to continue',0
ttt_str_draw       db 'Draw! Press Enter to continue',0
ttt_str_help       db 'Esc to quit',0
ttt_str_mode_title db 'Select Mode',0
ttt_str_vs_ai      db '[ VS Computer ]',0
ttt_str_vs_ai_f    db '> VS Computer <',0
ttt_str_2p         db '[ 2 Players ]',0
ttt_str_2p_f       db '> 2 Players <',0
ttt_mode           db 0
ttt_mode_focus     db 0
ttt_mode_exit      db 0
menu_str_title    db 'Menu',0
menu_str_back     db '[ Back to CLI ]',0
menu_str_reboot   db '[ Reboot ]',0
menu_str_shutdown db '[ Shutdown ]',0
menu_focus        db 0
menu_exit         db 0
ctrl_pressed      db 0
fm_str_title      db '===== yOS File Mgr =====',0
fm_str_name       db 'Name',0
fm_str_type       db 'Type',0
fm_str_size       db 'Size (KB)',0
fm_str_status     db 'Selected:',0
fm_str_keys1      db 'F1:Help  F2:Rename  F3:NewFile  F4:NewDir  F8:View  F10:Exit',0
fm_str_confirm_del db 'Delete selected item?',0
fm_str_yes         db '[ YES ]',0
fm_str_yes_f       db '> YES <',0
fm_str_no          db '[ NO ]',0
fm_str_no_f        db '> NO <',0
fm_confirm_focus   db 0
fm_disk_focus      db 0
fm_drive_count     dd 0
fm_drive_list      db 0,0,0,0,0,0,0,0
fm_str_disk_help   db 'Up/Down: select  Enter: confirm  Esc: cancel',0
fm_str_keys2      db 'F11:Disk  F12:Edit  Ctrl+C:Copy  Ctrl+V:Paste  Ctrl+D:Del  Ctrl+R:Ref',0
fm_str_newfile    db 'New file name: ',0
fm_str_newdir     db 'New dir name: ',0
fm_str_rename     db 'Rename to: ',0
fm_str_viewer     db '=== File Viewer (Esc to close) ===',0
fm_str_viewer_hint db 'Up/Down=Scroll  PgUp/PgDn=Page  Esc=Close',0
fm_str_help_title db 'File Mgr Help',0
fm_str_help1      db 'Up/Down        - Select file/folder',0
fm_str_help2      db 'Enter          - Open folder or edit file',0
fm_str_help3      db 'Backspace/Ctrl+Up - Go to parent dir',0
fm_str_help4      db 'F1             - Show this help',0
fm_str_help5      db 'F2             - Rename selected item',0
fm_str_help6      db 'F3             - Create new file',0
fm_str_help7      db 'F4             - Create new directory',0
fm_str_help8      db 'F8             - View selected file',0
fm_str_help9      db 'F11            - Select disk drive',0
fm_str_help10     db 'F12            - Edit selected file',0
fm_str_help11     db 'Ctrl+C         - Copy selected item',0
fm_str_help12     db 'Ctrl+V         - Paste from clipboard',0
fm_str_help13     db 'Ctrl+D / Del   - Delete selected item',0
fm_str_help14     db 'Ctrl+R         - Refresh file list',0
fm_str_help15     db 'Esc            - Exit File Mgr',0
fm_str_help_exit  db 'Press Esc or Enter to close',0
fm_str_disk_title db 'Select Disk',0

fm_exit           db 0
fm_draw_color    db 0
fm_mode           db 0
fm_ctrl_pressed   db 0
fm_input_type     db 0
fm_file_count     dd 0
fm_selected       dd 0
fm_scroll         dd 0
fm_saved_parent_cluster dd 0
fm_saved_parent_sector  dd 0
fm_view_exit      db 0
fm_view_scroll    dd 0
fm_help_exit      db 0
fm_disk_exit      db 0
fm_input_buf      times 16 db 0
fm_input_prompt   times 32 db 0
fm_tmp_str        times 16 db 0
fm_tmp_name       times 32 db 0
fm_clipboard      times 32 db 0
fm_paste_num      dd 0
fm_paste_numstr   times 4 db 0
fm_entries        times 64*32 db 0
fm_file_buf       times 512 db 0
notepad_str_title db 'Notepad - yOS',0
notepad_str_close db '   ',0
notepad_str_help  db 'Ctrl+S:Save  Ctrl+O:Open  Ctrl+Z:Undo  Ctrl+Y:Redo  Esc:Exit',0
notepad_buf       times 2048 db 0
np_row            db 0
np_col            db 0
np_cur_row        db 0
np_cur_col        db 0
notepad_len       dd 0
notepad_cursor    dd 0
notepad_scroll    dd 0
notepad_exit      db 0
notepad_disp_row  dd 0
notepad_disp_col  dd 0
notepad_cur_row   dd 0
notepad_cur_col   dd 0
notepad_undo_stack times 20480 db 0
notepad_undo_count dd 0
notepad_redo_stack times 20480 db 0
notepad_redo_count dd 0
notepad_dlg_mode  db 0
notepad_dlg_focus db 0
notepad_dlg_exit  db 0
notepad_dlg_result db 0
notepad_dlg_filename times 32 db 0
notepad_dlg_tmpname times 16 db 0
dlg_drive_sel      db 0
notepad_dir_entries times 128 db 0
notepad_dir_count dd 0
notepad_dir_sel   dd 0
notepad_current_file times 32 db 0
notepad_file_loaded db 0
dlg_str_save_title db 'Save File',0
dlg_str_open_title db 'Open File',0
dlg_str_files     db 'Files:',0
dlg_str_filename  db 'Name:',0
dlg_str_save      db '[ Save ]',0
dlg_str_open      db '[ Open ]',0
dlg_str_cancel    db '[ Cancel ]',0
dlg_str_path      db 'Path: ',0
dlg_str_drives    db 'Drives: ',0
dlg_str_name      db 'Name: ',0
dlg_str_parent    db '[..]',0
dlg_str_parent_f  db '>..<',0
history_buf       times 1024 db 0
history_count     dd 0
history_pos       dd 0
history_temp      times 128 db 0
;=============================================================================
; yOS Kernel - Main Entry Point
; 32-bit protected mode kernel with FAT12/FAT32 filesystem support
;=============================================================================

cmd_loop:
    mov esi, prompt_prefix
    call print32
    mov esi, current_path
    call print32
    mov esi, prompt_suffix
    call print32
    call read_line
    mov esi, input_buf
    cmp byte [esi], 0
    je cmd_loop
    mov edi, cmd_cls
    call cmd_match
    cmp eax, 1
    je .do_cls
    mov edi, cmd_time
    call cmd_match
    cmp eax, 1
    je .do_time
    mov edi, cmd_shutdown
    call cmd_match
    cmp eax, 1
    je .do_shutdown
    mov edi, cmd_reboot
    call cmd_match
    cmp eax, 1
    je .do_reboot
    mov edi, cmd_output
    call cmd_match
    cmp eax, 1
    je .do_output
    mov edi, cmd_help
    call cmd_match
    cmp eax, 1
    je .do_help
    mov edi, cmd_dl_list
    call cmd_match
    cmp eax, 1
    je .do_dl_list
    mov edi, cmd_disk_list
    call cmd_match
    cmp eax, 1
    je .do_disk_list
    mov edi, cmd_disk_sel
    call cmd_match
    cmp eax, 1
    je .do_disk_sel
    mov edi, cmd_disk_part
    call cmd_match
    cmp eax, 1
    je .do_disk_part
    mov edi, cmd_disk_del_allpart
    call cmd_match
    cmp eax, 1
    je .do_disk_del_allpart
    mov edi, cmd_part_list
    call cmd_match
    cmp eax, 1
    je .do_part_list
    mov edi, cmd_part_sel
    call cmd_match
    cmp eax, 1
    je .do_part_sel
    mov edi, cmd_part_fm
    call cmd_match
    cmp eax, 1
    je .do_part_fm
    mov edi, cmd_part_del
    call cmd_match
    cmp eax, 1
    je .do_part_del
    mov edi, cmd_ls
    call cmd_match
    cmp eax, 1
    je .do_ls
    mov edi, cmd_cd
    call cmd_match
    cmp eax, 1
    je .do_cd
    mov edi, cmd_write
    call cmd_match
    cmp eax, 1
    je .do_write
    mov edi, cmd_read
    call cmd_match
    cmp eax, 1
    je .do_read
    mov edi, cmd_crdir
    call cmd_match
    cmp eax, 1
    je .do_crdir
    mov edi, cmd_dedir
    call cmd_match
    cmp eax, 1
    je .do_dedir
    mov edi, cmd_del
    call cmd_match
    cmp eax, 1
    je .do_del
    mov edi, cmd_mem
    call cmd_match
    cmp eax, 1
    je .do_mem
    mov edi, cmd_copy
    call cmd_match
    cmp eax, 1
    je .do_copy
    mov edi, cmd_mov
    call cmd_match
    cmp eax, 1
    je .do_mov
    mov edi, cmd_color
    call cmd_match
    cmp eax, 1
    je .do_color
    mov edi, cmd_date
    call cmd_match
    cmp eax, 1
    je .do_date
    mov edi, cmd_tui
    call cmd_match
    cmp eax, 1
    je .do_tui
    mov edi, cmd_ver
    call cmd_match
    cmp eax, 1
    je .do_ver
    mov edi, cmd_devinfo
    call cmd_match
    cmp eax, 1
    je .do_devinfo
    mov esi, unknown_msg
    call print32
    jmp cmd_loop
.do_cls:
    call clear_screen
    jmp cmd_loop
.do_time:
    call show_time
    jmp cmd_loop
.do_shutdown:
    call shutdown_pc
    jmp cmd_loop
.do_reboot:
    call reboot_pc
    jmp cmd_loop
.do_output:
    call output_handler
    jmp cmd_loop
.do_help:
    call help_cmd
    jmp cmd_loop
.do_dl_list:
    call dl_list_cmd
    jmp cmd_loop
.do_disk_list:
    call disk_list
    jmp cmd_loop
.do_disk_sel:
    call disk_select
    jmp cmd_loop
.do_disk_part:
    call disk_partition
    jmp cmd_loop
.do_disk_del_allpart:
    call disk_del_allpart
    jmp cmd_loop
.do_part_list:
    call part_list
    jmp cmd_loop
.do_part_sel:
    call part_select
    jmp cmd_loop
.do_part_fm:
    call part_format
    jmp cmd_loop
.do_part_del:
    call part_del
    jmp cmd_loop
.do_ls:
    call ls_cmd
    jmp cmd_loop
.do_cd:
    call cd_cmd
    jmp cmd_loop
.do_write:
    call write_cmd
    jmp cmd_loop
.do_read:
    call read_cmd
    jmp cmd_loop
.do_crdir:
    call crdir_cmd
    jmp cmd_loop
.do_dedir:
    call dedir_cmd
    jmp cmd_loop
.do_del:
    call del_cmd
    jmp cmd_loop
.do_mem:
    call mem_cmd
    jmp cmd_loop
.do_copy:
    call copy_cmd
    jmp cmd_loop
.do_mov:
    call cut_cmd
    jmp cmd_loop
.do_color:
    call color_cmd
    jmp cmd_loop
.do_date:
    call date_cmd
    jmp cmd_loop
.do_tui:
    call tui_cmd
    jmp cmd_loop
.do_ver:
    call ver_cmd
    jmp cmd_loop
.do_devinfo:
    call devinfo_cmd
    jmp cmd_loop
ver_cmd:
    pusha
    mov esi, ver_msg
    call print32
    popa
    ret
devinfo_cmd:
    pusha
    mov esi, devinfo_header
    call print32
    mov esi, devinfo_cpu
    call print32
    xor eax, eax
    cpuid
    mov [cpu_vendor], ebx
    mov [cpu_vendor + 4], edx
    mov [cpu_vendor + 8], ecx
    mov byte [cpu_vendor + 12], 0
    mov esi, cpu_vendor
    call print32
    mov esi, devinfo_space
    call print32
    mov eax, 1
    cpuid
    mov ecx, eax
    mov ebx, eax
    shr ebx, 8
    and ebx, 0xF
    mov esi, devinfo_family
    call print32
    mov eax, ebx
    call print_number
    mov esi, devinfo_model
    call print32
    mov eax, ecx
    shr eax, 4
    and eax, 0xF
    call print_number
    mov esi, newline
    call print32
    mov esi, devinfo_mem
    call print32
    mov eax, [total_kb]
    call print_number
    mov esi, devinfo_kb
    call print32
    mov esi, devinfo_display
    call print32
    mov esi, devinfo_display
    call print32
    mov esi, devinfo_disks
    call print32
    mov ecx, 4
    xor ebx, ebx
.disk_loop:
    cmp byte [disk_present + ebx], 0
    je .disk_next
    mov eax, ebx
    inc eax
    call print_number
    mov al, ' '
    call print_char
    mov esi, disk_names
    mov eax, ebx
    mov edx, 7
    mul edx
    add esi, eax
    call print32
    mov al, ' '
    call print_char
    push ebx
    push ecx
    mov eax, ebx
    call get_disk_size
    mov eax, [disk_size_sectors]
    xor edx, edx
    mov ecx, 2048
    div ecx
    call print_number
    mov esi, devinfo_mb
    call print32
    pop ecx
    pop ebx
.disk_next:
    inc ebx
    dec ecx
    jnz .disk_loop
    mov esi, newline
    call print32
    popa
    ret
mem_cmd:
    pusha
    call mem_update_stats
    mov esi, mem_header
    call print32
    xor ecx, ecx
.pcb_loop:
    cmp ecx, 8
    jge .pcb_done
    mov eax, ecx
    shl eax, 6
    add eax, 0x110000
    mov ebx, [eax + 4]
    cmp ebx, 0
    je .pcb_next
    mov eax, [eax + 0]
    push ecx
    push eax
    mov al, ' '
    call print_char
    mov al, ' '
    call print_char
    pop eax
    call print_number
    pop ecx
    mov al, ' '
    call print_char
    mov eax, ecx
    shl eax, 6
    add eax, 0x110000
    mov ebx, [eax + 4]
    cmp ebx, 1
    je .print_ready
    mov esi, status_run
    call print32
    jmp .after_status
.print_ready:
    mov esi, status_ready
    call print32
.after_status:
    mov al, ' '
    call print_char
    mov eax, ecx
    shl eax, 6
    add eax, 0x110000
    mov eax, [eax + 16]
    mov ebx, 1024
    xor edx, edx
    div ebx
    push ecx
    push eax
    call count_digits
    mov ecx, 6
    sub ecx, eax
    jle .mem_no_pad
.mem_pad_loop:
    mov al, ' '
    call print_char
    loop .mem_pad_loop
.mem_no_pad:
    pop eax
    call print_number
    pop ecx
    mov al, ' '
    call print_char
    mov al, ' '
    call print_char
    mov eax, ecx
    shl eax, 6
    add eax, 0x110000
    lea esi, [eax + 24]
    mov ebx, 0
.name_loop:
    cmp ebx, 16
    jge .name_done
    mov al, [esi + ebx]
    cmp al, 0
    je .name_done
    call print_char
    inc ebx
    jmp .name_loop
.name_done:
    mov esi, newline
    call print32
.pcb_next:
    inc ecx
    jmp .pcb_loop
.pcb_done:
    mov esi, mem_total_prefix
    call print32
    mov eax, [total_kb]
    call print_number
    mov al, 'K'
    call print_char
    mov esi, mem_used_prefix
    call print32
    mov eax, [used_kb]
    call print_number
    mov al, 'K'
    call print_char
    mov esi, mem_free_prefix
    call print32
    mov eax, [free_kb]
    call print_number
    mov al, 'K'
    call print_char
    mov esi, newline
    call print32
    popa
    ret
copy_internal_read_to_buffer:
    pusha
    mov esi, tmp_filename
    call find_dir_entry
    cmp eax, -1
    je .not_found
    mov edi, dir_buffer
    add edi, eax
    mov al, [edi + 11]
    test al, 0x10
    jnz .is_dir
    movzx eax, word [edi + 26]
    mov esi, 0x1F0000
    mov [copy_bytes_total], dword 0
.read_loop:
    cmp eax, 0x0FF8
    jae .done_read
    cmp eax, 2
    jb .done_read
    push eax
    call cluster_to_lba
    mov ecx, 1
    mov edi, sector_buffer
    call ide_read_sectors
    mov esi, sector_buffer
    mov ecx, 512
    mov edi, 0x1F0000
    add edi, [copy_bytes_total]
    cld
    rep movsb
    add [copy_bytes_total], dword 512
    pop eax
    call get_next_cluster
    jmp .read_loop
.done_read:
    mov eax, [copy_bytes_total]
    mov [copy_temp_size], eax
    popa
    mov eax, [copy_temp_size]
    ret
.not_found:
    mov esi, msg_file_not_found
    call print32
    popa
    mov eax, -1
    ret
.is_dir:
    mov esi, msg_is_directory
    call print32
    popa
    mov eax, -1
    ret
copy_internal_write_from_buffer:
    pusha
    mov esi, tmp_filename
    call find_dir_entry
    cmp eax, -1
    je .create_new
    call delete_file
.create_new:
    mov ecx, [copy_temp_size]
    test ecx, ecx
    jz .zero_size
    mov esi, 0x1F0000
    mov dword [copy_write_pos], 0
    mov dword [copy_first_cluster], 0
    mov dword [copy_prev_cluster], 0
.cluster_write_loop:
    mov eax, [copy_write_pos]
    cmp eax, ecx
    jge .write_fat_and_dir
    call find_free_cluster
    cmp eax, 0
    je .disk_full
    cmp dword [copy_first_cluster], 0
    jne .not_first
    mov [copy_first_cluster], eax
.not_first:
    cmp dword [copy_prev_cluster], 0
    je .no_link
    push eax
    mov eax, [copy_prev_cluster]
    mov ebx, [esp]
    call set_next_cluster
    pop eax
.no_link:
    mov [copy_prev_cluster], eax
    push eax
    push ecx
    call cluster_to_lba
    mov ecx, 1
    mov edi, sector_buffer
    push edi
    mov ecx, 512
    xor al, al
    cld
    rep stosb
    pop edi
    mov esi, 0x1F0000
    add esi, [copy_write_pos]
    mov ecx, 512
    mov eax, [copy_temp_size]
    sub eax, [copy_write_pos]
    cmp eax, 512
    jge .full_cluster
    mov ecx, eax
.full_cluster:
    cld
    rep movsb
    mov esi, sector_buffer
    call ide_write_sectors
    pop ecx
    pop eax
    add dword [copy_write_pos], 512
    jmp .cluster_write_loop
.write_fat_and_dir:
    cmp dword [copy_prev_cluster], 0
    je .zero_size
    mov eax, [copy_prev_cluster]
    mov ebx, 0x0FFF
    call set_next_cluster
    call write_fat
    call find_free_dir_entry
    cmp eax, -1
    je .dir_full
    mov edi, dir_buffer
    add edi, eax
    push esi
    mov esi, tmp_filename
    mov ecx, 11
    rep movsb
    pop esi
    mov byte [edi - 11 + 11], 0x00
    mov ebx, [copy_first_cluster]
    mov word [edi - 11 + 26], bx
    mov edx, [copy_temp_size]
    mov dword [edi - 11 + 28], edx
    call write_dir_sector
    mov esi, msg_written
    call print32
    jmp .done
.zero_size:
    mov esi, msg_written
    call print32
    jmp .done
.disk_full:
    mov esi, msg_disk_full
    call print32
    jmp .done
.dir_full:
    mov esi, msg_dir_full
    call print32
.done:
    popa
    ret
extract_src_filename:
    pusha
    mov esi, copy_src_path
.find_end:
    cmp byte [esi], 0
    je .find_sep
    inc esi
    jmp .find_end
.find_sep:
    cmp esi, copy_src_path
    je .start_found
    dec esi
    mov al, [esi]
    cmp al, '\'
    je .sep_found
    cmp al, '/'
    je .sep_found
    cmp al, ':'
    je .sep_found
    jmp .find_sep
.sep_found:
    inc esi
.start_found:
    mov edi, copy_src_file_name
    mov ecx, 11
    mov al, ' '
    cld
    rep stosb
    mov edi, copy_src_file_name
    mov ecx, 8
.name_loop:
    lodsb
    cmp al, 0
    je .done
    cmp al, '.'
    je .start_ext
    cmp al, 'a'
    jb .write_name
    cmp al, 'z'
    ja .write_name
    sub al, 32
.write_name:
    stosb
    dec ecx
    jnz .name_loop
.skip_rest:
    lodsb
    cmp al, 0
    je .done
    cmp al, '.'
    je .start_ext
    jmp .skip_rest
.start_ext:
    mov edi, copy_src_file_name
    add edi, 8
    mov ecx, 3
.ext_loop:
    lodsb
    cmp al, 0
    je .done
    cmp al, ' '
    je .done
    cmp al, 'a'
    jb .write_ext
    cmp al, 'z'
    ja .write_ext
    sub al, 32
.write_ext:
    stosb
    dec ecx
    jnz .ext_loop
.done:
    popa
    ret
check_target_is_dir:
    push ebx
    push edx
    push esi
    push edi
    mov esi, tmp_filename
    call find_dir_entry
    cmp eax, -1
    je .not_exist
    mov ebx, eax
    mov edi, dir_buffer
    add edi, ebx
    mov al, [edi + 11]
    test al, 0x10
    jz .not_dir
    mov eax, 1
    jmp .done
.not_dir:
    mov eax, 0
    jmp .done
.not_exist:
    mov eax, 0
.done:
    pop edi
    pop esi
    pop edx
    pop ebx
    ret
append_filename_to_dst:
    pusha
    mov esi, copy_src_path
.find_src_end:
    cmp byte [esi], 0
    je .find_src_sep
    inc esi
    jmp .find_src_end
.find_src_sep:
    cmp esi, copy_src_path
    je .src_start_found
    dec esi
    mov al, [esi]
    cmp al, '\'
    je .src_sep_found
    cmp al, '/'
    je .src_sep_found
    cmp al, ':'
    je .src_sep_found
    jmp .find_src_sep
.src_sep_found:
    inc esi
.src_start_found:
    mov ebx, esi
    mov edi, copy_dst_path
.find_dst_end:
    cmp byte [edi], 0
    je .check_slash
    inc edi
    jmp .find_dst_end
.check_slash:
    cmp edi, copy_dst_path
    je .add_slash
    mov al, [edi - 1]
    cmp al, '\'
    je .do_copy
    cmp al, '/'
    je .do_copy
.add_slash:
    mov byte [edi], '\'
    inc edi
.do_copy:
    mov esi, ebx
.copy_loop:
    mov al, [esi]
    mov [edi], al
    cmp al, 0
    je .done
    inc esi
    inc edi
    jmp .copy_loop
.done:
    popa
    ret
copy_parse_tokens:
    pusha
    mov esi, input_buf
.skip_cmd_name:
    mov al, [esi]
    cmp al, ' '
    je .skip_leading
    cmp al, 0x09
    je .skip_leading
    cmp al, 0
    je .bad_input
    inc esi
    jmp .skip_cmd_name
.bad_input:
    popa
    mov eax, -1
    ret
.skip_leading:
    mov al, [esi]
    cmp al, ' '
    je .skip_one
    cmp al, 0x09
    je .skip_one
    jmp .src_start
.skip_one:
    inc esi
    jmp .skip_leading
.src_start:
    lea edi, [copy_src_path]
.src_loop:
    mov al, [esi]
    cmp al, 0
    je .src_end_nul
    cmp al, ' '
    je .src_end
    cmp al, 0x09
    je .src_end
    mov [edi], al
    inc esi
    inc edi
    jmp .src_loop
.src_end_nul:
    mov byte [edi], 0
    popa
    mov eax, -1
    ret
.src_end:
    mov byte [edi], 0
    inc esi
.skip_mid:
    mov al, [esi]
    cmp al, ' '
    je .skip_mid_one
    cmp al, 0x09
    je .skip_mid_one
    jmp .dst_start
.skip_mid_one:
    inc esi
    jmp .skip_mid
.dst_start:
    lea edi, [copy_dst_path]
.dst_loop:
    mov al, [esi]
    cmp al, 0
    je .dst_end
    cmp al, ' '
    je .dst_end
    cmp al, 0x09
    je .dst_end
    mov [edi], al
    inc esi
    inc edi
    jmp .dst_loop
.dst_end:
    mov byte [edi], 0
    lea esi, [copy_src_path]
    mov al, [esi]
    cmp al, 0
    jne .check_dst
    popa
    mov eax, -1
    ret
.check_dst:
    lea esi, [copy_dst_path]
    mov al, [esi]
    cmp al, 0
    jne .ok
    popa
    mov eax, -1
    ret
.ok:
    popa
    mov eax, 0
    ret
;=============================================================================
; Copy/Move Operations - File copy and move with path resolution
;=============================================================================

copy_cmd:
    ; Copy file from source to destination
    ; Usage: copy <source> <destination>
    pusha
    call copy_parse_tokens
    cmp eax, 0
    jne .usage
    mov eax, [copy_src_path]
    and eax, 0xFFFF
    cmp eax, 0x002A
    je .wildcard
.normal:
    push dword [selected_disk]
    push dword [selected_partition]
    push dword [selected_partition_start]
    push dword [current_dir_cluster]
    push dword [current_dir_sector]
    sub esp, 128
    mov esi, current_path
    mov edi, esp
    mov ecx, 128
    cld
    rep movsb
    lea esi, [copy_src_path]
    push esi
    call resolve_path_to_dir
    add esp, 4
    cmp eax, 0
    jne .src_fail_restore
    call read_dir_sector
    call copy_internal_read_to_buffer
    cmp eax, -1
    je .src_fail_restore
    mov [copy_temp_size], eax
    mov esi, esp
    mov edi, current_path
    mov ecx, 128
    cld
    rep movsb
    add esp, 128
    pop dword [current_dir_sector]
    pop dword [current_dir_cluster]
    pop dword [selected_partition_start]
    pop dword [selected_partition]
    pop dword [selected_disk]
    push dword [selected_disk]
    push dword [selected_partition]
    push dword [selected_partition_start]
    push dword [current_dir_cluster]
    push dword [current_dir_sector]
    sub esp, 128
    mov esi, current_path
    mov edi, esp
    mov ecx, 128
    cld
    rep movsb
    lea esi, [copy_dst_path]
    push esi
    call resolve_path_to_dir
    add esp, 4
    cmp eax, 0
    jne .dst_fail_restore
    call read_dir_sector
    call extract_src_filename
    mov esi, copy_src_file_name
    mov edi, tmp_filename
    mov ecx, 11
    cld
    rep movsb
    mov byte [tmp_filename + 11], 0
    call check_target_is_dir
    cmp eax, 1
    jne .write_now
    call append_filename_to_dst
    mov esi, esp
    mov edi, current_path
    mov ecx, 128
    cld
    rep movsb
    add esp, 128
    pop dword [current_dir_sector]
    pop dword [current_dir_cluster]
    pop dword [selected_partition_start]
    pop dword [selected_partition]
    pop dword [selected_disk]
    push dword [selected_disk]
    push dword [selected_partition]
    push dword [selected_partition_start]
    push dword [current_dir_cluster]
    push dword [current_dir_sector]
    sub esp, 128
    mov esi, current_path
    mov edi, esp
    mov ecx, 128
    cld
    rep movsb
    lea esi, [copy_dst_path]
    push esi
    call resolve_path_to_dir
    add esp, 4
    cmp eax, 0
    jne .dst_fail_restore
    call read_dir_sector
.write_now:
    call copy_internal_write_from_buffer
    mov esi, esp
    mov edi, current_path
    mov ecx, 128
    cld
    rep movsb
    add esp, 128
    pop dword [current_dir_sector]
    pop dword [current_dir_cluster]
    pop dword [selected_partition_start]
    pop dword [selected_partition]
    pop dword [selected_disk]
    jmp .done
.src_fail_restore:
    mov esi, esp
    mov edi, current_path
    mov ecx, 128
    cld
    rep movsb
    add esp, 128
    pop dword [current_dir_sector]
    pop dword [current_dir_cluster]
    pop dword [selected_partition_start]
    pop dword [selected_partition]
    pop dword [selected_disk]
    jmp .done
.dst_fail_restore:
    mov esi, msg_file_not_found
    call print32
    mov esi, esp
    mov edi, current_path
    mov ecx, 128
    cld
    rep movsb
    add esp, 128
    pop dword [current_dir_sector]
    pop dword [current_dir_cluster]
    pop dword [selected_partition_start]
    pop dword [selected_partition]
    pop dword [selected_disk]
    jmp .done
.wildcard:
    push dword [selected_disk]
    push dword [selected_partition]
    push dword [selected_partition_start]
    push dword [current_dir_cluster]
    push dword [current_dir_sector]
    sub esp, 128
    mov esi, current_path
    mov edi, esp
    mov ecx, 128
    cld
    rep movsb
    mov eax, esp
    mov [cut_src_path_save], eax
    lea esi, [copy_dst_path]
    push esi
    call resolve_path_to_dir
    add esp, 4
    cmp eax, 0
    jne .wc_dst_fail
    call read_dir_sector
    mov esi, copy_src_file_name
    mov edi, tmp_filename
    mov ecx, 11
    cld
    rep movsb
    mov byte [tmp_filename + 11], 0
    call check_target_is_dir
    cmp eax, 1
    jne .wc_not_dir
    mov esi, [cut_src_path_save]
    mov edi, current_path
    mov ecx, 128
    cld
    rep movsb
    add esp, 128
    pop dword [current_dir_sector]
    pop dword [current_dir_cluster]
    pop dword [selected_partition_start]
    pop dword [selected_partition]
    pop dword [selected_disk]
    push dword [selected_disk]
    push dword [selected_partition]
    push dword [selected_partition_start]
    push dword [current_dir_cluster]
    push dword [current_dir_sector]
    sub esp, 128
    mov esi, current_path
    mov edi, esp
    mov ecx, 128
    cld
    rep movsb
    mov [cut_dst_restore], esp
    call read_dir_sector
    mov ebp, 0
    mov ecx, [fat_root_entries]
    cmp dword [current_dir_cluster], 0
    jne .wc_data_dir
    mov ecx, [fat_root_entries]
    jmp .wc_loop_prep
.wc_data_dir:
    mov ecx, 16
.wc_loop_prep:
    xor ebx, ebx
.wc_entry_loop:
    cmp ebx, ecx
    jge .wc_done
    mov eax, ebx
    mov edx, 32
    mul edx
    mov edi, dir_buffer
    add edi, eax
    cmp byte [edi], 0
    je .wc_done
    cmp byte [edi], 0xE5
    je .wc_next_entry
    mov al, [edi + 11]
    test al, 0x10
    jnz .wc_next_entry
    test al, 0x08
    jnz .wc_next_entry
    cmp byte [edi], '.'
    jne .wc_not_dot
    cmp byte [edi + 1], ' '
    je .wc_next_entry
    cmp byte [edi + 1], '.'
    je .wc_next_entry
.wc_not_dot:
    push ebx
    push ecx
    mov esi, edi
    mov edi, wildcard_tmp
    mov ecx, 11
    cld
    rep movsb
    mov byte [wildcard_tmp + 11], 0
    mov esi, wildcard_tmp
    mov edi, tmp_filename
    mov ecx, 11
    cld
    rep movsb
    mov byte [tmp_filename + 11], 0
    mov edi, copy_src_path
    mov esi, wildcard_tmp
    mov ecx, 8
.wc_name_copy:
    lodsb
    cmp al, ' '
    je .wc_name_done
    stosb
    loop .wc_name_copy
.wc_name_done:
    mov al, [wildcard_tmp + 8]
    cmp al, ' '
    je .wc_no_ext
    mov byte [edi], '.'
    inc edi
    mov ecx, 3
    lea esi, [wildcard_tmp + 8]
.wc_ext_copy:
    lodsb
    cmp al, ' '
    je .wc_no_ext
    stosb
    loop .wc_ext_copy
.wc_no_ext:
    mov byte [edi], 0
    call copy_internal_read_to_buffer
    cmp eax, -1
    je .wc_skip_file
    mov [copy_temp_size], eax
    mov esi, [cut_dst_restore]
    mov edi, current_path
    mov ecx, 128
    cld
    rep movsb
    add esp, 128
    pop dword [current_dir_sector]
    pop dword [current_dir_cluster]
    pop dword [selected_partition_start]
    pop dword [selected_partition]
    pop dword [selected_disk]
    push dword [selected_disk]
    push dword [selected_partition]
    push dword [selected_partition_start]
    push dword [current_dir_cluster]
    push dword [current_dir_sector]
    sub esp, 128
    mov esi, current_path
    mov edi, esp
    mov ecx, 128
    cld
    rep movsb
    lea esi, [copy_dst_path]
    push esi
    call resolve_path_to_dir
    add esp, 4
    cmp eax, 0
    jne .wc_skip_switch_back
    call read_dir_sector
    mov esi, wildcard_tmp
    mov edi, tmp_filename
    mov ecx, 11
    cld
    rep movsb
    mov byte [tmp_filename + 11], 0
    call copy_internal_write_from_buffer
.wc_skip_switch_back:
    mov esi, esp
    mov edi, current_path
    mov ecx, 128
    cld
    rep movsb
    add esp, 128
    pop dword [current_dir_sector]
    pop dword [current_dir_cluster]
    pop dword [selected_partition_start]
    pop dword [selected_partition]
    pop dword [selected_disk]
    push dword [selected_disk]
    push dword [selected_partition]
    push dword [selected_partition_start]
    push dword [current_dir_cluster]
    push dword [current_dir_sector]
    sub esp, 128
    mov esi, current_path
    mov edi, esp
    mov ecx, 128
    cld
    rep movsb
    mov [cut_dst_restore], esp
    call read_dir_sector
.wc_skip_file:
    pop ecx
    pop ebx
.wc_next_entry:
    inc ebx
    jmp .wc_entry_loop
.wc_done:
    mov esi, esp
    mov edi, current_path
    mov ecx, 128
    cld
    rep movsb
    add esp, 128
    pop dword [current_dir_sector]
    pop dword [current_dir_cluster]
    pop dword [selected_partition_start]
    pop dword [selected_partition]
    pop dword [selected_disk]
    jmp .done
.wc_not_dir:
    mov esi, msg_dst_not_dir
    call print32
    mov esi, esp
    mov edi, current_path
    mov ecx, 128
    cld
    rep movsb
    add esp, 128
    pop dword [current_dir_sector]
    pop dword [current_dir_cluster]
    pop dword [selected_partition_start]
    pop dword [selected_partition]
    pop dword [selected_disk]
    jmp .done
.wc_dst_fail:
    mov esi, msg_dst_not_dir
    call print32
    mov esi, esp
    mov edi, current_path
    mov ecx, 128
    cld
    rep movsb
    add esp, 128
    pop dword [current_dir_sector]
    pop dword [current_dir_cluster]
    pop dword [selected_partition_start]
    pop dword [selected_partition]
    pop dword [selected_disk]
    jmp .done
.usage:
    mov esi, copy_usage_msg
    call print32
.done:
    popa
    ret
cut_cmd:
    pusha
    call copy_parse_tokens
    cmp eax, 0
    jne .usage
    mov eax, [copy_src_path]
    and eax, 0xFFFF
    cmp eax, 0x002A
    je .wildcard
.normal:
    push dword [selected_disk]
    push dword [selected_partition]
    push dword [selected_partition_start]
    push dword [current_dir_cluster]
    push dword [current_dir_sector]
    sub esp, 128
    mov esi, current_path
    mov edi, esp
    mov ecx, 128
    cld
    rep movsb
    mov [cut_src_path_save], esp
    lea esi, [copy_src_path]
    push esi
    call resolve_path_to_dir
    add esp, 4
    cmp eax, 0
    jne .src_fail_restore
    call read_dir_sector
    call copy_internal_read_to_buffer
    cmp eax, -1
    je .src_fail_restore
    mov [copy_temp_size], eax
    mov esi, [cut_src_path_save]
    mov edi, current_path
    mov ecx, 128
    cld
    rep movsb
    add esp, 128
    pop dword [current_dir_sector]
    pop dword [current_dir_cluster]
    pop dword [selected_partition_start]
    pop dword [selected_partition]
    pop dword [selected_disk]
    push dword [selected_disk]
    push dword [selected_partition]
    push dword [selected_partition_start]
    push dword [current_dir_cluster]
    push dword [current_dir_sector]
    sub esp, 128
    mov esi, current_path
    mov edi, esp
    mov ecx, 128
    cld
    rep movsb
    mov [cut_dst_restore], esp
    lea esi, [copy_dst_path]
    push esi
    call resolve_path_to_dir
    add esp, 4
    cmp eax, 0
    jne .dst_fail_restore
    call read_dir_sector
    call extract_src_filename
    mov esi, copy_src_file_name
    mov edi, tmp_filename
    mov ecx, 11
    cld
    rep movsb
    mov byte [tmp_filename + 11], 0
    call check_target_is_dir
    cmp eax, 1
    jne .cut_write_now
    call append_filename_to_dst
    mov esi, [cut_dst_restore]
    mov edi, current_path
    mov ecx, 128
    cld
    rep movsb
    add esp, 128
    pop dword [current_dir_sector]
    pop dword [current_dir_cluster]
    pop dword [selected_partition_start]
    pop dword [selected_partition]
    pop dword [selected_disk]
    push dword [selected_disk]
    push dword [selected_partition]
    push dword [selected_partition_start]
    push dword [current_dir_cluster]
    push dword [current_dir_sector]
    sub esp, 128
    mov esi, current_path
    mov edi, esp
    mov ecx, 128
    cld
    rep movsb
    mov [cut_dst_restore], esp
    lea esi, [copy_dst_path]
    push esi
    call resolve_path_to_dir
    add esp, 4
    cmp eax, 0
    jne .dst_fail_restore
    call read_dir_sector
.cut_write_now:
    call copy_internal_write_from_buffer
    mov esi, [cut_dst_restore]
    mov edi, current_path
    mov ecx, 128
    cld
    rep movsb
    add esp, 128
    pop dword [current_dir_sector]
    pop dword [current_dir_cluster]
    pop dword [selected_partition_start]
    pop dword [selected_partition]
    pop dword [selected_disk]
    push dword [selected_disk]
    push dword [selected_partition]
    push dword [selected_partition_start]
    push dword [current_dir_cluster]
    push dword [current_dir_sector]
    sub esp, 128
    mov esi, current_path
    mov edi, esp
    mov ecx, 128
    cld
    rep movsb
    lea esi, [copy_src_path]
    push esi
    call resolve_path_to_dir
    add esp, 4
    cmp eax, 0
    jne .del_fail_restore
    call read_dir_sector
    call delete_file
    add esp, 128
    pop dword [current_dir_sector]
    pop dword [current_dir_cluster]
    pop dword [selected_partition_start]
    pop dword [selected_partition]
    pop dword [selected_disk]
    jmp .done
.del_fail_restore:
    add esp, 128
    pop dword [current_dir_sector]
    pop dword [current_dir_cluster]
    pop dword [selected_partition_start]
    pop dword [selected_partition]
    pop dword [selected_disk]
    jmp .done
.src_fail_restore:
    add esp, 128
    pop dword [current_dir_sector]
    pop dword [current_dir_cluster]
    pop dword [selected_partition_start]
    pop dword [selected_partition]
    pop dword [selected_disk]
    jmp .done
.dst_fail_restore:
    mov esi, msg_file_not_found
    call print32
    add esp, 128
    pop dword [current_dir_sector]
    pop dword [current_dir_cluster]
    pop dword [selected_partition_start]
    pop dword [selected_partition]
    pop dword [selected_disk]
    jmp .done
.wildcard:
    push dword [selected_disk]
    push dword [selected_partition]
    push dword [selected_partition_start]
    push dword [current_dir_cluster]
    push dword [current_dir_sector]
    sub esp, 128
    mov esi, current_path
    mov edi, esp
    mov ecx, 128
    cld
    rep movsb
    mov [cut_src_path_save], esp
    lea esi, [copy_dst_path]
    push esi
    call resolve_path_to_dir
    add esp, 4
    cmp eax, 0
    jne .wc_dst_fail
    call read_dir_sector
    mov esi, copy_src_file_name
    mov edi, tmp_filename
    mov ecx, 11
    cld
    rep movsb
    mov byte [tmp_filename + 11], 0
    call check_target_is_dir
    cmp eax, 1
    jne .wc_not_dir
    mov esi, [cut_src_path_save]
    mov edi, current_path
    mov ecx, 128
    cld
    rep movsb
    add esp, 128
    pop dword [current_dir_sector]
    pop dword [current_dir_cluster]
    pop dword [selected_partition_start]
    pop dword [selected_partition]
    pop dword [selected_disk]
    push dword [selected_disk]
    push dword [selected_partition]
    push dword [selected_partition_start]
    push dword [current_dir_cluster]
    push dword [current_dir_sector]
    sub esp, 128
    mov esi, current_path
    mov edi, esp
    mov ecx, 128
    cld
    rep movsb
    mov [cut_dst_restore], esp
    call read_dir_sector
    mov ecx, [fat_root_entries]
    cmp dword [current_dir_cluster], 0
    jne .wc_data_dir
    mov ecx, [fat_root_entries]
    jmp .wc_loop_prep
.wc_data_dir:
    mov ecx, 16
.wc_loop_prep:
    xor ebx, ebx
.wc_entry_loop:
    cmp ebx, ecx
    jge .wc_done
    mov eax, ebx
    mov edx, 32
    mul edx
    mov edi, dir_buffer
    add edi, eax
    cmp byte [edi], 0
    je .wc_done
    cmp byte [edi], 0xE5
    je .wc_next_entry
    mov al, [edi + 11]
    test al, 0x10
    jnz .wc_next_entry
    test al, 0x08
    jnz .wc_next_entry
    cmp byte [edi], '.'
    jne .wc_not_dot
    cmp byte [edi + 1], ' '
    je .wc_next_entry
    cmp byte [edi + 1], '.'
    je .wc_next_entry
.wc_not_dot:
    push ebx
    push ecx
    mov esi, edi
    mov edi, wildcard_tmp
    mov ecx, 11
    cld
    rep movsb
    mov byte [wildcard_tmp + 11], 0
    mov esi, wildcard_tmp
    mov edi, tmp_filename
    mov ecx, 11
    cld
    rep movsb
    mov byte [tmp_filename + 11], 0
    mov edi, copy_src_path
    mov esi, wildcard_tmp
    mov ecx, 8
.wc_name_copy:
    lodsb
    cmp al, ' '
    je .wc_name_done
    stosb
    loop .wc_name_copy
.wc_name_done:
    mov al, [wildcard_tmp + 8]
    cmp al, ' '
    je .wc_no_ext
    mov byte [edi], '.'
    inc edi
    mov ecx, 3
    lea esi, [wildcard_tmp + 8]
.wc_ext_copy:
    lodsb
    cmp al, ' '
    je .wc_no_ext
    stosb
    loop .wc_ext_copy
.wc_no_ext:
    mov byte [edi], 0
    call copy_internal_read_to_buffer
    cmp eax, -1
    je .wc_skip_file
    mov [copy_temp_size], eax
    mov esi, [cut_dst_restore]
    mov edi, current_path
    mov ecx, 128
    cld
    rep movsb
    add esp, 128
    pop dword [current_dir_sector]
    pop dword [current_dir_cluster]
    pop dword [selected_partition_start]
    pop dword [selected_partition]
    pop dword [selected_disk]
    push dword [selected_disk]
    push dword [selected_partition]
    push dword [selected_partition_start]
    push dword [current_dir_cluster]
    push dword [current_dir_sector]
    sub esp, 128
    mov esi, current_path
    mov edi, esp
    mov ecx, 128
    cld
    rep movsb
    lea esi, [copy_dst_path]
    push esi
    call resolve_path_to_dir
    add esp, 4
    cmp eax, 0
    jne .wc_switch_back_src
    call read_dir_sector
    mov esi, wildcard_tmp
    mov edi, tmp_filename
    mov ecx, 11
    cld
    rep movsb
    mov byte [tmp_filename + 11], 0
    call copy_internal_write_from_buffer
.wc_switch_back_src:
    mov esi, esp
    mov edi, current_path
    mov ecx, 128
    cld
    rep movsb
    add esp, 128
    pop dword [current_dir_sector]
    pop dword [current_dir_cluster]
    pop dword [selected_partition_start]
    pop dword [selected_partition]
    pop dword [selected_disk]
    push dword [selected_disk]
    push dword [selected_partition]
    push dword [selected_partition_start]
    push dword [current_dir_cluster]
    push dword [current_dir_sector]
    sub esp, 128
    mov esi, current_path
    mov edi, esp
    mov ecx, 128
    cld
    rep movsb
    mov esi, wildcard_tmp
    mov edi, tmp_filename
    mov ecx, 11
    cld
    rep movsb
    mov byte [tmp_filename + 11], 0
    call read_dir_sector
    call delete_file
    mov esi, esp
    mov edi, current_path
    mov ecx, 128
    cld
    rep movsb
    add esp, 128
    pop dword [current_dir_sector]
    pop dword [current_dir_cluster]
    pop dword [selected_partition_start]
    pop dword [selected_partition]
    pop dword [selected_disk]
    push dword [selected_disk]
    push dword [selected_partition]
    push dword [selected_partition_start]
    push dword [current_dir_cluster]
    push dword [current_dir_sector]
    sub esp, 128
    mov esi, current_path
    mov edi, esp
    mov ecx, 128
    cld
    rep movsb
    mov [cut_dst_restore], esp
    call read_dir_sector
.wc_skip_file:
    pop ecx
    pop ebx
.wc_next_entry:
    inc ebx
    jmp .wc_entry_loop
.wc_done:
    mov esi, esp
    mov edi, current_path
    mov ecx, 128
    cld
    rep movsb
    add esp, 128
    pop dword [current_dir_sector]
    pop dword [current_dir_cluster]
    pop dword [selected_partition_start]
    pop dword [selected_partition]
    pop dword [selected_disk]
    jmp .done
.wc_not_dir:
    mov esi, msg_dst_not_dir
    call print32
    mov esi, esp
    mov edi, current_path
    mov ecx, 128
    cld
    rep movsb
    add esp, 128
    pop dword [current_dir_sector]
    pop dword [current_dir_cluster]
    pop dword [selected_partition_start]
    pop dword [selected_partition]
    pop dword [selected_disk]
    jmp .done
.wc_dst_fail:
    mov esi, msg_dst_not_dir
    call print32
    mov esi, esp
    mov edi, current_path
    mov ecx, 128
    cld
    rep movsb
    add esp, 128
    pop dword [current_dir_sector]
    pop dword [current_dir_cluster]
    pop dword [selected_partition_start]
    pop dword [selected_partition]
    pop dword [selected_disk]
    jmp .done
.usage:
    mov esi, cut_usage_msg
    call print32
.done:
    popa
    ret
prompt_prefix  db 'yOS#', 0
prompt_suffix  db '> ', 0
welcome_msg_pm db 'Welcome to yOS!', 0x0d, 0x0a
               db 'by YuZhuohao', 0x0d, 0x0a, 0
cmd_cls        db 'cls', 0
cmd_time       db 'time', 0
cmd_shutdown   db 'shutdown', 0
cmd_reboot     db 'reboot', 0
cmd_output     db 'output', 0
cmd_help       db 'help', 0
cmd_dl_list    db 'dl list', 0
cmd_disk_list  db 'disk list', 0
cmd_disk_sel   db 'disk sel', 0
cmd_disk_part  db 'disk part', 0
cmd_disk_del_allpart db 'disk del allpart', 0
cmd_part_list  db 'part list', 0
cmd_part_sel   db 'part sel', 0
cmd_part_fm    db 'part fm', 0
cmd_part_del   db 'part del', 0
cmd_ls         db 'ls', 0
cmd_cd         db 'cd', 0
cmd_write      db 'write', 0
cmd_read       db 'read', 0
cmd_crdir      db 'crdir', 0
cmd_dedir      db 'dedir', 0
cmd_del        db 'del', 0
cmd_mem        db 'mem', 0
cmd_copy       db 'copy', 0
cmd_mov        db 'mov', 0
cmd_color      db 'color', 0
cmd_tui        db 'tui', 0
cmd_date       db 'date', 0
cmd_ver        db 'ver', 0
cmd_devinfo    db 'devinfo', 0
ver_msg        db 'yOS Version 0.48', 0x0d, 0x0a, 0
devinfo_header db '=== Device Information ===', 0x0d, 0x0a, 0
devinfo_cpu    db 'CPU: ', 0
devinfo_space  db ' ', 0
devinfo_family db 'Family ', 0
devinfo_model  db ' Model ', 0
devinfo_mem    db 'Memory: ', 0
devinfo_kb     db ' KB', 0x0d, 0x0a, 0
devinfo_display db 'Display: VGA Text 80x25', 0x0d, 0x0a, 0
devinfo_disks  db 'Disks:', 0x0d, 0x0a, 0
devinfo_mb     db ' MB', 0x0d, 0x0a, 0
cpu_vendor     times 13 db 0
unknown_msg    db 'Unknown command', 0x0d, 0x0a, 0
time_prefix    db 'Time: ', 0
date_prefix    db 'Date: ', 0
shutdown_msg   db 'Shutting down...', 0x0d, 0x0a, 0
reboot_msg     db 'Rebooting...', 0x0d, 0x0a, 0
mem_header     db ' PID  STATUS  MEM(K) NAME', 0x0d, 0x0a, 0
status_ready   db '  READY ', 0
status_run     db '  RUN   ', 0
mem_total_prefix db 'Memory: Total=', 0
mem_used_prefix  db '   Used=', 0
mem_free_prefix  db '   Free=', 0
copy_usage_msg db 'Usage: copy <src> <dst>', 0x0d, 0x0a, 0
cut_usage_msg  db 'Usage: mov <src> <dst>', 0x0d, 0x0a, 0
msg_dst_not_dir db 'Destination directory not found', 0x0d, 0x0a, 0
copy_temp_size     dd 0
copy_bytes_total   dd 0
copy_write_pos     dd 0
copy_first_cluster dd 0
copy_prev_cluster  dd 0
cut_src_path_save  dd 0
cut_dst_restore    dd 0
copy_src_path      times 128 db 0
copy_dst_path      times 128 db 0
copy_src_file_name times 12 db 0
wildcard_tmp       times 12 db 0
