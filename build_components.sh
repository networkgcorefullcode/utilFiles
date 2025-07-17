for dir in "$PWD"/*/; do
    [ -d "$dir" ] && echo "Directorio: $dir"
    if (cd "$dir" && make all); then
        :
    else
        echo "error al ejecutar make all"
    fi
done