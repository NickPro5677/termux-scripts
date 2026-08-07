#!/data/data/com.termux/files/usr/bin/bash

DESTINO="/storage/emulated/0/Documents/MisDocumentos"
LOG="$DESTINO/log_recoleccion_$(date +%Y%m%d_%H%M%S).txt"

mkdir -p "$DESTINO"
echo "Carpeta destino lista: $DESTINO"
echo "Iniciando recolección..." | tee -a "$LOG"
echo "Fecha: $(date)" | tee -a "$LOG"
echo "----------------------------------------" | tee -a "$LOG"

encontrados=0
copiados=0
errores=0

find /storage/emulated/0 \
  -type f \
  \( -iname "*.pdf" -o \
     -iname "*.doc" -o -iname "*.docx" -o \
     -iname "*.odt" -o -iname "*.rtf" -o \
     -iname "*.txt" -o \
     -iname "*.xls" -o -iname "*.xlsx" -o -iname "*.ods" -o \
     -iname "*.ppt" -o -iname "*.pptx" -o -iname "*.odp" -o \
     -iname "*.csv" -o -iname "*.md" -o \
     -iname "*.epub" -o -iname "*.mobi" -o -iname "*.azw3" -o \
     -iname "*.djvu" \) \
  ! -path "*/Android/data/*" \
  ! -path "*/Android/obb/*" \
  ! -path "*/.thumbnails/*" \
  ! -path "*/MisDocumentos/*" \
  2>/dev/null | while read -r archivo; do

    ((encontrados++))
    
    nombre=$(basename "$archivo")
    destino_final="$DESTINO/$nombre"
    contador=1
    while [ -f "$destino_final" ]; do
        nombre_sin_ext="${nombre%.*}"
        extension="${nombre##*.}"
        destino_final="$DESTINO/${nombre_sin_ext}_$contador.$extension"
        ((contador++))
    done

    if cp -n "$archivo" "$destino_final" 2>/dev/null; then
        ((copiados++))
        echo "✓ Copiado: $archivo" | tee -a "$LOG"
    else
        ((errores++))
        echo "✗ Error: $archivo" | tee -a "$LOG"
    fi
done

echo "" | tee -a "$LOG"
echo "========================================" | tee -a "$LOG"
echo "PROCESO TERMINADO" | tee -a "$LOG"
echo "Archivos encontrados: $encontrados" | tee -a "$LOG"
echo "Archivos copiados:    $copiados" | tee -a "$LOG"
echo "Errores:              $errores" | tee -a "$LOG"
echo "Carpeta destino:      $DESTINO" | tee -a "$LOG"
echo "========================================" | tee -a "$LOG"

echo ""
echo "¡Listo! Se copiaron los documentos a:"
echo "$DESTINO"
