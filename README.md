# termux-scripts

Scripts en Bash para Android con [Termux](https://termux.dev): batería, organización de archivos e inventario del almacenamiento. Escritos para un Redmi Note 11.

[![ShellCheck](https://github.com/NickPro5677/termux-scripts/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/NickPro5677/termux-scripts/actions/workflows/shellcheck.yml)
[![Licencia: MIT](https://img.shields.io/badge/licencia-MIT-green.svg)](LICENSE)

## Para qué sirve

Cuidar la batería, ordenar archivos del teléfono y ver qué ocupa espacio, todo desde Termux.

## Requisitos

- Termux con acceso al almacenamiento: `termux-setup-storage`.
- Para los scripts de batería: la app **Termux:API** y los paquetes `termux-api` y `jq`:

  ```sh
  pkg install termux-api jq
  ```

## Cómo usarlos

```sh
git clone https://github.com/NickPro5677/termux-scripts.git
cd termux-scripts
chmod +x *.sh
```

Los logs y reportes se guardan en `~/scripts/logs` y `~/scripts/reportes`.

### Batería

| Script | Qué hace |
|---|---|
| `battery.sh` | Lanzador con menú: `monitor`, `start`, `stop`, `status`, `once`, `tail`, `conf` |
| `battery_monitor.sh` | Pantalla en vivo con porcentaje, estado, temperatura, corriente, voltaje y salud |
| `battery_logger.sh` | Registra lecturas en un CSV cada N segundos (`--once` para una sola lectura) |
| `battery.conf` | Configuración: ruta del CSV, intervalos y unidades de corriente |

```sh
./battery.sh           # menú interactivo
./battery.sh start     # registro en segundo plano
./battery.sh monitor   # pantalla en vivo
```

El CSV (por defecto `~/storage/shared/battery_log.csv`) tiene las columnas `fecha,porcentaje,estado,temperatura,corriente_mA,conectado,voltaje,salud`.

### Organización de archivos

| Script | Qué hace |
|---|---|
| `organizar_telefono.sh` | Clasifica archivos sueltos del almacenamiento por tipo y origen, según `organizar_telefono.conf`. Por defecto solo simula. |
| `organizar_descargas.sh` | Ordena la carpeta Descargas en subcarpetas (APK, Documentos, Imágenes, Videos, Audio, Comprimidos, Otros). Por defecto solo simula; `--aplicar` mueve de verdad. |
| `organizar_tiktok.sh` | Busca videos `.mp4`/`.mov` de TikTok (nombre o ruta con `tiktok`, `musically`, `ugc.trill`, `snaptik` o `ssstik`) en DCIM, Download, Movies, Pictures y Android/media y los pasa a `TikTok_Videos`. Por defecto solo simula; `--aplicar` mueve de verdad. |
| `recolectar_documentos.sh` | Copia documentos (PDF, Office, ODF, TXT, CSV, MD, EPUB…) de todo el almacenamiento a `Documents/MisDocumentos` |

```sh
./organizar_telefono.sh              # simulación: muestra qué haría
./organizar_telefono.sh --informe    # solo cuenta el desorden
./organizar_telefono.sh --aplicar    # mueve de verdad
./organizar_telefono.sh --verbose    # lista cada archivo

./organizar_descargas.sh             # simulación
./organizar_descargas.sh --aplicar   # mueve de verdad
./organizar_tiktok.sh                # simulación
./organizar_tiktok.sh --aplicar      # mueve de verdad
```

Todos los organizadores arrancan en **modo simulación**: muestran qué harían sin mover nada. Revisa la salida y luego usa `--aplicar`. `organizar_descargas.sh` también acepta `DRY_RUN="no"` como variable de entorno.

`organizar_telefono.conf` define los destinos por tipo, las zonas a escanear, las carpetas protegidas que nunca se tocan, las extensiones a ignorar y si se pide confirmación. El script también guarda un CSV con lo movido (`~/scripts/reportes/organizar_ultimo.csv`) para poder deshacerlo a mano.

### Inventario

| Script | Qué hace |
|---|---|
| `inventario_completo.sh` | Reporte del almacenamiento: espacio (`df`), carpetas más pesadas, archivos de 50 MB o más, conteo por extensión, zonas críticas, detalle de Descargas, paquetes en `Android/data` y `obb`, alertas y resumen |

El reporte se guarda en `~/scripts/reportes/inventario_<fecha>.txt` (y `inventario_LATEST.txt`).

## Estructura de archivos

```text
termux-scripts/
├── battery.sh / battery_monitor.sh / battery_logger.sh / battery.conf
├── organizar_telefono.sh / organizar_telefono.conf
├── organizar_descargas.sh
├── organizar_tiktok.sh
├── recolectar_documentos.sh
├── inventario_completo.sh
└── .github/workflows/shellcheck.yml
```

## Tecnologías

- Bash
- Termux y Termux:API
- `jq` (para los scripts de batería)
- ShellCheck en la CI

## Estado

Activo. No hay issues ni *releases*. La CI corre ShellCheck (`--severity=error`) sobre los scripts.

## Licencia

Distribuido bajo la licencia [MIT](LICENSE).
