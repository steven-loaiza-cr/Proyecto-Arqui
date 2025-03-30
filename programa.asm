; programa.asm - Proyecto 1 Arquitectura de Computadores
; Programa que lee archivos de configuración y datos de estudiantes
; para ordenarlos y mostrar un histograma de notas

%include "linux.inc"

section .data
; Nombres de archivos por defecto
archconf db "config.txt",0
archdat db "datos.txt",0

; Mensajes y formatos
msg_config db "Leyendo archivo de configuración...",10,0
msg_datos db "Leyendo archivo de datos...",10,0
msg_ordenando db "Ordenando datos...",10,0
msg_histograma db "Generando histograma...",10,0
msg_estudiantes db "# estudiantes",10,0
msg_notas db "-> Notas",10,0
msg_error db "Error al abrir el archivo",10,0
msg_uso db "Uso: ./programa config.txt datos.txt",10,0
msg_ordenamiento_numerico db "Ordenamiento numérico:",10,0
msg_ordenamiento_alfabetico db "Ordenamiento alfabético:",10,0
msg_config_leida db "Configuración leída:",10,0
msg_nda db "Nota de aprobación: ",0
msg_ndr db "Nota de reposición: ",0
msg_tdgn db "Tamaño de los grupos de notas: ",0
msg_edg db "Escala del gráfico: ",0
msg_tdo db "Ordenamiento: ",0
msg_newline db 10,0

; Caracteres para el histograma
exis db "X ",0
dobleespacio db "  ",0
espacioyenter db " ",10,0
finalfila db "|",0
cuatroespacios db "    ",0
cien db "100 ",0

; Colores ANSI
verde db 0x1b,"[32m",0
rojo db 0x1b,"[31m",0
naranja db 0x1b,"[33m",0
blanco db 0x1b,"[37m",0

; Valores por defecto (en caso de error en la lectura)
def_nda db "70",0
def_ndr db "50",0
def_tdgn db "10",0
def_edg db "5",0
def_tdo db "numerico",0

; Cadenas para comparación
str_numerico db "numerico",0
str_alfabetico db "alfabetico",0

section .bss
; Buffers para archivos
textconf resb 256    ; Buffer para archivo de configuración
textdat resb 4096    ; Buffer para archivo de datos
textdat_ordenado resb 4096 ; Buffer para datos ordenados

; Variables para procesamiento
nda resb 4           ; Nota de aprobación
ndr resb 4           ; Nota de reposición
tdgn resb 4          ; Tamaño de los grupos de notas
edg resb 4           ; Escala del gráfico
tdo resb 16          ; Tipo de ordenamiento

; Variables para ordenamiento
byteactual resw 1    ; Posición actual en el buffer
finalf1 resw 1       ; Posición final de la fila 1
iniciof1 resw 1      ; Posición inicial de la fila 1
iniciof2 resw 1      ; Posición inicial de la fila 2
finalf2 resw 1       ; Posición final de la fila 2
bytefinaltext resw 1 ; Posición final del texto
contadorletras resw 1 ; Contador de letras
copiadorfilas resw 1  ; Contador para copiar filas
sizef1 resw 1        ; Tamaño de la fila 1
sizef2 resw 1        ; Tamaño de la fila 2
bubletimes resw 1    ; Contador para bubble sort
contadorfilas resw 1  ; Contador de filas
total_estudiantes resw 1 ; Total de estudiantes

; Variables para histograma
arraynotas resb 101      ; Almacena las notas en el eje x (0-100)
arrayestudiantes resb 101 ; Almacena la cantidad de estudiantes por grupo (0-100)
todaslasnotas resb 100    ; Almacena todas las notas
contador_estudiantes resb 101 ; Contador de estudiantes por nota

; Variables para conversión
nota resb 1
num1 resb 2
num2 resb 2
num3 resb 2
buffer resb 16       ; Buffer general para conversiones

; Variables para comparación
letra1 resb 1
letra2 resb 1
copiafila1 resb 256  ; Almacena la fila 1
copiafila2 resb 256  ; Almacena la fila 2

; Variables para histograma
canty resb 1
cantx resb 1
edgb resb 1
residuoy resb 1
residuox resb 1
tdgnb resb 1
arrayaxisy resb 101  ; Guarda los valores en el eje y (0-100)
max_estudiantes_grupo resb 1 ; Máximo número de estudiantes en un grupo
fila_actual resb 1   ; Fila actual para el histograma
columna_actual resb 1 ; Columna actual para el histograma

