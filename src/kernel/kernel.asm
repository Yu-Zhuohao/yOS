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



clear_screen:

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



keyboard_init:

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
    mov esi, input_buf
    add esi, ebx
    push edi
    mov edi, input_buf
    add edi, [input_len]
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
    mov ecx, 128
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



cmd_match:

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



ide_select_disk:

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



read_mbr:

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

    mov edi, sector_buffer

    mov ecx, 512

    xor al, al

    rep stosb

    mov byte [sector_buffer], 0xEB

    mov byte [sector_buffer + 1], 0x3C

    mov byte [sector_buffer + 2], 0x90

    mov edi, sector_buffer + 446

    mov byte [edi], 0x80

    mov byte [edi + 1], 0x01

    mov byte [edi + 2], 0x01

    mov byte [edi + 3], 0x00

    mov byte [edi + 4], 0x01

    mov byte [edi + 5], 0xFE

    mov byte [edi + 6], 0xFF

    mov byte [edi + 7], 0xFF

    mov dword [edi + 8], 1

    mov eax, [disk_size_sectors]

    dec eax

    mov [edi + 12], eax

    mov word [sector_buffer + 510], 0xAA55

    xor eax, eax

    mov ecx, 1

    mov esi, sector_buffer

    call ide_write_sectors

    popa

    ret



load_boot_sector:

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

    call load_boot_sector

    mov eax, [root_dir_start]

    mov [current_dir_cluster], dword 0

    mov [current_dir_sector], eax

    popa

    ret



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



list_directory:

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

    mov esi, edi

    mov ecx, 8

.name_part:

    lodsb

    cmp al, ' '

    je .name_skip

    call print_char

.name_skip:

    loop .name_part

    mov al, [edi + 8]

    cmp al, ' '

    je .no_ext

    mov al, '.'

    call print_char

    mov ecx, 3

    lea esi, [edi + 8]

.ext_part:

    lodsb

    cmp al, ' '

    je .ext_skip

    call print_char

.ext_skip:

    loop .ext_part

.no_ext:

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



init_drive_table:

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



part_list:

    pusha

    cmp byte [selected_disk], 0xFF

    je .no_disk

    call read_mbr

    mov esi, msg_part_list

    call print32

    mov ecx, 4

    xor ebx, ebx

.loop:

    mov eax, ebx

    shl eax, 4

    cmp byte [partition_table + eax], 0

    je .next

    push ebx

    push ecx

    mov eax, ebx

    inc eax

    call print_number

    mov al, ' '

    call print_char

    mov al, '-'

    call print_char

    mov al, ' '

    call print_char

    mov eax, ebx

    shl eax, 4

    movzx eax, byte [partition_table + eax + 4]

    call print_hex_byte

    mov al, ' '

    call print_char

    mov al, '('

    call print_char

    mov eax, ebx

    shl eax, 4

    mov eax, [partition_table + eax + 8]

    call print_number

    mov al, ' '

    call print_char

    mov eax, ebx

    shl eax, 4

    mov eax, [partition_table + eax + 12]

    call print_number

    mov al, ')'

    call print_char

    mov esi, newline

    call print32

    pop ecx

    pop ebx

.next:

    inc ebx

    dec ecx

    jnz .loop

    popa

    ret

.no_disk:

    mov esi, msg_no_disk_selected

    call print32

    popa

    ret



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

    pusha

    cmp byte [selected_partition], 0xFF

    je .no_part

    call format_fat12

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



ls_cmd:

    pusha

    cmp byte [selected_partition], 0xFF

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

    cmp byte [selected_partition], 0xFF

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

    push esi

    mov esi, ebx

    mov edi, tmp_filename

    call filename_to_83

    pop esi

    mov edi, tmp_filename

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

    cmp byte [selected_partition], 0xFF

    je .no_part

    mov esi, input_buf

    add esi, 4

    call skip_spaces_esi

    cmp byte [esi], 0

    je .no_arg

    call read_dir_sector

    mov edi, tmp_filename

    call filename_to_83

    mov esi, tmp_filename

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

    cmp byte [selected_partition], 0xFF

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

    cmp byte [selected_partition], 0xFF

    je .no_part

    mov esi, input_buf

    add esi, 5

    call skip_spaces_esi

    cmp byte [esi], 0

    je .no_arg

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

    cmp byte [selected_partition], 0xFF

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



copy_file_data:

    push ebx

    push ecx

    push edx

    push esi

    push edi

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

    xor eax, eax

    jmp .done

.error:

    mov eax, -1

.done:

    pop edi

    pop esi

    pop edx

    pop ecx

    pop ebx

    ret



resolve_path_to_dir:

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



auto_mount:

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



ls_header            db 'Name       Type', 0x0d, 0x0a, 0

type_dir             db '  <DIR>', 0

type_file            db '  <FILE>', 0



drive_table          times 256 db 0

current_drive        db 0

tmp_drive_letter     db 0

tmp_component        times 16 db 0

path_parse_pos       dd 0



msg_disk_list        db 'Disks:', 0x0d, 0x0a, 0

msg_disk_selected    db 'Disk selected: ', 0

msg_partitioned      db 'Disk partitioned.', 0x0d, 0x0a, 0

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



mem_init:

    pusha

    mov edi, 0x120000

    mov ecx, 512

    xor al, al

    rep stosb

    mov dword [total_kb], 2048

    mov dword [used_kb], 0

    mov dword [free_kb], 2048

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



proc_init:

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



help_pages:

    db 'cln        - Clear screen',0

    db 'time       - Show current time',0

    db 'shutdown   - Soft shutdown',0

    db 'reboot     - Reboot the system',0

    db 'output     - Print text',0

    db 'dl list    - List drive letters',0

    db 'disk list  - List disk drives',0

    db 'disk sel   - Select disk drive',0

    db 'disk part  - Partition disk (single)',0

    db 'part list  - List partitions',0

    db 'part sel   - Select partition',0

    db 'part fm    - Format as FAT12',0

    db 'ls         - List directory',0

    db 'cd         - Change directory',0

    db 'write      - Write file',0

    db 'read       - Read file',0

    db 'crdir      - Create directory',0

    db 'dedir      - Delete directory',0

    db 'del        - Delete file',0

    db 'mov        - Move file',0

    db 'mem        - Show memory usage',0

    db 'copy       - Copy file',0

    db 'color      - Set console color',0

    db 'tui        - Enter TUI mode',0

    db 'date       - Show current date',0

    db 'help       - Show this help',0

help_page_count equ 26

help_lines_per_page equ 5



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

    mov eax, help_page_count

    add eax, help_lines_per_page - 1

    mov ebx, help_lines_per_page

    xor edx, edx

    div ebx

    cmp ecx, eax

    jg .invalid_page

    dec ecx

    mov eax, help_lines_per_page

    mul ecx

    mov ebx, eax

    mov edx, help_page_count

    sub edx, ebx

    cmp edx, help_lines_per_page

    jle .set_lines

    mov edx, help_lines_per_page

.set_lines:

    mov ecx, edx

    mov esi, help_pages

    mov edi, ebx

    test edi, edi

    jz .print_loop

.skip_loop:

    lodsb

    cmp al, 0

    jne .skip_loop

    dec edi

    jnz .skip_loop

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



tui_cmd:
    call clear_screen
    pusha
    mov byte [tui_focus], 1
    mov byte [tui_exit], 0
