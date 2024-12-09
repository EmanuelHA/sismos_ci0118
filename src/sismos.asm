section .data
    CSV_SEP         equ ';'                             ; Separador de archivos .CSV
    LINE_FEED       equ 0xA                             ; Salto de linea (ASCII)
    ss_fname        db  "s_sentidos_ovsicori.csv", 0  ; Nombre del archivo Sismos Sentidos recientes
    sa_fname        db  "s_anuales_ovsicori.csv", 0   ; Nombre del archivo Sismos Anuales

    python_path db '/usr/bin/python3', 0            ; Ruta al interprete de Python
    script_name db 'data_downloader.py', 0          ; Nombre del script
    ; Array de argumentos
    args        dd python_path
                dd script_name
                dd param_one, 0
    env         dd 0                                ; Entorno (NULL)

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
    BUFFER_LEN      equ  256
    buffer          resb BUFFER_LEN         ; Reserva 128B para el buffer
    buffer_aux      resb 16                 ; Reserva 16B para buffer auxiliar (flotantes)
    b_readed        resb 2                  ; Reserva 2B para llevar el conteo de los bytes del archivo leidos
    b_processed     resb 2                  ; Reserva 2B para el indice del buffer
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
    ; global _start
    global open_sa_file
    global open_ss_file
    global parse_data

_start:
    jmp _exit

_exit:
    mov eax, 60                     ; Llamada al sistema sys_exit
    mov edi, 0
    int 0x80

; Abrir archivo de sismos anuales
open_sa_file:
    mov eax, 5                      ; Llamada al sistema sys_open
    mov ebx, sa_fname               ; Nombre del archivo
    mov ecx, 0                      ; Modo lectura
    int 0x80
    mov [file_desc], eax            ; Guarda el File Descriptor

    ret

; Abrir archivo de sismos sentidos
open_ss_file:
    mov eax, 5                      ; Llamada al sistema sys_open
    mov ebx, ss_fname               ; Nombre del archivo
    mov ecx, 0                      ; Modo lectura
    int 0x80

    mov [file_desc], eax            ; Guarda el File Descriptor
    ret

; Leer archivo archivo abierto anteriormente (con alguna de las funciones open_sX_file; X = {a, s})
read_file:
    mov eax, 3                      ; Llamada al sistema sys_read
    mov ebx, [file_desc]            ; Descriptor de archivo
    lea ecx, buffer                 ; Buffer donde se almacenan los datos
    mov edx, BUFFER_LEN             ; Limite de lectura (en bytes)
    int 0x80

    mov word [b_readed], ax         ; Guarda la cantidad de bytes leidos
    ret
parse_data:
    lea esi, buffer                 ; Carga la direccion del buffer
    mov dword [sismos_i],   0x0     ; Inicializa indice del arreglo
    mov word [b_processed], 0x0     ; Inicializa el contador de bytes procesados
    cmp word [b_readed],    256     ; Valida carga completa del buffer
    jl .parse_data_end
; Verifica el tipo de .CSV (anual, reciente)
.verify_sismo_doc_type:
    lodsb
    cmp al, 'S'
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
    mov eax, esi                    ; Hace un respaldo de la dir. actual en el buffer
    sub eax, buffer                 ; Resta la dir. del buffer de la dir. actual
    mov word [b_processed], ax      ; Guarda el calculo del indice en b_processed

.parse_sismos_loop:

.adjust_date_offset:
    lea edi, sismos_arr             ; Carga la dir. base de sismos_arr
    add edi, dword [sismos_i]       ; Ajusta el desplazamiento
.load_date:
    mov ax, word [b_processed]
    cmp ax, word [b_readed]         ; Compara la cantidad de los bytes leidos con los procesados
    jl .store_date                  ; Salta si aun hay datos por leer en el buffer
    call read_file                  ; Carga datos al buffer
    lea esi, buffer                 ; Carga la direccion del buffer
    test eax, eax                   ; Verifica si se ha alcanzado el fin del archivo (EAX = 0)
    jz .parse_data_end              ; Salta al fin del analisis de los datos
.store_date:
    lodsb                           ; Carga sig. byte del buffer y aumenta ESI
    inc word [b_processed]          ; Aumenta el numero de bytes procesados
    cmp al, CSV_SEP                 ; Compara con el separador del CSV (;)
    je .adjust_hour_offset
    stosb                           ; Guarda el caracter en la dir. de ESI e inc. ESI
    jmp .load_date                  ; Salta a extraer siguiente caracter

