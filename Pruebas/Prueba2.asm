section .data
    msg db "Procesando archivo de estudiantes...", 0
    msg_len equ $ - msg
    err_msg db "Error: Faltan argumentos o archivos no encontrados.", 10, 0
    err_len equ $ - err_msg
    input_file db 256 dup(0)    ; Path for archivo.txt
    config_file db 256 dup(0)   ; Path for configuracion.txt
    newline db 10, 0
    format db "%s <%s> <%s> nota:[%d]", 0  ; Expected student format (not used directly here)
    sort_mode db "alfabetico", 0
    pass_threshold db 70        ; From configuracion.txt
    retry_threshold db 60       ; From configuracion.txt
    pass_label db "Aprobados: ", 0
    retry_label db "Reposición: ", 0
    fail_label db "Reprobados: ", 0

section .bss
    buffer resb 1024            ; Buffer for archivo.txt
    student_data resb 2048      ; Processed student data
    config_data resb 256        ; Buffer for configuracion.txt
    sorted_data resb 2048       ; Sorted output
    fd_input resq 1             ; File descriptor for input
    fd_config resq 1            ; File descriptor for config
    grades resb 100             ; Extracted grades
    grade_count resq 1          ; Number of grades

section .text
    global _start

_start:
    ; Check argument count (expect 3: program, config, input)
    ;cmp rdi, 3
    ;jne error_exit

    ; Copy config file path (argv[1])
    mov rsi, [rsi + 16]
    mov rdi, config_file
    call copy_string

    ; Copy input file path (argv[2])
    mov rsi, [rsi + 24]
    mov rdi, input_file
    call copy_string

    ; Open config file
    mov rax, 2
    mov rdi, config_file
    mov rsi, 0              ; Read-only
    syscall
    cmp rax, 0
    jl error_exit
    mov [fd_config], rax

    ; Read config file
    mov rax, 0
    mov rdi, [fd_config]
    mov rsi, config_data
    mov rdx, 256
    syscall
    mov byte [rsi + rax], 0  ; Null-terminate
    mov rax, 3
    mov rdi, [fd_config]
    syscall

    ; Open input file
    mov rax, 2
    mov rdi, input_file
    mov rsi, 0
    syscall
    cmp rax, 0
    jl error_exit
    mov [fd_input], rax

    ; Read input file
    mov rax, 0
    mov rdi, [fd_input]
    mov rsi, buffer
    mov rdx, 1024
    syscall
    cmp rax, 0
    jl error_exit
    mov byte [rsi + rax], 0  ; Null-terminate
    mov rax, 3
    mov rdi, [fd_input]
    syscall

    ; Process data
    call parse_students
    call sort_students
    call generate_histogram
    call print_output

    ; Exit
    mov rax, 60
    xor rdi, rdi
    syscall

error_exit:
    mov rax, 1
    mov rdi, 1
    mov rsi, err_msg
    mov rdx, err_len
    syscall
    mov rax, 60
    mov rdi, 1
    syscall

; Copy null-terminated string from rsi to rdi
copy_string:
.loop:
    mov al, [rsi]
    mov [rdi], al
    test al, al
    je .done
    inc rsi
    inc rdi
    jmp .loop
.done:
    ret

; Parse students from buffer into student_data and grades
parse_students:
    mov rsi, buffer
    mov rdi, student_data
    mov rdx, grades
    xor r8, r8              ; Grade counter
.loop:
    mov al, [rsi]
    test al, al
    je .done
    cmp al, 10           ; Newline marks end of record
    je .next_record
    cmp al, '['          ; Start of grade
    je .parse_grade
    mov [rdi], al        ; Copy character to student_data
    inc rsi
    inc rdi
    jmp .loop
.parse_grade:
    inc rsi              ; Skip '['
    movzx eax, byte [rsi]
    sub al, '0'          ; Convert ASCII digit to number
    mov bl, 10
    mul bl               ; Tens place
    movzx ebx, byte [rsi + 1]
    sub bl, '0'          ; Units place
    add al, bl           ; Total grade
    cmp r8, 100
    jge .skip_grade
    mov [rdx], al        ; Store grade
    inc rdx
    inc r8
.skip_grade:
    add rsi, 3           ; Skip "XX]"
    mov [rdi], byte 0    ; Null-terminate student name
    inc rdi
    jmp .loop
.next_record:
    inc rsi
    jmp .loop
.done:
    mov [grade_count], r8
    ret

; Simple bubble sort on student_data (null-terminated strings)
sort_students:
    mov rcx, [grade_count]
    dec rcx              ; Number of comparisons
    jle .done
.outer:
    mov rsi, student_data
    mov rbx, rcx         ; Inner loop counter
.inner:
    mov al, [rsi]
    mov dl, [rsi + 1]
    test dl, dl
    jz .no_swap          ; Skip if next is null
    cmp al, dl
    jle .no_swap
    ; Swap characters (simplified, assumes single-char comparison)
    xchg al, [rsi + 1]
    mov [rsi], al
.no_swap:
    inc rsi
    dec rbx
    jnz .inner
    loop .outer
.done:
    ret

; Generate histogram into sorted_data
generate_histogram:
    mov rsi, grades
    mov rdi, sorted_data
    mov rcx, [grade_count]
    test rcx, rcx
    jz .done
.loop:
    mov al, [rsi]
    cmp al, [pass_threshold]
    jge .pass
    cmp al, [retry_threshold]
    jge .retry
    mov byte [rdi], '-'
    jmp .next
.pass:
    mov byte [rdi], 'X'
    jmp .next
.retry:
    mov byte [rdi], 'O'
.next:
    inc rdi
    mov byte [rdi], 10   ; Newline
    inc rdi
    inc rsi
    loop .loop
.done:
    mov byte [rdi], 0    ; Null-terminate
    ret

; Print results
print_output:
    ; Print initial message
    mov rax, 1
    mov rdi, 1
    mov rsi, msg
    mov rdx, msg_len
    syscall

    ; Print pass label
    mov rax, 1
    mov rdi, 1
    mov rsi, pass_label
    mov rdx, 11
    syscall

    ; Print histogram (simplified to just show grades status)
    mov rax, 1
    mov rdi, 1
    mov rsi, sorted_data
    mov rdx, 2048
    call strlen
    mov rdx, rax
    syscall

    ret

; Compute length of null-terminated string in rsi
strlen:
    xor rax, rax
.loop:
    cmp byte [rsi + rax], 0
    je .done
    inc rax
    jmp .loop
.done:
    ret