.tui_loop:
    call tui_draw_main
    call tui_handle_main
    cmp byte [tui_exit], 1
    je .exit
    jmp .tui_loop
.exit:
    call clear_screen
    popa
    ret

tui_draw_main:
    pusha
    mov edi, 0xB8000
    mov ecx, 80*24
    mov ax, 0x1F20
    rep stosw
    mov edi, 0xB8000 + 2*80*2 + 30*2
    mov esi, tui_str_desktop
    mov ah, 0x1F
    call tui_put_str
    mov edi, 0xB8000 + 4*80*2 + 30*2
    mov esi, tui_str_calc
    mov ah, 0x1F
    call tui_put_str
    mov edi, 0xB8000 + 6*80*2 + 30*2
    mov esi, tui_str_notepad
    call tui_put_str
    mov edi, 0xB8000 + 8*80*2 + 30*2
    mov esi, tui_str_reboot
    call tui_put_str
    mov edi, 0xB8000 + 10*80*2 + 30*2
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
    mov al, [tui_focus]
    cmp al, 0
    je .focus_menu
    cmp al, 1
    je .focus_calc
    cmp al, 2
    je .focus_notepad
    cmp al, 3
    je .focus_reboot
    cmp al, 4
    je .focus_shutdown
    jmp .done
.focus_menu:
    mov edi, 0xB8000 + 24*80*2 + 1*2
    mov esi, tui_str_menu
    mov ah, 0x1F
    call tui_put_str
    jmp .done
.focus_calc:
    mov edi, 0xB8000 + 4*80*2 + 30*2
    mov esi, tui_str_calc
    mov ah, 0x3F
    call tui_put_str
    jmp .done
.focus_notepad:
    mov edi, 0xB8000 + 6*80*2 + 30*2
    mov esi, tui_str_notepad
    mov ah, 0x3F
    call tui_put_str
    jmp .done
.focus_reboot:
    mov edi, 0xB8000 + 8*80*2 + 30*2
    mov esi, tui_str_reboot
    mov ah, 0x3F
    call tui_put_str
    jmp .done
.focus_shutdown:
    mov edi, 0xB8000 + 10*80*2 + 30*2
    mov esi, tui_str_shutdown
    mov ah, 0x3F
    call tui_put_str
.done:
    popa
    ret

tui_handle_main:
    pusha
    call read_scancode
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
    inc byte [tui_focus]
    cmp byte [tui_focus], 5
    jne .done
    mov byte [tui_focus], 0
    jmp .done
.prev:
    dec byte [tui_focus]
    cmp byte [tui_focus], 0xFF
    jne .done
    mov byte [tui_focus], 4
    jmp .done
.enter:
    mov al, [tui_focus]
    cmp al, 0
    je .do_menu
    cmp al, 1
    je .do_calc
    cmp al, 2
    je .do_notepad
    cmp al, 3
    je .do_reboot
    cmp al, 4
    je .do_shutdown
    jmp .done
.do_menu:
    call tui_menu_popup
    jmp .done
.do_calc:
    call calc_app
    jmp .done
.do_notepad:
    call notepad_app
    jmp .done
.do_reboot:
    call reboot_pc
    jmp .done
.do_shutdown:
    call shutdown_pc
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
    mov byte [tui_exit], 1
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

calc_app:
    pusha
    mov dword [calc_accum], 0
    mov dword [calc_input], 0
    mov byte [calc_op], 0
    mov byte [calc_typing], 0
    mov byte [calc_focus], 1
    mov byte [calc_exit], 0
    mov byte [shift_pressed], 0
    mov byte [ctrl_pressed], 0
    call calc_update_display
.calc_loop:
    call calc_draw
    call calc_handle_input
    cmp byte [calc_exit], 1
    je .exit
    jmp .calc_loop
.exit:
    popa
    ret

calc_draw:
    pusha
    mov ebx, 3
.calc_body_row:
    mov edi, 0xB8000
    mov eax, ebx
    mov ecx, 80
    mul ecx
    shl eax, 1
    add edi, eax
    add edi, 20*2
    mov ecx, 40
    mov ax, 0x7020
    rep stosw
    inc ebx
    cmp ebx, 21
    jl .calc_body_row
    mov edi, 0xB8000 + 3*80*2 + 20*2
    mov ecx, 40
    mov ax, 0x1F20
    rep stosw
    mov edi, 0xB8000 + 3*80*2 + 21*2
    mov esi, calc_str_title
    mov ah, 0x1F
    call tui_put_str
    mov edi, 0xB8000 + 3*80*2 + 54*2
    mov esi, calc_str_close
    call tui_put_str
    mov edi, 0xB8000 + 4*80*2 + 20*2
    mov ecx, 40
    mov ax, 0x70DF
    rep stosw
    mov edi, 0xB8000 + 5*80*2 + 22*2
    mov ecx, 36
    mov ax, 0x7020
    rep stosw
    mov esi, calc_display_buf
    call str_len
    mov edi, 0xB8000 + 5*80*2 + 56*2
    sub edi, eax
    sub edi, eax
    mov ah, 0x70
    call tui_put_str
    mov edi, 0xB8000 + 8*80*2 + 24*2
    mov esi, calc_str_7
    mov ah, 0x70
    call tui_put_str
    mov edi, 0xB8000 + 8*80*2 + 29*2
    mov esi, calc_str_8
    call tui_put_str
    mov edi, 0xB8000 + 8*80*2 + 34*2
    mov esi, calc_str_9
    call tui_put_str
    mov edi, 0xB8000 + 8*80*2 + 39*2
    mov esi, calc_str_div
    call tui_put_str
    mov edi, 0xB8000 + 10*80*2 + 24*2
    mov esi, calc_str_4
    call tui_put_str
    mov edi, 0xB8000 + 10*80*2 + 29*2
    mov esi, calc_str_5
    call tui_put_str
    mov edi, 0xB8000 + 10*80*2 + 34*2
    mov esi, calc_str_6
    call tui_put_str
    mov edi, 0xB8000 + 10*80*2 + 39*2
    mov esi, calc_str_mul
    call tui_put_str
    mov edi, 0xB8000 + 12*80*2 + 24*2
    mov esi, calc_str_1
    call tui_put_str
    mov edi, 0xB8000 + 12*80*2 + 29*2
    mov esi, calc_str_2
    call tui_put_str
    mov edi, 0xB8000 + 12*80*2 + 34*2
    mov esi, calc_str_3
    call tui_put_str
    mov edi, 0xB8000 + 12*80*2 + 39*2
    mov esi, calc_str_sub
    call tui_put_str
    mov edi, 0xB8000 + 14*80*2 + 24*2
    mov esi, calc_str_0
    call tui_put_str
    mov edi, 0xB8000 + 14*80*2 + 29*2
    mov esi, calc_str_clr
    call tui_put_str
    mov edi, 0xB8000 + 14*80*2 + 34*2
    mov esi, calc_str_eq
    call tui_put_str
    mov edi, 0xB8000 + 14*80*2 + 39*2
    mov esi, calc_str_add
    call tui_put_str
    mov edi, 0xB8000 + 16*80*2 + 24*2
    mov esi, calc_str_back
    call tui_put_str
    mov al, [calc_focus]
    cmp al, 0
    je .f_close
    cmp al, 1
    je .f_7
    cmp al, 2
    je .f_8
    cmp al, 3
    je .f_9
    cmp al, 4
    je .f_div
    cmp al, 5
    je .f_4
    cmp al, 6
    je .f_5
    cmp al, 7
    je .f_6
    cmp al, 8
    je .f_mul
    cmp al, 9
    je .f_1
    cmp al, 10
    je .f_2
    cmp al, 11
    je .f_3
    cmp al, 12
    je .f_sub
    cmp al, 13
    je .f_0
    cmp al, 14
    je .f_clr
    cmp al, 15
    je .f_eq
    cmp al, 16
    je .f_add
    cmp al, 17
    je .f_back
    jmp .calc_done