; Buffer para argumentos de línea de comandos
argc resq 1          ; Número de argumentos
argv resq 3          ; Punteros a argumentos

; Líneas temporales para ordenamiento
linea_temp resb 256
linea_actual resb 256
linea_siguiente resb 256
nota_actual resb 4
nota_siguiente resb 4

section .text
global _start

_start:
; Procesar argumentos de línea de comandos
mov [argc], rdi
mov [argv], rsi

; Verificar si se proporcionaron argumentos
cmp qword [argc], 1
jle .usar_archivos_por_defecto

; Verificar si hay suficientes argumentos
cmp qword [argc], 3
jl .mostrar_uso

; Obtener nombres de archivos de los argumentos
mov rax, [argv]
mov rdi, [rax+8]  ; argv[1] - archivo de configuración
mov [archconf], rdi

mov rdi, [rax+16] ; argv[2] - archivo de datos
mov [archdat], rdi
jmp .continuar

.mostrar_uso:
print msg_uso
exit

.usar_archivos_por_defecto:
; Usar archivos por defecto (ya configurados en .data)

.continuar:
; Inicializar valores por defecto en caso de error
mov rsi, def_nda
mov rdi, nda
call copiar_string

mov rsi, def_ndr
mov rdi, ndr
call copiar_string

mov rsi, def_tdgn
mov rdi, tdgn
call copiar_string

mov rsi, def_edg
mov rdi, edg
call copiar_string

mov rsi, def_tdo
mov rdi, tdo
call copiar_string

; Mostrar mensaje de inicio
print msg_config

; Abrir archivo de configuración
mov rax, SYS_OPEN
mov rdi, archconf
mov rsi, O_RDONLY
mov rdx, 0
syscall

; Verificar si se abrió correctamente
cmp rax, 0
jl error_archivo ; Saltar a error_archivo si hay un error

; Leer archivo de configuración
push rax
mov rdi, rax
mov rax, SYS_READ
mov rsi, textconf
mov rdx, 256
syscall

; Cerrar archivo
mov rax, SYS_CLOSE
pop rdi
syscall

; Mostrar configuración leída
print textconf

; Extraer información de configuración
call extraer_configuracion

; Mostrar configuración extraída
print msg_config_leida

print msg_nda
print nda
print msg_newline

print msg_ndr
print ndr
print msg_newline

print msg_tdgn
print tdgn
print msg_newline

print msg_edg
print edg
print msg_newline

print msg_tdo
print tdo
print msg_newline

; Mostrar mensaje de lectura de datos
print msg_datos

; Abrir archivo de datos
mov rax, SYS_OPEN
mov rdi, archdat
mov rsi, O_RDONLY
mov rdx, 0
syscall

; Verificar si se abrió correctamente
cmp rax, 0
jl error_archivo ; Saltar a error_archivo si hay un error

; Leer archivo de datos
push rax
mov rdi, rax
mov rax, SYS_READ
mov rsi, textdat
mov rdx, 4096
syscall

; Guardar el tamaño del archivo
mov [bytefinaltext], rax

; Cerrar archivo
mov rax, SYS_CLOSE
pop rdi
syscall

; Mostrar datos leídos
print textdat

; Copiar datos originales al buffer de ordenamiento
mov rsi, textdat
mov rdi, textdat_ordenado
mov rcx, [bytefinaltext]
rep movsb

; Ordenar datos según configuración
print msg_ordenando
call ordenar_datos

; Mostrar datos ordenados
print textdat_ordenado

; Generar histograma
print msg_histograma
call generar_histograma

; Finalizar programa
exit

; Manejador de error de archivo
error_archivo:
; Mostrar mensaje de error
print msg_error
; Continuar con valores por defecto
jmp _start.continuar

; Función para copiar una cadena
copiar_string:
push rax
push rcx

xor rcx, rcx
.copiar:
mov al, [rsi+rcx]
cmp al, 0
je .fin

mov [rdi+rcx], al
inc rcx
jmp .copiar

.fin:
mov byte [rdi+rcx], 0  ; Terminar con null
pop rcx
pop rax
ret

; Función para comparar cadenas
comparar_string:
; Compara las cadenas en rsi y rdi, devuelve 0 si son iguales, 1 si rsi > rdi, -1 si rsi < rdi
push rcx
push rdx

xor rcx, rcx
.comparar:
mov al, [rsi+rcx]
mov dl, [rdi+rcx]
cmp al, 0
je .fin_rsi
cmp dl, 0
je .fin_rdi
cmp al, dl
jne .diferentes
inc rcx
jmp .comparar

