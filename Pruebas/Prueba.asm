section .data
    filename db "datos.txt", 0       ; Nombre del archivo de entrada
    buffer db 10000 dup(0)           ; Buffer para almacenar el contenido del archivo
    array times 1000 db 158 dup(0)   ; Array para almacenar los datos (1000 entradas de 158 bytes cada una)
    newline db 10                    ; Salto de línea
    current_entry dq 0               ; Índice de la entrada actual en el array

section .bss
    filehandle resq 1                ; Descriptor del archivo
    filesize resq 1                  ; Tamaño del archivo

section .text
    global _start

_start:
    ; Abrir el archivo
    mov rax, 2                       ; sys_open
    mov rdi, filename                ; nombre del archivo
    mov rsi, 0                       ; modo de lectura
    syscall
    cmp rax, 0                       ; Verificar si se abrió correctamente
    jl error                        ; Si hay error, salir
    mov [filehandle], rax            ; guardar el descriptor del archivo

    ; Leer el archivo
    mov rax, 0                       ; sys_read
    mov rdi, [filehandle]            ; descriptor del archivo
    mov rsi, buffer                  ; buffer para almacenar los datos
    mov rdx, 10000                   ; tamaño del buffer
    syscall
    cmp rax, 0                       ; Verificar si se leyó correctamente
    jl error                        ; Si hay error, salir
    mov [filesize], rax              ; guardar el tamaño del archivo leído

    ; Cerrar el archivo
    mov rax, 3                       ; sys_close
    mov rdi, [filehandle]            ; descriptor del archivo
    syscall

    ; Parsear el contenido del buffer
    mov rsi, buffer                  ; puntero al buffer
    xor rcx, rcx                     ; contador de líneas

parse_line:
    ; Verificar si hemos alcanzado el límite del array
    mov rax, [current_entry]
    cmp rax, 1000                    ; Límite de 1000 entradas
    jge .end_parse                   ; Si se alcanza el límite, terminar


	cmp byte [rsi], 0
	je .end_parse

    ; Calcular la dirección de la entrada actual en el array
    imul rax, 158                    ; Calcular el desplazamiento (158 bytes por entrada)
    lea rdi, [array + rax]           ; Dirección de la entrada actual en el array

    ; Leer nombre
    call read_word                   ; Leer nombre y almacenar en [rdi]
    add rdi, 50                      ; Mover el puntero al campo de apellido1

    ; Leer apellido1 (opcional)
    call read_word                   ; Leer apellido1 y almacenar en [rdi]
    add rdi, 50                      ; Mover el puntero al campo de apellido2

    ; Leer apellido2 (opcional)
    call read_word                   ; Leer apellido2 y almacenar en [rdi]
    add rdi, 50                      ; Mover el puntero al campo de nota

    ; Leer nota
    call read_number                 ; Leer nota
    mov [rdi], rax                   ; Almacenar la nota en el campo correspondiente

    ; Incrementar el índice de la entrada actual
    inc qword [current_entry]        ; Incrementar el contador de entradas

    ; Avanzar a la siguiente línea
.next_line:
    lodsb                            ; Cargar el siguiente byte desde [rsi] en AL, incrementar rsi
    cmp al, 10                       ; ¿Es un salto de línea?
    je parse_line                    ; Si es salto de línea, continuar con la siguiente línea
    cmp al, 0                        ; ¿Es el final del buffer?
    jne .next_line                   ; Si no, continuar buscando

.end_parse:
    ; Ordenar los datos por nombre
    call sort_by_name

    ; Imprimir los datos ordenados
    call print_array

    ; Salir del programa
    mov rax, 60                      ; sys_exit
    xor rdi, rdi                     ; código de salida 0
    syscall

error:
    ; Manejar error (por ejemplo, imprimir un mensaje de error)
    mov rax, 60                      ; sys_exit
    mov rdi, 1                       ; código de salida 1 (error)
    syscall

; Funciones auxiliares
read_word:
    xor rax, rax                     ; Inicializar contador de longitud
.read_char:
    lodsb                            ; Cargar el siguiente byte desde [rsi] en AL, incrementar rsi
    cmp al, ' '                      ; ¿Es un espacio?
    je .end_word                     ; Si es espacio, terminar la palabra
    cmp al, 10                       ; ¿Es un salto de línea?
    je .end_word                     ; Si es salto de línea, terminar la palabra
    cmp al, 0                        ; ¿Es el final del buffer?
    je .end_word                     ; Si es el final, terminar la palabra
    stosb                            ; Almacenar AL en [rdi], incrementar rdi
    inc rax                          ; Incrementar contador de longitud
    jmp .read_char                   ; Continuar leyendo
.end_word:
    mov byte [rdi], 0                ; Terminar la palabra con un byte nulo
    ret

read_number:
    xor rax, rax                     ; Inicializar acumulador
.read_digit:
    lodsb                            ; Cargar el siguiente byte desde [rsi] en AL, incrementar rsi
    cmp al, '0'                      ; ¿Es menor que '0'?
    jb .end_number                   ; Si es menor, terminar
    cmp al, '9'                      ; ¿Es mayor que '9'?
    ja .end_number                   ; Si es mayor, terminar
    sub al, '0'                      ; Convertir ASCII a número
    imul rax, 10                     ; Multiplicar acumulador por 10
    add rax, rcx                     ; Sumar el nuevo dígito
    mov rcx, rax                     ; Guardar el valor acumulado
    jmp .read_digit                  ; Continuar leyendo