.f_close:
    mov edi, 0xB8000 + 3*80*2 + 54*2
    mov esi, calc_str_close
    mov ah, 0x4F
    call tui_put_str
    jmp .calc_done
.f_7:
    mov edi, 0xB8000 + 8*80*2 + 24*2
    mov esi, calc_str_7
    mov ah, 0x1F
    call tui_put_str
    jmp .calc_done
.f_8:
    mov edi, 0xB8000 + 8*80*2 + 29*2
    mov esi, calc_str_8
    mov ah, 0x1F
    call tui_put_str
    jmp .calc_done
.f_9:
    mov edi, 0xB8000 + 8*80*2 + 34*2
    mov esi, calc_str_9
    mov ah, 0x1F
    call tui_put_str
    jmp .calc_done
.f_div:
    mov edi, 0xB8000 + 8*80*2 + 39*2
    mov esi, calc_str_div
    mov ah, 0x1F
    call tui_put_str
    jmp .calc_done
.f_4:
    mov edi, 0xB8000 + 10*80*2 + 24*2
    mov esi, calc_str_4
    mov ah, 0x1F
    call tui_put_str
    jmp .calc_done
.f_5:
    mov edi, 0xB8000 + 10*80*2 + 29*2
    mov esi, calc_str_5
    mov ah, 0x1F
    call tui_put_str
    jmp .calc_done
.f_6:
    mov edi, 0xB8000 + 10*80*2 + 34*2
    mov esi, calc_str_6
    mov ah, 0x1F
    call tui_put_str
    jmp .calc_done
.f_mul:
    mov edi, 0xB8000 + 10*80*2 + 39*2
    mov esi, calc_str_mul
    mov ah, 0x1F
    call tui_put_str
    jmp .calc_done
.f_1:
    mov edi, 0xB8000 + 12*80*2 + 24*2
    mov esi, calc_str_1
    mov ah, 0x1F
    call tui_put_str
    jmp .calc_done
.f_2:
    mov edi, 0xB8000 + 12*80*2 + 29*2
    mov esi, calc_str_2
    mov ah, 0x1F
    call tui_put_str
    jmp .calc_done
.f_3:
    mov edi, 0xB8000 + 12*80*2 + 34*2
    mov esi, calc_str_3
    mov ah, 0x1F
    call tui_put_str
    jmp .calc_done
.f_sub:
    mov edi, 0xB8000 + 12*80*2 + 39*2
    mov esi, calc_str_sub
    mov ah, 0x1F
    call tui_put_str
    jmp .calc_done
.f_0:
    mov edi, 0xB8000 + 14*80*2 + 24*2
    mov esi, calc_str_0
    mov ah, 0x1F
    call tui_put_str
    jmp .calc_done
.f_clr:
    mov edi, 0xB8000 + 14*80*2 + 29*2
    mov esi, calc_str_clr
    mov ah, 0x1F
    call tui_put_str
    jmp .calc_done
.f_eq:
    mov edi, 0xB8000 + 14*80*2 + 34*2
    mov esi, calc_str_eq
    mov ah, 0x1F
    call tui_put_str
    jmp .calc_done
.f_add:
    mov edi, 0xB8000 + 14*80*2 + 39*2
    mov esi, calc_str_add
    mov ah, 0x1F
    call tui_put_str
    jmp .calc_done
.f_back:
    mov edi, 0xB8000 + 16*80*2 + 24*2
    mov esi, calc_str_back
    mov ah, 0x1F
    call tui_put_str
.calc_done:
    popa
    ret

calc_handle_input:
    pusha
    call read_scancode
    cmp al, 0x1D
    je .ctrl_down
    cmp al, 0x9D
    je .ctrl_up
    cmp al, 0x2A
    je .shift_down
    cmp al, 0x36
    je .shift_down
    cmp al, 0xAA
    je .shift_up
    cmp al, 0xB6
    je .shift_up
    cmp al, 0x01
    je .esc
    cmp al, 0x0F
    je .tab
    cmp al, 0x1C
    je .enter
    cmp al, 0x0E
    je .backspace
    cmp al, 0x48
    je .up
    cmp al, 0x50
    je .down
    cmp al, 0x4B
    je .left
    cmp al, 0x4D
    je .right
    call scancode_to_ascii
    cmp al, 0
    je .done
    cmp al, '0'
    jb .check_op
    cmp al, '9'
    ja .check_op
    sub al, '0'
    movzx ebx, al
    call calc_digit
    jmp .done
.check_op:
    cmp al, '+'
    je .op_add
    cmp al, '-'
    je .op_sub
    cmp al, '*'
    je .op_mul
    cmp al, '/'
    je .op_div
    cmp al, '='
    je .equals
    cmp al, 'c'
    je .clear
    cmp al, 'C'
    je .clear
    jmp .done
.op_add:
    mov bl, 1
    call calc_operator
    jmp .done
.op_sub:
    mov bl, 2
    call calc_operator
    jmp .done
.op_mul:
    mov bl, 3
    call calc_operator
    jmp .done
.op_div:
    mov bl, 4
    call calc_operator
    jmp .done
.equals:
    call calc_equals
    jmp .done
.clear:
    call calc_clear
    jmp .done
.backspace:
    call calc_backspace
    jmp .done
.ctrl_down:
    mov byte [ctrl_pressed], 1
    jmp .done
.ctrl_up:
    mov byte [ctrl_pressed], 0
    jmp .done
.shift_down:
    mov byte [shift_pressed], 1
    jmp .done
.shift_up:
    mov byte [shift_pressed], 0
    jmp .done
.esc:
    mov byte [calc_exit], 1
    jmp .done
.tab:
    inc byte [calc_focus]
    cmp byte [calc_focus], 18
    jne .done
    mov byte [calc_focus], 0
    jmp .done
.up:
    movzx eax, byte [calc_focus]
    cmp eax, 0
    je .done
    cmp eax, 4
    jle .up_to_close
    cmp eax, 17
    je .up_back
    sub eax, 4
    mov [calc_focus], al
    jmp .done
.up_to_close:
    mov byte [calc_focus], 0
    jmp .done
.up_back:
    mov byte [calc_focus], 13
    jmp .done
.down:
    movzx eax, byte [calc_focus]
    cmp eax, 0
    je .down_to_first
    cmp eax, 13
    jge .down_check
    add eax, 4
    cmp eax, 17
    jg .down_to_back
    mov [calc_focus], al
    jmp .done
.down_to_first:
    mov byte [calc_focus], 1
    jmp .done
.down_check:
    cmp eax, 16
    jle .down_to_back
    jmp .done
.down_to_back:
    mov byte [calc_focus], 17
    jmp .done
