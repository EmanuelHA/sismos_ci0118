section .data
    CSV_SEP     equ ';'                             ; Separador de archivos .CSV
    ss_fname    db  "s_sentidos_ovsicori.csv", 0    ; Nombre del archivo Sismos Sentidos recientes
    sa_fname    db  "s_anuales_ovsicori.csv", 0     ; Nombre del archivo Sismos Anuales
    dwnldr_path db  './data_downloader', 0          ; Ruta al servicio de descarga
section .bss
; PSEUDO-STRUCT sismo
sismo:
    ; Reserva los parametros necesarios para representar cada sismo
    date        resb 16
    time        resb 16
    magnitude   resb 4
    depth       resb 4
    location    resb 128
    origin      resb 128
    city_report resb 256
    latitude    resb 4
    longitude   resb 4
    SISMO_LEN   equ  560                ; Suma de todos los elementos de sismos
    sismos_arr  resb 256 * SISMO_LEN    ; Reserva la memoria para la tabla
    ; Parametro de llamada al servicio de descarga
    param_one   resb 4
    ; Auxiliares de conversion a flotante
    fint_part   resb 4
    fdec_part   resb 4
    fdec_offset resb 4
    fresult     resb 4

    buffer      resb 256                ; Reserva 256B para el buffer
    BUFFER_LEN  equ  256
    buffer_aux  resb 16                 ; Reserva 16B para buffer auxiliar

section .text
    global _start

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
    ret

; Abrir archivo de sismos sentidos
open_ss_file:
    mov eax, 5                      ; Llamada al sistema sys_open
    mov ebx, ss_fname               ; Nombre del archivo
    mov ecx, 0                      ; Modo lectura
    int 0x80
    ret

; Leer archivo archivo abierto con alguna de las funciones open_sX_file; X = {a, s}
read_file:
    mov eax, 3                      ; Llamada al sistema sys_read
    mov ebx, esi                    ; Descriptor de archivo
    mov ecx, buffer                 ; Buffer donde se almacenan los datos
    mov edx, BUFFER_LEN             ; Limite de lectura (en bytes)
    int 0x80

    cmp eax, 0                      ; EAX == EOF? (End Of File)
    jle .end_read_file              ; Finaliza la lectura (con codigo en EAX) si alcanza EOF o hay un error

mov esi, ecx
; Verifica el tipo de .CSV (anual, reciente)
.verify_sismo_doc_type:
    lodsb
    cmp al, 'S'
    je .s_anual_doc_type

.s_reciente_doc_type:
    mov ecx, 20                     ; s_recientes contiene 20 elementos (sismos)
    dec esi                         ; Ajusta ESI para apuntar al primer caracter
    jmp .read_file_loop             ; Procede a leer el archivo

.s_anual_doc_type:
    lodsb
    cmp al, '='
    je .s_anual_doc_type
    ; Verifica cuantos elementos tiene el documento mediante la primera linea

.read_file_loop:

    loop .read_file_loop
.parse_date:

.parse_time:

.parse_magnitude:

.parse_depth:

.parse_location:

.parse_origin:

.parse_city_report:

.parse_latitude:

.parse_longitude:

    jmp .read_file_loop             ; Continuar lectura del archivo
.end_read_file:
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
    mov ebx, dwnldr_path            ; Ruta al ejecutable
    lea ecx, [param_one]            ; Primer parametro
    xor edi, edx                    ; Limpiar EDX (indicador de ultimo parametro)
    mov eax, 11                     ; Llamada al sistema execve
    int 0x80

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
    imul ecx, 10                    ; ECX = ECX * 10 (Desplazar en 1 digito hacia la izq.)
    jmp .conversion_loop            ; Continuar loop

.sign_verification:
    test ah, ah
    jz .conversion_end              ; Retorna si no hay signo
    neg ecx   
.conversion_end:
    ret