.fin_rsi:
cmp dl, 0
je .iguales
mov rax, -1  ; rsi < rdi
jmp .fin

.fin_rdi:
mov rax, 1   ; rsi > rdi
jmp .fin

.diferentes:
cmp al, dl
jl .menor
mov rax, 1   ; rsi > rdi
jmp .fin

.menor:
mov rax, -1  ; rsi < rdi
jmp .fin

.iguales:
mov rax, 0   ; rsi = rdi

.fin:
pop rdx
pop rcx
ret

; Función para extraer configuración del archivo
extraer_configuracion:
; Extraer nota de aprobación (línea 1)
mov rdi, textconf
call buscar_dos_puntos
inc rdi         ; Saltar el espacio después de ':'
mov rsi, nda
call copiar_valor

; Extraer nota de reposición (línea 2)
mov rdi, textconf
call buscar_linea
call buscar_dos_puntos
inc rdi
mov rsi, ndr
call copiar_valor

; Extraer tamaño de grupos de notas (línea 3)
mov rdi, textconf
call buscar_linea
call buscar_linea
call buscar_dos_puntos
inc rdi
mov rsi, tdgn
call copiar_valor

; Extraer escala del gráfico (línea 4)
mov rdi, textconf
call buscar_linea
call buscar_linea
call buscar_linea
call buscar_dos_puntos
inc rdi
mov rsi, edg
call copiar_valor

; Extraer tipo de ordenamiento (línea 5)
mov rdi, textconf
call buscar_linea
call buscar_linea
call buscar_linea
call buscar_linea
call buscar_dos_puntos
inc rdi
mov rsi, tdo
call copiar_valor

ret

; Función para buscar el caracter ':'
buscar_dos_puntos:
push rax
.buscar:
mov al, [rdi]
cmp al, 0
je .fin
cmp al, ':'
je .encontrado
inc rdi
jmp .buscar
.encontrado:
inc rdi  ; Posicionarse después de ':'
.fin:
pop rax
ret

; Función para buscar el siguiente salto de línea
buscar_linea:
push rax
.buscar:
mov al, [rdi]
cmp al, 0
je .fin
cmp al, 10  ; Salto de línea
je .encontrado
inc rdi
jmp .buscar
.encontrado:
inc rdi  ; Posicionarse después del salto de línea
.fin:
pop rax
ret

; Función para copiar un valor hasta el fin de línea
copiar_valor:
push rax
push rcx

xor rcx, rcx
.copiar:
mov al, [rdi]
cmp al, 0    ; Fin de archivo
je .fin
cmp al, 10   ; Fin de línea
je .fin
cmp al, 13   ; Retorno de carro
je .fin

; Saltar espacios iniciales
cmp al, ' '
je .espacio

mov [rsi+rcx], al
inc rcx
inc rdi
jmp .copiar

.espacio:
inc rdi
; Si no hemos copiado nada, seguimos buscando
cmp rcx, 0
je .copiar
; Si ya copiamos algo, terminamos
jmp .fin

.fin:
mov byte [rsi+rcx], 0  ; Terminar con null
pop rcx
pop rax
ret

; Función para ordenar los datos
ordenar_datos:
; Contar líneas y extraer notas
call contar_lineas_y_extraer_notas

; Determinar tipo de ordenamiento
mov rsi, tdo
mov rdi, str_alfabetico
call comparar_string
cmp rax, 0
je .ordenamiento_alfabetico

; Si no es alfabético, usar numérico por defecto
print msg_ordenamiento_numerico
call ordenar_por_nota
jmp .fin_ordenar

.ordenamiento_alfabetico:
print msg_ordenamiento_alfabetico
call ordenar_alfabeticamente

.fin_ordenar:
ret

; Función para contar líneas y extraer notas
contar_lineas_y_extraer_notas:
mov word [contadorfilas], 0
mov word [total_estudiantes], 0
mov rdi, textdat

.contar_lineas:
mov al, [rdi]
cmp al, 0
je .fin_contar

cmp al, 10  ; Salto de línea
jne .no_es_linea
inc word [contadorfilas]
inc word [total_estudiantes]

.no_es_linea:
inc rdi
jmp .contar_lineas

.fin_contar:
; Asegurarse de contar la última línea si no termina con salto de línea
cmp byte [rdi-1], 10
je .ya_contada
inc word [contadorfilas]
inc word [total_estudiantes]

.ya_contada:
ret