.left:
    movzx eax, byte [calc_focus]
    cmp eax, 0
    je .done
    cmp eax, 17
    je .done
    cmp eax, 1
    je .done
    cmp eax, 5
    je .done
    cmp eax, 9
    je .done
    cmp eax, 13
    je .done
    dec eax
    mov [calc_focus], al
    jmp .done
.right:
    movzx eax, byte [calc_focus]
    cmp eax, 0
    je .done
    cmp eax, 17
    je .done
    cmp eax, 4
    je .done
    cmp eax, 8
    je .done
    cmp eax, 12
    je .done
    cmp eax, 16
    je .done
    inc eax
    mov [calc_focus], al
    jmp .done
.enter:
    cmp byte [ctrl_pressed], 1
    je .ctrl_enter
    movzx eax, byte [calc_focus]
    mov bl, [calc_btn_actions + eax]
    cmp bl, 0xFF
    je .btn_close
    cmp bl, 0xF8
    je .btn_back
    cmp bl, 0xF9
    je .btn_add
    cmp bl, 0xFA
    je .btn_eq
    cmp bl, 0xFB
    je .btn_clr
    cmp bl, 0xFC
    je .btn_sub
    cmp bl, 0xFD
    je .btn_mul
    cmp bl, 0xFE
    je .btn_div
    movzx ebx, bl
    call calc_digit
    jmp .done
.ctrl_enter:
    call calc_equals
    jmp .done
.btn_close:
    mov byte [calc_exit], 1
    jmp .done
.btn_back:
    call calc_backspace
    jmp .done
.btn_add:
    mov bl, 1
    call calc_operator
    jmp .done
.btn_eq:
    call calc_equals
    jmp .done
.btn_clr:
    call calc_clear
    jmp .done
.btn_sub:
    mov bl, 2
    call calc_operator
    jmp .done
.btn_mul:
    mov bl, 3
    call calc_operator
    jmp .done
.btn_div:
    mov bl, 4
    call calc_operator
.done:
    popa
    ret

calc_digit:
    pusha
    cmp byte [calc_typing], 0
    jne .append
    mov dword [calc_input], 0
    mov byte [calc_typing], 1
.append:
    mov eax, [calc_input]
    mov ecx, 10
    mul ecx
    add eax, ebx
    mov [calc_input], eax
    call calc_update_display
    popa
    ret

calc_operator:
    pusha
    cmp byte [calc_typing], 1
    jne .set_op
    cmp byte [calc_op], 0
    je .store_accum
    call calc_compute
    jmp .set_op
.store_accum:
    mov eax, [calc_input]
    mov [calc_accum], eax
.set_op:
    mov [calc_op], bl
    mov byte [calc_typing], 0
    call calc_update_display
    popa
    ret

calc_equals:
    pusha
    cmp byte [calc_op], 0
    je .done
    cmp byte [calc_typing], 0
    je .done
    call calc_compute
    mov byte [calc_op], 0
    mov byte [calc_typing], 0
    call calc_update_display
.done:
    popa
    ret

calc_clear:
    pusha
    mov dword [calc_accum], 0
    mov dword [calc_input], 0
    mov byte [calc_op], 0
    mov byte [calc_typing], 0
    call calc_update_display
    popa
    ret

calc_backspace:
    pusha
    cmp byte [calc_typing], 1
    jne .done
    mov eax, [calc_input]
    xor edx, edx
    mov ecx, 10
    div ecx
    mov [calc_input], eax
    call calc_update_display
.done:
    popa
    ret

calc_compute:
    pusha
    mov eax, [calc_accum]
    mov ebx, [calc_input]
    cmp byte [calc_op], 1
    je .add
    cmp byte [calc_op], 2
    je .sub
    cmp byte [calc_op], 3
    je .mul
    cmp byte [calc_op], 4
    je .div
    jmp .done
.add:
    add eax, ebx
    jmp .store
.sub:
    sub eax, ebx
    jmp .store
.mul:
    imul ebx
    jmp .store
.div:
    cmp ebx, 0
    je .done
    cdq
    idiv ebx
.store:
    mov [calc_accum], eax
    mov [calc_input], eax
.done:
    popa
    ret

calc_update_display:
    pusha
    mov edi, calc_display_buf
    cmp byte [calc_typing], 1
    je .show_input
    mov eax, [calc_accum]
    call int_to_string
    cmp byte [calc_op], 0
    je .done
    mov esi, calc_display_buf
    call str_len
    mov edi, calc_display_buf
    add edi, eax
    mov al, [calc_op]
    cmp al, 1
    je .op_plus
    cmp al, 2
    je .op_minus
    cmp al, 3
    je .op_mul
    cmp al, 4
    je .op_div
    jmp .done
.op_plus:
    mov al, '+'
    jmp .append_op
.op_minus:
    mov al, '-'
    jmp .append_op
.op_mul:
    mov al, '*'
    jmp .append_op
.op_div:
    mov al, '/'
.append_op:
    stosb
    mov al, 0
    stosb
    jmp .done
.show_input:
    mov eax, [calc_input]
    call int_to_string
.done:
    popa
    ret

int_to_string:
    pusha
    mov ecx, 0
    cmp eax, 0
    jge .positive
    mov byte [edi], '-'
    inc edi
    neg eax
.positive:
    mov ebx, 10
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
    stosb
    dec ecx
    jnz .write
    mov byte [edi], 0
    popa
    ret

notepad_app:
    pusha
    mov dword [notepad_len], 0
    mov dword [notepad_cursor], 0
    mov byte [notepad_buf], 0
    mov dword [notepad_undo_count], 0
    mov dword [notepad_redo_count], 0
    mov byte [notepad_exit], 0
    mov byte [ctrl_pressed], 0
    mov byte [shift_pressed], 0
.np_loop:
    call notepad_draw
    call notepad_handle
    cmp byte [notepad_exit], 1
    je .exit
    jmp .np_loop
.exit:
    call clear_screen
    popa
    ret

notepad_draw:
    pusha
    mov edi, 0xB8000
    mov ecx, 80*25
    mov ax, 0x1F20
    rep stosw
    mov edi, 0xB8000
    mov ecx, 80
    mov ax, 0x1F20
    rep stosw
    mov edi, 0xB8000 + 1*2
    mov esi, notepad_str_title
    mov ah, 0x1F
    call tui_put_str
    mov edi, 0xB8000 + 72*2
    mov esi, notepad_str_close
    call tui_put_str
    mov esi, notepad_buf
    mov edi, 0xB8000 + 80*2
    mov ah, 0x1F
    xor ecx, ecx
    xor edx, edx
    mov dword [notepad_disp_row], 0
    mov dword [notepad_disp_col], 0
.draw_loop:
    cmp ecx, [notepad_len]
    jge .draw_done
    mov al, [esi + ecx]
    cmp ecx, [notepad_cursor]
    jne .no_cursor_mark
    mov dword [notepad_cur_row], edx
    mov eax, [notepad_disp_col]
    mov [notepad_cur_col], eax
.no_cursor_mark:
    cmp al, 0x0A
    je .newline
    cmp al, 0x09
    je .tab
    mov [edi], al
    mov [edi+1], ah
    add edi, 2
    inc dword [notepad_disp_col]
    jmp .next_char
.newline:
    inc edx
    mov dword [notepad_disp_col], 0
    mov eax, edx
    mov ecx, 80
    mul ecx
    shl eax, 1
    mov edi, 0xB8000
    add edi, eax
    add edi, 80*2
    jmp .next_char
