# Waveshare ESP32-S3 Handheld

This target ports Retro-Go 1.46 to the Waveshare ESP32-S3-DEV-KIT-N16R8-M with:

- 16 MB flash and 8 MB OPI PSRAM
- DFRobot Fermion DFR0669 ILI9488, 480x320
- SPI micro-SD card
- 12 GPIO buttons
- Battery voltage divider

## Important OPI PSRAM pin constraint

ESP32-S3 N16R8 boards use GPIO33-37 for OPI PSRAM. Do not connect the LCD to those pins. Doing so can cause `PSRAM ID read error`, MSPI timing failures, and watchdog resets.

### LCD wiring

| LCD signal | ESP32-S3 GPIO |
| --- | ---: |
| SCK / CLK | GPIO3 |
| MOSI / SDA | GPIO21 |
| MISO / SDO | GPIO10 |
| CS | GPIO9 |
| DC / RS | GPIO47 |
| RESET | GPIO48 |

### SD wiring

| SD signal | ESP32-S3 GPIO |
| --- | ---: |
| SCK / CLK | GPIO17 |
| MOSI / DI | GPIO18 |
| MISO / DO | GPIO8 |
| CS | GPIO16 |

The SD module is powered from 5 V in this build. The LCD is powered from 3.3 V.

## Build and flash

Use ESP-IDF 4.4.8 and source its environment before running Retro-Go tools:

```sh
source "$HOME/esp/esp-idf/export.sh"
python3 rg_tool.py --target esp32-s3-handheld --no-networking clean launcher
python3 rg_tool.py --target esp32-s3-handheld --no-networking build-img launcher
```

To build and flash all emulator applications:

```sh
python3 rg_tool.py --target esp32-s3-handheld \
  --port /dev/cu.wchusbserial5B910348501 --baud 921600 \
  --no-networking install
```

The installed applications are:

- `retro-core`: NES, SNES, Game Boy, Game Boy Color, Game & Watch, PC Engine, Lynx, SMS, Game Gear, and ColecoVision
- `prboom-go`: DOOM
- `gwenesis`: Mega Drive / Genesis
- `fmsx`: MSX

## ROMs and BIOS files

Retro-Go mounts the FAT32 SD card at `/sd`. Put ROMs under `/roms`, for example:

```text
/roms/nes/
/roms/snes/
/roms/gb/
/roms/gbc/
/roms/genesis/
/roms/doom/
/roms/msx/
```

ZIP files should contain exactly one ROM. BIOS locations documented by Retro-Go include:

```text
/retro-go/bios/gb_bios.bin
/retro-go/bios/gbc_bios.bin
/retro-go/bios/fds_bios.bin
/retro-go/bios/msx/
```

Only use ROMs and BIOS files that you are legally entitled to use. Metal Slug is a Neo Geo arcade title; this target does not include a Neo Geo emulator.

## Troubleshooting

If PSRAM fails, check that no external wiring uses GPIO33-37 and that the target config has OPI PSRAM enabled. If storage fails, check FAT32 formatting and the SD wiring above. The standalone `sd_only` project in the parent workspace was used to validate the SD and LCD wiring before integration.
