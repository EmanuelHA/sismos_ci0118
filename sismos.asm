section .data
    filename db "ssentidos_ovsicori.csv", 0     ; Nombre del archivo
    buffer   db 256                             ; Reserva 256B para el buffer

section .bss
Sismo:
    date        resb 16
    time        resb 16
    magnitude   resb 4
    depth       resb 4
    location    resb 128
    origen      resb 128
    city_report resb 512
    latitud     resb 4
    longitud    resb 4

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
    mov edx, 64                       ; Leer hasta 64 bytes
    int 0x80                          ; Llamada al sistema
    mov [bytes_read], eax             ; Guardar número de bytes leídos

    ; Comprobar fin de archivo
    cmp eax, 0                        ; Si eax = 0, alcanzó el fin de archivo
    je .close_file                    ; Salta a cerrar el archivo si termina

    ; Aquí puedes procesar los datos en 'buffer' de alguna forma
    ; Ejemplo: llamada a otro procedimiento, impresión en pantalla, etc.

    ; Repetir lectura
    jmp .read_loop                    ; Volver a leer

.close_file:
    ; Cerrar archivo (sys_close)
    mov eax, 6                        ; syscall número para sys_close
    mov ebx, esi                      ; Descriptor de archivo
    int 0x80                          ; Llamada al sistema

    ; Salir (sys_exit)
    mov eax, 1                        ; syscall número para sys_exit
    xor ebx, ebx                      ; Código de salida 0
    int 0x80                          ; Llamada al sistema
