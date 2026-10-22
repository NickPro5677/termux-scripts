#!/data/data/com.termux/files/usr/bin/bash

# === Script para organizar videos de TikTok ===
# Autor: personalizado para Redmi Note 11 + Termux
# Fecha: 2026
#
# Uso:
#   ./organizar_tiktok.sh            # simulación (por defecto): solo muestra qué movería
#   ./organizar_tiktok.sh --aplicar  # mueve de verdad
#
# Solo toma videos que parecen de TikTok: el nombre o la ruta contiene
# "tiktok", "musically", "ugc.trill", "snaptik" o "ssstik" (sin importar mayúsculas).

# Carpeta de destino
DESTINO="$HOME/storage/shared/TikTok_Videos"

# Modo simulación por defecto
DRY_RUN="${DRY_RUN:-si}"
if [ "${1:-}" = "--aplicar" ]; then
    DRY_RUN="no"
fi

# Patrón para reconocer videos de TikTok (en minúsculas)
PATRON_TIKTOK='tiktok|musically|ugc\.trill|snaptik|ssstik'

# Crear destino si no existe (solo al mover de verdad)
if [ "$DRY_RUN" = "no" ]; then
    mkdir -p "$DESTINO"
fi

# Contadores
count=0
moved=0

echo "========================================"
echo " Buscando videos de TikTok..."
echo " Destino: $DESTINO"
echo " Modo DRY_RUN: $DRY_RUN  (si = solo simula)"
echo "========================================"
echo

# Buscar en las ubicaciones más comunes
# Puedes añadir más rutas si quieres
SEARCH_PATHS=(
    "$HOME/storage/shared/DCIM"
    "$HOME/storage/shared/Download"
    "$HOME/storage/shared/Movies"
    "$HOME/storage/shared/Pictures"
    "$HOME/storage/shared/Android/media"
)

for path in "${SEARCH_PATHS[@]}"; do
    if [ -d "$path" ]; then
        echo "Escaneando: $path"

        # Busca archivos .mp4 y .mov
        while IFS= read -r -d '' file; do

            # Evitar mover archivos que ya están en la carpeta destino
            if [[ "$file" == "$DESTINO"* ]]; then
                continue
            fi

            # Filtro real: solo videos cuya ruta o nombre sea de TikTok
            ruta_min=$(printf '%s' "$file" | tr '[:upper:]' '[:lower:]')
            if ! [[ "$ruta_min" =~ $PATRON_TIKTOK ]]; then
                continue
            fi

            filename=$(basename "$file")
            size=$(du -h "$file" | cut -f1)

            echo "Encontrado: $filename ($size)"
            count=$((count + 1))

            if [ "$DRY_RUN" = "si" ]; then
                echo "  → [SIMULA] se movería a $DESTINO/"
                continue
            fi

            # Mover el archivo sin sobrescribir
            if [ -e "$DESTINO/$filename" ]; then
                echo "  → Omitido: ya existe en el destino"
            elif mv -n "$file" "$DESTINO/" 2>/dev/null; then
                echo "  → Movido correctamente"
                moved=$((moved + 1))
            else
                echo "  → Error al mover (permiso)"
            fi
        done < <(find "$path" -type f \( -iname "*.mp4" -o -iname "*.mov" \) -print0 2>/dev/null)
    fi
done

echo
echo "========================================"
echo " Proceso terminado"
echo " Videos de TikTok encontrados: $count"
echo " Archivos movidos: $moved"
if [ "$DRY_RUN" = "si" ]; then
    echo " ESTO FUE UNA SIMULACIÓN. No se movió nada."
    echo " Para mover de verdad: ./organizar_tiktok.sh --aplicar"
else
    echo " Revisa la carpeta: $DESTINO"
fi
echo "========================================"