.adjust_hour_offset:
    mov al, 0x0                     ; AL = EOF
    stosb                           ; Coloca al final de la cadena anterior (en EDI) un EOF

    add dword [sismos_i], DATE_SIZE ; Ajusta el desplazamiento al siguiente dato
    lea edi, sismos_arr             ; Carga la dir. base de sismos_arr
    add edi, dword [sismos_i]       ; Ajusta el desplazamiento

.load_hour:
    mov ax, word [b_processed]
    cmp ax, word [b_readed]         ; Compara la cantidad de los bytes leidos con los procesados
    jl .store_hour                  ; Salta si aun hay datos por leer en el buffer
    call read_file                  ; Carga datos al buffer
    lea esi, buffer                 ; Carga la direccion del buffer
    test eax, eax                   ; Verifica si se ha alcanzado el fin del archivo (EAX = 0)
    jz .parse_data_end              ; Salta al fin del analisis de los datos

.store_hour:
    lodsb                           ; Carga sig. byte del buffer y aumenta ESI
    inc word [b_processed]          ; Aumenta el numero de bytes procesados
    cmp al, CSV_SEP                 ; Compara con el separador del CSV (;)
    je .adjust_magnitude_offset
    stosb                           ; Guarda el caracter en la dir. de ESI e inc. ESI
    jmp .load_hour                  ; Salta a extraer siguiente caracter

.adjust_magnitude_offset:
    mov al, 0x0                     ; AL = EOF
    stosb                           ; Coloca al final de la cadena anterior (en EDI) un EOF
    add dword [sismos_i], HOUR_SIZE ; Ajusta el desplazamiento al siguiente dato
    lea edi, buffer_aux             ; Carga el buffer auxiliar para convertir el punto flotante
    
.load_magnitude:
    mov ax, word [b_processed]
    cmp ax, word [b_readed]         ; Compara la cantidad de los bytes leidos con los procesados
    jl .store_magnitude             ; Salta si aun hay datos por leer en el buffer
    call read_file                  ; Carga datos al buffer
    lea esi, buffer                 ; Carga la direccion del buffer
    test eax, eax                   ; Verifica si se ha alcanzado el fin del archivo (EAX = 0)
    jz .parse_data_end              ; Salta al fin del analisis de los datos

.store_magnitude:
    lodsb                           ; Carga sig. byte del buffer y aumenta ESI
    inc word [b_processed]          ; Aumenta el numero de bytes procesados
    cmp al, CSV_SEP                 ; Compara con el separador del CSV (;)
    je .convert_magnitude
    stosb                           ; Guarda el caracter en la dir. de ESI e inc. ESI
    jmp .load_magnitude             ; Salta a extraer siguiente caracter

.convert_magnitude:
    mov al, 0x0                     ; AL = EOF
    stosb                           ; Coloca al final de la cadena anterior (en EDI) un EOF
    push rsi                        ; Guarda ESI (ptr. buffer)
    mov esi, edi
    call string_to_float            ; Convierte el buffer auxiliar a flotante
    pop rsi                         ; Recupera el puntero al buffer
    lea edi, sismos_arr             ; Carga la dir. base de sismos_arr
    add edi, dword [sismos_i]       ; Ajusta el desplazamiento
    mov edi, dword [fresult]        ; Almacena el flotante

.adjust_depth_offset:
    add dword [sismos_i], MAGNITUDE_SIZE    ; Ajusta el desplazamiento al siguiente dato
    lea edi, buffer_aux             ; Carga el buffer auxiliar para convertir el punto flotante
    
.load_depth:
    mov ax, word [b_processed]
    cmp ax, word [b_readed]         ; Compara la cantidad de los bytes leidos con los procesados
    jl .store_depth                 ; Salta si aun hay datos por leer en el buffer
    call read_file                  ; Carga datos al buffer
    lea esi, buffer                 ; Carga la direccion del buffer
    test eax, eax                   ; Verifica si se ha alcanzado el fin del archivo (EAX = 0)
    jz .parse_data_end              ; Salta al fin del analisis de los datos

.store_depth:
    lodsb                           ; Carga sig. byte del buffer y aumenta ESI
    inc word [b_processed]          ; Aumenta el numero de bytes procesados
    cmp al, CSV_SEP                 ; Compara con el separador del CSV (;)
    je .convert_depth
    stosb                           ; Guarda el caracter en la dir. de ESI e inc. ESI
    jmp .load_depth                 ; Salta a extraer siguiente caracter

