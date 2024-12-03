import argparse
import requests
from bs4 import BeautifulSoup
import csv

# Crear analizador de argumentos
parser = argparse.ArgumentParser(description="Descargador de registro de sismos, OVSICORI.")
# Agregar parámetro para seleccionar el año
parser.add_argument('-y', "--year", type=int, help="Año en el que ocurrieron los sismos. Ejemplo de uso: -y 2024")

# Analizar síntaxis de los argumentos
args = parser.parse_args()
if args.year:
    filename = 's_anuales_ovsicori.csv'
    year_mode = 1
else:
    filename = 's_sentidos_ovsicori.csv'
    year_mode = 0

if (year_mode == 1):
    # URL de la página que procesa el formulario
    url = 'http://www.ovsicori.una.ac.cr/sistemas/ssentido/SismosAnual.php'
    # Datos del formulario
    data = {'anno': args.year}
    # Realizar el POST
    response = requests.post(url, data=data)
else:
    url = 'http://www.ovsicori.una.ac.cr/sistemas/sentidos_map/index.php'
    response = requests.get(url)

# Verificar si la solicitud fue exitosa
if (response.status_code == 200):
    # Analizar el contenido HTML de la respuesta
    soup = BeautifulSoup(response.text, 'html.parser')
    # Encontrar la tabla
    table = soup.find('table')
    if (table):
    # Crear una lista de listas para almacenar los datos de la tabla
        table_data = []
        if (year_mode == 1):
            # Encuentra solo el primer <th> de la tabla
            first_header = table.find('th')
            # Si existe un encabezado, extraer texto
            if first_header:
                header_text = first_header.get_text()
                # Dividir encabezados en una lista
                headers = header_text.split('\n')
                # Eliminar último elemento (vacío por error de estructura del HTML)
                headers.pop()
                # Encolar encabezados en la tabla
                table_data.append(headers)
        # Extraer las filas de la tabla
        rows = table.find_all('tr')
        # Iterar sobre las filas
        for row in rows:
            cols = row.find_all('td')  # Extraer las celdas
            cols = [col.text.strip() for col in cols]  # Limpiar el texto
            if cols:  # Asegurarse de que hay celdas
                table_data.append(cols)
        # Organizar sismos y encabezados de la tabla (error de estructura del HTML)
        if (year_mode == 1):
            table_data[0], table_data[1] = table_data[1], table_data[0]
        else:
            table_data.pop(0)
            table_data.pop(0)
        # Escribir los datos extraídos en un archivo CSV con ";" como delimitador
        with open(filename, 'w', newline='', encoding='utf-8') as csvfile:
            writer = csv.writer(csvfile, delimiter=';')
            writer.writerows(table_data)

        print("Datos sísmicos generados.")
    else:
        print("Tabla no encontrada")
# Solicitud errónea
else:
    print(f"Error en la solicitud: {response.status_code}")