.tab:
    mov eax, [notepad_disp_col]
    add eax, 4
    and eax, 0xFFFFFFFC
    mov [notepad_disp_col], eax
    mov ebx, eax
    mov eax, edx
    mov ecx, 80
    mul ecx
    add eax, ebx
    shl eax, 1
    mov edi, 0xB8000
    add edi, eax
    add edi, 80*2
.next_char:
    inc ecx
    jmp .draw_loop
.draw_done:
    cmp ecx, [notepad_cursor]
    jne .set_hw_cursor
    mov dword [notepad_cur_row], edx
    mov eax, [notepad_disp_col]
    mov [notepad_cur_col], eax
.set_hw_cursor:
    mov eax, [notepad_cur_row]
    mov ecx, 80
    mul ecx
    add eax, [notepad_cur_col]
    add eax, 80
    mov [cursor_pos], eax
    call update_cursor
    popa
    ret

notepad_handle:
    pusha
    call read_scancode
    cmp al, 0x1D
    je .ctrl_down
    cmp al, 0x9D
    je .ctrl_up
    cmp al, 0x2A
    je .shift_down
    cmp al, 0x36
    je .shift_down
    cmp al, 0xAA
    je .shift_up
    cmp al, 0xB6
    je .shift_up
    cmp al, 0x01
    je .esc
    cmp al, 0x1C
    je .enter
    cmp al, 0x0E
    je .backspace
    cmp al, 0x4B
    je .left
    cmp al, 0x4D
    je .right
    cmp al, 0x48
    je .up
    cmp al, 0x50
    je .down
    cmp al, 0x0F
    je .tab_key
    cmp byte [ctrl_pressed], 1
    jne .check_char
    cmp al, 0x1F
    je .ctrl_s
    cmp al, 0x18
    je .ctrl_o
    cmp al, 0x2C
    je .ctrl_z
    cmp al, 0x15
    je .ctrl_y
.check_char:
    test al, 0x80
    jnz .done
    call scancode_to_ascii
    cmp al, 0
    je .done
    cmp al, 0x20
    jb .done
    cmp al, 0x7E
    ja .done
    call notepad_undo_push
    call notepad_insert_char
    jmp .done
.ctrl_down:
    mov byte [ctrl_pressed], 1
    jmp .done
.ctrl_up:
    mov byte [ctrl_pressed], 0
    jmp .done
.shift_down:
    mov byte [shift_pressed], 1
    jmp .done
.shift_up:
    mov byte [shift_pressed], 0
    jmp .done
.esc:
    mov byte [notepad_exit], 1
    jmp .done
.enter:
    call notepad_undo_push
    mov al, 0x0A
    call notepad_insert_char
    jmp .done
.tab_key:
    call notepad_undo_push
    mov al, 0x09
    call notepad_insert_char
    jmp .done
.backspace:
    cmp dword [notepad_cursor], 0
    je .done
    call notepad_undo_push
    call notepad_delete_char
    jmp .done
.left:
    cmp dword [notepad_cursor], 0
    je .done
    dec dword [notepad_cursor]
    jmp .done
.right:
    mov eax, [notepad_cursor]
    cmp eax, [notepad_len]
    jge .done
    inc dword [notepad_cursor]
    jmp .done
.up:
    call notepad_cursor_up
    jmp .done
.down:
    call notepad_cursor_down
    jmp .done
.ctrl_s:
    call notepad_save_dialog
    jmp .done
.ctrl_o:
    call notepad_open_dialog
    jmp .done
.ctrl_z:
    call notepad_undo
    jmp .done
.ctrl_y:
    call notepad_redo
.done:
    popa
    ret

notepad_insert_char:
    pusha
    mov ebx, [notepad_cursor]
    mov esi, notepad_buf
    add esi, [notepad_len]
    mov edi, esi
    inc edi
    mov ecx, [notepad_len]
    sub ecx, ebx
    std
    rep movsb
    cld
    mov byte [notepad_buf + ebx], al
    inc dword [notepad_len]
    inc dword [notepad_cursor]
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
    cld
    rep movsb
    dec dword [notepad_len]
    dec dword [notepad_cursor]
    mov ebx, [notepad_len]
    mov byte [notepad_buf + ebx], 0
    popa
    ret

notepad_cursor_up:
    pusha
    mov eax, [notepad_cursor]
    mov ebx, 0
    mov ecx, 0
.find_cur_line:
    cmp ecx, eax
    jge .found_cur
    cmp byte [notepad_buf + ecx], 0x0A
    je .found_nl
    inc ecx
    jmp .find_cur_line
.found_nl:
    mov ebx, ecx
    inc ecx
    jmp .find_cur_line
.found_cur:
    cmp ebx, 0
    je .up_done
    mov edx, eax
    sub edx, ebx
    dec edx
    mov esi, notepad_buf
    add esi, ebx
    dec esi
    mov ecx, ebx
    dec ecx
    mov ebx, 0
.find_prev_line:
    cmp ecx, 0
    je .found_prev
    cmp byte [notepad_buf + ecx - 1], 0x0A
    je .found_prev
    dec ecx
    jmp .find_prev_line
.found_prev:
    mov eax, ebx
    add eax, edx
    cmp eax, [notepad_cursor]
    jge .up_done
    mov [notepad_cursor], eax
.up_done:
    popa
    ret

notepad_cursor_down:
    pusha
    mov eax, [notepad_cursor]
    mov ecx, eax
    mov ebx, 0
.find_next_nl:
    cmp ecx, [notepad_len]
    jge .down_done
    cmp byte [notepad_buf + ecx], 0x0A
    je .found_next
    inc ecx
    jmp .find_next_nl
.found_next:
    mov ebx, ecx
    inc ebx
    mov edx, eax
    mov ecx, 0
.find_cur_start:
    cmp ecx, eax
    jge .calc_col
    cmp byte [notepad_buf + ecx], 0x0A
    je .nl_before
    inc ecx
    jmp .find_cur_start
.nl_before:
    inc ecx
    jmp .find_cur_start
.calc_col:
    sub edx, ecx
    mov eax, ebx
    add eax, edx
    cmp eax, [notepad_len]
    jg .set_len
    mov ecx, ebx
.check_nl:
    cmp ecx, eax
    jge .set_cursor
    cmp byte [notepad_buf + ecx], 0x0A
    je .set_cursor_here
    inc ecx
    jmp .check_nl
.set_cursor_here:
    mov eax, ecx
.set_cursor:
    mov [notepad_cursor], eax
    jmp .down_done
.set_len:
    mov eax, [notepad_len]
    mov [notepad_cursor], eax
.down_done:
    popa
    ret

notepad_undo_push:
    pusha
    mov eax, [notepad_undo_count]
    cmp eax, 4
    jl .no_shift
    mov esi, notepad_undo_stack + 2048
    mov edi, notepad_undo_stack
    mov ecx, 2048 * 3
    cld
    rep movsb
    dec dword [notepad_undo_count]
.no_shift:
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
    je .undo_done
    dec dword [notepad_undo_count]
    mov eax, [notepad_undo_count]
    mov esi, notepad_buf
    mov edi, notepad_redo_stack
    mov ecx, 2048
    mov ebx, [notepad_redo_count]
    cmp ebx, 4
    jl .redo_no_shift
    mov esi, notepad_redo_stack + 2048
    mov edi, notepad_redo_stack
    mov ecx, 2048 * 3
    cld
    rep movsb
    dec dword [notepad_redo_count]
    mov ebx, [notepad_redo_count]
