#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# inventario_completo.sh
# Inventario riguroso del almacenamiento accesible desde Termux (Android)
# Autor: laboratorio personal — estudiante de ingeniería informática
# Versión: 2.0
# =============================================================================
# Diseño:
#   - Falla de forma controlada (set -u, comprobaciones, códigos de salida)
#   - No interrumpe todo el inventario si una ruta falla
#   - Reporte persistente + salida en pantalla
#   - Secciones numeradas y reproducibles
# =============================================================================

set -u
# No usamos "set -e" global: queremos continuar aunque una sección falle.

# -----------------------------------------------------------------------------
# Configuración (ajusta solo aquí)
# -----------------------------------------------------------------------------
readonly SCRIPT_NAME="inventario_completo"
readonly VERSION="2.0"
readonly HOME_DIR="${HOME}"
readonly SHARED="${HOME_DIR}/storage/shared"
readonly DOWNLOADS="${HOME_DIR}/storage/downloads"
readonly DCIM="${HOME_DIR}/storage/dcim"
readonly PICTURES="${HOME_DIR}/storage/pictures"
readonly MOVIES="${HOME_DIR}/storage/movies"
readonly MUSIC="${HOME_DIR}/storage/music"
readonly REPORT_DIR="${HOME_DIR}/scripts/reportes"
readonly LOG_DIR="${HOME_DIR}/scripts/logs"

# Umbrales
readonly BIG_FILE_MB=50          # Archivos "grandes" a listar
readonly TOP_N_DIRS=20           # Top carpetas
readonly TOP_N_FILES=30          # Top archivos
readonly MAX_FIND_DEPTH_DATA=3   # Profundidad al explorar Android/data (evitar lentitud extrema)

# -----------------------------------------------------------------------------
# Inicialización de rutas de salida
# -----------------------------------------------------------------------------
mkdir -p "${REPORT_DIR}" "${LOG_DIR}"

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
REPORT_FILE="${REPORT_DIR}/inventario_${TIMESTAMP}.txt"
LATEST_LINK="${REPORT_DIR}/inventario_LATEST.txt"
ERROR_LOG="${LOG_DIR}/${SCRIPT_NAME}_${TIMESTAMP}.err"

# -----------------------------------------------------------------------------
# Utilidades
# -----------------------------------------------------------------------------
log() {
  # Escribe en pantalla y en el reporte
  printf '%s\n' "$*" | tee -a "${REPORT_FILE}"
}

log_section() {
  log ""
  log "================================================================================"
  log " $1"
  log "================================================================================"
}

warn() {
  printf 'AVISO: %s\n' "$*" | tee -a "${REPORT_FILE}" "${ERROR_LOG}" >/dev/null
  printf 'AVISO: %s\n' "$*"
}

die() {
  printf 'ERROR FATAL: %s\n' "$*" | tee -a "${REPORT_FILE}" "${ERROR_LOG}" >&2
  exit 1
}

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

# Ejecuta un comando de inventario sin abortar el script si falla
run_soft() {
  # usage: run_soft "descripción" comando args...
  local desc="$1"
  shift
  if ! "$@" >>"${REPORT_FILE}" 2>>"${ERROR_LOG}"; then
    warn "Falló sección/comando: ${desc}"
    return 1
  fi
  # También mostrar en pantalla lo que se acaba de añadir es complejo;
  # para simplicidad, las secciones críticas usan log + pipeline propio.
  return 0
}

human_now() {
  date '+%Y-%m-%d %H:%M:%S %Z'
}

# -----------------------------------------------------------------------------
# Preflight
# -----------------------------------------------------------------------------
preflight() {
  log_section "0. PREFLIGHT — COMPROBACIONES"
  log "Script:      ${SCRIPT_NAME} v${VERSION}"
  log "Fecha:       $(human_now)"
  log "Usuario:     ${USER:-termux}"
  log "Home:        ${HOME_DIR}"
  log "Shell:       ${SHELL:-desconocida}"
  log "Reporte:     ${REPORT_FILE}"
  log "Log errores: ${ERROR_LOG}"
  log ""

  if ! have_cmd find || ! have_cmd du || ! have_cmd df; then
    die "Faltan utilidades básicas (find/du/df). Instala: pkg install coreutils findutils"
  fi

  if [ ! -d "${SHARED}" ]; then
    die "No existe ${SHARED}. Ejecuta: termux-setup-storage y concede permiso de todos los archivos"
  fi

  if [ ! -r "${SHARED}" ]; then
    die "Sin permiso de lectura en ${SHARED}. Revoca/vuelve a conceder almacenamiento a Termux"
  fi

  log "Acceso a SHARED: OK"
  log "Comandos find/du/df: OK"
}

