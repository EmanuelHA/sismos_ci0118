#include <gtk/gtk.h>
#include <cairo.h>
#include <stdio.h>
#define SISMOS_N 256

// Estructura para almacenar los datos de los sismos
typedef struct Sismo{
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

extern const unsigned short SISMO_SIZE;
extern const unsigned short SISMOS_N;

extern Sismo_T sismos_arr[SISMOS_N];

extern void open_sa_file();
extern void open_ss_file();
extern void parse_data();

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
}

// Callback para el evento "draw"
//static gboolean on_draw_event(GtkWidget *widget, cairo_t *cr, gpointer user_data) {
//    auto sismos = static_cast<std::vector<Sismo>*>(user_data);
//    draw(cr, *sismos);
//    return FALSE;
//}

static void activate(GtkApplication* app, gpointer user_data) {
    GtkWidget *window;
    GtkWidget *d_area;
    GtkWidget *box;

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

    open_sa_file();

    app = gtk_application_new("org.gtk.visor_sismico", G_APPLICATION_DEFAULT_FLAGS);
    g_signal_connect(app, "activate", G_CALLBACK(activate), NULL);
    status = g_application_run(G_APPLICATION(app), argc, argv);
    g_object_unref(app);

    return status;
}