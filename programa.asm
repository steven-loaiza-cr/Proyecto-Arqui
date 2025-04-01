;Proyecto - Steven Loaiza Valverde
section .data
    msg db "Procesando archivo de estudiantes...", 0  ; Mensaje de inicio del programa
    msg_len equ $ - msg  ; Longitud del mensaje, calculada automáticamente
    err_msg db "Error: Faltan argumentos o archivos no encontrados.", 10, 0  ; Mensaje de error
    err_len equ $ - err_msg  ; Longitud del mensaje de error
    input_file db 256 dup(0)   ; Espacio reservado para la ruta del archivo de estudiantes
    config_file db 256 dup(0)  ; Espacio reservado para la ruta del archivo de configuración
    newline db 10, 0           ; Carácter de nueva línea
    format db "%s <%s> <%s> nota:[%d]", 0 ; Formato de lectura de datos
    sort_mode db "alfabetico", 0 ; Modo de ordenamiento por defecto
    pass_threshold db 70        ; Nota mínima para aprobar
    retry_threshold db 50       ; Nota mínima para reposición
    var_exis db "X", 0

section .bss
    buffer resb 1024      ; Reservo un buffer para leer el archivo de estudiantes
    student_data resb 2048 ; Aquí guardo los datos de los estudiantes procesados
    config_data resb 256   ; Aquí guardo los datos del archivo de configuración
    sorted_data resb 2048  ; Aquí almaceno los datos ordenados
    fd_input resq 1        ; Descriptor del archivo de estudiantes
    fd_config resq 1       ; Descriptor del archivo de configuración
    grades resb 100        ; Reservo espacio para las notas extraídas de los estudiantes

section .text
    global _start  ; Este es el punto de entrada del programa

_start:
    mov rsi, [rsp + 8]  ; Obtengo la dirección de la tabla de argumentos
    mov rdi, [rsp]      ; Primer argumento (nombre del programa)
    add rsi, 8           ; Paso al siguiente argumento
    cmp rdi, 3           ; Verifico si tengo 3 argumentos
    jne error_exit       ; Si no, llamo a la función de manejo de errores

    ; Copiar ruta del archivo de configuración
    mov rsi, [rsp + 16]  ; Apunto al segundo argumento (config_file)
    mov rdi, config_file ; Indico el destino donde copiaré la ruta
    call copy_string     ; Llamo a la función que copia la cadena

    ; Copiar ruta del archivo de estudiantes
    mov rsi, [rsp + 24]  ; Apunto al tercer argumento (input_file)
    mov rdi, input_file  ; Indico el destino donde copiaré la ruta
    call copy_string     ; Llamo a la función que copia la cadena

    ; Abrir el archivo de estudiantes en modo de solo lectura
    mov rax, 2          ; Llamada al sistema sys_open
    mov rdi, input_file ; Ruta del archivo
    mov rsi, 0          ; Modo de solo lectura
    syscall             
    test rax, rax       ; Verifico si hubo error al abrir el archivo
    js error_exit       ; Si hay error, llamo a la función de manejo de errores
    mov [fd_input], rax  ; Guardo el descriptor del archivo

    ; Leer el archivo de estudiantes en el buffer
    mov rax, 0          ; Llamada al sistema sys_read
    mov rdi, [fd_input] ; Descriptor del archivo abierto
    mov rsi, buffer     ; Buffer donde almacenaré la lectura
    mov rdx, 1024       ; Número máximo de bytes a leer
    syscall

    ; Cerrar el archivo de estudiantes después de la lectura
    mov rax, 3          ; Llamada al sistema sys_close
    mov rdi, [fd_input] ; Descriptor del archivo a cerrar
    syscall

    ; Procesamiento y análisis de datos
    call parse_students  ; Extraer nombres y notas
    ;call sort_students   ; Ordenar la lista de estudiantes
    call generate_histogram  ; Generar el histograma visual
    call print_output    ; Imprimir resultados en pantalla

    ; Terminar el programa correctamente
    mov rax, 60         ; Llamada al sistema sys_exit
    xor rdi, rdi        ; Código de salida 0 (sin errores)
    syscall

