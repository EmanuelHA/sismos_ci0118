section .data
    filename    db "ssentidos_ovsicori.csv", 0  ; Nombre del archivo
    buffer      db 256                          ; Reserva 256B para el buffer
    dwnldr_path db './data_downloader', 0       ; Ruta al servicio de descarga

section .bss
sismo:
    date        resb 16
    time        resb 16
    magnitude   resb 4
    depth       resb 4
    location    resb 128
    origen      resb 128
    city_report resb 256
    latitude    resb 4
    longitude   resb 4
    SISMO_LEN   equ $ - sismo

    ; Parametros de llamada al servicio de descarga
    param_one   resb 4
    param_two   resb 4

sismos_array    db 256 * SISMO_LEN
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
    je .close_file                    ; Salta a cerrar el archivo si termina

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

download_data:
    ; Preparar los argumentos para execve
    mov ebx, dwnldr_path    ; Ruta al ejecutable
    lea ecx, [param_one]    ; Primer parametro
    lea edx, [param_two]    ; Segundo parametro
    xor edi, edi            ; Limpiar EDI (indicador de ultimo parametro)

    ; Llamar a execve
    mov eax, 11             ; syscall execve
    int 0x80

    mov eax, 1              ; Llamada al sistema exit
    xor ebx, ebx
    int 0x80                ; Salida normal del programa

convert_to_float:

.integer_part:

.decimal_part:
    ret

