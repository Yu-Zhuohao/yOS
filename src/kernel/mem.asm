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
    mov edi, 0x100000
    mov cr3, edi
    mov ecx, 1024
    xor eax, eax
    rep stosd
    mov edi, 0x101000
    mov ecx, 1024 * 8
    mov eax, 0x00000003
.build_pt:
    stosd
    add eax, 0x1000
    loop .build_pt
    mov dword [0x100000 + 0*4], 0x101000 + 0x03
    mov dword [0x100000 + 1*4], 0x102000 + 0x03
    mov dword [0x100000 + 2*4], 0x103000 + 0x03
    mov dword [0x100000 + 3*4], 0x104000 + 0x03
    mov dword [0x100000 + 4*4], 0x105000 + 0x03
    mov dword [0x100000 + 5*4], 0x106000 + 0x03
    mov dword [0x100000 + 6*4], 0x107000 + 0x03
    mov dword [0x100000 + 7*4], 0x108000 + 0x03
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
