section .data
    ; Buffer for reading files
    buffer times 256 db 0
    buffer_len equ 256

    ; Buffer for printing numbers
    print_buffer times 21 db 0
    print_buffer_len equ 21

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

    ; Debug messages
    starting_msg db "Starting program", 10, 0
    starting_msg_len equ $ - starting_msg
    opening_config_msg db "Opening config file", 10, 0
    opening_config_msg_len equ $ - opening_config_msg
    config_error_msg db "Error opening config file", 10, 0
    config_error_msg_len equ $ - config_error_msg
    opening_data_msg db "Opening data file", 10, 0
    opening_data_msg_len equ $ - opening_data_msg
    data_error_msg db "Error opening data file", 10, 0
    data_error_msg_len equ $ - data_error_msg
    reading_more_msg db "Reading more data", 10, 0
    reading_more_msg_len equ $ - reading_more_msg
    read_error_msg db "Error reading data file", 10, 0
    read_error_msg_len equ $ - read_error_msg
    closing_data_msg db "Closing data file", 10, 0
    closing_data_msg_len equ $ - closing_data_msg
    storing_msg db "Storing student", 10, 0
    storing_msg_len equ $ - storing_msg
    stored_name_msg db "Stored name", 10, 0
    stored_name_msg_len equ $ - stored_name_msg
    parsing_name_msg db "Parsing name", 10, 0
    parsing_name_msg_len equ $ - parsing_name_msg
    parsing_grade_msg db "Parsing grade", 10, 0
    parsing_grade_msg_len equ $ - parsing_grade_msg
    buffer_content_msg db "Buffer content: ", 0
    buffer_content_msg_len equ $ - buffer_content_msg
    storing_rdi_msg db "rdi: ", 0
    storing_rdi_msg_len equ $ - storing_rdi_msg
    storing_rsi_msg db "rsi: ", 0
    storing_rsi_msg_len equ $ - storing_rsi_msg
    temp_name_msg db "temp_name: ", 0
    temp_name_msg_len equ $ - temp_name_msg
    r12_msg db "r12 r13: ", 0
    r12_msg_len equ $ - r12_msg
    parsing_rdi_msg db "rdi before parse_name: ", 0
    parsing_rdi_msg_len equ $ - parsing_rdi_msg
    parsed_name_msg db "Parsed name: ", 0
    parsed_name_msg_len equ $ - parsed_name_msg
    char_at_rsi_msg db "Char at rsi: ", 0
    char_at_rsi_msg_len equ $ - char_at_rsi_msg

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

    ; Debug: Print "Starting program"
    mov rax, 1
    mov rdi, 1
    mov rsi, starting_msg
    mov rdx, starting_msg_len
    syscall

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
    ;call print_students

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
    ; Debug: Print "Opening config file"
    mov rax, 1
    mov rdi, 1
    mov rsi, opening_config_msg
    mov rdx, opening_config_msg_len
    syscall

    ; Open config file
    mov rax, 2    ; sys_open
    mov rdi, config_path
    xor rsi, rsi  ; O_RDONLY
    syscall
    mov rbx, rax  ; Save file descriptor

    ; Debug: Print file descriptor
    push rax
    mov rax, rbx
    call print_number
    mov rax, 1
    mov rdi, 1
    mov rsi, newline
    mov rdx, 1
    syscall
    pop rax

    ; Check if file opened successfully
    cmp rax, 0
    jl config_open_error

    ; Read file into buffer
    xor r12, r12    ; Total bytes read
read_config_loop:
    mov rax, 0    ; sys_read
    mov rdi, rbx
    mov rsi, buffer
    add rsi, r12
    mov rdx, buffer_len
    sub rdx, r12
    syscall

    ; Check for errors
    cmp rax, 0
    jl read_error
    test rax, rax
    jz end_config_read

    add r12, rax
    cmp r12, buffer_len
    jl read_config_loop

end_config_read:
    ; Debug: Print number of bytes read
    push rax
    mov rax, r12
    call print_number
    mov rax, 1
    mov rdi, 1
    mov rsi, newline
    mov rdx, 1
    syscall
    pop rax

    ; Parse configuration (simplified - assumes correct format)
    mov rsi, buffer
    call parse_number
    mov [pass_grade], rax

    ; Debug: Print pass_grade
    push rax
    mov rax, [pass_grade]
    call print_number
    mov rax, 1
    mov rdi, 1
    mov rsi, newline
    mov rdx, 1
    syscall
    pop rax

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