; Función para ordenar por nota
ordenar_por_nota:
; Implementar bubble sort por nota (de mayor a menor)
mov word [bubletimes], 0
movzx rcx, word [total_estudiantes]
dec rcx  ; n-1 iteraciones
cmp rcx, 0
jle .fin_bubble  ; Si hay 0 o 1 líneas, no hay que ordenar

.outer_loop:
mov word [contadorfilas], cx  ; Restaurar contador para esta pasada
mov word [byteactual], 0
mov rsi, textdat_ordenado
mov word [iniciof1], 0

.inner_loop:
; Obtener línea actual
mov rdi, linea_actual
call obtener_linea
mov word [finalf1], ax
add word [byteactual], ax

; Obtener nota de la línea actual
mov rdi, linea_actual
call extraer_nota_de_linea
mov [nota_actual], al

; Verificar si hay más líneas
cmp word [contadorfilas], 1
jle .no_swap  ; Si es la última línea, no hay con qué comparar

; Obtener línea siguiente
mov rdi, linea_siguiente
call obtener_linea
mov word [finalf2], ax
add word [byteactual], ax

; Obtener nota de la línea siguiente
mov rdi, linea_siguiente
call extraer_nota_de_linea
mov [nota_siguiente], al

; Comparar notas (ordenar de mayor a menor)
movzx rax, byte [nota_actual]
movzx rbx, byte [nota_siguiente]
cmp rax, rbx
jge .no_swap  ; Si nota_actual >= nota_siguiente, no intercambiar

; Intercambiar líneas
mov rdi, linea_temp
mov rsi, linea_actual
movzx rcx, word [finalf1]
rep movsb

mov rdi, linea_actual
mov rsi, linea_siguiente
movzx rcx, word [finalf2]
rep movsb

mov rdi, linea_siguiente
mov rsi, linea_temp
movzx rcx, word [finalf1]
rep movsb

; Actualizar en el buffer ordenado
mov rdi, textdat_ordenado
add rdi, [iniciof1]
mov rsi, linea_actual
movzx rcx, word [finalf2]
rep movsb

mov rdi, textdat_ordenado
add rdi, [iniciof1]
add rdi, rcx
mov rsi, linea_siguiente
movzx rcx, word [finalf1]
rep movsb

.no_swap:
; Actualizar índice de inicio para la próxima línea
movzx rax, word [finalf1]
add word [iniciof1], ax

; Verificar si hemos terminado con esta pasada
dec word [contadorfilas]
cmp word [contadorfilas], 0
jg .inner_loop

; Continuar con la siguiente pasada
inc word [bubletimes]
movzx rax, word [bubletimes]
cmp ax, cx
jl .outer_loop

.fin_bubble:
ret

; Función para ordenar alfabéticamente
ordenar_alfabeticamente:
; Implementar bubble sort alfabético
mov word [bubletimes], 0
movzx rcx, word [total_estudiantes]
dec rcx  ; n-1 iteraciones
cmp rcx, 0
jle .fin_bubble  ; Si hay 0 o 1 líneas, no hay que ordenar

.outer_loop:
mov word [contadorfilas], cx  ; Restaurar contador para esta pasada
mov word [byteactual], 0
mov rsi, textdat_ordenado
mov word [iniciof1], 0

.inner_loop:
; Obtener línea actual
mov rdi, linea_actual
call obtener_linea
mov word [finalf1], ax
add word [byteactual], ax

; Verificar si hay más líneas
cmp word [contadorfilas], 1
jle .no_swap  ; Si es la última línea, no hay con qué comparar

; Obtener línea siguiente
mov rdi, linea_siguiente
call obtener_linea
mov word [finalf2], ax
add word [byteactual], ax

; Comparar líneas alfabéticamente
mov rsi, linea_actual
mov rdi, linea_siguiente
call comparar_string_nombre
cmp rax, 1
jle .no_swap  ; Si linea_actual <= linea_siguiente, no intercambiar

; Intercambiar líneas
mov rdi, linea_temp
mov rsi, linea_actual
movzx rcx, word [finalf1]
rep movsb

mov rdi, linea_actual
mov rsi, linea_siguiente
movzx rcx, word [finalf2]
rep movsb

mov rdi, linea_siguiente
mov rsi, linea_temp
movzx rcx, word [finalf1]
rep movsb

; Actualizar en el buffer ordenado
mov rdi, textdat_ordenado
add rdi, [iniciof1]
mov rsi, linea_actual
movzx rcx, word [finalf2]
rep movsb

mov rdi, textdat_ordenado
add rdi, [iniciof1]
add rdi, rcx
mov rsi, linea_siguiente
movzx rcx, word [finalf1]
rep movsb

