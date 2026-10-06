# termux-scripts

Scripts en Bash para Android con [Termux](https://termux.dev): batería, organización de archivos e inventario del almacenamiento. Escritos para un Redmi Note 11.

## Requisitos

- Termux con acceso al almacenamiento: `termux-setup-storage`.
- Para los scripts de batería: la app **Termux:API** y los paquetes `termux-api` y `jq`:

  ```sh
  pkg install termux-api jq
  ```

## Instalación

```sh
git clone https://github.com/NickPro5677/termux-scripts.git
cd termux-scripts
chmod +x *.sh
```

Los logs y reportes se guardan en `~/scripts/logs` y `~/scripts/reportes`.

## Scripts

### Batería

| Script | Qué hace |
|---|---|
| `battery.sh` | Lanzador con menú: `monitor`, `start`, `stop`, `status`, `once`, `tail`, `conf` |
| `battery_monitor.sh` | Pantalla en vivo con porcentaje, estado, temperatura, corriente, voltaje y salud |
| `battery_logger.sh` | Registra lecturas en un CSV cada N segundos (`--once` para una sola lectura) |
| `battery.conf` | Configuración: ruta del CSV, intervalos y unidades de corriente |

```sh
./battery.sh           # menú interactivo
./battery.sh start     # logger en segundo plano
./battery.sh monitor   # pantalla en vivo
```

El CSV (por defecto `~/storage/shared/battery_log.csv`) tiene las columnas `fecha,porcentaje,estado,temperatura,corriente_mA,conectado,voltaje,salud`.

### Organización de archivos

| Script | Qué hace |
|---|---|
| `organizar_telefono.sh` | Clasifica archivos sueltos del almacenamiento por tipo y origen según `organizar_telefono.conf`. **Por defecto solo simula.** |
| `organizar_descargas.sh` | Ordena la carpeta Descargas en subcarpetas (APK, Documentos, Imágenes, Videos, Audio, Comprimidos, Otros) |
| `organizar_tiktok.sh` | Busca archivos `.mp4`/`.mov` en DCIM, Download, Movies, Pictures y Android/media y los mueve a `TikTok_Videos` |
| `recolectar_documentos.sh` | Copia documentos (PDF, Office, ODF, TXT, CSV, MD, EPUB…) de todo el almacenamiento a `Documents/MisDocumentos` |

```sh
./organizar_telefono.sh              # simulación: muestra qué haría
./organizar_telefono.sh --informe    # solo cuenta el desorden
./organizar_telefono.sh --aplicar    # mueve de verdad
./organizar_telefono.sh --verbose    # lista cada archivo
```

> ⚠️ `organizar_descargas.sh` (con `DRY_RUN="no"` en el script) y `organizar_tiktok.sh` mueven archivos de verdad desde el primer uso. `organizar_tiktok.sh` mueve **todos** los `.mp4`/`.mov` que encuentre en esas carpetas, no solo los de TikTok. Revisa las rutas antes de ejecutarlos.

`organizar_telefono.conf` define los destinos por tipo, las zonas a escanear, las carpetas protegidas que nunca se tocan, las extensiones a ignorar y si se pide confirmación. El script también guarda un CSV con lo movido (`~/scripts/reportes/organizar_ultimo.csv`) para poder deshacerlo a mano.

### Inventario

| Script | Qué hace |
|---|---|
| `inventario_completo.sh` | Reporte del almacenamiento: espacio (`df`), carpetas más pesadas, archivos de 50 MB o más, conteo por extensión, zonas críticas, detalle de Descargas, paquetes en `Android/data` y `obb`, alertas y resumen |

El reporte se guarda en `~/scripts/reportes/inventario_<fecha>.txt` (y `inventario_LATEST.txt`).
