section .data
    BUFFER_LEN      equ 512
; PSEUDO-STRUCT sismo
    SISMO_SIZE      equ 560                 ; Largo (en bytes) reservado para cada sismo
    SISMOS_ARR_N    equ 10                  ; Cantidad maxima de sismos de la tabla
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
    SISMOS_ARR_SIZE equ SISMOS_ARR_N * SISMO_SIZE   ; Largo (en bytes) de la tabla

section .bss
    global buffer
    buffer          resb BUFFER_LEN
    global sismos_arr
    sismos_arr      resb SISMOS_ARR_SIZE    ; Reserva la memoria para la tabla
    sismos_i        resb 4                  ; Reserva un entero para el indice i de sismos_arr
    sismos_j        resb 4                  ; Reserva un entero para el indice j de sismos_arr
    sismo_a         resb SISMO_SIZE         ; Reserva espacio para almacenar un objeto de tipo sismo
    sismo_b         resb SISMO_SIZE         ; Reserva espacio para almacenar un objeto de tipo sismo

section .text
; Abrir archivo
global open_file
; Leer archivo archivo
global read_file
; Desplazarse en el archivo
global seek_file
; Cerrar archivo
global close_file

open_file:
    mov eax, 5              ; Llam ada al sistema sys_open
    mov ebx, edi            ; string con ruta de archivo
    mov ecx, 0              ; MODO: 0: O_RDONLY - solo lectura
    xor edx, 0              ; Permisos (no necesario en modo 0)
    
    int 0x80                ; Interrupcion
    ret

read_file:
    cmp edi, 0
    jle .no_file
    mov eax, 3              ; Llamada al sistema sys_read
    mov ebx, edi            ; Descriptor de archivo
    lea ecx, buffer         ; Buffer donde se almacenan los datos
    mov edx, BUFFER_LEN     ; Limite de lectura (en bytes)
    int 0x80
    ret
.no_file:
    xor eax, eax
    ret

seek_file:
    cmp edi, 0
    jle .no_file
    mov eax, 19             ; Llamada al sistema sys_lseek
    mov ebx, edi            ; Descriptor de archivo
    mov ecx, esi            ; OFFSET
    ;  EDX - MODO           ; MODO: 0: SEEK_SET - desde inicio del archivo
                            ;       1: SEEK_CUR - desde posición actual
                            ;       2: SEEK_END - desde final del archivo
    int 0x80
.no_file:
    ret

close_file:
    mov eax, 6              ; Llamda al sistema sys_close
    mov ebx, edi            ; Descriptor de archivo
    int 0x80
    ret

; Datos ordenados por fecha por defecto
sort_sismos:
    ret