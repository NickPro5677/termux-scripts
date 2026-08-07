#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
# Monitor de batería en vivo (pantalla)
# Uso:  ./battery_monitor.sh
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=battery.conf
source "$SCRIPT_DIR/battery.conf"

for cmd in termux-battery-status jq; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERROR: falta '$cmd'. Instala: pkg install termux-api jq"
    exit 1
  fi
done

trap 'echo; echo "Monitor cerrado."; exit 0' INT TERM

while true; do
  raw=$(termux-battery-status 2>/dev/null)
  if [[ -z "$raw" ]]; then
    clear
    echo "No pude leer el estado de la batería."
    echo "Reintento en ${MONITOR_INTERVAL}s…"
    sleep "$MONITOR_INTERVAL"
    continue
  fi

  # Un solo jq para todo el bloque de texto
  if [[ "$CURRENT_IN_MA" == "si" ]]; then
    info=$(echo "$raw" | jq -r '
      "Porcentaje:  \(.percentage)%",
      "Estado:      \(.status)",
      "Conectado:   \(.plugged // "?")",
      "Temperatura: \(.temperature)°C",
      "Corriente:   \((.current / 1000) | round) mA",
      "Voltaje:     \(.voltage // "?") mV",
      "Salud:       \(.health // "?")",
      "Tecnología:  \(.technology // "?")"
    ')
  else
    info=$(echo "$raw" | jq -r '
      "Porcentaje:  \(.percentage)%",
      "Estado:      \(.status)",
      "Conectado:   \(.plugged // "?")",
      "Temperatura: \(.temperature)°C",
      "Corriente:   \(.current) µA",
      "Voltaje:     \(.voltage // "?") mV",
      "Salud:       \(.health // "?")",
      "Tecnología:  \(.technology // "?")"
    ')
  fi

  clear
  echo "========== MONITOR DE BATERÍA =========="
  date '+%Y-%m-%d %H:%M:%S'
  echo ""
  echo "$info"
  echo ""
  echo "Refresco cada ${MONITOR_INTERVAL}s  ·  Ctrl+C para salir"
  sleep "$MONITOR_INTERVAL"
done
