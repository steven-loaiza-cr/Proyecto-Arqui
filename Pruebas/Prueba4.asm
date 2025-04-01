section .data
    ; Buffer for reading files
    buffer times 256 db 0
    buffer_len equ 256

    ; Color codes for terminal output
    green db 27, "[32m", 0    ; Green for passing
    orange db 27, "[33m", 0   ; Orange for retake
    red db 27, "[31m", 0      ; Red for failing
    reset db 27, "[0m", 0     ; Reset color

    ; Format strings
    newline db 10, 0
    space db " ", 0
    x_char db "X", 0
    dash db "-", 0

    ; Configuration variables
    pass_grade dq 0
    retake_grade dq 0
    group_size dq 0
    scale dq 0
    sort_type db 0    ; 0 for alphabetical, 1 for numerical

    ; Student structure: name (64 bytes), grade (8 bytes)
    student_struct_size equ 72
    max_students equ 100
    students times max_students * student_struct_size db 0
    student_count dq 0

section .bss
    config_path resb 256
    data_path resb 256
    temp_name resb 64
    temp_grade resq 1
    histogram resq 11    ; For 0-10, 10-20, ..., 90-100

section .text
global _start

_start:
    ; Check if we have exactly 2 arguments (plus program name)
    mov rax, [rsp]    ; argc
    cmp rax, 3
    jne exit_error

    ; Get config and data file paths from command line
    mov rsi, [rsp + 16]    ; argv[1] - config path
    mov rdi, config_path
    call copy_string

    mov rsi, [rsp + 24]    ; argv[2] - data path
    mov rdi, data_path
    call copy_string

    ; Read configuration file
    call read_config

    ; Read student data
    call read_students
    call print_students

    ; Sort students based on sort_type
    cmp byte [sort_type], 0
    je sort_alpha
    call sort_numeric
    jmp after_sort
sort_alpha:
    call sort_alphabetical
after_sort:
    ; Print sorted list
    call print_students

    ; Generate and print histogram
    call generate_histogram
    call print_histogram

    ; Exit successfully
    mov rax, 60    ; sys_exit
    xor rdi, rdi   ; status 0
    syscall

exit_error:
    mov rax, 60
    mov rdi, 1
    syscall

; Copy string from rsi to rdi
copy_string:
    xor rcx, rcx
copy_loop:
    mov al, [rsi + rcx]
    mov [rdi + rcx], al
    inc rcx
    cmp al, 0
    jne copy_loop
    ret

; Read configuration file
read_config:
    ; Open config file
    mov rax, 2    ; sys_open
    mov rdi, config_path
    xor rsi, rsi  ; O_RDONLY
    syscall
    mov rbx, rax  ; Save file descriptor

    ; Read file into buffer
    mov rax, 0    ; sys_read
    mov rdi, rbx
    mov rsi, buffer
    mov rdx, buffer_len
    syscall

    ; Parse configuration (simplified - assumes correct format)
    mov rsi, buffer
    call parse_number
    mov [pass_grade], rax

    call parse_number
    mov [retake_grade], rax

    call parse_number
    mov [group_size], rax

    call parse_number
    mov [scale], rax

    ; Parse sort type
    mov al, [rsi]
    cmp al, 'a'
    je set_alpha
    mov byte [sort_type], 1
    jmp close_config
set_alpha:
    mov byte [sort_type], 0

close_config:
    ; Close file
    mov rax, 3    ; sys_close
    mov rdi, rbx
    syscall
    ret

; Parse a number from buffer at rsi, advance rsi
parse_number:
    xor rax, rax
skip_whitespace:
    movzx rcx, byte [rsi]
    inc rsi
    cmp rcx, 32    ; space
    je skip_whitespace
    cmp rcx, 10    ; newline
    je parse_num_done
    ; Now we have a digit
parse_num_loop:
    sub rcx, '0'
    imul rax, 10
    add rax, rcx
    movzx rcx, byte [rsi]
    inc rsi
    cmp rcx, 10    ; newline
    je parse_num_done
    jmp parse_num_loop
parse_num_done:
    ret