.no_swap:
; Actualizar índice de inicio para la próxima línea
movzx rax, word [finalf1]
add word [iniciof1], ax

; Verificar si hemos terminado con esta pasada
dec word [contadorfilas]
cmp word [contadorfilas], 0
jg .inner_loop

; Continuar con la siguiente pasada
inc word [bubletimes]
movzx rax, word [bubletimes]
cmp ax, cx
jl .outer_loop

.fin_bubble:
ret

; Función para comparar solo los nombres (ignorando "nota:")
comparar_string_nombre:
; Compara las cadenas en rsi y rdi, devuelve 0 si son iguales, 1 si rsi > rdi, -1 si rsi < rdi
push rcx
push rdx

xor rcx, rcx
.comparar:
mov al, [rsi+rcx]
mov dl, [rdi+rcx]

; Verificar si llegamos a "nota:"
cmp al, 'n'
je .verificar_nota
cmp dl, 'n'
je .verificar_nota

; Verificar fin de cadena
cmp al, 0
je .fin_rsi
cmp dl, 0
je .fin_rdi
cmp al, 10
je .fin_rsi
cmp dl, 10
je .fin_rdi

; Comparar caracteres
cmp al, dl
jne .diferentes
inc rcx
jmp .comparar

.verificar_nota:
; Verificar si es "nota:"
cmp byte [rsi+rcx+1], 'o'
jne .continuar
cmp byte [rsi+rcx+2], 't'
jne .continuar
cmp byte [rsi+rcx+3], 'a'
jne .continuar
cmp byte [rsi+rcx+4], ':'
jne .continuar
; Es "nota:", terminar comparación
mov rax, 0  ; Considerar iguales
jmp .fin

.continuar:
cmp al, dl
jne .diferentes
inc rcx
jmp .comparar

.fin_rsi:
cmp dl, 0
je .iguales
cmp dl, 10
je .iguales
mov rax, -1  ; rsi < rdi
jmp .fin

.fin_rdi:
mov rax, 1   ; rsi > rdi
jmp .fin

.diferentes:
cmp al, dl
jl .menor
mov rax, 1   ; rsi > rdi
jmp .fin

.menor:
mov rax, -1  ; rsi < rdi
jmp .fin

.iguales:
mov rax, 0   ; rsi = rdi

.fin:
pop rdx
pop rcx
ret

; Función para obtener una línea del buffer
obtener_linea:
; rsi = puntero al buffer, rdi = destino, devuelve en ax el tamaño de la línea
push rbx
push rcx
push rdx

xor rcx, rcx
.copiar:
mov al, [rsi]
cmp al, 0
je .fin_buffer
cmp al, 10  ; Salto de línea
je .fin_linea

mov [rdi+rcx], al
inc rcx
inc rsi
jmp .copiar

.fin_buffer:
.fin_linea:
mov [rdi+rcx], al  ; Copiar el salto de línea o el 0
inc rcx
inc rsi

mov ax, cx  ; Devolver tamaño de la línea
pop rdx
pop rcx
pop rbx
ret

; Función para extraer la nota de una línea
extraer_nota_de_linea:
; rdi = línea, devuelve en al la nota
push rbx
push rcx
push rdx
push rdi

; Buscar "nota:"
.buscar_nota:
mov al, [rdi]
cmp al, 0
je .no_encontrado
cmp al, 10  ; Salto de línea
je .no_encontrado
cmp al, 'n'
jne .siguiente_char

; Verificar si es "nota:"
cmp byte [rdi+1], 'o'
jne .siguiente_char
cmp byte [rdi+2], 't'
jne .siguiente_char
cmp byte [rdi+3], 'a'
jne .siguiente_char
cmp byte [rdi+4], ':'
jne .siguiente_char

; Encontramos "nota:", extraer valor
add rdi, 5
.saltar_espacios:
mov al, [rdi]
cmp al, ' '
jne .fin_espacios
inc rdi
jmp .saltar_espacios

.fin_espacios:
; Extraer dígitos
mov rcx, 0
.extraer_digito:
mov al, [rdi]
cmp al, '0'
jb .fin_digitos
cmp al, '9'
ja .fin_digitos

mov [buffer+rcx], al
inc rcx
inc rdi
jmp .extraer_digito

.fin_digitos:
mov byte [buffer+rcx], 0  ; Terminar con null

; Convertir a número
mov rdi, buffer
call ascii_a_decimal
jmp .fin

