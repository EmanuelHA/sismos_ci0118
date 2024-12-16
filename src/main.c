#include <gtk/gtk.h>
#include <cairo.h>
#include <stdlib.h>

#define EOF         0
#define SISMOS_N    10
#define SEEK_SET    0
#define SEEK_CUR    1
#define SEEK_END    2
#define BUFFER_LEN  512

char args[] = "python3 src/data_downloader.py";
GtkWidget *drawing_area; // Area de dibujado global
// Estructura para almacenar los datos de los sismos
typedef struct {
    char    fecha [16];
    char    hora [16];
    float   magnitud;
    float   profundidad;
    char    localizacion [128];
    char    origen [128];
    char    reportado [256];
    float   latitud;
    float   longitud;
} Sismo_T;

extern Sismo_T sismos_arr[SISMOS_N];
extern char buffer[BUFFER_LEN];

// Dada la ruta a un archivo (valida o no), abre el archivo
// Retorna su descriptor
extern int open_file(const char* file_path);
// Dado un descriptor de archivo, lee 1KB de este y lo guarda en el buffer
// Retorna la cantidad de bytes leídos
extern unsigned int read_file(int file_descriptor);
// Se desplaza en el archivo dado pi_stror el F.D.
// MODOS DE DESPLAZAMIENTO: 0: Desde el inicio; 1: Desde pos. actual; 2: Desde el final
// Retorna el desplazamiento desde el inicio del archivo hasta la pos. actual
extern int seek_file(int file_descriptor, int offset, uint8_t mode);
// Dado un descriptor de archivo, cierra el archivo asociado a este
// Retorna un booleano (invertido) que indica si tuvo o no éxito
extern bool close_file(int file_descriptor);
// Ordena en sismos_arr los N_SISMOS más recientes
extern void sort_sismos();

void print_sismo(Sismo_T s) {
    printf("%s; %s; %f; %f; %s; %s; %s; %f; %f\n",
            s.fecha,
            s.hora,
            s.magnitud,
            s.profundidad,
            s.localizacion,
            s.origen,
            s.reportado,
            s.latitud,
            s.longitud);
}