.end_number:
    ret

sort_by_name:
    mov rcx, [current_entry]         ; Número de entradas
    dec rcx                          ; Número de iteraciones (n-1)
.outer_loop:
    mov rsi, array                   ; Puntero al inicio del array
    mov rdx, rcx                     ; Contador interno
.inner_loop:
    mov rdi, rsi                     ; Puntero a la entrada actual
    add rdi, 158                     ; Puntero a la siguiente entrada (158 bytes por entrada)
    mov rax, rsi                     ; Nombre de la entrada actual
    mov rbx, rdi                     ; Nombre de la siguiente entrada
    call compare_strings             ; Comparar las cadenas
    cmp rax, 1                       ; Si la cadena actual es mayor que la siguiente, intercambiar
    jle .no_swap
    call swap_entries                ; Intercambiar las entradas
.no_swap:
    add rsi, 158                     ; Mover al siguiente par de entradas
    dec rdx                          ; Decrementar el contador interno
    jnz .inner_loop                  ; Repetir si no se ha terminado
    loop .outer_loop                 ; Repetir el proceso para todas las entradas
    ret

compare_strings:
.compare_loop:
    mov cl, [rax]                    ; Cargar byte de la cadena 1
    mov dl, [rbx]                    ; Cargar byte de la cadena 2
    cmp cl, dl                       ; Comparar bytes
    jg .greater                      ; Si cadena1 > cadena2
    jl .less                         ; Si cadena1 < cadena2
    inc rax                          ; Mover al siguiente byte de cadena1
    inc rbx                          ; Mover al siguiente byte de cadena2
    cmp cl, 0                        ; ¿Llegamos al final de las cadenas?
    jne .compare_loop                ; Si no, continuar comparando
    xor rax, rax                     ; Si son iguales, rax = 0
    ret
.greater:
    mov rax, 1                       ; cadena1 > cadena2
    ret
.less:
    mov rax, -1                      ; cadena1 < cadena2
    ret

swap_entries:
    mov rcx, 158                     ; Tamaño de cada entrada (158 bytes)
    xor rax, rax                     ; Contador de bytes
.swap_loop:
    mov bl, [rsi + rax]              ; Cargar byte de la entrada actual
    mov dl, [rdi + rax]              ; Cargar byte de la siguiente entrada
    mov [rsi + rax], dl              ; Almacenar byte en la entrada actual
    mov [rdi + rax], bl              ; Almacenar byte en la siguiente entrada
    inc rax                          ; Incrementar el contador de bytes
    loop .swap_loop                  ; Repetir para todos los bytes
    ret

print_array:
    mov rcx, [current_entry]         ; Número de entradas
    mov rsi, array                   ; Puntero al inicio del array
.print_loop:
    lea rdi, [rsi]                   ; Nombre está al inicio de la entrada
    call print_string
    lea rdi, [rsi + 50]              ; Apellido1 está en el offset 50
    call print_string
    lea rdi, [rsi + 100]             ; Apellido2 está en el offset 100
    call print_string
    mov rax, [rsi + 150]             ; Nota está en el offset 150
    call print_number
    mov rax, 1                       ; sys_write
    mov rdi, 1                       ; stdout
    lea rsi, [newline]               ; Salto de línea
    mov rdx, 1                       ; Longitud
    syscall
    add rsi, 158                     ; Mover a la siguiente entrada
    loop .print_loop                 ; Repetir para todas las entradas
    ret

print_string:
    mov rsi, rdi                     ; Puntero a la cadena
    mov rdx, 0                       ; Contador de longitud
.calculate_length:
    cmp byte [rsi + rdx], 0          ; ¿Llegamos al final de la cadena?
    je .print                        ; Si es así, imprimir
    inc rdx                          ; Incrementar el contador de longitud
    jmp .calculate_length            ; Continuar calculando
.print:
    mov rax, 1                       ; sys_write
    mov rdi, 1                       ; stdout
    syscall
    ret

print_number:
    mov rcx, 10                      ; Base 10
    mov rbx, buffer                  ; Buffer para almacenar los dígitos
    add rbx, 19                      ; Empezar desde el final del buffer
    mov byte [rbx], 0                ; Terminar la cadena con un byte nulo
.convert_loop:
    dec rbx                          ; Mover al siguiente byte en el buffer
    xor rdx, rdx                     ; Limpiar rdx para la división
    div rcx                          ; Dividir rax por 10
    add dl, '0'                      ; Convertir el residuo a ASCII
    mov [rbx], dl                    ; Almacenar el dígito en el buffer
    cmp rax, 0                       ; ¿Se ha terminado el número?
    jne .convert_loop                ; Si no, continuar
    mov rax, 1                       ; sys_write
    mov rdi, 1                       ; stdout
    mov rsi, rbx                     ; Puntero al buffer
    mov rdx, 20                      ; Longitud máxima
    sub rdx, rbx                     ; Calcular la longitud real
    syscall
    ret
