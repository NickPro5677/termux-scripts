#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
# Organizador de Descargas v1
# Para Termux en Android
# ============================================================

# Carpeta de descargas del teléfono
DESCARGAS="$HOME/storage/downloads"

# Carpeta donde se guardará el registro de lo que hace el script
LOGDIR="$HOME/scripts/logs"
mkdir -p "$LOGDIR"
LOGFILE="$LOGDIR/organizar_$(date +%Y%m%d_%H%M%S).log"

# Modo simulación (por defecto): con "si" NO mueve nada, solo muestra.
# Para mover de verdad: ./organizar_descargas.sh --aplicar
# (o DRY_RUN="no" ./organizar_descargas.sh)
DRY_RUN="${DRY_RUN:-si}"
if [ "${1:-}" = "--aplicar" ]; then
  DRY_RUN="no"
fi

# ------------------------------------------------------------
# Función: escribir en pantalla y en el log
# ------------------------------------------------------------
log() {
  echo "$1" | tee -a "$LOGFILE"
}

# ------------------------------------------------------------
# Comprobaciones iniciales
# ------------------------------------------------------------
if [ ! -d "$DESCARGAS" ]; then
  echo "ERROR: No encuentro la carpeta de Descargas:"
  echo "  $DESCARGAS"
  echo "Ejecuta primero: termux-setup-storage"
  exit 1
fi

log "========================================"
log " Organizador de Descargas"
log " Fecha: $(date)"
log " Carpeta: $DESCARGAS"
log " Modo DRY_RUN: $DRY_RUN  (si = solo simula)"
log "========================================"
log ""

# Crear subcarpetas de destino
CARPETAS=("APK" "Documentos" "Imagenes" "Videos" "Audio" "Comprimidos" "Otros")

for carpeta in "${CARPETAS[@]}"; do
  mkdir -p "$DESCARGAS/$carpeta"
done

# Contadores
movidos=0
omitidos=0

# ------------------------------------------------------------
# Recorrer archivos de la carpeta Descargas (solo archivos, no carpetas)
# ------------------------------------------------------------
cd "$DESCARGAS" || exit 1

for archivo in *; do
  # Saltar si no es un archivo normal (por ejemplo, es una carpeta)
  if [ ! -f "$archivo" ]; then
    continue
  fi

  # Obtener extensión en minúsculas (ej: PDF -> pdf)
  extension="${archivo##*.}"
  extension=$(echo "$extension" | tr 'A-Z' 'a-z')

  # Si el archivo no tiene punto, extension será el nombre completo
  if [ "$extension" = "$archivo" ]; then
    extension=""
  fi

  destino="Otros"

  case "$extension" in
    apk|xapk|apks)
      destino="APK"
      ;;
    pdf|doc|docx|txt|xls|xlsx|ppt|pptx|odt|rtf)
      destino="Documentos"
      ;;
    jpg|jpeg|png|gif|webp|heic|bmp|svg)
      destino="Imagenes"
      ;;
    mp4|mkv|avi|mov|webm|3gp|m4v)
      destino="Videos"
      ;;
    mp3|wav|ogg|m4a|flac|aac)
      destino="Audio"
      ;;
    zip|rar|7z|tar|gz|bz2)
      destino="Comprimidos"
      ;;
    *)
      destino="Otros"
      ;;
  esac

  # Si ya está dentro de una de nuestras carpetas, no lo tocamos
  # (este bucle solo mira la raíz de Descargas, así que está bien)

  ruta_destino="$DESCARGAS/$destino/$archivo"

  if [ "$DRY_RUN" = "si" ]; then
    log "[SIMULA] '$archivo'  →  $destino/"
    movidos=$((movidos + 1))
  else
    if mv "$archivo" "$ruta_destino" 2>/dev/null; then
      log "[OK]     '$archivo'  →  $destino/"
      movidos=$((movidos + 1))
    else
      log "[ERROR]  No pude mover '$archivo'"
      omitidos=$((omitidos + 1))
    fi
  fi
done

log ""
log "========================================"
log " Resumen"
log " Archivos procesados: $movidos"
log " Errores/omitidos:    $omitidos"
log " Log guardado en:     $LOGFILE"
log "========================================"

if [ "$DRY_RUN" = "si" ]; then
  echo ""
  echo ">>> ESTO FUE UNA SIMULACIÓN. No se movió nada."
  echo ">>> Cuando quieras hacerlo de verdad:"
  echo ">>>   ./organizar_descargas.sh --aplicar"
fi
