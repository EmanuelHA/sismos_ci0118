#include <gtk/gtk.h>
#include <cairo.h>
#include <stdio.h>
#include <fcntl.h>
#define SISMOS_N 256

// Estructura para almacenar los datos de los sismos
typedef struct {
    char date [16];
    char hour [16];
    float magnitud;
    float profundidad;
    char localizacion [128];
    char origen [128];
    char reportado [256];
    float latitud;
    float longitud;
} Sismo_T;

extern Sismo_T sismos_arr[SISMOS_N];
extern int file_desc;
extern void parse_data();

void print_sismo(Sismo_T s) {
    printf("%s; %s; %f; %f \n", s.date, s.hour, s.magnitud, s.profundidad);
}

static void on_open_response (GtkWidget *dialog, int response) {
  if (response == GTK_RESPONSE_ACCEPT) {
      GListModel *files = gtk_file_chooser_get_files(GTK_FILE_CHOOSER(GTK_DIALOG(dialog)));
        if (g_list_model_get_n_items(files) > 0) {
            GFile *file = G_FILE(g_list_model_get_item(files, 0));
            // Convertor GFile* a File Descriptor
            char *file_path = g_file_get_path(file);
            if (!file_path) {
                g_warning("No se pudo obtener la ruta del archivo.");
                file_desc = -1;
            }
            int fd = open(file_path, O_RDONLY);         // Abrir solo en modo lectura
            g_free(file_path);                          // Liberar memoria de la ruta
            if (fd == -1) {
                perror("Error al abrir el archivo");
                file_desc = -1;
            } else {
                file_desc = fd;
            }
            g_object_unref(file);                       // Liberar memoria del GFile
        }
    }
  gtk_window_destroy (GTK_WINDOW (dialog));
}

static void show_open_file_dialog(GtkWidget *dialog, GtkWidget* parent_window) {
    GtkFileChooserAction action = GTK_FILE_CHOOSER_ACTION_OPEN;
    dialog = gtk_file_chooser_dialog_new ("Open File",
                                          GTK_WINDOW(parent_window),
                                          action,
                                          ("_Cancel"),
                                          GTK_RESPONSE_CANCEL,
                                          ("_Open"),
                                          GTK_RESPONSE_ACCEPT,
                                          NULL);
    gtk_window_present (GTK_WINDOW (dialog));

    g_signal_connect (dialog, "response",
                      G_CALLBACK (on_open_response),
                      NULL);
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
    //double x_step = (width - 2 * margin) / (sismos.size() - 1);
    double max_intensity = 10.0; // Supongamos que la intensidad máxima es 10

    // Dibujar ejes
    cairo_set_source_rgb(cr, 0, 0, 0); // Negro
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
        cairo_move_to(cr, margin - 10, y);
        //cairo_show_text(cr, std::to_string(i).c_str());
    }

    // Dibujar el gráfico de barras
    cairo_set_source_rgb(cr, 0, 0, 1); // Azul
    cairo_set_line_width(cr, 2);
/*
    for (size_t i = 0; i < sismos.size(); ++i) {
        double x = margin + i * x_step;
        double y = height - margin - sismos[i].intensity * ((height - 2 * margin) / max_intensity);

        cairo_rectangle(cr, x - 5, y, 10, height - margin - y);
        cairo_fill(cr);
    }
*/
/*
    // Dibujar etiquetas de tiempo en el eje X
    cairo_set_source_rgb(cr, 0, 0, 0); // Negro
    for (size_t i = 0; i < sismos.size(); ++i) {
        double x = margin + i * x_step;
        cairo_move_to(cr, x, height - margin + 20);
        //cairo_show_text(cr, sismos[i].time.c_str());
    }
*/
    
    show_open_file_dialog(dialog, window);
    printf("%d File Descriptor: \n", file_desc);
    parse_data();
    //close_file();
    for (unsigned int i = 0; i < SISMOS_N; i++) {
        //print_sismo(sismos_arr[i]);
    }
}

static void activate(GtkApplication* app, gpointer user_data) {
    GtkWidget *window;
    GtkWidget *d_area;
    GtkWidget *box;

    GtkWidget *dialog;

    window = gtk_application_window_new(app);
    d_area = gtk_drawing_area_new();
    
    box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 5);
    gtk_box_set_homogeneous(GTK_BOX (box), TRUE);
    gtk_window_set_child(GTK_WINDOW(window), box);

    gtk_box_append(GTK_BOX(box), d_area);

    gtk_drawing_area_set_draw_func(GTK_DRAWING_AREA (d_area),
                                    draw,
                                    NULL, NULL);

    //gtk_window_set_position(GTK_WINDOW(window));
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