; Read students from data file
read_students:
    ; Open data file
    mov rax, 2
    mov rdi, data_path
    xor rsi, rsi
    syscall
    mov rbx, rax

read_student_loop:
    ; Clear buffer
    mov rdi, buffer
    mov rcx, buffer_len
    xor al, al
    rep stosb

    ; Read line into buffer
    mov rax, 0
    mov rdi, rbx
    mov rsi, buffer
    mov rdx, buffer_len
    syscall
    test rax, rax
    jz close_data

    ; Ensure buffer is null-terminated
    mov byte [buffer + rax], 0

    ; Parse student data
    mov rsi, buffer
    mov rdi, temp_name
    call parse_name
    mov rsi, rax
    call parse_number
    mov [temp_grade], rax

    ; Store student
    mov rcx, [student_count]
    imul rcx, student_struct_size
    mov rdi, students
    add rdi, rcx
    mov rsi, temp_name
    mov rcx, 64
    rep movsb
    mov rax, [temp_grade]
    mov [rdi], rax

    inc qword [student_count]
    jmp read_student_loop

close_data:
    mov rax, 3
    mov rdi, rbx
    syscall
    ret

; Parse name (including optional parts)
parse_name:
    xor rcx, rcx
parse_name_loop:
    mov al, [rsi]
    inc rsi
    cmp al, 10    ; newline
    je parse_name_done
    cmp al, 32    ; space
    je parse_name_done
    mov [rdi + rcx], al
    inc rcx
    jmp parse_name_loop
parse_name_done:
    mov byte [rdi + rcx], 0
    mov rax, rsi
    ret

; Sort students alphabetically (bubble sort)
sort_alphabetical:
    mov rbx, [student_count]
    dec rbx
outer_alpha_loop:
    xor rcx, rcx
    mov rdx, rbx
inner_alpha_loop:
    mov rsi, students
    imul rdi, rcx, student_struct_size
    add rsi, rdi
    mov rdi, rsi
    add rdi, student_struct_size
    call compare_strings
    jge no_swap_alpha
    call swap_students
no_swap_alpha:
    inc rcx
    dec rdx
    jnz inner_alpha_loop
    dec rbx
    jnz outer_alpha_loop
    ret

; Sort students numerically (bubble sort)
sort_numeric:
    mov rbx, [student_count]
    dec rbx
outer_num_loop:
    xor rcx, rcx
    mov rdx, rbx
inner_num_loop:
    mov rsi, students
    imul rdi, rcx, student_struct_size
    add rsi, rdi
    mov rdi, rsi
    add rdi, student_struct_size
    mov rax, [rsi + 64]
    cmp rax, [rdi + 64]
    jle no_swap_num
    call swap_students
no_swap_num:
    inc rcx
    dec rdx
    jnz inner_num_loop
    dec rbx
    jnz outer_num_loop
    ret

; Compare strings at rsi and rdi
compare_strings:
    xor rcx, rcx
compare_loop:
    mov al, [rsi + rcx]
    mov bl, [rdi + rcx]
    cmp al, bl
    jne compare_done
    test al, al
    jz compare_equal
    inc rcx
    jmp compare_loop
compare_equal:
    xor rax, rax
    ret
compare_done:
    sub al, bl
    movsx rax, al
    ret

; Swap students at rsi and rdi
swap_students:
    mov rcx, student_struct_size
swap_loop:
    mov al, [rsi]
    mov bl, [rdi]
    mov [rsi], bl
    mov [rdi], al
    inc rsi
    inc rdi
    dec rcx
    jnz swap_loop
    ret

; Print sorted student list
print_students:
    xor rbx, rbx
print_student_loop:
    cmp rbx, [student_count]
    jge print_done

    mov rsi, students
    imul rcx, rbx, student_struct_size
    add rsi, rcx

    ; Print name
    mov rax, 1
    mov rdi, 1
    mov rdx, 64
    syscall

    ; Print space
    mov rax, 1
    mov rdi, 1
    mov rsi, space
    mov rdx, 1
    syscall

    ; Print grade
    mov rax, [rsi + 64]
    call print_number

    ; Print newline
    mov rax, 1
    mov rdi, 1
    mov rsi, newline
    mov rdx, 1
    syscall

    inc rbx
    jmp print_student_loop