.convert_depth:
    mov al, 0x0                     ; AL = EOF
    stosb                           ; Coloca al final de la cadena anterior (en EDI) un EOF
    push rsi                        ; Guarda ESI (ptr. buffer)
    mov esi, edi
    call string_to_float            ; Convierte el buffer auxiliar a flotante
    pop rsi                         ; Recupera el puntero al buffer
    lea edi, sismos_arr             ; Carga la dir. base de sismos_arr
    add edi, dword [sismos_i]       ; Ajusta el desplazamiento
    mov edi, dword [fresult]        ; Almacena el flotante

.adjust_location_offset:
    add dword [sismos_i], DEPTH_SIZE    ; Ajusta el desplazamiento al siguiente dato
    lea edi, sismos_arr             ; Carga la dir. base de sismos_arr
    add edi, dword [sismos_i]       ; Ajusta el desplazamiento

.load_location:
    mov ax, word [b_processed]
    cmp ax, word [b_readed]         ; Compara la cantidad de los bytes leidos con los procesados
    jl .store_location              ; Salta si aun hay datos por leer en el buffer
    call read_file                  ; Carga datos al buffer
    lea esi, buffer                 ; Carga la direccion del buffer
    test eax, eax                   ; Verifica si se ha alcanzado el fin del archivo (EAX = 0)
    jz .parse_data_end              ; Salta al fin del analisis de los datos

.store_location:
    lodsb                           ; Carga sig. byte del buffer y aumenta ESI
    inc word [b_processed]          ; Aumenta el numero de bytes procesados
    cmp al, CSV_SEP                 ; Compara con el separador del CSV (;)
    je .adjust_origin_offset
    stosb                           ; Guarda el caracter en la dir. de ESI e inc. ESI
    jmp .load_location              ; Salta a extraer siguiente caracter

.adjust_origin_offset:
    mov al, 0x0                     ; AL = EOF
    stosb                           ; Coloca al final de la cadena anterior (en EDI) un EOF

    add dword [sismos_i], LOCATION_SIZE ; Ajusta el desplazamiento al siguiente dato
    lea edi, sismos_arr             ; Carga la dir. base de sismos_arr
    add edi, dword [sismos_i]       ; Ajusta el desplazamiento

.load_origin:
    mov ax, word [b_processed]
    cmp ax, word [b_readed]         ; Compara la cantidad de los bytes leidos con los procesados
    jl .store_origin                ; Salta si aun hay datos por leer en el buffer
    call read_file                  ; Carga datos al buffer
    lea esi, buffer                 ; Carga la direccion del buffer
    test eax, eax                   ; Verifica si se ha alcanzado el fin del archivo (EAX = 0)
    jz .parse_data_end              ; Salta al fin del analisis de los datos

.store_origin:
    lodsb                           ; Carga sig. byte del buffer y aumenta ESI
    inc word [b_processed]          ; Aumenta el numero de bytes procesados
    cmp al, CSV_SEP                 ; Compara con el separador del CSV (;)
    je .adjust_c_report_offset
    stosb                           ; Guarda el caracter en la dir. de ESI e inc. ESI
    jmp .load_origin                ; Salta a extraer siguiente caracter

.adjust_c_report_offset:
    mov al, 0x0                     ; AL = EOF
    stosb                           ; Coloca al final de la cadena anterior (en EDI) un EOF

    add dword [sismos_i], ORIGIN_SIZE   ; Ajusta el desplazamiento al siguiente dato
    lea edi, sismos_arr             ; Carga la dir. base de sismos_arr
    add edi, dword [sismos_i]       ; Ajusta el desplazamiento

.load_c_report:
    mov ax, word [b_processed]
    cmp ax, word [b_readed]         ; Compara la cantidad de los bytes leidos con los procesados
    jl .store_c_report              ; Salta si aun hay datos por leer en el buffer
    call read_file                  ; Carga datos al buffer
    lea esi, buffer                 ; Carga la direccion del buffer
    test eax, eax                   ; Verifica si se ha alcanzado el fin del archivo (EAX = 0)
    jz .parse_data_end              ; Salta al fin del analisis de los datos

.store_c_report:
    lodsb                           ; Carga sig. byte del buffer y aumenta ESI
    inc word [b_processed]          ; Aumenta el numero de bytes procesados
    cmp al, CSV_SEP                 ; Compara con el separador del CSV (;)
    je .adjust_latitude_offset
    stosb                           ; Guarda el caracter en la dir. de ESI e inc. ESI
    jmp .load_c_report              ; Salta a extraer siguiente caracter

.adjust_latitude_offset:
    mov al, 0x0                     ; AL = EOF
    stosb                           ; Coloca al final de la cadena anterior (en EDI) un EOF
    add dword [sismos_i], C_REPORT_SIZE ; Ajusta el desplazamiento al siguiente dato
    lea edi, buffer_aux             ; Carga el buffer auxiliar para convertir el punto flotante
    