.redo_no_shift:
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
    mov [notepad_cursor], eax
.undo_done:
    popa
    ret

notepad_redo:
    pusha
    cmp dword [notepad_redo_count], 0
    je .redo_done
    dec dword [notepad_redo_count]
    mov eax, [notepad_redo_count]
    mov esi, notepad_buf
    mov edi, notepad_undo_stack
    mov ecx, 2048
    mov ebx, [notepad_undo_count]
    cmp ebx, 4
    jl .undo_no_shift
    mov esi, notepad_undo_stack + 2048
    mov edi, notepad_undo_stack
    mov ecx, 2048 * 3
    cld
    rep movsb
    dec dword [notepad_undo_count]
    mov ebx, [notepad_undo_count]
.undo_no_shift:
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
    mov [notepad_cursor], eax
.redo_done:
    popa
    ret

notepad_save_dialog:
    pusha
    mov byte [notepad_dlg_mode], 0
    call notepad_file_dialog
    cmp byte [notepad_dlg_result], 0
    je .save_cancel
    mov esi, notepad_dlg_filename
    mov edi, notepad_buf
    mov ecx, [notepad_len]
    call notepad_write_file
.save_cancel:
    popa
    ret

notepad_open_dialog:
    pusha
    mov byte [notepad_dlg_mode], 1
    call notepad_file_dialog
    cmp byte [notepad_dlg_result], 0
    je .open_cancel
    mov esi, notepad_dlg_filename
    mov edi, notepad_buf
    call notepad_read_file
    mov esi, notepad_buf
    call str_len
    mov [notepad_len], eax
    mov [notepad_cursor], eax
.open_cancel:
    popa
    ret

notepad_file_dialog:
    pusha
    mov byte [notepad_dlg_focus], 0
    mov byte [notepad_dlg_exit], 0
    mov byte [notepad_dlg_result], 0
    mov byte [notepad_dlg_filename], 0
    call notepad_collect_dir
.dlg_loop:
    call notepad_draw
    call dlg_draw
    call dlg_handle
    cmp byte [notepad_dlg_exit], 1
    je .dlg_exit
    jmp .dlg_loop
.dlg_exit:
    popa
    ret

dlg_draw:
    pusha
    mov ebx, 4
.dlg_row:
    mov edi, 0xB8000
    mov eax, ebx
    mov ecx, 80
    mul ecx
    shl eax, 1
    add edi, eax
    add edi, 10*2
    mov ecx, 60
    mov ax, 0x7020
    rep stosw
    inc ebx
    cmp ebx, 21
    jl .dlg_row
    mov edi, 0xB8000 + 4*80*2 + 10*2
    mov ecx, 60
    mov ax, 0x1F20
    rep stosw
    mov edi, 0xB8000 + 4*80*2 + 11*2
    cmp byte [notepad_dlg_mode], 0
    je .save_title
    mov esi, dlg_str_open_title
    jmp .title_done
.save_title:
    mov esi, dlg_str_save_title
.title_done:
    mov ah, 0x1F
    call tui_put_str
    mov edi, 0xB8000 + 6*80*2 + 12*2
    mov esi, dlg_str_files
    mov ah, 0x70
    call tui_put_str
    xor ebx, ebx
.file_loop:
    cmp ebx, [notepad_dir_count]
    jge .file_done
    cmp ebx, 8
    jge .file_done
    mov eax, ebx
    shl eax, 2
    mov esi, notepad_dir_entries
    add esi, eax
    mov eax, [esi]
    mov esi, dir_buffer
    add esi, eax
    mov edi, 0xB8000
    mov eax, ebx
    add eax, 7
    mov ecx, 80
    mul ecx
    shl eax, 1
    add edi, eax
    add edi, 14*2
    mov ah, 0x70
    mov ecx, 8
.name_loop:
    lodsb
    cmp al, ' '
    je .name_skip
    mov [edi], al
    mov [edi+1], ah
    add edi, 2
.name_skip:
    loop .name_loop
    mov al, [esi - 8 + 8]
    cmp al, ' '
    je .no_ext
    mov al, '.'
    mov [edi], al
    mov [edi+1], ah
    add edi, 2
    mov ecx, 3
    lea esi, [esi - 8 + 8]
.ext_loop:
    lodsb
    cmp al, ' '
    je .ext_skip
    mov [edi], al
    mov [edi+1], ah
    add edi, 2
.ext_skip:
    loop .ext_loop
.no_ext:
    mov al, [esi - 11 + 11]
    test al, 0x10
    jz .file_entry
    mov al, '/'
    mov [edi], al
    mov [edi+1], ah
.file_entry:
    inc ebx
    jmp .file_loop
.file_done:
    mov eax, [notepad_dir_sel]
    cmp eax, [notepad_dir_count]
    jl .sel_valid
    mov dword [notepad_dir_sel], 0
.sel_valid:
    mov eax, [notepad_dir_sel]
    cmp eax, 8
    jge .no_highlight
    mov edi, 0xB8000
    add eax, 7
    mov ecx, 80
    mul ecx
    shl eax, 1
    add edi, eax
    add edi, 13*2
    mov ecx, 50
    mov ax, 0x1F20
    rep stosw
    mov eax, [notepad_dir_sel]
    shl eax, 2
    mov esi, notepad_dir_entries
    add esi, eax
    mov eax, [esi]
    mov esi, dir_buffer
    add esi, eax
    mov edi, 0xB8000
    mov eax, [notepad_dir_sel]
    add eax, 7
    mov ecx, 80
    mul ecx
    shl eax, 1
    add edi, eax
    add edi, 14*2
    mov ah, 0x1F
    mov ecx, 8
.hl_name:
    lodsb
    cmp al, ' '
    je .hl_skip
    mov [edi], al
    mov [edi+1], ah
    add edi, 2
.hl_skip:
    loop .hl_name
    mov al, [esi - 8 + 8]
    cmp al, ' '
    je .hl_noext
    mov al, '.'
    mov [edi], al
    mov [edi+1], ah
    add edi, 2
    mov ecx, 3
    lea esi, [esi - 8 + 8]
.hl_ext:
    lodsb
    cmp al, ' '
    je .hl_extskip
    mov [edi], al
    mov [edi+1], ah
    add edi, 2
.hl_extskip:
    loop .hl_ext
.hl_noext:
    mov al, [esi - 11 + 11]
    test al, 0x10
    jz .no_highlight
    mov al, '/'
    mov [edi], al
    mov [edi+1], ah
.no_highlight:
    mov edi, 0xB8000 + 18*80*2 + 12*2
    mov esi, dlg_str_filename
    mov ah, 0x70
    call tui_put_str
    mov edi, 0xB8000 + 18*80*2 + 22*2
    mov ecx, 30
    mov ax, 0x7020
    rep stosw
    mov esi, notepad_dlg_filename
    mov edi, 0xB8000 + 18*80*2 + 22*2
    mov ah, 0x70
    call tui_put_str
    mov edi, 0xB8000 + 20*80*2 + 20*2
    cmp byte [notepad_dlg_mode], 0
    je .save_btn
    mov esi, dlg_str_open
    jmp .btn_done