.siguiente_char:
inc rdi
jmp .buscar_nota

.no_encontrado:
xor al, al  ; Nota 0 si no se encuentra

.fin:
pop rdi
pop rdx
pop rcx
pop rbx
ret

; Función para generar histograma
generar_histograma:
; Imprimir encabezado
print msg_estudiantes

; Inicializar arrays para el histograma
call inicializar_arrays

; Contar frecuencias de notas
call contar_frecuencias

; Encontrar el máximo número de estudiantes en un grupo
call encontrar_maximo_estudiantes

; Dibujar histograma
call dibujar_histograma

; Imprimir eje X
print msg_notas

ret

; Función para encontrar el máximo número de estudiantes en un grupo
encontrar_maximo_estudiantes:
xor rcx, rcx
mov byte [max_estudiantes_grupo], 0

.buscar_maximo:
movzx rax, byte [cantx]
cmp cl, al
jae .fin_buscar

movzx rax, byte [arrayestudiantes+rcx]
cmp al, byte [max_estudiantes_grupo]
jle .siguiente_grupo

mov [max_estudiantes_grupo], al

.siguiente_grupo:
inc rcx
jmp .buscar_maximo

.fin_buscar:
ret

; Función para inicializar arrays
inicializar_arrays:
; Limpiar arrays
mov rcx, 101 ; Cambiado a 101 para incluir 0-100
mov rdi, arraynotas
mov rsi, arrayestudiantes
mov al, 0

.limpiar:
mov byte [rdi], al
mov byte [rsi], al
inc rdi
inc rsi
loop .limpiar

; Limpiar contador de estudiantes por nota
mov rcx, 101
mov rdi, contador_estudiantes
mov al, 0

.limpiar_contador:
mov byte [rdi], al
inc rdi
loop .limpiar_contador

; Convertir escala del gráfico a decimal
mov rdi, edg
call ascii_a_decimal
mov [edgb], al

; Convertir tamaño de grupos a decimal
mov rdi, tdgn
call ascii_a_decimal
mov [tdgnb], al

; Calcular número de grupos en eje X (0-100 dividido por tamaño de grupo)
xor rdx, rdx
mov rax, 100 ; Usar rax para la división
movzx rbx, byte [tdgnb]
cmp rbx, 0
je .division_por_cero
div rbx
mov [cantx], al
mov [residuox], dl ; El residuo está en dl después de la división
jmp .continuar_x

.division_por_cero:
mov byte [cantx], 1
mov byte [residuox], 0

.continuar_x:
; Si hay residuo, agregar un grupo más
cmp byte [residuox], 0
je .sin_residuo_x
inc byte [cantx]
.sin_residuo_x:

; Calcular número de filas en eje Y (0-100 dividido por escala)
xor rdx, rdx
mov rax, 100
movzx rbx, byte [edgb]
cmp rbx, 0
je .division_por_cero_y
div rbx
mov [canty], al
mov [residuoy], dl
jmp .continuar_y

.division_por_cero_y:
mov byte [canty], 1
mov byte [residuoy], 0

.continuar_y:
; Si hay residuo, agregar una fila más
cmp byte [residuoy], 0
je .sin_residuo_y
inc byte [canty]
.sin_residuo_y:

; Inicializar eje Y
mov rcx, 0
mov al, 0
.init_y:
cmp rcx, 20  ; Limitar a 20 filas para evitar desbordamiento
jae .fin_init_y
movzx rbx, byte [edgb]
mul rbx
add al, bl
cmp al, 100
jg .fin_init_y
mov [arrayaxisy+rcx], al
inc rcx
jmp .init_y
.fin_init_y:
mov byte [arrayaxisy+rcx], 100 ; Asegurar que el 100 esté incluido

; Inicializar eje X
mov rcx, 0
mov al, 0
.init_x:
cmp rcx, 20  ; Limitar a 20 columnas para evitar desbordamiento
jae .fin_init_x
movzx rbx, byte [tdgnb]
mul rbx
add al, bl
cmp al, 100
jg .fin_init_x
mov [arraynotas+rcx], al
inc rcx
jmp .init_x
.fin_init_x:
mov byte [arraynotas+rcx], 100 ; Asegurar que el 100 esté incluido

ret

; Función para contar frecuencias de notas
contar_frecuencias:
; Extraer notas del archivo de datos y contarlas
mov rdi, textdat_ordenado  ; Usar datos ordenados
mov rcx, 0  ; Contador de notas

.buscar_nota:
; Buscar la palabra "nota:"
call buscar_palabra_nota
cmp al, 0
je .fin_buscar  ; Si no se encontró, terminar

