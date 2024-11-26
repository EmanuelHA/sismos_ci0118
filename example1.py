import requests
from bs4 import BeautifulSoup

url = "http://www.ovsicori.una.ac.cr/index.php/sismos-sentidos"

# Solicitud HTTP
response = requests.get(url)

# Verificar que la solicitud fue exitosa
if response.status_code == 200:
    # Crear un objeto BeautifulSoup con el contenido HTML
    soup = BeautifulSoup(response.text, 'html.parser')
    
    # Ejemplo: Extraer todos los titulos (etiquetas <h1>)
    titulos = soup.find_all('h1')
    for titulo in titulos:
        print(titulo.text)  # Imprimir el texto dentro de cada <h1>

    # Ejemplo: Extraer todos los enlaces (etiquetas <a>)
    enlaces = soup.find_all('a')
    for enlace in enlaces:
        print(enlace.get('href'))  # Obtener el atributo href de cada <a>
else:
    print("Error al acceder a la pagina:", response.status_code)