.save_btn:
    mov esi, dlg_str_save
.btn_done:
    mov ah, 0x70
    call tui_put_str
    mov edi, 0xB8000 + 20*80*2 + 35*2
    mov esi, dlg_str_cancel
    call tui_put_str
    mov al, [notepad_dlg_focus]
    cmp al, 0
    je .focus_list
    cmp al, 1
    je .focus_name
    cmp al, 2
    je .focus_ok
    cmp al, 3
    je .focus_cancel
    jmp .dlg_done
.focus_list:
    mov edi, 0xB8000 + 6*80*2 + 12*2
    mov esi, dlg_str_files
    mov ah, 0x1F
    call tui_put_str
    jmp .dlg_done
.focus_name:
    mov edi, 0xB8000 + 18*80*2 + 12*2
    mov esi, dlg_str_filename
    mov ah, 0x1F
    call tui_put_str
    jmp .dlg_done
.focus_ok:
    mov edi, 0xB8000 + 20*80*2 + 20*2
    cmp byte [notepad_dlg_mode], 0
    je .ok_save
    mov esi, dlg_str_open
    jmp .ok_done
.ok_save:
    mov esi, dlg_str_save
.ok_done:
    mov ah, 0x1F
    call tui_put_str
    jmp .dlg_done
.focus_cancel:
    mov edi, 0xB8000 + 20*80*2 + 35*2
    mov esi, dlg_str_cancel
    mov ah, 0x1F
    call tui_put_str
.dlg_done:
    popa
    ret

dlg_handle:
    pusha
    call read_scancode
    cmp al, 0x0F
    je .tab
    cmp al, 0x01
    je .esc
    cmp al, 0x1C
    je .enter
    cmp al, 0x48
    je .up
    cmp al, 0x50
    je .down
    cmp al, 0x0E
    je .backspace
    cmp byte [notepad_dlg_focus], 1
    jne .check_done
    test al, 0x80
    jnz .done
    call scancode_to_ascii
    cmp al, 0
    je .done
    cmp al, 0x20
    jb .done
    cmp al, 0x7E
    ja .done
    mov esi, notepad_dlg_filename
    call str_len
    cmp eax, 28
    jge .done
    mov byte [notepad_dlg_filename + eax], al
    mov byte [notepad_dlg_filename + eax + 1], 0
    jmp .done
.tab:
    inc byte [notepad_dlg_focus]
    cmp byte [notepad_dlg_focus], 4
    jne .done
    mov byte [notepad_dlg_focus], 0
    jmp .done
.esc:
    mov byte [notepad_dlg_exit], 1
    jmp .done
.up:
    cmp byte [notepad_dlg_focus], 0
    jne .done
    cmp dword [notepad_dir_sel], 0
    je .done
    dec dword [notepad_dir_sel]
    jmp .done
.down:
    cmp byte [notepad_dlg_focus], 0
    jne .done
    mov eax, [notepad_dir_sel]
    inc eax
    cmp eax, [notepad_dir_count]
    jge .done
    inc dword [notepad_dir_sel]
    jmp .done
.backspace:
    cmp byte [notepad_dlg_focus], 1
    jne .done
    mov esi, notepad_dlg_filename
    call str_len
    cmp eax, 0
    je .done
    dec eax
    mov byte [notepad_dlg_filename + eax], 0
    jmp .done
.enter:
    mov al, [notepad_dlg_focus]
    cmp al, 0
    je .enter_list
    cmp al, 1
    je .enter_name
    cmp al, 2
    je .enter_ok
    cmp al, 3
    je .enter_cancel
    jmp .done
.enter_list:
    mov eax, [notepad_dir_sel]
    cmp eax, [notepad_dir_count]
    jge .done
    mov edx, 4
    mul edx
    mov esi, notepad_dir_entries
    add esi, eax
    mov eax, [esi]
    mov esi, dir_buffer
    add esi, eax
    mov al, [esi + 11]
    test al, 0x10
    jnz .enter_dir
    mov ecx, 8
    lea edi, [notepad_dlg_filename]
    push esi
    mov ecx, 8
.copy_name:
    lodsb
    cmp al, ' '
    je .copy_skip
    stosb
.copy_skip:
    loop .copy_name
    mov al, [esi]
    cmp al, ' '
    je .copy_noext
    mov al, '.'
    stosb
    mov ecx, 3
.copy_ext:
    lodsb
    cmp al, ' '
    je .copy_extskip
    stosb
.copy_extskip:
    loop .copy_ext
.copy_noext:
    mov byte [edi], 0
    pop esi
    jmp .done
.enter_dir:
    mov edi, notepad_dlg_tmpname
    mov ecx, 8
    push esi
.copy_dirname:
    lodsb
    cmp al, ' '
    je .copy_dirskip
    stosb
.copy_dirskip:
    loop .copy_dirname
    mov byte [edi], 0
    pop esi
    mov esi, notepad_dlg_tmpname
    call cd_directory
    call notepad_collect_dir
    mov dword [notepad_dir_sel], 0
    jmp .done
.enter_name:
    mov byte [notepad_dlg_focus], 2
    jmp .done
.enter_ok:
    cmp byte [notepad_dlg_filename], 0
    je .done
    mov byte [notepad_dlg_result], 1
    mov byte [notepad_dlg_exit], 1
    jmp .done
.enter_cancel:
    mov byte [notepad_dlg_exit], 1
.check_done:
.done:
    popa
    ret

notepad_collect_dir:
    pusha
    call read_dir_sector
    mov dword [notepad_dir_count], 0
    mov dword [notepad_dir_sel], 0
    mov ecx, [fat_root_entries]
    cmp dword [current_dir_cluster], 0
    jne .data_dir
    mov ecx, [fat_root_entries]
    jmp .collect
.data_dir:
    mov ecx, 224
.collect:
    xor ebx, ebx
.loop:
    cmp ebx, ecx
    jge .done
    mov eax, ebx
    mov edx, 32
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
    cmp dword [notepad_dir_count], 32
    jge .done
    mov edx, [notepad_dir_count]
    mov esi, notepad_dir_entries
    add esi, edx
    add esi, edx
    add esi, edx
    add esi, edx
    mov [esi], eax
    inc dword [notepad_dir_count]
.next:
    inc ebx
    jmp .loop
.done:
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

notepad_write_file:
    pusha
    push esi
    push edi
    mov esi, edi
    mov edi, tmp_filename
    call filename_to_83
    pop edi
    push edi
    mov esi, tmp_filename
    call find_dir_entry
    pop edi
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
    je .done
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
    call notepad_copy_to_sector
    mov esi, sector_buffer
    call ide_write_sectors
    jmp .done
.create_new:
    call find_free_cluster
    cmp eax, 0
    je .done
    mov ebx, eax
    push ebx
    mov eax, ebx
    mov ebx, 0x0FFF
    call set_next_cluster
    pop ebx
    call write_fat
    call find_free_dir_entry
    cmp eax, -1
    je .done
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
    call notepad_copy_to_sector
    mov esi, sector_buffer
    call ide_write_sectors
.done:
    pop esi
    popa
    ret

notepad_copy_to_sector:
    pusha
    mov ecx, 512
    mov al, 0
    rep stosb
    mov edi, sector_buffer
    mov esi, notepad_buf
    mov ecx, [notepad_len]
    cmp ecx, 512
    jle .copy_ok
    mov ecx, 512
