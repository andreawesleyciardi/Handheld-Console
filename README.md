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
- 12 GPIO buttons and a battery voltage divider

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

The 12-button GPIO mapping and battery ADC configuration are also defined in
[`config.h`](components/retro-go/targets/esp32-s3-handheld/config.h). The
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

## Included emulators

- NES, SNES, Game Boy, Game Boy Color, Game & Watch, PC Engine, Lynx, SMS,
  Game Gear, and ColecoVision via `retro-core`
- DOOM via `prboom-go`
- Mega Drive / Genesis via `gwenesis`
- MSX via `fmsx`

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