static void load_s_data(int file_descriptor) {
    if (file_descriptor > 0) {
        int     bytes_readed   = 0;
        int     index_b        = 0;
        int     index_s        = 0;
        int     d_index        = 0;
        float   f_data         = 0.0f;
        char    buffer_aux[16] = "";
        char*   endstr;                // Requerido en strtof(char *str, char *endstr)
        Sismo_T      s;

        bytes_readed = read_file(file_descriptor);
        // Saltar encabezados del .CSV
        // Registro sismico anual
        if (buffer[0] == 'S'){
            while (buffer[index_b] != '\n') {
                index_b++;
            }
            index_b++;  // Salto de linea
        }

        while (buffer[index_b] != '\n') {
            index_b++;
        }
        index_b++;  // Salto de linea

        // Ajustar puntero del archivo
        seek_file(file_descriptor, index_b, SEEK_SET);
        bytes_readed = read_file(file_descriptor);
        index_b = 0;
        // Lectura de los datos del .CSV
        while ((bytes_readed != 0) && (index_s < SISMOS_N)) {
            // Parseo de datos
            // s.fecha
            d_index = 0;
            while (buffer[index_b] != ';') {
                s.fecha[d_index] = buffer[index_b];
                d_index++;
                index_b++;
            }
            s.fecha[d_index] = EOF;
            index_b++;

            // s.hora
            d_index = 0;
            while (buffer[index_b] != ';') {
                s.hora[d_index] = buffer[index_b];
                d_index++;
                index_b++;
            }
            s.hora[d_index] = EOF;
            index_b++;  // Separador del .CSV

            // s.magnitud
            d_index = 0;
            while (buffer[index_b] != ';') {
                buffer_aux[d_index] = buffer[index_b];
                d_index++;
                index_b++;
            }
            buffer_aux[d_index] = EOF;
            index_b++;
            s.magnitud = strtof(buffer_aux, endstr);
        
            // s.profundidad
            d_index = 0;
            while (buffer[index_b] != ';') {
                buffer_aux[d_index] = buffer[index_b];
                d_index++;
                index_b++;
            }
            buffer_aux[d_index] = EOF;
            index_b++;
            s.profundidad = strtof(buffer_aux, endstr);

            // s.localizacion
            d_index = 0;
            while (buffer[index_b] != ';') {
                s.localizacion[d_index] = buffer[index_b];
                d_index++;
                index_b++;
            }
            s.localizacion[d_index] = EOF;
            index_b++;  // Separador del .CSV

            // s.origen
            d_index = 0;
            while (buffer[index_b] != ';') {
                s.origen[d_index] = buffer[index_b];
                d_index++;
                index_b++;
            }
            s.origen[d_index] = EOF;
            index_b++;  // Separador del .CSV

            // s.reportado
            d_index = 0;
            while (buffer[index_b] != ';') {
                s.reportado[d_index] = buffer[index_b];
                d_index++;
                index_b++;
            }
            s.reportado[d_index] = EOF;
            index_b++;

            // s.latitud
            d_index = 0;
            while (buffer[index_b] != ';') {
                buffer_aux[d_index] = buffer[index_b];
                d_index++;
                index_b++;
            }
            buffer_aux[d_index] = EOF;
            index_b++;
            s.latitud = strtof(buffer_aux, endstr);

            // s.longitud
            d_index = 0;
            while (buffer[index_b] != '\n') {
                buffer_aux[d_index] = buffer[index_b];
                d_index++;
                index_b++;
            }
            buffer_aux[d_index] = EOF;
            index_b++;
            s.longitud = strtof(buffer_aux, endstr);
            index_b++;  // Salto de linea

            // Ajustar puntero del archivo a la siguiente fila
            int index_f = (index_b - bytes_readed - 1);
            seek_file(file_descriptor, index_f, SEEK_CUR);
            bytes_readed = read_file(file_descriptor);
            index_b = 0;
            sismos_arr[index_s] = s;
            index_s++;
        }
    }
}

static int on_download_pressed(GtkButton *button, gpointer user_data) {
    const char *text = gtk_editable_get_text (GTK_EDITABLE (user_data));
    unsigned short txt_len =  strlen(text);
    if (strlen(text) < 4) {
        printf("ARGS: %s,\n", args);
        return system(args);
    } else {
        char args_w_year[40];
        strcpy(args_w_year, args);
        unsigned short arg_len =  strlen(args);
        args_w_year[arg_len] = ' ';
        args_w_year[arg_len + 1] = '-';
        args_w_year[arg_len + 2] = 'y';
        args_w_year[arg_len + 3] = ' ';
        for (unsigned short i = 0; (i < txt_len) && ((arg_len + i) < 40); i++) {
            args_w_year[i + arg_len + 4] = text[i];
        }
        args_w_year[39] = 0; // EOF

        printf("ARGS: %s,\n", args_w_year);
        return system(args_w_year);
    }
}

static void on_open_response (GtkWidget *dialog, int response, gpointer user_data) {
    GtkDrawingArea *drawing_area = GTK_DRAWING_AREA(user_data);
    if (response == GTK_RESPONSE_ACCEPT) {
        GListModel *files = gtk_file_chooser_get_files(GTK_FILE_CHOOSER(GTK_DIALOG(dialog)));
            if (g_list_model_get_n_items(files) > 0) {
                GFile *file = G_FILE(g_list_model_get_item(files, 0));
                // Conversor GFile* a File Descriptor
                int file_desc = 0;
                char* file_path = g_file_get_path(file);
                if (!file_path) {
                    g_warning("No se pudo obtener la ruta del archivo.\n");
                    file_desc = -1;
                } else { 
                    file_desc = open_file(file_path);       // Abrir en modo solo lectura
                    if (file_desc <= 0) {
                        perror("Error al abrir el archivo\n");
                    } else {
                        printf("Procesando %s...\n", file_path);
                        load_s_data(file_desc);
                        bool closed_w_err = close_file(file_desc);
                        if (!closed_w_err) {
                            printf("Cerrando el archivo.\n");
                        } else {
                            perror("Error al cerrar el archivo.\n");
                        }
                    }
                }
                g_free(file_path);                          // Liberar memoria de la ruta
                g_object_unref(file);                       // Liberar memoria del GFile
            }
    }
    gtk_widget_queue_draw(drawing_area);                    // Redibujar la interfaz
    gtk_window_destroy(GTK_WINDOW(dialog));                 // Cerrar ventana y liberar mem.
}

