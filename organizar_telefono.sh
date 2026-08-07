#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
# Organizador completo del teléfono (Redmi / Android / Termux)
#
# Clasifica archivos desordenados por FORMATO y ORIGEN.
# Por defecto SOLO SIMULA (no mueve nada).
#
# Uso:
#   ./organizar_telefono.sh              # simulación (seguro)
#   ./organizar_telefono.sh --aplicar    # mueve de verdad
#   ./organizar_telefono.sh --informe    # solo cuenta el desorden
#   ./organizar_telefono.sh --verbose    # lista cada archivo
#   ./organizar_telefono.sh --help
# ============================================================

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF="$SCRIPT_DIR/organizar_telefono.conf"

if [[ ! -f "$CONF" ]]; then
  echo "ERROR: no encuentro $CONF"
  exit 1
fi
# shellcheck source=organizar_telefono.conf
source "$CONF"

# ---- CLI ----
MODO="simular"   # simular | aplicar | informe
VERBOSE="no"

for arg in "$@"; do
  case "$arg" in
    --aplicar|--apply|-a)  MODO="aplicar"; DRY_RUN="no" ;;
    --informe|--report|-i) MODO="informe"; DRY_RUN="si" ;;
    --simular|--dry-run|-n) MODO="simular"; DRY_RUN="si" ;;
    --verbose|-v) VERBOSE="si" ;;
    -h|--help|help)
      cat <<'EOF'
Organizador completo del teléfono

  ./organizar_telefono.sh              Simulación (no mueve nada)
  ./organizar_telefono.sh --informe    Cuenta desorden por categoría
  ./organizar_telefono.sh --aplicar    Mueve de verdad (pide confirmación)
  ./organizar_telefono.sh --verbose    Muestra cada archivo en pantalla

Config:  nano ~/scripts/organizar_telefono.conf

Destinos:
  Imágenes   → Pictures/Organizado/<origen>/
  Videos     → Movies/Organizado/<origen>/
  Audio      → Music/Organizado/<origen>/
  Documentos → Documents/Organizado/<origen>/
  APK / zip  → Download/Organizado/...

NO toca: Android/, MIUI/, DCIM, proyectos, WhatsApp (por defecto).
EOF
      exit 0
      ;;
    *)
      echo "Opción desconocida: $arg  (usa --help)"
      exit 1
      ;;
  esac
done

# ---- prep ----
mkdir -p "$LOGDIR" "$(dirname "$INFORME_CSV")"
LOGFILE="$LOGDIR/organizar_tel_$(date +%Y%m%d_%H%M%S).log"

log()  { printf '%s\n' "$1" | tee -a "$LOGFILE"; }
logq() { printf '%s\n' "$1" >> "$LOGFILE"; }

if [[ ! -d "$SHARED" ]]; then
  echo "ERROR: no hay almacenamiento compartido: $SHARED"
  echo "Ejecuta: termux-setup-storage"
  exit 1
fi

declare -A CONT_CAT=()
movidos=0
omitidos=0
errores=0
colisiones=0
bytes_movidos=0

# CSV en buffer (mucho más rápido que abrir el archivo miles de veces)
CSV_BUF="estado,origen_etiqueta,categoria,ruta_origen,ruta_destino,bytes"
CSV_LINES=0
flush_csv() {
  printf '%s\n' "$CSV_BUF" > "$INFORME_CSV"
  CSV_BUF=""
  CSV_LINES=0
}
append_csv() {
  # $1..$6
  CSV_BUF+=$'\n'"$1,$2,$3,$4,$5,$6"
  CSV_LINES=$((CSV_LINES + 1))
  if [[ "$CSV_LINES" -ge 200 ]]; then
    printf '%s\n' "$CSV_BUF" >> "$INFORME_CSV"
    CSV_BUF=""
    CSV_LINES=0
  fi
}
# cabecera inicial
printf '%s\n' "$CSV_BUF" > "$INFORME_CSV"
CSV_BUF=""
CSV_LINES=0