print_done:
    ret

; Print number in rax
print_number:
    push rbx
    mov rbx, 10
    xor rcx, rcx
    mov rdi, buffer
    add rdi, 20
    mov byte [rdi], 0
    dec rdi
convert_loop:
    xor rdx, rdx
    div rbx
    add dl, '0'
    mov [rdi], dl
    dec rdi
    test rax, rax
    jnz convert_loop
    inc rdi
    mov rsi, rdi
    mov rax, 1
    mov rdi, 1
    mov rdx, 21
    sub rdx, rcx
    syscall
    pop rbx
    ret

; Generate histogram
generate_histogram:
    ; Clear histogram
    mov rcx, 11
    mov rdi, histogram
    xor rax, rax
    rep stosq

    ; Count students in each grade range
    xor rbx, rbx
count_loop:
    cmp rbx, [student_count]
    jge count_done

    mov rsi, students
    imul rcx, rbx, student_struct_size
    add rsi, rcx
    mov rax, [rsi + 64]    ; Get grade
    xor rdx, rdx
    mov rcx, [group_size]
    div rcx
    inc qword [histogram + rax * 8]

    inc rbx
    jmp count_loop
count_done:
    ret

; Print histogram
print_histogram:
    ; Find max height for scaling
    mov rcx, 11
    mov rsi, histogram
    xor rax, rax
find_max:
    cmp [rsi], rax
    jle not_max
    mov rax, [rsi]
not_max:
    add rsi, 8
    loop find_max

    ; Scale to fit terminal (simplified)
    mov rbx, [scale]
    xor rdx, rdx
    div rbx
    test rax, rax
    jnz scale_ok
    inc rax
scale_ok:
    mov rbx, rax    ; rbx = scale factor

    ; Print histogram from top to bottom
    mov rax, 100
print_row:
    ; Print row number
    call print_number
    mov rax, 1
    mov rdi, 1
    mov rsi, space
    mov rdx, 1
    syscall

    ; Print X's for each column
    xor rcx, rcx
print_col:
    mov rsi, histogram
    mov rdx, rcx
    shl rdx, 3
    add rsi, rdx
    mov rsi, [rsi]    ; Number of students in this bin
    xor rdx, rdx
    div rbx
    cmp rax, rsi
    jg no_x

    ; Determine color based on grade
    mov rdx, rcx
    imul rdx, [group_size]
    cmp rdx, [pass_grade]
    jge use_green
    cmp rdx, [retake_grade]
    jge use_orange
    mov rsi, red
    jmp print_color
use_green:
    mov rsi, green
    jmp print_color
use_orange:
    mov rsi, orange
print_color:
    mov rax, 1
    mov rdi, 1
    mov rdx, 4
    syscall

    mov rax, 1
    mov rdi, 1
    mov rsi, x_char
    mov rdx, 1
    syscall

    mov rax, 1
    mov rdi, 1
    mov rsi, reset
    mov rdx, 4
    syscall

    jmp next_col
no_x:
    mov rax, 1
    mov rdi, 1
    mov rsi, space
    mov rdx, 1
    syscall
next_col:
    inc rcx
    cmp rcx, 11
    jl print_col

    mov rax, 1
    mov rdi, 1
    mov rsi, newline
    mov rdx, 1
    syscall

    sub rax, 10
    jnz print_row

    ; Print x-axis labels
    mov rax, 1
    mov rdi, 1
    mov rsi, space
    mov rdx, 4
    syscall

    xor rcx, rcx
print_labels:
    mov rax, rcx
    imul rax, [group_size]
    call print_number
    mov rax, 1
    mov rdi, 1
    mov rsi, dash
    mov rdx, 1
    syscall
    inc rcx
    cmp rcx, 11
    jl print_labels

    mov rax, 1
    mov rdi, 1
    mov rsi, newline
    mov rdx, 1
    syscall
    ret
