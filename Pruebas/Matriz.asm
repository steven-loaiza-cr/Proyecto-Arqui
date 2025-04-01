section .data
    ; Mensajes de error
    mensaje_error_argumentos db 'Existe un error en la lectura de los argumentos, por favor vuelva a correr el programa teniendo en cuenta el siguiente formato: ./Programa Ruta_Configuracion Ruta_Datos', 0xA, 0
    len_mensaje_error_argumentos equ $-mensaje_error_argumentos

section .bss
    ; Variables para el guardado de parámetros por parte del usuario
    ruta_configuracion resb 256
    ruta_datos resb 256
    ; Variables para almacenar el contenido del archivo .txt de datos de estudiantes
    fd resq 1
    bytes_read resq 1
    ; Reserva espacio para una matriz de 1024 estudiantes, cada uno con 128 bytes para el nombre y 8 bytes para la nota
    matriz resb 1024 * (128 + 8)
    num_estudiantes resq 1
    buffer resb 1024
    buffer_nota resb 20

section .text
    global _start

_start:
    ; Lectura de argumentos
    mov rdi, [rsp]
    cmp rdi, 3
    jne error_argumentos
    mov rsi, [rsp + 16]
    lea rdi, [ruta_configuracion]
    call captar_parametro
    mov rsi, [rsp + 24]
    lea rdi, [ruta_datos]
    call captar_parametro

    ; Apertura y lectura del archivo de datos
    mov rax, 2
    mov rdi, ruta_datos
    mov rsi, 0
    syscall
    mov [fd], rax
    mov rax, 0
    mov rdi, [fd]
    mov rsi, buffer
    mov rdx, 1024
    syscall
    mov [bytes_read], rax

    ; Parsear estudiantes
    mov rsi, buffer
    mov rdi, matriz
    mov rcx, [bytes_read]
    xor rbx, rbx
    mov r14, buffer
    add r14, [bytes_read]
parse_loop:
    cmp rsi, r14
    jge end_parse
    mov rdx, 128
copy_name:
    cmp rdx, 0
    je find_first_apellido
    cmp rsi, r14
    jge end_parse
    cmp byte [rsi], ' '
    je find_first_apellido
    mov al, [rsi]
    mov [rdi], al
    inc rsi
    inc rdi
    dec rdx
    jmp copy_name
find_first_apellido:
    mov byte [rdi], ' '
    inc rdi
    inc rsi
    cmp byte [rsi], '<'
    jne check_second_apellido
    inc rsi
copy_first_apellido_loop:
    cmp byte [rsi], '>'
    je check_second_apellido
    cmp rsi, r14
    jge end_parse
    cmp rdx, 0
    je end_parse
    mov al, [rsi]
    mov [rdi], al
    inc rsi
    inc rdi
    dec rdx
    jmp copy_first_apellido_loop
check_second_apellido:
    mov byte [rdi], ' '
    inc rdi
check_second_apellido_loop:
    cmp byte [rsi], '<'
    je copy_second_apellido
    cmp dword [rsi], 'aton'
    je copy_nota
    cmp rsi, r14
    jge end_parse
    inc rsi
    jmp check_second_apellido_loop
copy_second_apellido:
    inc rsi
copy_second_apellido_loop:
    cmp byte [rsi], '>'
    je copy_nota
    mov al, [rsi]
    mov [rdi], al
    inc rsi
    inc rdi
    dec rdx
    jmp copy_second_apellido_loop
copy_nota:
    mov byte [rdi], ' '
    inc rdi
    add rsi, 8
    xor rax, rax
    xor r8, r8
copy_nota_loop:
    cmp byte [rsi], ']'
    je end_copy_nota
    cmp rsi, r14
    jge end_parse
    movzx eax, byte [rsi]
    sub eax, '0'
    imul r8, r8, 10
    add r8, rax
    inc rsi
    jmp copy_nota_loop
end_copy_nota:
    mov al, '.'
fill_name_space:
    cmp rdx, 0
    je store_note
    mov [rdi], al
    inc rdi
    dec rdx
    jmp fill_name_space
store_note:
    mov [rdi], r8
    add rdi, 8
    mov byte [rdi], 10
    inc rdi
    xor r8, r8
    inc rbx
    inc rsi
    inc rsi
    jmp parse_loop
end_parse:
    mov [num_estudiantes], rbx
    mov rax, 3
    mov rdi, [fd]
    syscall

    ; Imprimir estudiantes
    mov rsi, matriz
    mov rcx, [num_estudiantes]
    xor rbx, rbx
imprimir_estudiante_loop:
    cmp rbx, rcx
    jge fin_imprimir_estudiantes
    mov rdi, rsi
    call imprimir_nombre
    mov rdi, rsi
    add rdi, 128
    mov rax, [rdi]
    call convertir_numero_a_cadena
    mov rsi, buffer_nota
    mov rdx, 20
    call imprimir
    add rsi, 136
    inc rbx
    jmp imprimir_estudiante_loop
fin_imprimir_estudiantes:
    mov rax, 60
    xor rdi, rdi
    syscall

captar_parametro:
    mov rcx, 0
loop_copia:
    mov al, [rsi + rcx]
    mov [rdi + rcx], al
    inc rcx
    cmp al, 0
    je copia_realizada
    jmp loop_copia
copia_realizada:
    ret

imprimir_nombre:
    mov rdx, 128
    call imprimir
    ret

convertir_numero_a_cadena:
    push rbx
    push rcx
    push rdx
    mov rcx, rsi
    add rcx, 19
    mov byte [rcx], 0
    cmp rax, 0
    jne convertir_loop
    mov byte [rsi], '0'
    mov byte [rsi + 1], 0
    jmp convertir_fin
convertir_loop:
    xor rdx, rdx
    mov rbx, 10
    div rbx
    add dl, '0'
    dec rcx
    mov [rcx], dl
    test rax, rax
    jnz convertir_loop
    mov rdi, rsi
    mov rsi, rcx
    call copiar_cadena
convertir_fin:
    pop rdx
    pop rcx
    pop rbx
    ret

copiar_cadena:
    .copiar_loop:
    mov al, [rsi]
    mov [rdi], al
    inc rsi
    inc rdi
    test al, al
    jnz .copiar_loop
    ret

imprimir:
    mov rax, 1
    mov rdi, 1
    syscall
    ret

error_argumentos:
    mov rax, 1
    mov rdi, 1
    mov rsi, mensaje_error_argumentos
    mov rdx, len_mensaje_error_argumentos
    syscall
    mov rax, 60
    xor rdi, rdi
    syscall
