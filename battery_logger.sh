#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
# Logger de batería — registra CSV cada N segundos
# Uso:  ./battery_logger.sh          (primer plano)
#       ./battery_logger.sh --once   (una sola lectura)
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=battery.conf
source "$SCRIPT_DIR/battery.conf"

mkdir -p "$(dirname "$LOGFILE")" "$(dirname "$PIDFILE")" 2>/dev/null

# Comprobaciones
for cmd in termux-battery-status jq; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERROR: falta '$cmd'. Instala: pkg install termux-api jq"
    exit 1
  fi
done

# Una sola llamada a jq (antes eran 4)
leer_bateria() {
  local raw
  raw=$(termux-battery-status 2>/dev/null) || {
    echo "ERROR: no pude leer termux-battery-status"
    return 1
  }

  # percentage|status|temperature|current|plugged|voltage|health
  echo "$raw" | jq -r '[
    .percentage,
    .status,
    .temperature,
    .current,
    .plugged // "?",
    .voltage // "?",
    .health // "?"
  ] | @tsv'
}

formatear_corriente() {
  local uA="$1"
  if [[ "$CURRENT_IN_MA" == "si" ]]; then
    # µA → mA con 1 decimal
    awk -v c="$uA" 'BEGIN { printf "%.1f", c/1000 }'
  else
    echo "$uA"
  fi
}

escribir_cabecera() {
  if [[ ! -f "$LOGFILE" ]]; then
    echo "fecha,porcentaje,estado,temperatura,corriente_mA,conectado,voltaje,salud" > "$LOGFILE"
  fi
}

registrar_una() {
  local fila fecha porc est temp curr plugged volt health curr_fmt
  fila=$(leer_bateria) || return 1

  IFS=$'\t' read -r porc est temp curr plugged volt health <<< "$fila"
  fecha=$(date '+%Y-%m-%d %H:%M:%S')
  curr_fmt=$(formatear_corriente "$curr")

  echo "$fecha,$porc,$est,$temp,$curr_fmt,$plugged,$volt,$health" >> "$LOGFILE"
  echo "Registrado: $fecha — ${porc}% | ${est} | ${temp}°C | ${curr_fmt} mA | $plugged"
}

# ---- main ----
escribir_cabecera

if [[ "${1:-}" == "--once" ]]; then
  registrar_una
  exit $?
fi

# Evitar dos loggers a la vez
if [[ -f "$PIDFILE" ]]; then
  old_pid=$(cat "$PIDFILE" 2>/dev/null)
  if [[ -n "$old_pid" ]] && kill -0 "$old_pid" 2>/dev/null; then
    echo "Ya hay un logger corriendo (PID $old_pid)."
    echo "Para detenerlo: ./battery.sh stop   o   kill $old_pid"
    exit 1
  fi
  rm -f "$PIDFILE"
fi

echo $$ > "$PIDFILE"
trap 'rm -f "$PIDFILE"; echo; echo "Logger detenido."; exit 0' INT TERM

echo "Logger de batería activo (cada ${LOGGER_INTERVAL}s)"
echo "CSV: $LOGFILE"
echo "Ctrl+C para salir"
echo ""

while true; do
  registrar_una || echo "Aviso: lectura fallida, reintento en ${LOGGER_INTERVAL}s"
  sleep "$LOGGER_INTERVAL"
done
