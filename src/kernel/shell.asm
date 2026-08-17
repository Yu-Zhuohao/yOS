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
    mov edi, cmd_cut
    call cmd_match
    cmp eax, 1
    je .do_cut
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
    mov esi, help_title
    call print32
    mov esi, help_cln
    call print32
    mov esi, help_time
    call print32
    mov esi, help_shutdown
    call print32
    mov esi, help_reboot
    call print32
    mov esi, help_output
    call print32
    mov esi, help_dl_list
    call print32
    mov esi, help_disk_list
    call print32
    mov esi, help_disk_sel
    call print32
    mov esi, help_disk_part
    call print32
    mov esi, help_part_list
    call print32
    mov esi, help_part_sel
    call print32
    mov esi, help_part_fm
    call print32
    mov esi, help_ls
    call print32
    mov esi, help_cd
    call print32
    mov esi, help_write
    call print32
    mov esi, help_read
    call print32
    mov esi, help_crdir
    call print32
    mov esi, help_dedir
    call print32
    mov esi, help_del
    call print32
    mov esi, help_mem
    call print32
    mov esi, help_copy
    call print32
    mov esi, help_cut
    call print32
    mov esi, help_help
    call print32
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
.do_cut:
    call cut_cmd
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
    call print_number
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
    call print_number
    mov al, ' '
    call print_char
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
help_title     db 'Commands:', 0x0d, 0x0a, 0
help_cln       db '  cln      - Clear screen', 0x0d, 0x0a, 0
help_time      db '  time     - Show current time', 0x0d, 0x0a, 0
help_shutdown  db '  shutdown - Soft shutdown', 0x0d, 0x0a, 0
help_reboot    db '  reboot   - Reboot the system', 0x0d, 0x0a, 0
help_output    db '  output   - Print text', 0x0d, 0x0a, 0
help_dl_list   db '  dl list  - List drive letters', 0x0d, 0x0a, 0
help_disk_list db '  disk list       - List disk drives', 0x0d, 0x0a, 0
help_disk_sel  db '  disk sel <n>    - Select disk drive', 0x0d, 0x0a, 0
help_disk_part db '  disk part       - Partition disk (single)', 0x0d, 0x0a, 0
help_part_list db '  part list       - List partitions', 0x0d, 0x0a, 0
help_part_sel  db '  part sel <n>    - Select partition', 0x0d, 0x0a, 0
help_part_fm   db '  part fm         - Format as FAT12', 0x0d, 0x0a, 0
help_ls        db '  ls              - List directory', 0x0d, 0x0a, 0
help_cd        db '  cd <path>       - Change directory', 0x0d, 0x0a, 0
help_write     db '  write <text> -2 <file> - Write file', 0x0d, 0x0a, 0
help_read      db '  read <file>     - Read file', 0x0d, 0x0a, 0
help_crdir     db '  crdir <name>    - Create directory', 0x0d, 0x0a, 0
help_dedir     db '  dedir <name>    - Delete directory', 0x0d, 0x0a, 0
help_del       db '  del <file>      - Delete file', 0x0d, 0x0a, 0
help_mem       db '  mem             - Show memory usage', 0x0d, 0x0a, 0
help_copy      db '  copy <src> <dst> - Copy file', 0x0d, 0x0a, 0
help_cut       db '  cut  <src> <dst> - Move file', 0x0d, 0x0a, 0
help_help      db '  help     - Show this help', 0x0d, 0x0a, 0
unknown_msg    db 'Unknown command', 0x0d, 0x0a, 0
time_prefix    db 'Time: ', 0
shutdown_msg   db 'Shutting down...', 0x0d, 0x0a, 0
reboot_msg     db 'Rebooting...', 0x0d, 0x0a, 0

mem_header     db 'PID  STATUS  MEM(K)  NAME', 0x0d, 0x0a, 0
status_ready   db 'READY ', 0
status_run     db 'RUN   ', 0
mem_total_prefix db 'Memory: Total=', 0
mem_used_prefix  db 'K Used=', 0
mem_free_prefix  db 'K Free=', 0
mem_suffix_k     db 'K', 0x0d, 0x0a, 0

copy_usage_msg db 'Usage: copy <src> <dst>', 0x0d, 0x0a, 0
cut_usage_msg  db 'Usage: cut <src> <dst>', 0x0d, 0x0a, 0
msg_dst_not_dir db 'Destination directory not found', 0x0d, 0x0a, 0
msg_no_match    db 'No files matched', 0x0d, 0x0a, 0

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
cmd_cut        db 'cut', 0

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