static void on_open_clicked(GtkButton *button, gpointer user_data) {
    GtkWidget* window;
    GtkWidget* dialog;
    
    window = GTK_WINDOW(user_data);
    dialog = gtk_file_chooser_dialog_new ("Open File",
                                          GTK_WINDOW(window),
                                          GTK_FILE_CHOOSER_ACTION_OPEN,
                                          ("_Cancel"),
                                          GTK_RESPONSE_CANCEL,
                                          ("_Open"),
                                          GTK_RESPONSE_ACCEPT,
                                          NULL);
    gtk_window_set_modal(GTK_WINDOW(dialog), TRUE);
    gtk_window_present(GTK_WINDOW(dialog));

    g_signal_connect(dialog, "response", G_CALLBACK (on_open_response), drawing_area);
}

// Función de dibujo de Cairo para el gráfico de intensidad vs tiempo
static void draw(GtkDrawingArea *area,
                 cairo_t        *cr,
                 int             width,
                 int             height,
                 gpointer        data)
{
    // Dibujar fondo
    cairo_set_source_rgb(cr, 1, 1, 1); // Blanco
    cairo_paint(cr);

    // Configurar propiedades del gráfico
    double margin = 50;
    double x_step = (width - 2 * margin) / (SISMOS_N - 1);
    double max_intensity = 10.0; // MAX - escala de Richter

    // Color de dibujado
    cairo_set_source_rgb(cr, 0, 0, 0);
    cairo_set_line_width(cr, 2);

    // Eje Y
    cairo_move_to(cr, margin, margin);
    cairo_line_to(cr, margin, height - margin);
    cairo_stroke(cr);

    // Eje X
    cairo_move_to(cr, margin, height - margin);
    cairo_line_to(cr, width - margin, height - margin);
    cairo_stroke(cr);

    // Dibujar las etiquetas del eje Y
    for (int i = 0; i <= max_intensity; ++i) {
        double y = height - margin - i * ((height - 2 * margin) / max_intensity);
        cairo_move_to(cr, margin - 20, y);
        char i_str[16];
        sprintf(i_str, "%d", i);
        cairo_show_text(cr, i_str);
    }

    // Dibujar el gráfico de barras
    cairo_set_source_rgb(cr, 0.5, 0.5, 0.5); // Gris
    cairo_set_line_width(cr, 2);

    for (size_t i = 0; i < SISMOS_N; ++i) {
        double x = margin + i * x_step;
        double y = height - margin - sismos_arr[i].magnitud * ((height - 2 * margin) / max_intensity);

        cairo_rectangle(cr, x - 5, y, 10, height - margin - y);
        cairo_fill(cr);
    }

    // Dibujar etiquetas de tiempo en el eje X
    cairo_set_source_rgb(cr, 0, 0, 0); // Negro
    for (size_t i = 0; i < SISMOS_N; ++i) {
        double x = margin + i * x_step;
        cairo_move_to(cr, x, height - margin + 20);
        cairo_show_text(cr, sismos_arr[i].fecha);
        printf("Fecha: %s\n", sismos_arr[i].fecha);
    }
}