# -----------------------------------------------------------------------------
# 1. Espacio global
# -----------------------------------------------------------------------------
section_df() {
  log_section "1. ESPACIO EN SISTEMA DE ARCHIVOS (df)"
  log "Nota: en Android sin root solo verás montajes accesibles a Termux."
  log ""
  {
    df -h "${SHARED}" 2>/dev/null || df -h 2>/dev/null
  } | tee -a "${REPORT_FILE}"
}

# -----------------------------------------------------------------------------
# 2. Top de carpetas en almacenamiento compartido
# -----------------------------------------------------------------------------
section_top_dirs() {
  log_section "2. TOP ${TOP_N_DIRS} CARPETAS (profundidad 1 en SHARED)"
  log "Ruta base: ${SHARED}"
  log ""

  # du -d 1: solo primer nivel; ordenar por tamaño humano
  if ! du -h -d 1 "${SHARED}" 2>>"${ERROR_LOG}" | sort -hr | head -n "${TOP_N_DIRS}" | tee -a "${REPORT_FILE}"; then
    warn "No se pudo obtener el top de carpetas de SHARED"
  fi

  log ""
  log "Sub-top: Descargas (si existe)"
  if [ -d "${DOWNLOADS}" ]; then
    du -h -d 1 "${DOWNLOADS}" 2>>"${ERROR_LOG}" | sort -hr | head -n 15 | tee -a "${REPORT_FILE}" || true
  else
    log "(Descargas no disponible)"
  fi
}

# -----------------------------------------------------------------------------
# 3. Archivos más grandes
# -----------------------------------------------------------------------------
section_big_files() {
  log_section "3. ARCHIVOS MÁS GRANDES (>= ${BIG_FILE_MB} MB)"
  log "Buscando en: ${SHARED}"
  log "Esto puede tardar 1–5 minutos según cuántos archivos tengas..."
  log ""

  # find + ls: portable en Termux; 2>> errores de permisos
  # Usamos -printf si está disponible (GNU find); si no, fallback.
  local count=0
  if find "${SHARED}" -type f -size +"${BIG_FILE_MB}"M -printf '%s\t%p\n' 2>>"${ERROR_LOG}" \
      | sort -nr \
      | head -n "${TOP_N_FILES}" \
      | awk '{
          size=$1;
          $1="";
          sub(/^ /,"");
          path=$0;
          if (size>=1073741824) printf "%7.2f GB  %s\n", size/1073741824, path;
          else if (size>=1048576) printf "%7.2f MB  %s\n", size/1048576, path;
          else printf "%7.2f KB  %s\n", size/1024, path;
        }' | tee -a "${REPORT_FILE}"; then
    :
  else
    # Fallback sin -printf (por si find no es GNU)
    warn "find -printf no disponible o falló; usando fallback ls"
    find "${SHARED}" -type f -size +"${BIG_FILE_MB}"M -exec ls -l {} \; 2>>"${ERROR_LOG}" \
      | awk '{print $5, $9}' \
      | sort -nr \
      | head -n "${TOP_N_FILES}" \
      | tee -a "${REPORT_FILE}" || warn "Fallback de archivos grandes también falló"
  fi
}

# -----------------------------------------------------------------------------
# 4. Conteo por extensiones (visión global en SHARED)
# -----------------------------------------------------------------------------
section_extensions() {
  log_section "4. CONTEO POR TIPO DE ARCHIVO (extensiones frecuentes)"
  log "Muestreo sobre todo SHARED. Puede tardar..."
  log ""

  # Lista de extensiones de interés para un estudiante / móvil
  local ext
  local -a EXTS=(
    apk xapk apks
    pdf doc docx txt xls xlsx ppt pptx
    jpg jpeg png gif webp heic
    mp4 mkv avi mov webm
    mp3 wav ogg m4a flac
    zip rar 7z tar gz
    html htm json csv xml
  )

  printf '%-10s %s\n' "EXT" "CANTIDAD" | tee -a "${REPORT_FILE}"
  printf '%-10s %s\n' "----------" "--------" | tee -a "${REPORT_FILE}"

  for ext in "${EXTS[@]}"; do
    # wc -l cuenta líneas; silenciar errores de permiso
    local n
    n="$(find "${SHARED}" -type f -iname "*.${ext}" 2>>"${ERROR_LOG}" | wc -l | tr -d ' ')"
    printf '%-10s %s\n' ".${ext}" "${n}" | tee -a "${REPORT_FILE}"
  done
}