config_open_error:
    mov rax, 1
    mov rdi, 1
    mov rsi, config_error_msg
    mov rdx, config_error_msg_len
    syscall
    mov rax, 60
    mov rdi, 1
    syscall

; Parse a number from buffer at rsi, advance rsi
parse_number:
    push rcx
    push rsi
    push rdi
    xor rax, rax
skip_whitespace:
    movzx rcx, byte [rsi]
    inc rsi
    cmp rcx, 32    ; space
    je skip_whitespace
    cmp rcx, 10    ; newline
    je parse_num_done
    ; Check if it's a digit
    cmp rcx, '0'
    jl parse_num_done
    cmp rcx, '9'
    jg parse_num_done
    ; Now we have a digit
    sub rcx, '0'
    imul rax, 10
    add rax, rcx
parse_num_loop:
    movzx rcx, byte [rsi]
    inc rsi
    cmp rcx, 10    ; newline
    je parse_num_done
    cmp rcx, 32    ; space
    je parse_num_done  ; Terminate on space
    ; Check if it's a digit
    cmp rcx, '0'
    jl parse_num_done
    cmp rcx, '9'
    jg parse_num_done
    sub rcx, '0'
    imul rax, 10
    add rax, rcx
    jmp parse_num_loop
parse_num_done:
    pop rdi
    pop rsi
    pop rcx
    ret

; Read students from data file
read_students:
    ; Debug: Print "Opening data file"
    mov rax, 1
    mov rdi, 1
    mov rsi, opening_data_msg
    mov rdx, opening_data_msg_len
    syscall

    ; Open data file
    mov rax, 2
    mov rdi, data_path
    xor rsi, rsi
    syscall
    mov rbx, rax

    ; Debug: Print file descriptor
    push rax
    mov rax, rbx
    call print_number
    mov rax, 1
    mov rdi, 1
    mov rsi, newline
    mov rdx, 1
    syscall
    pop rax

    ; Check if file opened successfully
    cmp rax, 0
    jl data_open_error

    ; Seek to the beginning of the file (just to be sure)
    mov rax, 8    ; sys_lseek
    mov rdi, rbx
    mov rsi, 0    ; offset
    mov rdx, 0    ; SEEK_SET
    syscall

    ; Initialize buffer position
    xor r12, r12    ; r12 will track the number of bytes processed in the buffer
    xor r13, r13    ; r13 will track the total number of bytes in the buffer

read_student_loop:
    ; Check if we've processed all bytes in the buffer
    cmp r12, r13
    jge read_more_data

process_line:
    ; Debug: Print r12 and r13
    push rax
    push rsi
    push rdx
    mov rax, 1
    mov rdi, 1
    mov rsi, r12_msg
    mov rdx, r12_msg_len
    syscall
    mov rax, r12
    call print_number
    mov rax, 1
    mov rdi, 1
    mov rsi, space
    mov rdx, 1
    syscall
    mov rax, r13
    call print_number
    mov rax, 1
    mov rdi, 1
    mov rsi, newline
    mov rdx, 1
    syscall
    pop rdx
    pop rsi
    pop rax

    ; Find the next newline in the buffer starting from r12
    mov rsi, buffer
    add rsi, r12
    mov rcx, r13
    sub rcx, r12    ; Remaining bytes in buffer
    xor rdx, rdx    ; Offset to newline
find_newline:
    cmp rcx, 0
    jle read_more_data
    cmp byte [rsi + rdx], 10    ; Newline
    je found_newline
    inc rdx
    dec rcx
    jmp find_newline

