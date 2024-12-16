section .data
    CSV_SEP         equ ';'                 ; Separador de archivos .CSV
    LINE_FEED       equ 0xA                 ; Salto de linea (ASCII)
    EOF             equ 0x0                 ; End Of File (ASCII)

section .bss
; PSEUDO-STRUCT sismo
sismo:
    ; Desplazamiento de los datos en el arreglo
    DATE_SIZE       equ 16                  ; 16 bytes
    HOUR_SIZE       equ 16                  ; 16 bytes
    MAGNITUDE_SIZE  equ 4                   ; 4 bytes
    DEPTH_SIZE      equ 4                   ; 4 bytes
    LOCATION_SIZE   equ 128                 ; 128 bytes
    ORIGIN_SIZE     equ 128                 ; 128 bytes
    C_REPORT_SIZE   equ 256                 ; 256 bytes
    LATITUDE_SIZE   equ 4                   ; 4 bytes
    LONGITUDE_SIZE  equ 4                   ; 4 bytes
    ; Manejo de memoria
    SISMO_SIZE      equ 560                 ; Largo (en bytes) reservado para cada sismo
    SISMOS_ARR_N    equ 256                 ; Cantidad maxima de sismos de la tabla
    SISMOS_ARR_SIZE equ SISMOS_ARR_N * SISMO_SIZE   ; Largo (en bytes) de la tabla
    global sismos_arr
    sismos_arr      resb SISMOS_ARR_SIZE    ; Reserva la memoria para la tabla
    sismos_i        resb 4                  ; Reserva 4B para manejar el indice del arreglo
    global sismos_n
    sismos_n        resb 1                  ; Reserva 1B para almacenar la cantidad de sismos del .CSV
    BUFFER_LEN      equ  1024               ; Reserva 1KB para el buffer de lectura del .CSV
    global buffer
    buffer          resb BUFFER_LEN         ; Reserva 128B para el buffer
    buffer_aux      resb 32                 ; Reserva 32B para buffer auxiliar (flotantes)
    global b_readed
    b_readed        resb 2                  ; Reserva 2B para llevar el conteo de los bytes del archivo leidos
    global file_desc
    file_desc       resd 1                  ; Reserva 4B para el descriptor del archivo abierto
    ; Auxiliares de conversion a flotante
    fint_part       resb 4
    fdec_part       resb 4
    fdec_offset     resb 4
    fresult         resb 4
    ; Parametros de llamada al servicio de descarga
    param_one       resb 16

