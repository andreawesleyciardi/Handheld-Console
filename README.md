# Handheld Console

This repository is a custom **Retro-Go port for a DIY ESP32-S3 handheld
console**. It is based on [Retro-Go](https://github.com/ducalex/retro-go), but
the target hardware, pin mapping, display support, storage wiring, and build
configuration in this repository are specific to this handheld.

The project is intended to make this particular hardware combination repeatable
for anyone building a similar console:

- Waveshare ESP32-S3-DEV-KIT-N16R8-M
- 16 MB flash and 8 MB OPI PSRAM
- DFRobot Fermion DFR0669 ILI9488 display, 480x320
- External SPI micro-SD module
- 12 GPIO buttons plus a Menu button, and a battery voltage divider

## Why this customization exists

The upstream Retro-Go project supports many devices, but this board and display
combination required a dedicated target. The important work in this repository
was not just selecting a board: it was resolving an interaction between the
display wiring and the ESP32-S3's OPI PSRAM interface.

## The problem we faced

The first display wiring used these GPIOs:

```text
LCD SCK   -> GPIO38
LCD MOSI  -> GPIO21
LCD MISO  -> GPIO37
LCD CS    -> GPIO36
LCD DC    -> GPIO35
LCD RESET -> GPIO48
```

The display backlight turned on, but the screen remained blank. The firmware
also reported symptoms such as:

```text
PSRAM ID read error: 0x00ffffff
SPI RAM enabled but initialization failed
MSPI Timing: tuning fail
```

Depending on the PSRAM mode and clock speed, the board either booted without
usable external RAM or entered watchdog-reset loops. Retro-Go then reported
that its requested `SPIRAM` capability was unavailable.

The key diagnosis was that the LCD was connected to GPIOs used by the board's
OPI PSRAM interface. This is especially important on N16R8 boards: a display
that works electrically in a simple SPI test can still prevent OPI PSRAM from
initializing when integrated into the complete firmware.

## The solution

The LCD was rewired away from the OPI PSRAM pins, and the target configuration
was updated to match:

| LCD signal | ESP32-S3 GPIO |
| ---------- | ------------: |
| SCK / CLK  |         GPIO3 |
| MOSI / SDA |        GPIO21 |
| MISO / SDO |        GPIO10 |
| CS         |         GPIO9 |
| DC / RS    |        GPIO47 |
| RESET      |        GPIO48 |

Do not connect the LCD or another external SPI device to GPIO33-GPIO37 on this
board. The relevant configuration is in
[`components/retro-go/targets/esp32-s3-handheld/config.h`](components/retro-go/targets/esp32-s3-handheld/config.h).

After rewiring, the boot log confirmed that PSRAM allocations were available,
the display initialized, and the timing warnings and watchdog resets stopped.
The Retro-Go launcher then loaded normally.

## Wiring

### LCD

| LCD signal | ESP32-S3 GPIO |
| ---------- | ------------: |
| SCK / CLK  |         GPIO3 |
| MOSI / SDA |        GPIO21 |
| MISO / SDO |        GPIO10 |
| CS         |         GPIO9 |
| DC / RS    |        GPIO47 |
| RESET      |        GPIO48 |

Power the LCD from 3.3 V.

### SD card

| SD signal | ESP32-S3 GPIO |
| --------- | ------------: |
| SCK / CLK |        GPIO17 |
| MOSI / DI |        GPIO18 |
| MISO / DO |         GPIO8 |
| CS        |        GPIO16 |

The current build uses the external SD module at `/sd`. Verify the module's
logic-level and power requirements before reproducing the 5 V supply used in
the original prototype.

### Controls and battery

The button GPIO mapping and battery ADC configuration are also defined in
[`config.h`](components/retro-go/targets/esp32-s3-handheld/config.h).

The Menu button goes between **GPIO13** and GND (the internal pull-up is enabled, like for the other
buttons). Pressing Start and Select together also works as Menu, so a console without the button is still
usable. Don't use GPIO14 for a button: it's the battery reading. The
current target has no dedicated audio hardware and uses the configured battery
voltage divider for voltage and percentage reporting.

## Build and flash

The target uses ESP-IDF 4.4.8. From the repository root:

```sh
source "$HOME/esp/esp-idf/export.sh"
python3 rg_tool.py --target esp32-s3-handheld --no-networking clean launcher
python3 rg_tool.py --target esp32-s3-handheld --no-networking build-img launcher
```

To build and flash the launcher and emulator applications:

```sh
python3 rg_tool.py --target esp32-s3-handheld \
  --port /dev/cu.wchusbserial5B910348501 --baud 921600 \
  --no-networking install
```

Replace the serial port with the one assigned to the board by macOS. The
project's [BUILDING.md](BUILDING.md) contains additional upstream build notes.

## Desktop preview (macOS)

The launcher and `retro-core` can run in a window on a Mac, with the same 480x320 screen and
buttons as the handheld. It's useful for UI and theme work without the device.

```sh
brew install sdl2
tools/build_sdl2_macos.sh            # build launcher + retro-core, then run
tools/build_sdl2_macos.sh launcher   # rebuild only the launcher, then run (faster for UI work)
tools/build_sdl2_macos.sh run        # run without rebuilding
SIZE=320x240 tools/build_sdl2_macos.sh   # preview another screen size (build again without SIZE for 480x320)
```

| Device button | Key       |
| ------------- | --------- |
| D-pad         | Arrows    |
| A / B         | X / Z     |
| X / Y         | S / A     |
| L / R         | Q / W     |
| Start         | Space     |
| Select        | Backspace |
| Menu          | Esc, or Space + Backspace (Start + Select) |

The emulated SD card is `./sd`. Put ROMs in `./sd/roms/<system>/`. `./sd/retro-go/themes`
links to this repository's `themes/` folder. The selected theme reloads by itself when one of its files
is saved, and Cmd+R (or F5) reloads it on demand (these developer keys are only in this desktop build). Logs
are written to `stdout.txt`. Setting `RG_SDL_SNAPSHOT=/path/file.bmp` saves the emulated
screen to that file whenever it changes. `RG_SDL_INPUT` plays back button presses for automated checks:
`RG_SDL_INPUT="1000:a,1200:,2000:start+select,2300:"` presses A at 1 s, releases it at 1.2 s, and so on.

The desktop target is
[`targets/sdl2-handheld`](components/retro-go/targets/sdl2-handheld/config.h). It reads pixels
in the same order as the device's ILI9488 driver, so the colors match what the device shows.
DOOM, Mega Drive and MSX aren't available on desktop.

## Themes

Themes go in `/retro-go/themes/<name>/` on the SD card and are selected in Options → Theme, which shows
a preview of each theme.

Besides images and colors (see [THEMING.md](THEMING.md)), a theme in this fork can include a
`theme.lua` script that redraws the launcher and the menus with its own layout, without rebuilding the
firmware. Themes can also bring their own font (`font.rgf`, made from a TTF with
`tools/make_theme_font.py`) and use PNG transparency. The included [`midnight`](themes/midnight/) theme
(adapted from the Recalbox theme by Benoit Bounar) and [`simplelight`](themes/simplelight/) theme (adapted
from the Recalbox theme by Nils Bonenberger and the Recalbox community) are examples. Copy the [`themes/`](themes/) folders to
the SD card to install them.

## Splash image

At power on and while a game loads, Retro-Go shows `/retro-go/splash.png` from the SD card, or a built-in
"RETRO-GO" image if there's none. Use any PNG: the best size is the screen's (480x320 on this handheld).
Other sizes are shrunk to fit without stretching and centered, and the rest of the screen gets the color
of the image's top left corner.

## Included emulators

- NES, SNES, Game Boy, Game Boy Color, Game & Watch, PC Engine, Lynx, SMS,
  Game Gear, and ColecoVision via `retro-core`
- DOOM via `prboom-go`
- Mega Drive / Genesis via `gwenesis`
- MSX via `fmsx`

In a game, a short press on Menu opens the game menu. Holding it for 2 seconds opens a quit menu
instead: **Resume game**, **Save & Quit** (pick a save slot, then back to the launcher) or **Quit** (back
to the launcher without saving, so the last save stays as it was). B also closes it.

The game speed set in a game's menu (Speed, 0.5x to 2.5x) is remembered for that game: it starts at
that speed next time. It's saved in `/retro-go/config/<game file name>.json`.

Game Boy games use the classic green DMG palette by default. For monochrome
GB titles, open the emulator's Options menu and change Palette to Pocket,
Light, or another available palette. GBC games use their cartridge color
data. Game Boy Advance (`.gba`) games are not supported by this build because
it does not include a GBA emulator.

Neo Geo is not included in this build. Original Metal Slug games therefore
cannot run without adding and integrating a separate arcade or Neo Geo core.

## SD card layout

Format the card as FAT32. Place legally obtained ROMs in the corresponding
folders, for example:

```text
/roms/nes/
/roms/snes/
/roms/gb/
/roms/gbc/
/roms/pce/
/roms/lynx/
/roms/sms/
/roms/gg/
/roms/col/
/roms/genesis/
/roms/msx/
/roms/doom/
```

BIOS files, when required, belong under `/retro-go/bios`. SNES games generally
do not require a BIOS. DOOM requires its legally obtained IWAD files, and MSX
systems may require BIOS files under `/retro-go/bios/msx/`.

## Troubleshooting

### Blank display with working backlight

1. Check that the LCD wiring matches the table above.
2. Confirm that GPIO33-GPIO37 are not connected to the LCD or another SPI device.
3. Confirm that `config.h` uses the same LCD pins and the ILI9488 target.
4. Capture the complete boot log. `PSRAM ID read error`, MSPI timing failures,
   or watchdog resets point to the PSRAM/pin conflict described above.

### SD mount failure

Check FAT32 formatting, power, chip select, and the SD wiring. A successful
boot with an empty card is different from a mount failure: once mounted,
Retro-Go loads its configuration from `/sd/retro-go/config/`.

### No games in the launcher

Install the emulator applications with `rg_tool.py ... install`, then copy
ROMs into the matching `/roms/` directories on the SD card.

## Repository relationship and license

This is an independent hardware customization of Retro-Go, maintained so the
ESP32-S3 handheld solution and its fixes can be reproduced. Upstream Retro-Go
and the included emulator components retain their original licenses. Review
the license files in this repository, including the additional terms for the
fMSX component, before redistribution.

Only use ROMs, BIOS files, and DOOM IWADs that you are legally entitled to use.