found_newline:
    mov byte [rsi + rdx], 0    ; Null-terminate the line

    ; Debug: Print the line
    push rsi
    push rdx
    mov rax, 1
    mov rdi, 1
    mov rsi, buffer
    add rsi, r12
    mov rdx, rdx    ; Length of the line
    syscall
    mov rax, 1
    mov rdi, 1
    mov rsi, newline
    mov rdx, 1
    syscall
    pop rdx
    pop rsi

    ; Debug: Print "Parsing name"
    push rax
    push rdi
    mov rax, 1
    mov rdi, 1
    mov rsi, parsing_name_msg
    mov rdx, parsing_name_msg_len
    syscall
    mov rax, 1
    mov rdi, 1
    mov rsi, parsing_rdi_msg
    mov rdx, parsing_rdi_msg_len
    syscall
    mov r15, [rsp]    ; Save rdi in r15
    mov rax, r15
    call print_number
    mov rax, 1
    mov rdi, 1
    mov rsi, newline
    mov rdx, 1
    syscall
    pop rdi
    pop rax

    ; Parse student data
    mov rdi, temp_name
    call parse_name
    mov rsi, rax

    ; Debug: Print character at rsi
    push rax
    push rsi
    mov rax, 1
    mov rdi, 1
    mov rsi, char_at_rsi_msg
    mov rdx, char_at_rsi_msg_len
    syscall
    mov rax, 1
    mov rdi, 1
    mov rsi, [rsp]    ; Get rsi from stack
    mov rdx, 1
    syscall
    mov rax, 1
    mov rdi, 1
    mov rsi, newline
    mov rdx, 1
    syscall
    pop rsi
    pop rax

    ; Debug: Print "Parsing grade"
    push rax
    mov rax, 1
    mov rdi, 1
    mov rsi, parsing_grade_msg
    mov rdx, parsing_grade_msg_len
    syscall
    pop rax

    call parse_number
    mov [temp_grade], rax

    ; Debug: Print parsed name and grade
    push rsi
    push rdx
    mov rax, 1
    mov rdi, 1
    mov rsi, temp_name
    mov rdx, 64
    syscall
    mov rax, 1
    mov rdi, 1
    mov rsi, space
    mov rdx, 1
    syscall
    mov rax, [temp_grade]
    call print_number
    mov rax, 1
    mov rdi, 1
    mov rsi, newline
    mov rdx, 1
    syscall
    pop rdx
    pop rsi

    ; Store student
    mov rcx, [student_count]
    imul rcx, student_struct_size
    mov rdi, students
    add rdi, rcx

    ; Debug: Print "Storing student"
    push rax
    mov rax, 1
    mov rdi, 1
    mov rsi, storing_msg
    mov rdx, storing_msg_len
    syscall
    pop rax

    ; Debug: Print temp_name before storing
    push rax
    push rdi
    push rsi
    mov rax, 1
    mov rdi, 1
    mov rsi, temp_name_msg
    mov rdx, temp_name_msg_len
    syscall
    mov rax, 1
    mov rdi, 1
    mov rsi, temp_name
    mov rdx, 64
    syscall
    mov rax, 1
    mov rdi, 1
    mov rsi, newline
    mov rdx, 1
    syscall
    pop rsi
    pop rdi
    pop rax

    ; Debug: Print rdi and rsi before rep movsb
    push rax
    push rdi
    push rsi
    mov rax, 1
    mov rdi, 1
    mov rsi, storing_rdi_msg
    mov rdx, storing_rdi_msg_len
    syscall
    mov r15, [rsp + 16]    ; Save rdi in r15
    mov rax, r15
    call print_number
    mov rax, 1
    mov rdi, 1
    mov rsi, newline
    mov rdx, 1
    syscall
    mov rax, 1
    mov rdi, 1
    mov rsi, storing_rsi_msg
    mov rdx, storing_rsi_msg_len
    syscall
    mov r15, [rsp + 8]     ; Save rsi in r15
    mov rax, r15
    call print_number
    mov rax, 1
    mov rdi, 1
    mov rsi, newline
    mov rdx, 1
    syscall
    pop rsi
    pop rdi
    pop rax

    mov rsi, temp_name
    mov rcx, 64
    rep movsb

    ; Debug: Print "Stored name"
    push rax
    mov rax, 1
    mov rdi, 1
    mov rsi, stored_name_msg
    mov rdx, stored_name_msg_len
    syscall
    pop rax

    mov rax, [temp_grade]
    mov [rdi], rax

    inc qword [student_count]

    ; Update the buffer position (r12)
    add r12, rdx    ; Move to the \n
    inc r12         ; Move past the \n

    ; Debug: Print current position (r12) after update
    push rax
    mov rax, r12
    call print_number
    mov rax, 1
    mov rdi, 1
    mov rsi, space
    mov rdx, 1
    syscall
    mov rax, r13
    call print_number
    mov rax, 1
    mov rdi, 1
    mov rsi, newline
    mov rdx, 1
    syscall
    pop rax

    jmp read_student_loop

