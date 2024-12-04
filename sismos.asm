section .data
    filename    db "ssentidos_ovsicori.csv", 0  ; Nombre del archivo
    dwnldr_path db './data_downloader', 0       ; Ruta al servicio de descarga
section .bss
; PSEUDO-STRUCT sismo
sismo:
    ; Reserva los parametros necesarios para representar cada sismos
    date        resb 16
    time        resb 16
    magnitude   resb 4
    depth       resb 4
    location    resb 128
    origen      resb 128
    city_report resb 256
    latitude    resb 4
    longitude   resb 4
    SISMO_LEN   equ  $ - sismo                  ; Calcula el tamaño de sismos
    sismos_arr  resb 256 * SISMO_LEN            ; Reserva la memoria para la tabla
    ; Parametros de llamada al servicio de descarga
    param_one   resb 4
    param_two   resb 4
    ; Auxiliares de conversion a flotante
    fint_part   resb 4
    fdec_part   resb 4
    fdec_offset resb 4
    fresult     resb 4

    buffer      resb 256                          ; Reserva 256B para el buffer
section .text
    global _start
_start:
    jmp _exit

_exit:
    mov eax, 60                       ; Llamada al sistema sys_exit
    mov edi, 0
    int 0x80

open_file:
    mov eax, 5                        ; Llamada al sistema sys_open
    mov ebx, filename
    mov ecx, 0                        ; Modo lectura
    int 0x80
    ret

.read_loop:
    mov eax, 3                        ; Llamada al sistema sys_read
    mov ebx, esi                      ; Descriptor de archivo
    mov ecx, buffer                   ; Buffer donde almacenar datos
    mov edx, 64                       ; Leer 64 bytes
    int 0x80

    ; Comprobar fin de archivo
    cmp eax, 0                        ; EAX == EOF? (End Of File)
    je .close_file                    ; Salta a cerrar el archivo si alcanza EOF

    ; // TODO // Analizar y guardar los datos en el buffer

    ; Repetir lectura
    jmp .read_loop                    ; Volver a leer

.close_file:
    ; Cerrar archivo (sys_close)
    mov eax, 6                        ; Llamda al sistema sys_close
    mov ebx, esi                      ; Descriptor de archivo
    int 0x80

    ; Salir (sys_exit)
    mov eax, 1                        ; Llamada al sistema sys_exit
    xor ebx, ebx                      ; Codigo de salida
    int 0x80

; Llamada a programa externo con parametros
download_data:
    ; Preparar los argumentos para execve
    mov ebx, dwnldr_path    ; Ruta al ejecutable
    lea ecx, [param_one]    ; Primer parametro
    lea edx, [param_two]    ; Segundo parametro
    xor edi, edi            ; Limpiar EDI (indicador de ultimo parametro)

    ; Llamar a execve
    mov eax, 11             ; syscall execve
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
    lodsb                   ; Carga caracter en AL y avanza a la sig. pos.
    test al, al             ; Verifica si la cadena esta vacia
    jz .conversion_end
    xor ecx, ecx            ; Limpia ECX para pasar a la conversion
    cmp al, '-'             ; Comprobacion de signo
    jne .integer_loop       ; Salta si es positivo
    mov ah, 0x1             ; Marcar AH = 1 para indicar que hay signo
    lodsb
.integer_loop:
    sub al, '0'             ; Resta el caracter para convertir a entero
    movzx ebx, al
    add ecx, ebx            ; Suma el digito a ECX
    lodsb
    cmp al, '.'             ; Comprobacion de caracter
    jne .sign_verification  ; Salta si se llego al punto decimal
    imul ecx, 10            ; ECX = ECX * 10 (Desplazar en 1 digito hacia la izq.)
    jmp .integer_loop
.sign_verification:
    test ah, ah
    jz .decimal_part        ; Pasa a convertir la parte decimal si no hay signo
    neg ecx                 ; En caso de signo, ECX se invierte, (complemento a 2)
.decimal_part:
    mov [fint_part], ecx    ; Guarda la conversion de la parte entera
    xor ecx, ecx            ; Limpia ECX para pasar a la conversion
    lodsb                   ; Carga el caracter despues del punto decimal
.decimal_loop:
    sub al, '0'             ; Resta el caracter para convertir a entero
    movzx ebx, al
    add ecx, ebx            ; Suma el digito a ECX
    mov ebx, dword [fdec_offset]    ; Carga el offset en EBX
    imul ebx, 10                    ; EBX = EBX * 10 (Aumentar offset de decimales en 10 (0xA))
    mov dword [fdec_offset], ebx    ; Guarda el nuevo offset
    lodsb
    test al, al                     ; Verifica si el caracter
    jz .joint_parts                 ; Salta si se llego al final de la cadena
    imul ecx, 10                    ; ECX = ECX * 10 (Desplazar en 1 digito hacia la izq.)
    jmp .decimal_loop
.joint_parts:
    mov [fdec_part], ecx    ; Guarda la conversion de la parte decimal
    ; Libera los ultimos 2 registros (al fondo) del stack FPU
    ffree st7
    ffree st6
    fild dword [fint_part]      ; Carga (y convierte a formato REAL10) fint_part en el stack FPU ST[0] = [fint_part]
    fild dword [fdec_part]      ; ST[0] = [fdec_part]
    fidiv dword [fdec_offset]   ; ST[0] = ST[0]/[fdec_offset]
    fadd st1                    ; ST[0]  = ST[0] + ST[1]
    fstp dword [fresult]        ; [fresult] = ST[0] y saca ST[0] de la pila
.conversion_end:
    ret

