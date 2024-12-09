# Compilador C + banderillas
CC = gcc
C_FLAGS = -c
LD_FLAGS = -no-pie -z noexecstack
# Compilador S + banderillas
ASM = nasm
ASM_FLAGS = -f elf64
# Banderillas de GTK
GTK_FLAGS = `pkg-config --cflags gtk4`
GTK_LIBS = `pkg-config --libs gtk4`
# Directorios
OBJ_DIR = obj
BIN_DIR = bin
SRC_DIR = src
# Archivos fuente
C_SRC = $(SRC_DIR)/main.c
ASM_SRC = $(SRC_DIR)/sismos.asm
# Archivos objeto
C_OBJ = $(OBJ_DIR)/main.o
ASM_OBJ = $(OBJ_DIR)/sismos.o
# Salida
TARGET = $(BIN_DIR)/sismos

# Regla predeterminada
all: $(TARGET)

# Regla para ejecutar el programa
run: all
	./$(TARGET)

# Enlazar el programa
$(TARGET): $(C_OBJ) $(ASM_OBJ)
	$(CC) $(C_OBJ) $(ASM_OBJ) $(LD_FLAGS) $(GTK_LIBS) -o $@

# Compilar .asm
$(C_OBJ): $(C_SRC)
	$(CC) $(C_FLAGS) $(GTK_FLAGS) $< -o $@

$(ASM_OBJ): $(ASM_SRC)
	$(ASM) $(ASM_FLAGS) $< -o $@

# Limpiar archivos de salida
clean:
	rm -rf $(OBJ_DIR)/*.o

.PHONY: all clean run