; Función para manejar errores mostrando un mensaje y saliendo
error_exit:
    mov rax, 1          ; Llamada a sys_write (escribir en stdout)
    mov rdi, 1          ; Descriptor de salida estándar (stdout)
    mov rsi, err_msg    ; Dirección del mensaje de error
    mov rdx, err_len    ; Longitud del mensaje de error
    syscall
    mov rax, 60         ; Llamada a sys_exit
    mov rdi, 1          ; Código de salida con error
    syscall

; Función para copiar una cadena de caracteres
copy_string:
    .loop:
        mov al, [rsi]   ; Leo un byte de la cadena origen
        mov [rdi], al   ; Lo copio al destino
        test al, al     ; Verifico si es el carácter nulo (fin de la cadena)
        je .done        ; Si es el fin, salgo de la función
        inc rsi         ; Avanzo al siguiente carácter en la cadena origen
        inc rdi         ; Avanzo al siguiente byte en el destino
        jmp .loop       ; Repito el proceso
    .done:
        ret

; Extraer nombres y notas del archivo leído en buffer
parse_students:
    mov rsi, buffer
    mov rdi, student_data
    mov rdx, grades
    .loop:
        mov al, [rsi]   ; Leo el carácter actual
        test al, al     ; Verifico si llegué al fin del archivo
        je .done
        cmp al, '0'     ; Verifico si es un número (parte de la nota)
        jl .skip
        cmp al, '9'
        jg .skip
        sub al, '0'     ; Convierte el carácter a su valor numérico
        mov [rdx], al   ; Guardo la nota
        inc rdx
    .skip:
        mov [rdi], al   ; Guardo el carácter en la estructura de estudiantes
        inc rsi
        inc rdi
        jmp .loop
    .done:
        ret

; Ordenar los datos con Bubble Sort
sort_students:
    mov rcx, 2048  
    .outer:
        mov rsi, student_data
        mov rdi, sorted_data
        mov rdx, 0   
        .inner:
            mov al, byte [rsi]        ; Leo byte desde student_data
            cmp al, byte [rsi + 1]    ; Comparo con el siguiente byte
            jle .no_swap
            xchg al, byte [rsi + 1]   ; Intercambio si es mayor
            mov byte [rsi], al        ; Guardo el byte intercambiado
            inc rdx
        .no_swap:
            inc rsi
            loop .inner  
        cmp rdx, 0
        jne .outer
    ret

; Generar histograma basado en notas
generate_histogram:
    mov rsi, grades
    mov rdi, sorted_data
    .loop:
        mov al, [rsi]
        test al, al
        je .done
        cmp al, [pass_threshold]
        jge .pass
        cmp al, [retry_threshold]
        jge .retry
        jmp .fail
    .pass:
        mov byte [rdi], 'X'
        jmp .next
    .retry:
        mov byte [rdi], 'O'
        jmp .next
    .fail:
        mov byte [rdi], '-'
    .next:
        inc rdi
        mov byte [rdi], 10
        inc rdi
        inc rsi
        jmp .loop
    .done:
        ret

; Imprimir la salida generada
print_output:
    ; Primero, imprimo el mensaje de inicio
    mov rax, 1
    mov rdi, 1
    mov rsi, msg
    mov rdx, msg_len
    syscall

    ; Luego, imprimo los resultados del histograma
    mov rsi, sorted_data
    mov rdx, 2048  ; Número máximo de caracteres a imprimir
    .print_loop:
        mov al, [rsi]
        test al, al
        je .end_print
        mov rdi, 1
        mov rax, 1  ; sys_write
        syscall
        inc rsi
        dec rdx
        jnz .print_loop
    .end_print:
        ret