.copy_ok:
    cld
    rep movsb
    popa
    ret

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

tui_draw_datetime:
    pusha
    push edi
    mov al, 0x04
    out 0x70, al
    in al, 0x71
    mov [tui_tmp_hour], al
    mov al, 0x02
    out 0x70, al
    in al, 0x71
    mov [tui_tmp_min], al
    mov al, 0x00
    out 0x70, al
    in al, 0x71
    mov [tui_tmp_sec], al
    mov al, 0x32
    out 0x70, al
    in al, 0x71
    mov [tui_tmp_cent], al
    mov al, 0x09
    out 0x70, al
    in al, 0x71
    mov [tui_tmp_year], al
    mov al, 0x08
    out 0x70, al
    in al, 0x71
    mov [tui_tmp_mon], al
    mov al, 0x07
    out 0x70, al
    in al, 0x71
    mov [tui_tmp_day], al
    pop edi
    mov al, [tui_tmp_hour]
    call tui_put_bcd
    mov al, ':'
    stosw
    mov al, [tui_tmp_min]
    call tui_put_bcd
    mov al, ':'
    stosw
    mov al, [tui_tmp_sec]
    call tui_put_bcd
    mov al, ' '
    stosw
    mov al, [tui_tmp_cent]
    call tui_put_bcd
    mov al, [tui_tmp_year]
    call tui_put_bcd
    mov al, '-'
    stosw
    mov al, [tui_tmp_mon]
    call tui_put_bcd
    mov al, '-'
    stosw
    mov al, [tui_tmp_day]
    call tui_put_bcd
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

tui_str_menu      db '[ Menu ]',0
tui_str_desktop   db 'yOS Desktop',0
tui_str_calc      db '[ Calculator ]',0
tui_str_notepad   db '[ Notepad ]',0
tui_str_reboot    db '[ Reboot ]',0
tui_str_shutdown  db '[ Shutdown ]',0
tui_focus         db 0
tui_exit          db 0
tui_tmp_hour      db 0
tui_tmp_min       db 0
tui_tmp_sec       db 0
tui_tmp_cent      db 0
tui_tmp_year      db 0
tui_tmp_mon       db 0
tui_tmp_day       db 0

menu_str_title    db 'Menu',0
menu_str_back     db '[ Back to CLI ]',0
menu_str_reboot   db '[ Reboot ]',0
menu_str_shutdown db '[ Shutdown ]',0
menu_focus        db 0
menu_exit         db 0

calc_str_close    db '[X]',0
calc_str_title    db 'Calculator',0
calc_str_0        db '[0]',0
calc_str_1        db '[1]',0
calc_str_2        db '[2]',0
calc_str_3        db '[3]',0
calc_str_4        db '[4]',0
calc_str_5        db '[5]',0
calc_str_6        db '[6]',0
calc_str_7        db '[7]',0
calc_str_8        db '[8]',0
calc_str_9        db '[9]',0
calc_str_add      db '[+]',0
calc_str_sub      db '[-]',0
calc_str_mul      db '[*]',0
calc_str_div      db '[/]',0
calc_str_eq       db '[=]',0
calc_str_clr      db '[C]',0
calc_str_back     db '[Back]',0
calc_btn_actions  db 0xFF,7,8,9,0xFE,4,5,6,0xFD,1,2,3,0xFC,0,0xFB,0xFA,0xF9,0xF8
calc_accum        dd 0
calc_input        dd 0
calc_op           db 0
calc_typing       db 0
calc_focus        db 0
calc_exit         db 0
calc_display_buf  times 16 db 0
ctrl_pressed      db 0

notepad_str_title db 'Notepad',0
notepad_str_close db '[X]',0
notepad_buf       times 2048 db 0
notepad_len       dd 0
notepad_cursor    dd 0
notepad_exit      db 0
notepad_disp_row  dd 0
notepad_disp_col  dd 0
notepad_cur_row   dd 0
notepad_cur_col   dd 0
notepad_undo_stack times 8192 db 0
notepad_undo_count dd 0
notepad_redo_stack times 8192 db 0
notepad_redo_count dd 0
notepad_dlg_mode  db 0
notepad_dlg_focus db 0
notepad_dlg_exit  db 0
notepad_dlg_result db 0
notepad_dlg_filename times 32 db 0
notepad_dlg_tmpname times 16 db 0
notepad_dir_entries times 128 db 0
notepad_dir_count dd 0
notepad_dir_sel   dd 0
dlg_str_save_title db 'Save File',0
dlg_str_open_title db 'Open File',0
dlg_str_files     db 'Files:',0
dlg_str_filename  db 'Name:',0
dlg_str_save      db '[ Save ]',0
dlg_str_open      db '[ Open ]',0
dlg_str_cancel    db '[ Cancel ]',0

history_buf       times 1024 db 0
history_count     dd 0
history_pos       dd 0
history_temp      times 128 db 0

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

    mov edi, cmd_cln

    call cmd_match

    cmp eax, 1

    je .do_cln

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

    mov esi, unknown_msg

    call print32

    jmp cmd_loop

.do_cln:

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

.do_part_list:

    call part_list

    jmp cmd_loop

.do_part_sel:

    call part_select

    jmp cmd_loop

.do_part_fm:

    call part_format

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

    call print_number

    pop ecx

    mov al, ' '

    call print_char

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

    call print_number

    pop eax

    cmp eax, 10

    jl .pad3

    cmp eax, 100

    jl .pad2

    cmp eax, 1000

    jl .pad1

    jmp .pad_done

.pad3:

    mov al, ' '

    call print_char

.pad2:

    mov al, ' '

    call print_char

.pad1:

    mov al, ' '

    call print_char

.pad_done:

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



copy_cmd:

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



cmd_cln        db 'cln', 0

cmd_time       db 'time', 0

cmd_shutdown   db 'shutdown', 0

cmd_reboot     db 'reboot', 0

cmd_output     db 'output', 0

cmd_help       db 'help', 0

cmd_dl_list    db 'dl list', 0

cmd_disk_list  db 'disk list', 0

cmd_disk_sel   db 'disk sel', 0

cmd_disk_part  db 'disk part', 0

cmd_part_list  db 'part list', 0

cmd_part_sel   db 'part sel', 0

cmd_part_fm    db 'part fm', 0

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



unknown_msg    db 'Unknown command', 0x0d, 0x0a, 0

time_prefix    db 'Time: ', 0

date_prefix    db 'Date: ', 0

shutdown_msg   db 'Shutting down...', 0x0d, 0x0a, 0

reboot_msg     db 'Rebooting...', 0x0d, 0x0a, 0



mem_header     db 'PID  STATUS  MEM(K)  NAME', 0x0d, 0x0a, 0

status_ready   db 'READY ', 0

status_run     db 'RUN   ', 0

mem_total_prefix db 'Memory: Total=', 0

mem_used_prefix  db 'K Used=', 0

mem_free_prefix  db 'K Free=', 0



copy_usage_msg db 'Usage: copy <src> <dst>', 0x0d, 0x0a, 0

cut_usage_msg  db 'Usage: mov <src> <dst>', 0x0d, 0x0a, 0

msg_dst_not_dir db 'Destination directory not found', 0x0d, 0x0a, 0

msg_no_match    db 'No files matched', 0x0d, 0x0a, 0



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