# -----------------------------------------------------------------------------
# 5. Zonas críticas del teléfono
# -----------------------------------------------------------------------------
section_zones() {
  log_section "5. ZONAS CRÍTICAS (tamaño y existencia)"

  local -a ZONES=(
    "${DOWNLOADS}|Descargas"
    "${DCIM}|Camara_DCIM"
    "${PICTURES}|Pictures"
    "${MOVIES}|Movies"
    "${MUSIC}|Music"
    "${SHARED}/WhatsApp|WhatsApp_clasico"
    "${SHARED}/Android/media|Android_media"
    "${SHARED}/Android/data|Android_data"
    "${SHARED}/Android/obb|Android_obb"
    "${SHARED}/Documents|Documents"
    "${SHARED}/Download|Download_alt"
    "${SHARED}/Movies|Movies_alt"
    "${SHARED}/Pictures|Pictures_alt"
    "${SHARED}/DCIM|DCIM_alt"
  )

  printf '%-22s %-10s %s\n' "ZONA" "ESTADO" "TAMAÑO" | tee -a "${REPORT_FILE}"
  printf '%-22s %-10s %s\n' "--------------------" "----------" "------" | tee -a "${REPORT_FILE}"

  local entry path label
  for entry in "${ZONES[@]}"; do
    path="${entry%%|*}"
    label="${entry##*|}"
    if [ -d "${path}" ]; then
      local sz
      sz="$(du -sh "${path}" 2>>"${ERROR_LOG}" | awk '{print $1}')"
      printf '%-22s %-10s %s\n' "${label}" "OK" "${sz:-?}" | tee -a "${REPORT_FILE}"
    else
      printf '%-22s %-10s %s\n' "${label}" "NO EXISTE" "-" | tee -a "${REPORT_FILE}"
    fi
  done
}

# -----------------------------------------------------------------------------
# 6. Descargas en detalle
# -----------------------------------------------------------------------------
section_downloads_detail() {
  log_section "6. DETALLE DE DESCARGAS"

  if [ ! -d "${DOWNLOADS}" ]; then
    log "No hay carpeta de Descargas en ${DOWNLOADS}"
    return 0
  fi

  log "Ruta: ${DOWNLOADS}"
  log ""
  log "Tamaño total:"
  du -sh "${DOWNLOADS}" 2>>"${ERROR_LOG}" | tee -a "${REPORT_FILE}" || true
  log ""
  log "Elementos en raíz (primer nivel):"
  ls -lah "${DOWNLOADS}" 2>>"${ERROR_LOG}" | tee -a "${REPORT_FILE}" || true
  log ""
  log "Conteo de archivos bajo Descargas:"
  find "${DOWNLOADS}" -type f 2>>"${ERROR_LOG}" | wc -l | tee -a "${REPORT_FILE}"
  log ""
  log "APK dentro de Descargas:"
  find "${DOWNLOADS}" -type f \( -iname '*.apk' -o -iname '*.xapk' -o -iname '*.apks' \) 2>>"${ERROR_LOG}" \
    | tee -a "${REPORT_FILE}" || true
}

# -----------------------------------------------------------------------------
# 7. Android/data y obb (solo tamaños de primer nivel — puede ser lento)
# -----------------------------------------------------------------------------
section_android_data() {
  log_section "7. ANDROID/DATA y OBB (top paquetes por tamaño)"
  log "Nota: sin root no verás el interior privado de todas las apps,"
  log "pero sí el peso de muchas carpetas exportadas al almacenamiento compartido."
  log ""

  local data_dir="${SHARED}/Android/data"
  local obb_dir="${SHARED}/Android/obb"

  if [ -d "${data_dir}" ]; then
    log "Top 25 en Android/data:"
    du -h -d 1 "${data_dir}" 2>>"${ERROR_LOG}" | sort -hr | head -n 25 | tee -a "${REPORT_FILE}" || true
  else
    log "Android/data no existe o no es accesible"
  fi

  log ""
  if [ -d "${obb_dir}" ]; then
    log "Top 15 en Android/obb:"
    du -h -d 1 "${obb_dir}" 2>>"${ERROR_LOG}" | sort -hr | head -n 15 | tee -a "${REPORT_FILE}" || true
  else
    log "Android/obb no existe o no es accesible"
  fi
}

