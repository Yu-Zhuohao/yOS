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