.load_latitude:
    mov ax, word [b_processed]
    cmp ax, word [b_readed]         ; Compara la cantidad de los bytes leidos con los procesados
    jl .store_latitude             ; Salta si aun hay datos por leer en el buffer
    call read_file                  ; Carga datos al buffer
    lea esi, buffer                 ; Carga la direccion del buffer
    test eax, eax                   ; Verifica si se ha alcanzado el fin del archivo (EAX = 0)
    jz .parse_data_end              ; Salta al fin del analisis de los datos

.store_latitude:
    lodsb                           ; Carga sig. byte del buffer y aumenta ESI
    inc word [b_processed]          ; Aumenta el numero de bytes procesados
    cmp al, CSV_SEP                 ; Compara con el separador del CSV (;)
    je .convert_latitude
    stosb                           ; Guarda el caracter en la dir. de ESI e inc. ESI
    jmp .load_latitude              ; Salta a extraer siguiente caracter

.convert_latitude:
    mov al, 0x0                     ; AL = EOF
    stosb                           ; Coloca al final de la cadena anterior (en EDI) un EOF
    push rsi                        ; Guarda ESI (ptr. buffer)
    mov esi, edi
    call string_to_float            ; Convierte el buffer auxiliar a flotante
    pop rsi                         ; Recupera el puntero al buffer
    lea edi, sismos_arr             ; Carga la dir. base de sismos_arr
    add edi, dword [sismos_i]       ; Ajusta el desplazamiento
    mov edi, dword [fresult]        ; Almacena el flotante

.adjust_longitude_offset:
    add dword [sismos_i], LATITUDE_SIZE ; Ajusta el desplazamiento al siguiente dato
    lea edi, buffer_aux             ; Carga el buffer auxiliar para convertir el punto flotante
    
.load_longitude:
    mov ax, word [b_processed]
    cmp ax, word [b_readed]         ; Compara la cantidad de los bytes leidos con los procesados
    jl .store_longitude             ; Salta si aun hay datos por leer en el buffer
    call read_file                  ; Carga datos al buffer
    lea esi, buffer                 ; Carga la direccion del buffer
    test eax, eax                   ; Verifica si se ha alcanzado el fin del archivo (EAX = 0)
    jz .parse_data_end              ; Salta al fin del analisis de los datos

.store_longitude:
    lodsb                           ; Carga sig. byte del buffer y aumenta ESI
    inc word [b_processed]          ; Aumenta el numero de bytes procesados
    cmp al, CSV_SEP                 ; Compara con el separador del CSV (;)
    je .convert_longitude
    stosb                           ; Guarda el caracter en la dir. de ESI e inc. ESI
    jmp .load_longitude             ; Salta a extraer siguiente caracter

.convert_longitude:
    mov al, 0x0                     ; AL = EOF
    stosb                           ; Coloca al final de la cadena anterior (en EDI) un EOF
    push rsi                        ; Guarda ESI (ptr. buffer)
    mov esi, edi
    call string_to_float            ; Convierte el buffer auxiliar a flotante
    pop rsi                         ; Recupera el puntero al buffer
    lea edi, sismos_arr             ; Carga la dir. base de sismos_arr
    add edi, dword [sismos_i]       ; Ajusta el desplazamiento
    mov edi, dword [fresult]        ; Almacena el flotante

    add dword [sismos_i], LONGITUDE_SIZE    ; Ajusta el desplazamiento del ultimo dato
    cmp dword [sismos_i], SISMOS_ARR_SIZE   ; Compara para saber si se alcanzo el maximo de la tabla
    jl .parse_sismos_loop

.parse_data_end:
    ret

; Cerrar archivo
close_file:
    mov eax, 6                      ; Llamda al sistema sys_close
    mov ebx, esi                    ; Descriptor de archivo
    int 0x80

    ret

; Llamada a programa externo con parametros
download_data:
    ; Preparar los argumentos para execve
    mov eax, 11            ; Numero de syscall (execve)
    mov ebx, python_path   ; Ruta al ejecutable (Python)
    lea ecx, [args]        ; Puntero al array de argumentos
    lea edx, [env]         ; Puntero al entorno (NULL)
    int 0x80               ; Llamada al sistema

    ret

; Convierte un string a un numero flotante.
; El puntero al string debe estar en ESI, ademas debe representar un numero en decimal (ej. 3.14) y finalizar en 0 (EOF)
string_to_float:
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

.sign_verification:
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
    ret

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