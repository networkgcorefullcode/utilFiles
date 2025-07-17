for dir in "$current_dir"/* ; do
    echo "Revisando $dir"
    # Verifica si existe la carpeta bin dentro del directorio
    if [ -d "$dir/bin" ]; then
        # Copia el contenido de bin al directorio actual
        cp -r "$dir/bin/" "$current_dir"
        echo "Contenido de $dir/bin copiado a $current_dir"
    fi
done