read_more_data:
    ; Debug: Print "Reading more data"
    mov rax, 1
    mov rdi, 1
    mov rsi, reading_more_msg
    mov rdx, reading_more_msg_len
    syscall

    ; Copy unprocessed data to the start of the buffer
    mov rsi, buffer
    add rsi, r12    ; Start of unprocessed data
    mov rdi, buffer ; Destination
    mov rcx, r13
    sub rcx, r12    ; Number of unprocessed bytes
    mov r14, rcx    ; Save the number of unprocessed bytes
    test rcx, rcx
    jz no_unprocessed_data
    rep movsb
no_unprocessed_data:
    ; Update r13 to the number of unprocessed bytes
    mov r13, r14
    mov r12, 0

    ; Read more data starting after the unprocessed data
    mov rax, 0
    mov rdi, rbx
    mov rsi, buffer
    add rsi, r13    ; Start after unprocessed data
    mov rdx, buffer_len
    sub rdx, r13    ; Remaining space in buffer
    syscall

    ; Check for errors
    cmp rax, 0
    jl read_error
    test rax, rax
    jz close_data

    ; Debug: Print number of bytes read
    push rax
    mov rax, rax
    call print_number
    mov rax, 1
    mov rdi, 1
    mov rsi, newline
    mov rdx, 1
    syscall
    pop rax

    ; Debug: Print "Buffer content"
    push rax
    mov rax, 1
    mov rdi, 1
    mov rsi, buffer_content_msg
    mov rdx, buffer_content_msg_len
    syscall
    mov rax, 1
    mov rdi, 1
    mov rsi, buffer
    mov rdx, 20
    syscall
    mov rax, 1
    mov rdi, 1
    mov rsi, newline
    mov rdx, 1
    syscall
    pop rax

    add r13, rax    ; Total bytes in buffer
    mov r12, 0      ; Reset buffer position
    jmp process_line

read_error:
    mov rax, 1
    mov rdi, 1
    mov rsi, read_error_msg
    mov rdx, read_error_msg_len
    syscall
    mov rax, 60
    mov rdi, 1
    syscall

close_data:
    ; Debug: Print "Closing data file"
    mov rax, 1
    mov rdi, 1
    mov rsi, closing_data_msg
    mov rdx, closing_data_msg_len
    syscall

    mov rax, 3
    mov rdi, rbx
    syscall
    ret

data_open_error:
    mov rax, 1
    mov rdi, 1
    mov rsi, data_error_msg
    mov rdx, data_error_msg_len
    syscall
    mov rax, 60
    mov rdi, 1
    syscall

; Parse name (including optional parts)
parse_name:
    push rcx
    push rax
    push rsi
    push rdi
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
    ; Debug: Print temp_name after parsing
    push rax
    mov rax, 1
    mov rdi, 1
    mov rsi, parsed_name_msg
    mov rdx, parsed_name_msg_len
    syscall
    mov rax, 1
    mov rdi, 1
    mov rsi, [rsp + 16]    ; Get rdi (temp_name) from stack
    mov rdx, 64
    syscall
    mov rax, 1
    mov rdi, 1
    mov rsi, newline
    mov rdx, 1
    syscall
    pop rax
    pop rdi
    pop rsi
    pop rax
    pop rcx
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
    push rcx
    push rdx
    push rsi
    push rdi
    push rax
    mov rbx, 10
    mov rcx, 20    ; Start at the end of the print_buffer
    mov rdi, print_buffer
    add rdi, 20
    mov byte [rdi], 0
    dec rdi
    mov rax, [rsp]    ; Get the original rax
convert_loop:
    xor rdx, rdx
    div rbx
    add dl, '0'
    mov [rdi], dl
    dec rdi
    dec rcx
    test rax, rax
    jnz convert_loop
    inc rdi
    mov rsi, rdi
    mov rax, 1
    mov rdi, 1
    mov rdx, 20
    sub rdx, rcx    ; Number of digits
    test rdx, rdx
    jnz print_digits
    mov rdx, 1      ; Print at least one digit
print_digits:
    syscall
    pop rax
    pop rdi
    pop rsi
    pop rdx
    pop rcx
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
