# Compilador C + banderillas
CC = gcc
C_FLAGS = -c
LD_FLAGS = -no-pie -z noexecstack
# Compilador S + banderillas
ASM = nasm
ASM_FLAGS = -f elf64
# Bamderillas de GTK
GTK_FLAGS = `pkg-config --cflags gtk4`
GTK_LIBS = `pkg-config --libs gtk4`
# Archivos fuente
C_SRC = main.c
ASM_SRC = sismos.asm
# Archivos objeto
C_OBJ = $(C_SRC:.c=.o)
ASM_OBJ = $(ASM_SRC:.asm=.o)
# Salida
TARGET = calc

# Regla predeterminada
all: $(TARGET)

# Regla para ejecutar el programa
run:
	./$(TARGET)

# Enlazar el programa
$(TARGET): $(C_OBJ) $(ASM_OBJ)
	$(CC) $(C_OBJ) $(ASM_OBJ) $(LD_FLAGS) $(GTK_LIBS) -o $@

# Compilar .asm
$(ASM_OBJ): $(ASM_SRC)
	$(ASM) $(ASM_FLAGS) $< -o $@

# Compilar .c
$(C_OBJ): $(C_SRC) $(ASM_OBJ)
	$(CC) $(C_FLAGS) $(GTK_FLAGS) $< -o $@

# Limpiar archivos de salida
clean:
	rm -f $(TARGET) $(C_OBJ) $(ASM_OBJ)