static void activate(GtkApplication* app, gpointer user_data) {
    GtkWidget *window;
    GtkWidget *hbox;
    GtkWidget *vbox;
    GtkWidget *button;
    GtkWidget *dialog;
    GtkWidget *entry;
    GMenu     *menu;
    GMenu     *file_menu;

    window = gtk_application_window_new(app);

    menu = g_menu_new();
    file_menu = g_menu_new();
    g_menu_append(file_menu, "Abrir archivo", "app.open");
    g_menu_append_section(menu, "Archivo", G_MENU_MODEL(file_menu));

    // Crea un botón de menú en la cabecera
    GtkWidget *menu_button = gtk_menu_button_new();
    GtkWidget *popover = gtk_popover_menu_new_from_model(G_MENU_MODEL(menu));
    gtk_menu_button_set_popover(GTK_MENU_BUTTON(menu_button), GTK_WIDGET(popover));
    gtk_menu_button_set_icon_name(GTK_MENU_BUTTON(menu_button), "open-menu-symbolic");
    //gtk_popover_set_position(GTK_POPOVER(popover), GTK_POS_RIGHT); // Posicionamiento a la derecha
    //gtk_popover_set_has_arrow(popover, FALSE); // Desactivar flecha
    gtk_popover_set_offset(GTK_WIDGET(popover), 35, 0); // Offset horizontal
    
    // Añadir el botón de menú a la barra de encabezado
    GtkWidget *header = gtk_header_bar_new();
    gtk_header_bar_pack_start(GTK_HEADER_BAR(header), menu_button);
    gtk_window_set_titlebar(GTK_WINDOW(window), GTK_WIDGET(header));

    // Crea acción para "Abrir"
    GSimpleAction *open_action = g_simple_action_new("open", NULL);
    g_signal_connect(open_action, "activate", G_CALLBACK(on_open_clicked), window);
    g_action_map_add_action(G_ACTION_MAP(app), G_ACTION(open_action));

    // Crea un contenedor vertical para la disposición
    vbox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
    gtk_window_set_child(GTK_WINDOW(window), vbox);

    // Crea el área de dibujo (drawing area) y la agrega al contenedor
    drawing_area = gtk_drawing_area_new();
    gtk_widget_set_vexpand(drawing_area, TRUE);
    gtk_box_append(GTK_BOX(vbox), drawing_area);

    // Crea un contenedor horizontal para organizar las opciones
    hbox = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0);
    gtk_box_append(GTK_BOX(vbox), hbox);

    vbox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
    gtk_widget_set_hexpand(vbox, TRUE); // Expande hacia la izquierda
    gtk_box_append(GTK_BOX(hbox), vbox);

    vbox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 1);
    gtk_widget_set_hexpand(vbox, TRUE); // HBOX central
    gtk_box_append(GTK_BOX(hbox), vbox);

    // Crear el texto
    entry = gtk_entry_new();
    gtk_box_append(GTK_BOX(vbox), entry);
    gtk_entry_set_placeholder_text(GTK_ENTRY(entry), "AÑO DE REGISTRO / EN BLANCO PARA RECIENTES");

    // Crear el botón
    button = gtk_button_new_with_label("DESCARGAR REGISTRO");
    gtk_box_append(GTK_BOX(vbox), button);
    g_signal_connect(button, "clicked", G_CALLBACK(on_download_pressed), entry);

    vbox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
    gtk_widget_set_hexpand(vbox, TRUE); // Expande hacia la derecha
    gtk_box_append(GTK_BOX(hbox), vbox);


    //Función por defecto para dibujado
    gtk_drawing_area_set_draw_func(GTK_DRAWING_AREA (drawing_area),
                                    draw,
                                    NULL, NULL);

    gtk_window_set_default_size(GTK_WINDOW(window), 700, 500);
    gtk_window_set_title(GTK_WINDOW(window), "Graficador Sísmico");

    gtk_window_present(GTK_WINDOW(window));
}

int main(int argc, char *argv[]) {
    GtkApplication *app;
    int status;

    app = gtk_application_new("org.gtk.visor_sismico", G_APPLICATION_DEFAULT_FLAGS);
    g_signal_connect(app, "activate", G_CALLBACK(activate), NULL);
    status = g_application_run(G_APPLICATION(app), argc, argv);
    g_object_unref(app);

    return status;
}