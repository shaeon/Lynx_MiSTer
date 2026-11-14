# Camputers Lynx para MiSTer

Core de MiSTer del **Camputers Lynx** (1983) que junta en uno solo los dos
cores del Lynx de **Kyp**. El modelo se elige en el OSD:

| Modelo | Core de Kyp |
|---|---|
| Lynx 48K, 96K y 96K con ROM Scorpion | [lynx.poseidon](https://github.com/Kyp069/lynx.poseidon) ([lynx](https://github.com/Kyp069/lynx)) |
| Lynx 128K | [lynx128.poseidon](https://github.com/Kyp069/lynx128.poseidon) ([lynx128](https://github.com/Kyp069/lynx128)) |

Port a MiSTer: Shaeon (Carlos Palmero).

## Instalación

- Copia el `.rbf` a `/media/fat/_Computer/`.
- Copia `roms/boot.rom` (48K/96K) y `roms/boot1.rom` (128K) a
  `/media/fat/games/Lynx/`. Las dos se cargan solas al arrancar el core.
- Las cintas (`.tzx`) y los discos (`.ldf`) pueden ir en la misma carpeta.

En [roms/README.md](roms/README.md) está qué lleva cada fichero de ROM. La ROM
de la disquetera (XDOS) **todavía no está incluida**, así que la disquetera no
funciona hasta que se añada (ahí se explica cómo).

## OSD

| Opción | |
|---|---|
| Mount LDF | Imagen de disco para la controladora WD1793 (DOS del Lynx, `XROM`) |
| Load TZX | Cinta. Se guarda en la DDR3, sin límite práctico de tamaño |
| Model | 96K, 96K Scorpion, 48K, 128K. **Se aplica al hacer reset** ("Reset & apply model") |
| Bank 2 CAS enable | Solo en 48K/96K (como en el core de Kyp) |
| Video | Relación de aspecto, scandoubler/HQ2x/scanlines, escalado entero |
| Audio & Tape | Sonido de la cinta, invertir la entrada de audio, intercambiar joysticks |
| Tape play / stop | Igual que RePág / AvPág |

## Teclas

- **F9**: reset.
- **RePág / AvPág**: play / stop de la cinta.
- Bloq Mayús = SHIFT LOCK, Esc = ESCAPE, Retroceso = DELETE, Ctrl = CONTROL,
  cursores = cursores. El resto sigue la distribución del Lynx (`matrix.v` del
  core de Kyp).
- Joysticks: puerto 0x7A (joystick 1) y 0x7B (joystick 2), con un botón de disparo.
- Cinta desde un casete de verdad: entrada de audio de la placa I/O (ADC).

## Cómo funciona

Las dos máquinas están dentro del core y solo funciona la elegida; la otra se
queda en reset. Comparten la SDRAM, la WD1793, la cinta, el teclado, el audio
y el vídeo.

| | 48K / 96K | 128K |
|---|---|---|
| CPU | 4 MHz | 6 MHz |
| Píxel / 6845 | 6 MHz / 0,75 MHz | 12 MHz / 1,5 MHz |
| Memoria de vídeo | 2 × 16K (BRAM) | 64K (BRAM) |
| ROM | `boot.rom`, 64K | `boot1.rom`, 32K |

- **Los cores de Kyp son submódulos y no se tocan** (`rtl/lynx` y
  `rtl/lynx128`). Los dos tienen módulos llamados `lynx` y `video` con distinto
  contenido, y Quartus no lo admite. Antes de cada compilación,
  `rtl/pre_flow.tcl` escribe en `rtl/gen/` una copia de `lynx.v` + `video.v`
  de cada core con los módulos renombrados (`lynx48`, `lynx128`) y una salida
  `de` (display enable del 6845) para el blanking de MiSTer. Si un cambio de
  Kyp rompe alguno de los patrones, la compilación se para con un error. Los
  módulos comunes (T80, 6845, WD1793, teclado) se toman de `rtl/lynx`; son
  idénticos en los dos repositorios.
- **ROMs**: Main_MiSTer carga `boot1.rom` con índice 0x40 y `boot.rom` con
  índice 0. Mapa de la SDRAM: `boot.rom` en 0x00000, `boot1.rom` en 0x10000,
  RAM en 0x20000 (y el banco 4 del 128K en 0x30000).
- **SDRAM**: `rtl/sdram_mister.v`, con la misma interfaz que el `sdram.v` de
  Kyp pero con el esquema habitual de MiSTer (SDRAM_CLK = clk_sys invertido, un
  solo ACTIVE y READ/WRITE con auto-precharge). Refresca por su cuenta mientras
  la CPU está en reset (durante la carga de las ROMs).
- **Memoria de vídeo**: `rtl/vram.v` sustituye al `dprf` de Kyp: Quartus 17
  no sabe meter el `dprf` en los bloques M10K del Cyclone V (por cómo lee
  mientras escribe).
- **Blanking**: el horizontal sale del DE del 6845, retrasado un carácter como
  los píxeles en `video.v`; el vertical, de las líneas con DE del cuadro
  anterior (el 6845 lo programa la ROM).
- **Cinta**: `rtl/tape_ddr.sv` y `rtl/tzxplayer.vhd` de
  [ZXP3_MiSTer](https://github.com/shaeon/ZXP3_MiSTer) (cinta en la DDR3,
  bloques de datos generalizados 0x19, bucles).

## Compilación

```
git clone --recursive https://github.com/shaeon/Lynx_MiSTer.git
```

(Hace falta `--recursive`: los cores de Kyp traen el T80 como submódulo anidado.)
Abre `Lynx.qpf` con Quartus 17.0 y compila, o ejecuta `build.bat`, que deja el
RBF en `releases/`.

GitHub Actions (`.github/workflows/build.yml`) compila el core en cada `push`
con Quartus 17.0 (imagen Docker `raetro/quartus:17.0`) y guarda el `.rbf`, los
informes y el detalle de tiempos de la SDRAM (`tools/rutas_sdram.tcl`) en la
pestaña *Actions*. Al subir una etiqueta `v*` crea además una Release con el
`.rbf`.

Para actualizar los cores de Kyp: `git -C rtl/lynx pull` /
`git -C rtl/lynx128 pull` y commit de los nuevos punteros de los submódulos.
Dentro de ellos no se parchea nada.

## Créditos y agradecimientos

- **Kyp** (Kyp069): los cores del Lynx 48K/96K y 128K sobre los que está hecho
  este port.
- **RetroWiki** y su equipo FPGA (RW-FPGA-devel-Team): rampa069 y ron hicieron
  el primer port del Lynx a MiSTer (a partir del core de Kyp para ZX-Uno) y
  [lynx2wav](https://github.com/RW-FPGA-devel-Team/lynx2wav); y gracias a toda
  la comunidad de RetroWiki por mantener vivo el Lynx.
- Los colaboradores de [Lynx48_MiSTer](https://github.com/MiSTer-devel/Lynx48_MiSTer)
  (rampa069, JasonA, JimmyStones, alanswx): las ROMs salen de ese repositorio.
- MAME (driver camplynx) por la documentación y las sumas de las ROMs; Jynx,
  PALE y quienes han documentado el Lynx (Pete Todd, el análisis de la ROM de
  w5Mike).
- T80 (Daniel Wallner, MikeJ y otros), UM6845R y WD1793 (desarrolladores de
  MiSTer, Sorgelig), tzxplayer (György Szombathelyi) y el marco de MiSTer
  (MiSTer-devel).

## Licencia

GPL v3, como los cores de Kyp (el marco `sys/` es GPL v2 o posterior). Las ROMs
son propiedad de sus autores y se incluyen con fines de preservación.

---

Desarrollado con la ayuda de Claude (Anthropic).