; Extraer el valor numérico
call extraer_nota

; Incrementar contador para esta nota
movzx rbx, al
cmp rbx, 100  ; Verificar que la nota no exceda 100
ja .siguiente_nota
inc byte [contador_estudiantes+rbx]

; Determinar a qué grupo pertenece la nota
call asignar_grupo

.siguiente_nota:
; Incrementar contador y continuar
inc rcx
cmp rcx, 100  ; Máximo 100 notas
jae .fin_buscar
jmp .buscar_nota

.fin_buscar:
ret

; Función para buscar la palabra "nota:"
buscar_palabra_nota:
push rcx
push rdx

; Buscar 'n'
.buscar_n:
mov al, [rdi]
cmp al, 0
je .no_encontrado
cmp al, 'n'
je .encontrado_n
inc rdi
jmp .buscar_n

.encontrado_n:
; Verificar si es "nota:"
cmp byte [rdi+1], 'o'
jne .no_es_nota
cmp byte [rdi+2], 't'
jne .no_es_nota
cmp byte [rdi+3], 'a'
jne .no_es_nota
cmp byte [rdi+4], ':'
jne .no_es_nota

; Encontramos "nota:", avanzar al valor
add rdi, 5
mov al, 1  ; Éxito
jmp .fin

.no_es_nota:
inc rdi
jmp .buscar_n

.no_encontrado:
mov al, 0  ; No encontrado

.fin:
pop rdx
pop rcx
ret

; Función para extraer el valor numérico de la nota
extraer_nota:
push rcx
push rdx

; Saltar espacios
.saltar_espacios:
mov al, [rdi]
cmp al, ' '
jne .fin_espacios
inc rdi
jmp .saltar_espacios

.fin_espacios:
; Extraer dígitos
mov rcx, 0
.extraer_digito:
mov al, [rdi]
cmp al, '0'
jb .fin_digitos
cmp al, '9'
ja .fin_digitos

mov [buffer+rcx], al
inc rcx
inc rdi
jmp .extraer_digito

.fin_digitos:
mov byte [buffer+rcx], 0  ; Terminar con null

; Convertir a número
mov rdi, buffer
call ascii_a_decimal
mov [todaslasnotas+rcx], al

pop rdx
pop rcx
ret

; Función para asignar una nota a su grupo correspondiente
asignar_grupo:
push rbx
push rcx
push rdx

; Determinar a qué grupo pertenece la nota
movzx rax, al  ; Nota actual (0-100)
movzx rbx, byte [tdgnb]  ; Tamaño del grupo

; Si el tamaño del grupo es 0, evitar la división por 0. Asignar al grupo 0.
cmp rbx, 0
je .es_cero

; Dividir la nota por el tamaño del grupo
xor rdx, rdx
div rbx
jmp .continuar_asignacion

.es_cero:
xor rax, rax ; asignar 0

.continuar_asignacion:
; El cociente es el índice del grupo
cmp rax, 100  ; Verificar que el índice no exceda 100
jae .fin_asignacion

; Incrementar el contador de ese grupo
inc byte [arrayestudiantes+rax]

.fin_asignacion:
pop rdx
pop rcx
pop rbx
ret

; Función para dibujar histograma
dibujar_histograma:
; Dibujar filas del histograma de arriba hacia abajo
mov byte [fila_actual], 0  ; Empezar desde la fila 0

.dibujar_fila:
; Verificar límite del array
movzx rcx, byte [fila_actual]
movzx rax, byte [canty]
cmp rcx, rax
jae .fin_histograma

; Calcular el valor del eje Y para esta fila
movzx rax, byte [canty]
sub rax, rcx
dec rax  ; Ajustar para índice 0-based
cmp rax, 20  ; Verificar límite del array
jae .siguiente_fila
movzx rax, byte [arrayaxisy+rax]  ; Obtener el valor de y del array

; Imprimir valor del eje Y (alineado a la derecha)
call decimal_a_ascii_3digitos

; Imprimir espacios para alinear
print dobleespacio

; Imprimir valor
mov rax, SYS_WRITE
mov rdi, STDOUT
mov rsi, num1
mov rdx, 1
syscall

mov rax, SYS_WRITE
mov rdi, STDOUT
mov rsi, num2
mov rdx, 1
syscall

mov rax, SYS_WRITE
mov rdi, STDOUT
mov rsi, num3
mov rdx, 1
syscall

; Imprimir espacios y barra
print dobleespacio
print finalfila
print dobleespacio

