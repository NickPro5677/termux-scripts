#!/data/data/com.termux/files/usr/bin/bash

# === Script para organizar videos de TikTok ===
# Autor: personalizado para Redmi Note 11 + Termux
# Fecha: 2026

# Carpeta de destino
DESTINO="$HOME/storage/shared/TikTok_Videos"

# Crear destino si no existe
mkdir -p "$DESTINO"

# Contador
count=0
moved=0

echo "========================================"
echo " Buscando videos de TikTok..."
echo " Destino: $DESTINO"
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
        
        # Busca archivos .mp4 (puedes añadir .mov si quieres)
        # -mtime -365 limita a archivos de los últimos 365 días (opcional, quítalo si quieres todos)
        find "$path" -type f \( -iname "*.mp4" -o -iname "*.mov" \) 2>/dev/null | while read -r file; do
            
            # Evitar mover archivos que ya están en la carpeta destino
            if [[ "$file" == "$DESTINO"* ]]; then
                continue
            fi

            filename=$(basename "$file")
            size=$(du -h "$file" | cut -f1)

            echo "Encontrado: $filename ($size)"
            
            # Mover el archivo (usa cp en lugar de mv si prefieres copiar)
            if mv -n "$file" "$DESTINO/" 2>/dev/null; then
                echo "  → Movido correctamente"
                ((moved++))
            else
                echo "  → Error al mover (puede que ya exista o permiso)"
            fi
            
            ((count++))
        done
    fi
done

echo
echo "========================================"
echo " Proceso terminado"
echo " Archivos encontrados: $count"
echo " Archivos movidos: $moved"
echo " Revisa la carpeta: $DESTINO"
echo "========================================"