section .text
    ; extern atof                     ; Funcion en C (ascii a flotante)
    ; global _start
    ; global parse_data               ; Falla :(
    ; global string_to_float

_start:
    jmp _exit

_exit:
    mov eax, 60                     ; Llamada al sistema sys_exit
    mov edi, 0
    int 0x80

; Leer archivo archivo abierto anteriormente (con alguna de las funciones open_sX_file; X = {a, s})
; Sin tantos mecanismos de proteccion por terminos de tiempo
read_file:
    mov eax, 3                      ; Llamada al sistema sys_read
    mov ebx, [file_desc]            ; Descriptor de archivo
    lea ecx, buffer                 ; Buffer donde se almacenan los datos
    mov edx, BUFFER_LEN             ; Limite de lectura (en bytes)
    int 0x80
    mov word [b_readed], ax         ; Guarda la cantidad de bytes leidos
    ret

parse_data:
    cmp word [file_desc],   0x0     ; Verifica que haya un archivo abierto
    jle .parse_data_end
    call read_file
    lea esi, buffer                 ; Carga la direccion del buffer
    mov dword [sismos_i],   0x0     ; Inicializa indice del arreglo
; Verifica el tipo de .CSV (anual, reciente)
.verify_sismo_doc_type:
    lodsb
    cmp al, 'S'                     ; Valida si el primer caracter del .CSV es "S"
    je .s_anual_doc_type

.s_reciente_doc_type:
    mov byte [sismos_n], 20         ; s_recientes contiene 20 elementos (sismos)
    jmp .adjust_header_offset       ; Procede a ajustar el desplazamiento de los encabezados

; Verifica cuantos elementos tiene el documento mediante la primera linea
.s_anual_doc_type:
    lodsb
    cmp al, '='
    jne .s_anual_doc_type
    lodsb                           ; Descarta el espacio despues de '='
    call string_to_int              ; Convierte el segmento del string a entero y retorna en ECX
    mov byte [sismos_n], cl         ; Almacena la cantidad de elementos del CSV

.adjust_header_offset:
    lodsb
    cmp al, LINE_FEED
    jne .adjust_header_offset
    mov ecx, esi                    ; Copia dir. actual en el buffer
    sub ecx, buffer                 ; Obtiene la cantidad de b_procesados (pos. act. - pos. buffer)

.parse_sismos_loop:
    ; Ajuste del indice para accesar y a sismos_arr[i]
    lea edi, sismos_arr             ; Carga la dir de sismos_arr en EDI (stosb)
    add edi, sismos_i               ; Ajusta sismos_arr[i]

.s_date:
    lodsb                           ; Carga en AL el caracter buffer[i] e incrementa i
    inc cx                          ; Aumenta el contador de bytes procesados
    cmp al, CSV_SEP                 ; Compara el caracter con el separador del .csv
    je .s_date_end                  ; Salta si llego al separador
    stosb
    jmp .s_date

.s_date_end:
    mov al, EOF                     ; Concatena el final de linea en la propiedad
    stosb
    add word [sismos_i], DATE_SIZE  ; Ajustar el indice a la sig. propiedad
    lea edi, sismos_arr
    add edi, sismos_i               ; Ajusta sismos_arr[i] a la sig. prop.

.s_hour:
    lodsb                           ; Carga en AL el caracter buffer[i] e incrementa i
    inc cx                          ; Aumenta el contador de bytes procesados
    cmp al, CSV_SEP                 ; Compara el caracter con el separador del .csv
    je .s_hour_end                  ; Salta si llego al separador
    stosb                           ; Guarda AL en sismos_arr[i] e incrementa i
    jmp .s_hour

.s_hour_end:
    mov al, EOF                     ; Concatena el final de linea en la propiedad
    stosb
    add word [sismos_i], HOUR_SIZE  ; Ajustar el indice a la sig. propiedad
    lea edi, buffer_aux             ; Carga el buffer auxilar para la conversion del flotante

.s_magnitude:
    lodsb                           ; Carga en AL el caracter buffer[i] e incrementa i
    inc cx                          ; Aumenta el contador de bytes procesados
    cmp al, CSV_SEP                 ; Compara el caracter con el separador del .csv
    je .s_magnitude_end             ; Salta si llego al separador
    stosb
    jmp .s_magnitude

.s_magnitude_end:
    mov al, EOF                     ; Concatena el final de linea en la propiedad
    stosb

    push rsi                        ; Guarda RSI
    lea rsi, buffer_aux             ; Carga el buffer auxiliar en ESI
    call atof                       ; Convierte el string a flotante
    pop rsi                         ; Restaura ESI (buffer)

    lea edi, sismos_arr             ; Carga sismos_arr en EDI
    add edi, sismos_i               ; Ajusta sismos_arr[i] para guardar el flotante
    fstp qword [fresult]            ; Almacena el valor del tope de la FPU en fresult
    mov qword [edi], fresult        ; Guarda el flotante en memoria

    add word [sismos_i], MAGNITUDE_SIZE ; Ajustar el indice a la sig. propiedad
    lea edi, buffer_aux             ; Carga el buffer auxiliar en EDI para convertir el flotante

.s_depth:
    lodsb                           ; Carga en AL el caracter buffer[i] e incrementa i
    inc cx                          ; Aumenta el contador de bytes procesados
    cmp al, CSV_SEP                 ; Compara el caracter con el separador del .csv
    je .s_depth_end                 ; Salta si llego al separador
    stosb                           ; Guarda AL en el buffer auxiliar
    jmp .s_depth

.s_depth_end:
    mov al, EOF                     ; Concatena el final de linea de la propiedad
    stosb

    push rsi                        ; Guarda RSI
    lea rsi, buffer_aux             ; Carga el buffer auxiliar en ESI
    call atof                       ; Convierte el string a flotante
    pop rsi                         ; Restaura ESI (buffer)

    lea edi, sismos_arr             ; Carga sismos_arr en EDI
    add edi, sismos_i               ; Ajusta sismos_arr[i] para guardar el flotante
    fstp qword [fresult]            ; Almacena el valor del tope de la FPU en fresult
    mov qword [edi], fresult        ; Guarda el flotante en memoria

    add word [sismos_i], MAGNITUDE_SIZE ; Ajustar el indice a la sig. propiedad
    add edi, MAGNITUDE_SIZE         ; Ajusta sismos_arr[i] a la sig. prop.

.s_location:
    lodsb                           ; Carga en AL el caracter buffer[i] e incrementa i
    inc cx                          ; Aumenta el contador de bytes procesados
    cmp al, CSV_SEP                 ; Compara el caracter con el separador del .csv
    je .s_location_end              ; Salta si llego al separador
    stosb
    jmp .s_location

.s_location_end:
    mov al, EOF                     ; Concatena el final de linea en la propiedad
    stosb
    add word [sismos_i], LOCATION_SIZE  ; Ajustar el indice a la sig. propiedad
    lea edi, sismos_arr
    add edi, sismos_i               ; Ajusta sismos_arr[i] a la sig. prop.

.s_origin:
    lodsb                           ; Carga en AL el caracter buffer[i] e incrementa i
    inc cx                          ; Aumenta el contador de bytes procesados
    cmp al, CSV_SEP                 ; Compara el caracter con el separador del .csv
    je .s_origin_end                ; Salta si llego al separador
    stosb
    jmp .s_origin

.s_origin_end:
    mov al, EOF                     ; Concatena el final de linea en la propiedad
    stosb
    add word [sismos_i], ORIGIN_SIZE    ; Ajustar el indice a la sig. propiedad
    lea edi, sismos_arr
    add edi, sismos_i               ; Ajusta sismos_arr[i] a la sig. prop.

.s_c_report:
    lodsb                           ; Carga en AL el caracter buffer[i] e incrementa i
    inc cx                          ; Aumenta el contador de bytes procesados
    cmp al, CSV_SEP                 ; Compara el caracter con el separador del .csv
    je .s_c_report_end              ; Salta si llego al separador
    stosb
    jmp .s_c_report

.s_c_report_end:
    mov al, EOF                     ; Concatena el final de linea en la propiedad
    stosb
    add word [sismos_i], C_REPORT_SIZE  ; Ajustar el indice a la sig. propiedad
    lea edi, buffer_aux             ; Carga el buffer auxilar para la conversion del flotante

.s_latitude:
    lodsb                           ; Carga en AL el caracter buffer[i] e incrementa i
    inc cx                          ; Aumenta el contador de bytes procesados
    cmp al, CSV_SEP                 ; Compara el caracter con el separador del .csv
    je .s_latitude_end              ; Salta si llego al separador
    stosb                           ; Guarda AL en el buffer auxiliar
    jmp .s_latitude

.s_latitude_end:
    mov al, EOF                     ; Concatena el final de linea en la propiedad
    stosb

    push rsi                        ; Guarda RSI
    lea rsi, buffer_aux             ; Carga el buffer auxiliar en ESI
    call atof                       ; Convierte el string a flotante
    pop rsi                         ; Restaura ESI (buffer)

    lea edi, sismos_arr             ; Carga sismos_arr en EDI
    add edi, sismos_i               ; Ajusta sismos_arr[i] para guardar el flotante
    fstp qword [fresult]            ; Almacena el valor del tope de la FPU en fresult
    mov qword [edi], fresult        ; Guarda el flotante en memoria

    add word [sismos_i], LATITUDE_SIZE ; Ajustar el indice a la sig. propiedad
    lea edi, buffer_aux             ; Carga el buffer auxiliar en EDI para convertir el flotante

.s_longitude:
    lodsb                           ; Carga en AL el caracter buffer[i] e incrementa i
    inc cx                          ; Aumenta el contador de bytes procesados
    cmp al, LINE_FEED               ; Compara el caracter con el separador del .csv
    je .s_longitude_end             ; Salta si llego al separador
    stosb
    jmp .s_longitude

.s_longitude_end:
    mov al, EOF                     ; Concatena el final de linea en la propiedad
    stosb

    push rsi                        ; Guarda RSI
    lea rsi, buffer_aux             ; Carga el buffer auxiliar en ESI
    call atof                       ; Convierte el string a flotante
    pop rsi                         ; Restaura ESI (buffer)

    lea edi, sismos_arr             ; Carga sismos_arr en EDI
    add edi, sismos_i               ; Ajusta sismos_arr[i] para guardar el flotante
    fstp qword [fresult]            ; Almacena el valor del tope de la FPU en fresult
    mov qword [edi], fresult        ; Guarda el flotante en memoria

    add word [sismos_i], LONGITUDE_SIZE  ; Ajustar el indice a la sig. propiedad

.adjust_file_ptr:

    ; TODO: Carga con lseek - desplazamiento en ECX - b_readed
    ;xor ecx, ecx                    ; Resetea el contador de bytes procesados
    ;lea esi, buffer                 ; Carga la dir del buffer en ESI (lodsb)

.parse_data_end:
    ret

; Cerrar archivo
close_file:
    mov eax, 6                      ; Llamda al sistema sys_close
    mov ebx, esi                    ; Descriptor de archivo
    int 0x80

    ret

; Convierte un string a un numero flotante.
; El puntero al string debe estar en EDI (ABI), ademas debe representar un numero en decimal (ej. 3.14) y finalizar en 0 (EOF)
string_to_float:
    mov esi, edi
    mov dword [fint_part], 0x0
    mov dword [fdec_part], 0x0
    mov dword [fdec_offset], 0xA
    mov dword [fresult], 0x0

.integer_part:
    lodsb                           ; Carga caracter en AL y avanza a la sig. pos.
    test al, al                     ; Verifica si la cadena esta vacia
    jz .conversion_end
    xor ecx, ecx                    ; Limpia ECX para pasar a la conversion
    cmp al, '-'                     ; Comprobacion de signo
    jne .integer_loop               ; Salta si es positivo
    mov ah, 0x1                     ; Marcar AH = 1 para indicar que hay signo
    lodsb

.integer_loop:
    sub al, '0'                     ; Resta el caracter para convertir a entero
    movzx edx, al                   ; EDX = AL (+ajuste del valor de registro 8 bits a 32 bits con ceros)
    add ecx, edx                    ; Suma el digito a ECX
    lodsb
    test al, al                     ; Verifica si el caracter
    jz .joint_parts                 ; Salta si se llego al final de la cadena
    cmp al, '.'                     ; Comprobacion de caracter
    jne .sign_verification          ; Salta si se llego al punto decimal
    imul ecx, 10                    ; ECX = ECX * 10 (Desplazar en 1 digito hacia la izq.)
    jmp .integer_loop               ; Continuar loop

.sign_verification:                 ; Error en numero entero -0.XXX... (entero -0)(necesita ajuste)
    test ah, ah
    jz .decimal_part                ; Pasa a convertir la parte decimal si no hay signo
    neg ecx                         ; En caso de signo, ECX se invierte, (complemento a 2)

.decimal_part:
    mov [fint_part], ecx            ; Guarda la conversion de la parte entera
    xor ecx, ecx                    ; Limpia ECX para pasar a la conversion
    lodsb                           ; Carga el caracter despues del punto decimal

.decimal_loop:
    sub al, '0'                     ; Resta el caracter para convertir a entero
    movzx edx, al
    add ecx, edx                    ; Suma el digito a ECX
    mov edx, dword [fdec_offset]    ; Carga el offset en EBX
    imul edx, 10                    ; EBX = EBX * 10 (Aumentar offset de decimales en 10 (0xA))
    mov dword [fdec_offset], edx    ; Guarda el nuevo offset
    lodsb
    test al, al                     ; Verifica si el caracter
    jz .joint_parts                 ; Salta si se llego al final de la cadena
    imul ecx, 10                    ; ECX = ECX * 10 (Desplazar en 1 digito hacia la izq.)
    jmp .decimal_loop               ; Continuar loop

.joint_parts:
    mov [fdec_part], ecx            ; Guarda la conversion de la parte decimal
    ; Libera los ultimos 2 registros (al fondo) del stack FPU
    ffree st7
    ffree st6
    fild dword [fint_part]          ; Carga (y convierte a formato REAL10) fint_part en el stack FPU (ST[0] = [fint_part])
    fild dword [fdec_part]          ; ST[0] = [fdec_part]
    fidiv dword [fdec_offset]       ; ST[0] = ST[0]/[fdec_offset]
    fadd st1                        ; ST[0] = ST[0] + ST[1]
    fstp dword [fresult]            ; [fresult] = (REAL4) ST[0] y saca ST[0] de la pila

.conversion_end:
    mov eax, dword [fresult]        ; Retorna el resultado en EAX (ABI)
    ret
    call atof                 ; Llama a la función atof
; Convierte un string a un numero flotante.
; El puntero al string debe estar en ESI, ademas debe finalizar en 0 (EOF)
string_to_int:
    lodsb                           ; Carga caracter en AL y avanza a la sig. pos.
    test al, al                     ; Verifica si la cadena esta vacia
    jz .conversion_end
    xor ecx, ecx                    ; Limpia ECX para pasar a la conversion
    cmp al, '-'                     ; Comprobacion de signo
    jne .conversion_loop            ; Salta si es positivo
    mov ah, 0x1                     ; Marcar AH = 1 para indicar que hay signo
    lodsb

.conversion_loop:
    sub al, '0'                     ; Resta el caracter para convertir a entero
    movzx edx, al                   ; EDX = AL (+ajuste del valor de registro 8 bits a 32 bits con ceros)
    add ecx, edx                    ; Suma el digito a ECX
    lodsb
    cmp al, 0                       ; Comprobacion de caracter
    jne .sign_verification          ; Salta si se llego al EOF
    cmp al, LINE_FEED               ; Comprobacion de caracter
    jne .sign_verification          ; Salta si se llego a \n
    imul ecx, 10                    ; ECX = ECX * 10 (Desplazar en 1 digito hacia la izq.)
    jmp .conversion_loop            ; Continuar loop

.sign_verification:
    test ah, ah
    jz .conversion_end              ; Retorna si no hay signo
    neg ecx   
.conversion_end:
    ret

; ECX -> dir. del msg
; EDX -> largo del msg
print:
    mov eax, 4                       ; sys_write
    mov ebx, 1                       ; std_out
    int 0x80
    ret