# ------------------------------------------------------------
# ¿Ruta bajo carpeta protegida? (prefijos precompilados)
# ------------------------------------------------------------
bajo_protegida() {
  local rel="${1#"$SHARED"/}"
  local p
  for p in "${PROTEGIDAS[@]}"; do
    [[ -z "$p" ]] && continue
    case "$rel" in
      "$p"|"$p"/*) return 0 ;;
    esac
  done
  return 1
}

ya_organizado() {
  case "${1#"$SHARED"/}" in
    Pictures/Organizado/*|Movies/Organizado/*|Music/Organizado/*|Documents/Organizado/*|Download/Organizado/*) return 0 ;;
    Download/APK/*|Download/Documentos/*|Download/Imagenes/*|Download/Videos/*|Download/Audio/*|Download/Comprimidos/*|Download/Otros/*) return 0 ;;
    DCIM/*) return 0 ;;
  esac
  return 1
}

# Extensión en minúsculas (soporta tar.gz)
ext_de() {
  local base="${1##*/}"
  case "$base" in
    *.tar.gz)  echo tar.gz; return ;;
    *.tar.bz2) echo tar.bz2; return ;;
    *.tar.xz)  echo tar.xz; return ;;
  esac
  if [[ "$base" != *.* ]]; then
    echo ""
    return
  fi
  local e="${base##*.}"
  # lower case portable
  printf '%s' "$e" | tr 'A-Z' 'a-z'
}

ignorar() {
  local base="${1##*/}"
  if [[ "$IGNORAR_OCULTOS" == "si" && "$base" == .* ]]; then
    return 0
  fi
  local n
  for n in "${IGNORAR_NOMBRES[@]}"; do
    [[ "$base" == "$n" ]] && return 0
  done
  local ext e
  ext=$(ext_de "$1")
  for e in "${IGNORAR_EXT[@]}"; do
    [[ "$ext" == "$e" ]] && return 0
  done
  return 1
}

clasificar() {
  case "$1" in
    jpg|jpeg|png|gif|webp|heic|heif|bmp|svg|tiff|tif|raw|dng|jfif) echo Imagenes ;;
    mp4|mkv|avi|mov|webm|3gp|m4v|flv|wmv|ts|mpeg|mpg) echo Videos ;;
    mp3|wav|ogg|m4a|flac|aac|opus|wma|amr|mid|midi) echo Audio ;;
    pdf|doc|docx|xls|xlsx|ppt|pptx|odt|ods|odp|rtf|txt|md|csv|epub|mobi|pages|numbers|key) echo Documentos ;;
    apk|xapk|apks|aab|xab) echo APK ;;
    zip|rar|7z|tar|gz|bz2|xz|tgz|tbz2|tar.gz|tar.bz2|tar.xz|iso|img) echo Comprimidos ;;
    py|js|ts|jsx|tsx|java|kt|c|cpp|h|hpp|cs|go|rs|rb|php|html|htm|css|json|xml|yaml|yml|toml|sh|bash|zsh|sql|ipynb) echo Codigo ;;
    ttf|otf|woff|woff2) echo Fuentes ;;
    *) echo Otros ;;
  esac
}

destino_base() {
  case "$1" in
    Imagenes)    echo "$DEST_IMAGENES" ;;
    Videos)      echo "$DEST_VIDEOS" ;;
    Audio)       echo "$DEST_AUDIO" ;;
    Documentos)  echo "$DEST_DOCUMENTOS" ;;
    APK)         echo "$DEST_APK" ;;
    Comprimidos) echo "$DEST_COMPRIMIDOS" ;;
    Codigo)      echo "$DEST_CODIGO" ;;
    Fuentes)     echo "$DEST_FUENTES" ;;
    *)           echo "$DEST_OTROS" ;;
  esac
}

ruta_unica() {
  local dest="$1"
  [[ ! -e "$dest" ]] && { echo "$dest"; return; }
  local dir base name ext n=1 cand
  dir=$(dirname "$dest")
  base=$(basename "$dest")
  if [[ "$base" == *.* ]]; then
    name="${base%.*}"; ext=".${base##*.}"
  else
    name="$base"; ext=""
  fi
  while true; do
    cand="$dir/${name}_${n}${ext}"
    [[ ! -e "$cand" ]] && { echo "$cand"; return; }
    n=$((n + 1))
  done
}