# -----------------------------------------------------------------------------
# 8. Hallazgos que merecen atención
# -----------------------------------------------------------------------------
section_alerts() {
  log_section "8. ALERTAS Y HALLAZGOS"

  local alerts=0

  # APK fuera de una carpeta APK organizada (en Descargas raíz o sueltas)
  log "--- APK / instaladores encontrados (primeros 40) ---"
  local apk_list
  apk_list="$(find "${SHARED}" -type f \( -iname '*.apk' -o -iname '*.xapk' -o -iname '*.apks' \) 2>>"${ERROR_LOG}" | head -n 40)"
  if [ -n "${apk_list}" ]; then
    printf '%s\n' "${apk_list}" | tee -a "${REPORT_FILE}"
    alerts=$((alerts + 1))
  else
    log "(ninguno)"
  fi

  log ""
  log "--- Archivos >= 500 MB (posibles videos/backups olvidados) ---"
  if find "${SHARED}" -type f -size +500M -printf '%s\t%p\n' 2>>"${ERROR_LOG}" \
      | sort -nr | head -n 15 \
      | awk '{printf "%.2f GB\t%s\n", $1/1073741824, substr($0, index($0,$2))}' \
      | tee -a "${REPORT_FILE}"; then
    alerts=$((alerts + 1))
  else
    find "${SHARED}" -type f -size +500M 2>>"${ERROR_LOG}" | head -n 15 | tee -a "${REPORT_FILE}" || log "(ninguno o no listable)"
  fi

  log ""
  log "--- Archivos vacíos (0 bytes) en Descargas (muestra) ---"
  if [ -d "${DOWNLOADS}" ]; then
    find "${DOWNLOADS}" -type f -size 0 2>>"${ERROR_LOG}" | head -n 30 | tee -a "${REPORT_FILE}" || log "(ninguno)"
  fi

  log ""
  log "Resumen de alertas generadas: código interno ${alerts} (informativo)"
}

# -----------------------------------------------------------------------------
# 9. Resumen ejecutivo
# -----------------------------------------------------------------------------
section_summary() {
  log_section "9. RESUMEN EJECUTIVO"

  local total_files
  total_files="$(find "${SHARED}" -type f 2>>"${ERROR_LOG}" | wc -l | tr -d ' ')"
  log "Archivos visibles bajo SHARED (aprox): ${total_files}"
  log "Reporte completo: ${REPORT_FILE}"
  log "Errores/avisos técnicos: ${ERROR_LOG}"
  log ""
  log "Interpretación rápida:"
  log "  1) Mira la sección 2: las carpetas más pesadas son tu prioridad de limpieza."
  log "  2) Mira la sección 3: archivos enormes suelen ser videos o backups."
  log "  3) Mira la sección 7: apps con Android/data enorme merecen 'borrar caché'."
  log "  4) Mira la sección 8: APK sueltos y archivos >500MB conviene decidir a mano."
  log ""
  log "Fin del inventario — $(human_now)"
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
  # Cabecera limpia del archivo de reporte
  : >"${REPORT_FILE}"
  : >"${ERROR_LOG}"

  preflight
  section_df
  section_top_dirs
  section_big_files
  section_extensions
  section_zones
  section_downloads_detail
  section_android_data
  section_alerts
  section_summary

  # Enlace simbólico al último reporte
  ln -sf "${REPORT_FILE}" "${LATEST_LINK}" 2>/dev/null || cp "${REPORT_FILE}" "${LATEST_LINK}"

  echo ""
  echo ">>> Inventario terminado."
  echo ">>> Reporte: ${REPORT_FILE}"
  echo ">>> Último:  ${LATEST_LINK}"
  echo ">>> Errores: ${ERROR_LOG}"
}

main "$@"
