import os

def extraer_codigo_local(directorio_base, archivo_salida="codigo_flutter.txt"):
    # Extensiones que nos interesan analizar
    extensiones_validas = ['.dart', '.yaml']
    
    # Carpetas que ignoramos para no saturar el archivo de texto
    carpetas_ignoradas = ['.git', '.dart_tool', 'build', 'android', 'ios', 'web', 'macos', 'windows', 'linux']

    print(f"Buscando archivos en: {directorio_base}...")

    with open(archivo_salida, "w", encoding="utf-8") as outfile:
        for root, dirs, files in os.walk(directorio_base):
            # Eliminamos las carpetas ignoradas de la búsqueda actual
            dirs[:] = [d for d in dirs if d not in carpetas_ignoradas]

            for file in files:
                if any(file.endswith(ext) for ext in extensiones_validas):
                    ruta_completa = os.path.join(root, file)
                    
                    # Usamos una ruta relativa para que sea más fácil de leer en el txt
                    ruta_relativa = os.path.relpath(ruta_completa, directorio_base)
                    
                    # Escribir separador y nombre del archivo
                    outfile.write("=" * 60 + "\n")
                    outfile.write(f"--- ARCHIVO: {ruta_relativa} ---\n")
                    outfile.write("=" * 60 + "\n\n")
                    
                    try:
                        with open(ruta_completa, "r", encoding="utf-8") as infile:
                            outfile.write(infile.read() + "\n\n")
                        print(f"Agregado: {ruta_relativa}")
                    except Exception as e:
                        print(f"Error al leer {ruta_completa}: {e}")
                        outfile.write(f"// Error al leer este archivo: {e}\n\n")

    print(f"\n¡Listo! Todo tu código se ha guardado en '{archivo_salida}'.")

if __name__ == "__main__":
    # Pide la ruta de tu proyecto
    print("Ejemplo de ruta: C:\\Users\\Calex\\Downloads\\AAAAA\\mobile")
    ruta = input("Ingresa la ruta raíz de tu proyecto Flutter: ")
    
    if os.path.exists(ruta):
        extraer_codigo_local(ruta)
    else:
        print("La ruta no existe. Verifica que esté bien escrita.")