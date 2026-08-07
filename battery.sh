#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
# Lanzador fácil de batería
#
#   ./battery.sh              → menú interactivo
#   ./battery.sh monitor      → pantalla en vivo
#   ./battery.sh start        → logger en segundo plano
#   ./battery.sh stop         → detener logger
#   ./battery.sh status       → ¿está corriendo el logger?
#   ./battery.sh once         → una sola lectura al CSV
#   ./battery.sh tail         → ver últimas líneas del CSV
#   ./battery.sh conf         → editar configuración
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=battery.conf
source "$SCRIPT_DIR/battery.conf"

mkdir -p "$(dirname "$PIDFILE")" 2>/dev/null

logger_pid() {
  if [[ -f "$PIDFILE" ]]; then
    local p
    p=$(cat "$PIDFILE" 2>/dev/null)
    if [[ -n "$p" ]] && kill -0 "$p" 2>/dev/null; then
      echo "$p"
      return 0
    fi
  fi
  return 1
}

cmd_monitor() {
  exec "$SCRIPT_DIR/battery_monitor.sh"
}

cmd_start() {
  local p
  if p=$(logger_pid); then
    echo "El logger ya está corriendo (PID $p)."
    return 0
  fi
  nohup "$SCRIPT_DIR/battery_logger.sh" >>"$LOGGER_ERRLOG" 2>&1 &
  sleep 0.5
  if p=$(logger_pid); then
    echo "Logger iniciado en segundo plano (PID $p)."
    echo "CSV: $LOGFILE"
    echo "Cada ${LOGGER_INTERVAL}s · Detener: ./battery.sh stop"
  else
    echo "ERROR: no arrancó el logger. Revisa: $LOGGER_ERRLOG"
    return 1
  fi
}

cmd_stop() {
  local p
  if ! p=$(logger_pid); then
    echo "No hay logger en ejecución."
    rm -f "$PIDFILE"
    return 0
  fi
  kill "$p" 2>/dev/null
  # Espera breve a que limpie el PID
  for _ in 1 2 3 4 5; do
    kill -0 "$p" 2>/dev/null || break
    sleep 0.2
  done
  if kill -0 "$p" 2>/dev/null; then
    kill -9 "$p" 2>/dev/null
  fi
  rm -f "$PIDFILE"
  echo "Logger detenido (era PID $p)."
}

cmd_status() {
  local p
  if p=$(logger_pid); then
    echo "Logger: ACTIVO (PID $p)"
    echo "Intervalo: ${LOGGER_INTERVAL}s"
    echo "CSV: $LOGFILE"
    if [[ -f "$LOGFILE" ]]; then
      echo "Última línea:"
      tail -n 1 "$LOGFILE"
    fi
  else
    echo "Logger: detenido"
    [[ -f "$LOGFILE" ]] && echo "CSV: $LOGFILE ($(wc -l < "$LOGFILE") líneas)"
  fi
}

cmd_once() {
  "$SCRIPT_DIR/battery_logger.sh" --once
}

cmd_tail() {
  if [[ ! -f "$LOGFILE" ]]; then
    echo "Aún no hay log: $LOGFILE"
    return 1
  fi
  echo "Últimas 15 líneas de $LOGFILE:"
  echo "----------------------------------------"
  tail -n 15 "$LOGFILE"
}

cmd_conf() {
  local editor="${EDITOR:-nano}"
  if command -v "$editor" >/dev/null 2>&1; then
    "$editor" "$SCRIPT_DIR/battery.conf"
  else
    echo "Edita a mano: $SCRIPT_DIR/battery.conf"
    echo "Editor no encontrado ($editor)."
  fi
}

menu() {
  while true; do
    clear
    echo "========== BATERÍA =========="
    echo ""
    if p=$(logger_pid); then
      echo "  Logger: ACTIVO (PID $p)"
    else
      echo "  Logger: detenido"
    fi
    echo ""
    echo "  1) Monitor en vivo"
    echo "  2) Iniciar logger (fondo)"
    echo "  3) Detener logger"
    echo "  4) Estado del logger"
    echo "  5) Registrar una vez"
    echo "  6) Ver últimas lecturas"
    echo "  7) Editar configuración"
    echo "  0) Salir"
    echo ""
    printf "Elige [0-7]: "
    read -r opcion
    case "$opcion" in
      1) cmd_monitor ;;
      2) cmd_start; echo; read -r -p "Enter…" _ ;;
      3) cmd_stop;  echo; read -r -p "Enter…" _ ;;
      4) cmd_status; echo; read -r -p "Enter…" _ ;;
      5) cmd_once;  echo; read -r -p "Enter…" _ ;;
      6) cmd_tail;  echo; read -r -p "Enter…" _ ;;
      7) cmd_conf ;;
      0|q|Q) echo "Listo."; exit 0 ;;
      *) echo "Opción no válida."; sleep 1 ;;
    esac
  done
}

# ---- entrada ----
case "${1:-}" in
  monitor|m)  cmd_monitor ;;
  start)      cmd_start ;;
  stop)       cmd_stop ;;
  status|s)   cmd_status ;;
  once|1)     cmd_once ;;
  tail|log)   cmd_tail ;;
  conf|config|edit) cmd_conf ;;
  help|-h|--help)
    cat <<'EOF'
Uso: ./battery.sh [comando]

  (sin args)   menú interactivo
  monitor      pantalla en vivo
  start        logger en segundo plano
  stop         detener logger
  status       ¿está corriendo?
  once         una sola lectura al CSV
  tail         ver últimas líneas del CSV
  conf         editar battery.conf
EOF
    ;;
  "") menu ;;
  *)
    echo "Comando desconocido: $1"
    echo "Usa: ./battery.sh help"
    exit 1
    ;;
esac