; Dibujar X para cada columna
mov byte [columna_actual], 0  ; Índice de columna

.dibujar_columna:
; Verificar límite del array
movzx rdx, byte [columna_actual]
movzx rax, byte [cantx]
cmp rdx, rax
jae .fin_columna

; Verificar si hay que dibujar X
movzx rax, byte [arrayestudiantes+rdx]  ; estudiantes en el grupo actual
cmp rax, 0
je .no_dibujar_x  ; Si no hay estudiantes, no dibujar

; Calcular umbral para esta fila
movzx rbx, byte [canty]
movzx rcx, byte [fila_actual]
sub rbx, rcx
dec rbx  ; Ajustar para índice 0-based
cmp rbx, 20  ; Verificar límite del array
jae .no_dibujar_x
movzx rbx, byte [arrayaxisy+rbx]  ; Valor del eje Y para esta fila

; Calcular valor para comparar
movzx rax, byte [arrayestudiantes+rdx]  ; estudiantes en el grupo actual
movzx rcx, byte [edgb]  ; escala del gráfico
mul cl  ; multiplicar por la escala (corregido: usar cl en lugar de rcx)

; Comparar para determinar si dibujar X
cmp rax, rbx
jl .no_dibujar_x

; Determinar color según nota
movzx rax, byte [arraynotas+rdx]

; Convertir nota de aprobación a decimal
push rax
push rcx
push rdx
mov rdi, nda
call ascii_a_decimal
mov bl, al  ; Guardar nota de aprobación en bl
pop rdx
pop rcx
pop rax

; Comparar con nota actual
cmp al, bl
jae .color_verde

; Convertir nota de reposición a decimal
push rax
push rcx
push rdx
mov rdi, ndr
call ascii_a_decimal
mov bl, al  ; Guardar nota de reposición en bl
pop rdx
pop rcx
pop rax

; Comparar con nota actual
cmp al, bl
jae .color_naranja

; Nota de reprobación
print rojo
jmp .imprimir_x

.color_naranja:
print naranja
jmp .imprimir_x

.color_verde:
print verde

.imprimir_x:
print exis
print blanco
jmp .siguiente_columna

.no_dibujar_x:
print dobleespacio

.siguiente_columna:
inc byte [columna_actual]
jmp .dibujar_columna

.fin_columna:
print finalfila
print espacioyenter

.siguiente_fila:
inc byte [fila_actual]
jmp .dibujar_fila ; Continuar dibujando filas

.fin_histograma:
; Dibujar eje X
print cuatroespacios
xor rcx, rcx

.dibujar_eje_x:
movzx rax, byte [cantx]
cmp cl, al
jae .fin_eje_x

movzx rax, byte [arraynotas+rcx]
call decimal_a_ascii_3digitos

; Imprimir valor
mov rax, SYS_WRITE
mov rdi, STDOUT
mov rsi, num1
mov rdx, 1
syscall

mov rax, SYS_WRITE
mov rdi, STDOUT
mov rsi, num2
mov rdx, 1
syscall

mov rax, SYS_WRITE
mov rdi, STDOUT
mov rsi, num3
mov rdx, 1
syscall

print dobleespacio

inc rcx
jmp .dibujar_eje_x

.fin_eje_x:
print espacioyenter

ret

; Función para convertir ASCII a decimal
ascii_a_decimal:
; Convertir string en rdi a valor decimal en al
xor rax, rax
xor rcx, rcx

.siguiente:
mov bl, [rdi+rcx]
cmp bl, 0
je .fin

cmp bl, '0'
jb .no_digito
cmp bl, '9'
ja .no_digito

; Multiplicar resultado actual por 10
imul rax, 10

; Convertir dígito y sumar
sub bl, '0'
add al, bl

inc rcx
jmp .siguiente

.no_digito:
inc rcx
jmp .siguiente

.fin:
ret

; Función para convertir decimal a ASCII (2 dígitos)
decimal_a_ascii:
; Convertir al a string en num1 y num2
mov ah, 0
mov bl, 10
div bl
add al, '0'
add ah, '0'
mov [num1], al
mov [num2], ah
ret

; Función para convertir decimal a ASCII (3 dígitos)
decimal_a_ascii_3digitos:
; Convertir al a string en num1, num2 y num3
xor ah, ah
mov bl, 100
div bl
add al, '0'
mov [num1], al

mov al, ah
xor ah, ah
mov bl, 10
div bl
add al, '0'
add ah, '0'
mov [num2], al
mov [num3], ah
ret
