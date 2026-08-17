clear_screen:
    mov edi, 0xB8000
    mov ecx, 80*25
    mov ax, 0x0F20
    rep stosw
    mov dword [cursor_pos], 0
    call update_cursor
    ret

scroll_screen:
    pusha
    cld
    mov esi, 0xB8000 + 160
    mov edi, 0xB8000
    mov ecx, 80*24
    rep movsd
    mov edi, 0xB8000 + 80*24*2
    mov ecx, 80
    mov ax, 0x0F20
    rep stosw
    mov dword [cursor_pos], 80*24
    popa
    call update_cursor
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
    mov ah, 0x0F
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
    mov ah, 0x0F
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
    test al, 0x80
    jnz .read_loop
    call scancode_to_ascii
    cmp al, 0
    jz .read_loop
    cmp al, 0x20
    jb .read_loop
    cmp al, 0x7E
    ja .read_loop
    mov [edi], al
    inc edi
    inc ecx
    movzx eax, al
    mov ah, 0x0F
    mov ebx, [cursor_pos]
    shl ebx, 1
    add ebx, 0xB8000
    mov [ebx], ax
    inc dword [cursor_pos]
    call check_scroll
    call update_cursor
    jmp .read_loop
.shift_down:
    mov byte [shift_pressed], 1
    jmp .read_loop
.shift_up:
    mov byte [shift_pressed], 0
    jmp .read_loop
.backspace:
    cmp ecx, 0
    je .read_loop
    dec edi
    dec ecx
    dec dword [cursor_pos]
    mov eax, [cursor_pos]
    mov ebx, 0xB8000
    shl eax, 1
    add ebx, eax
    mov word [ebx], 0x0F20
    call update_cursor
    jmp .read_loop
.enter:
    mov byte [edi], 0
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
    jne .nomatch
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
    jmp .nomatch
.success:
    mov eax, 1
    jmp .done
.nomatch:
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