human() {
  local b=${1:-0}
  awk -v b="$b" 'BEGIN {
    split("B KB MB GB TB", u, " ")
    i=1
    while (b >= 1024 && i < 5) { b /= 1024; i++ }
    printf "%.1f %s", b, u[i]
  }'
}

# ------------------------------------------------------------
# Procesar un archivo (ruta de calor)
# ------------------------------------------------------------
procesar() {
  local ruta="$1" etiqueta="$2"

  [[ -f "$ruta" ]] || return 0
  ignorar "$ruta" && { omitidos=$((omitidos + 1)); return 0; }
  ya_organizado "$ruta" && { omitidos=$((omitidos + 1)); return 0; }
  bajo_protegida "$ruta" && { omitidos=$((omitidos + 1)); return 0; }

  local ext cat dest_dir nombre dest_final size
  ext=$(ext_de "$ruta")
  cat=$(clasificar "$ext")
  nombre="${ruta##*/}"
  dest_dir=$(destino_base "$cat")
  if [[ "$USAR_SUBCARPETA_ORIGEN" == "si" && -n "$etiqueta" && "$cat" != "Fuentes" ]]; then
    dest_dir="$dest_dir/$etiqueta"
  fi
  dest_final="$dest_dir/$nombre"

  # Mismo sitio → skip
  if [[ "$ruta" == "$dest_final" ]]; then
    omitidos=$((omitidos + 1))
    return 0
  fi

  # size (barato; si falla → 0)
  size=$(stat -c%s "$ruta" 2>/dev/null || echo 0)
  CONT_CAT["$cat"]=$(( ${CONT_CAT["$cat"]:-0} + 1 ))

  if [[ -e "$dest_final" ]]; then
    dest_final=$(ruta_unica "$dest_final")
    colisiones=$((colisiones + 1))
  fi

  # Rutas al CSV sin comas rotas
  local o c
  o=${ruta//,/; }
  c=${dest_final//,/; }

  if [[ "$MODO" == "informe" || "$DRY_RUN" == "si" ]]; then
    local tag="SIMULA"
    [[ "$MODO" == "informe" ]] && tag="DETECTADO"
    append_csv "$tag" "$etiqueta" "$cat" "$o" "$c" "$size"
    if [[ "$VERBOSE" == "si" ]]; then
      log "[$tag] [$etiqueta] $cat ← $nombre"
    else
      logq "[$tag] [$etiqueta] $cat ← $nombre"
    fi
    movidos=$((movidos + 1))
    bytes_movidos=$((bytes_movidos + size))
    return 0
  fi

  # ---- mover de verdad ----
  mkdir -p "$dest_dir"
  if mv -- "$ruta" "$dest_final" 2>>"$LOGFILE"; then
    append_csv "MOVIDO" "$etiqueta" "$cat" "$o" "$c" "$size"
    if [[ "$VERBOSE" == "si" ]]; then
      log "[OK] [$etiqueta] $cat ← $nombre"
    else
      logq "[OK] [$etiqueta] $cat ← $nombre"
    fi
    movidos=$((movidos + 1))
    bytes_movidos=$((bytes_movidos + size))
  else
    log "[ERROR] $ruta"
    append_csv "ERROR" "$etiqueta" "$cat" "$o" "$c" "$size"
    errores=$((errores + 1))
  fi
}

# ------------------------------------------------------------
# Escanear zona
# ------------------------------------------------------------
escanear_zona() {
  local zona_dir="$1" profundidad="$2" etiqueta="$3"
  local antes=$movidos
  local n=0

  if [[ ! -d "$zona_dir" ]]; then
    logq "(zona ausente) $etiqueta"
    return 0
  fi

  log ">>> $etiqueta  ·  $zona_dir  ·  prof≤$profundidad"

  local args=( "$zona_dir" )
  [[ "$profundidad" -gt 0 ]] && args+=( -maxdepth "$profundidad" )
  args+=( -type f -print0 )

  while IFS= read -r -d '' archivo; do
    case "$archivo" in
      */.secret/*|*/.cache/*|*/.thumbnails/*|*/.tmp/*|*/.temp/*|*/.trash/*|*/.obsidian/*) continue ;;
    esac
    if bajo_protegida "$archivo" || ya_organizado "$archivo"; then
      continue
    fi
    procesar "$archivo" "$etiqueta"
    n=$((n + 1))
    # progreso cada 200 archivos (zonas grandes: TikTok, SnapTube)
    if [[ "$VERBOSE" != "si" && $((n % 200)) -eq 0 && "$n" -gt 0 ]]; then
      printf '\r    … %d archivos revisados en %s (útiles: %d)   ' "$n" "$etiqueta" "$((movidos - antes))"
    fi
  done < <(find "${args[@]}" 2>/dev/null)

  [[ "$VERBOSE" != "si" && "$n" -ge 200 ]] && printf '\n'
  log "    → útiles: $((movidos - antes))  ·  revisados: $n"
}

# ------------------------------------------------------------
# MAIN
# ------------------------------------------------------------
log "=============================================="
log " Organizador del teléfono"
log " $(date)"
log " Shared: $SHARED"
log " Modo:   $MODO   DRY_RUN=$DRY_RUN   verbose=$VERBOSE"
log " Log:    $LOGFILE"
log "=============================================="

avail_kb=$(df -k "$SHARED" 2>/dev/null | awk 'NR==2{print $4}')
if [[ -n "${avail_kb:-}" && "$avail_kb" -lt 500000 ]]; then
  log "AVISO: poco espacio libre (<~500 MB). mv no duplica, pero libera basura después."
fi

if [[ "$INCLUIR_WHATSAPP" == "si" ]]; then
  log "AVISO: WhatsApp incluido — mover media rompe enlaces en chats."
  ZONAS+=(
    "$SHARED/Android/media/com.whatsapp/WhatsApp/Media|3|WhatsApp"
  )
fi

if [[ "$DRY_RUN" != "si" ]]; then
  mkdir -p \
    "$DEST_IMAGENES" "$DEST_VIDEOS" "$DEST_AUDIO" "$DEST_DOCUMENTOS" \
    "$DEST_APK" "$DEST_COMPRIMIDOS" "$DEST_CODIGO" "$DEST_FUENTES" "$DEST_OTROS"
fi

if [[ "$MODO" == "aplicar" && "$CONFIRMAR" == "si" ]]; then
  echo ""
  echo "  VAS A MOVER ARCHIVOS DE VERDAD en el Redmi."
  echo "  Antes conviene:  ./organizar_telefono.sh --informe"
  printf "  Escribe ORGANIZAR para continuar: "
  read -r resp
  if [[ "$resp" != "ORGANIZAR" ]]; then
    echo "Cancelado."
    exit 0
  fi
fi

t0=$(date +%s)

for entrada in "${ZONAS[@]}"; do
  IFS='|' read -r zdir zprof zetiq <<< "$entrada"
  escanear_zona "$zdir" "$zprof" "$zetiq"
done

# vaciar buffer CSV
if [[ -n "$CSV_BUF" ]]; then
  printf '%s\n' "$CSV_BUF" >> "$INFORME_CSV"
fi

t1=$(date +%s)
dur=$((t1 - t0))

log ""
log "=============================================="
log " RESUMEN ($MODO)  ·  ${dur}s"
log "----------------------------------------------"
log " Detectados / a mover:  $movidos"
log " Omitidos:              $omitidos"
log " Errores:               $errores"
log " Colisiones renombradas:$colisiones"
log " Volumen:               $(human "$bytes_movidos")"
log ""
log " Por categoría:"
for c in Imagenes Videos Audio Documentos APK Comprimidos Codigo Fuentes Otros; do
  n=${CONT_CAT["$c"]:-0}
  [[ "$n" -gt 0 ]] && log "   • $c: $n"
done
log ""
log " CSV:  $INFORME_CSV"
log " Log:  $LOGFILE"
log "=============================================="

if [[ "$DRY_RUN" == "si" ]]; then
  echo ""
  echo ">>> SIMULACIÓN / informe: no se movió nada."
  echo ">>> Si el resumen te convence:"
  echo ">>>   cd ~/scripts && ./organizar_telefono.sh --aplicar"
  echo ">>> Config:"
  echo ">>>   nano ~/scripts/organizar_telefono.conf"
fi

if [[ "$MODO" == "aplicar" && "$movidos" -gt 0 ]]; then
  echo ""
  echo "Hecho. Si la Galería MIUI no refresca, cierra/abre la app o reinicia."
fi
