# AI Project Context

This repository is a custom Retro-Go firmware project for a DIY ESP32-S3 handheld. Use this file as the compact technical context when asking an AI to modify, build, debug, or flash the project.

## Project identity

- Repository root: this directory.
- Main target: `esp32-s3-handheld`.
- Board: Waveshare ESP32-S3-DEV-KIT-N16R8-M.
- MCU: ESP32-S3 with 16 MB flash and 8 MB OPI PSRAM.
- Framework: ESP-IDF 4.4.8 is the known-good version for this target.
- Build system: `rg_tool.py` orchestrates ESP-IDF builds, application partitions, firmware images, and flashing.
- Display: DFRobot DFR0669 ILI9488, 480x320, SPI at 40 MHz, BGR color order.
- Storage: external SPI micro-SD card mounted at `/sd`, SPI at 20 MHz (`SDMMC_FREQ_DEFAULT`). It was 1 MHz until 2026-11-16, which made theme images take 2-3 s per screen.
- Audio: the target currently has no installed DAC and audio is disabled, but a UDA1334A I2S DAC module has now arrived for the planned audio upgrade.
- Compact-board experiment: an ESP32-S3-N16R8 Mini Type-C development board has also arrived as a possible replacement for the larger Waveshare board.

## Non-negotiable hardware constraints

Do not use GPIO33-GPIO37 for LCD or other external wiring. These pins are used by the ESP32-S3 N16R8 OPI PSRAM interface. Conflicts can cause PSRAM initialization failures, MSPI timing failures, watchdog resets, or a blank display.

Current LCD wiring:

| Signal         | GPIO |
| -------------- | ---: |
| LCD SCK / CLK  |    3 |
| LCD MOSI / SDA |   21 |
| LCD MISO / SDO |   10 |
| LCD CS         |    9 |
| LCD DC / RS    |   47 |
| LCD RESET      |   48 |

Current SD wiring:

| Signal       | GPIO |
| ------------ | ---: |
| SD SCK / CLK |   17 |
| SD MOSI / DI |   18 |
| SD MISO / DO |    8 |
| SD CS        |   16 |

Current controls are defined in `components/retro-go/targets/esp32-s3-handheld/config.h`:

- L: GPIO1
- R: GPIO4
- X: GPIO5
- Y: GPIO6
- A: GPIO7
- B: GPIO15
- Start: GPIO12
- Select: GPIO11
- Up: GPIO2
- Down: GPIO42
- Right: GPIO41
- Left: GPIO40
- Menu: GPIO0 (the board's BOOT pin; the Menu button is wired in parallel with the BOOT button). Holding it at power-on enters download mode, which is harmless.
- Start + Select is also mapped to Menu, but only when both are pressed at the same moment; alone, Start and Select switch launcher tabs.
- Do not use GPIO13 for a button; it drives the LED stick.
- GPIO39 is the joystick center press (MID); not mapped, to avoid opening the menu by accident.
- Do not use GPIO38: it reads low on this board even with nothing connected. Mapping Menu there made Retro-Go see Menu held at boot and loop into recovery mode (hourglass on screen).
- No other free pins are suitable for buttons: 45/46 are strapping pins, 43/44 are the flashing UART, 19/20 are USB.
- Do not use GPIO14 for a button; it is reserved for battery ADC input.

The target battery reading is an ADC estimate, not a fuel gauge. It assumes ADC2 channel 3, a 2:1 voltage divider, and a 3.2 V to 4.2 V LiPo range. Verify the divider and calibrate against a multimeter before describing the percentage as accurate.

## Newly arrived hardware and planned use

Two parts were purchased to make the final handheld smaller and restore audio:

1. **UDA1334A stereo I2S DAC module**
   Product reference: [AliExpress UDA1334A module](https://www.aliexpress.com/item/1005012023315078.html)

   The ESP32-S3 has no internal analog DAC, which is why the current target sets
   `RG_AUDIO_USE_INT_DAC` and `RG_AUDIO_USE_EXT_DAC` to `0`. The UDA1334A converts
   the ESP32-S3's digital I2S stream into stereo analog audio. It is intended to
   be connected as an external DAC, not to the LCD or SD SPI buses.

   The existing Retro-Go I2S driver already supports the required mode. When
   enabled, it uses I2S master transmit with:
   - BCLK / BCK: ESP32-S3 output to DAC BCLK
   - WS / LRCLK: ESP32-S3 output to DAC word-select/LRCK
   - DATA / DIN: ESP32-S3 output to DAC serial data input
   - GND: common ground
   - VCC: use the module's documented supply voltage; prefer 3.3 V for a 3.3 V ESP32 logic system unless the received board's documentation confirms otherwise

   Do not connect a bare speaker directly to the UDA1334A analog outputs. The
   DAC output normally needs a headphone amplifier or speaker power amplifier
   before driving a passive speaker. Confirm the module's actual output
   connector and voltage levels before final case wiring.

   The firmware work for this upgrade will be target-specific:
   - Set `RG_AUDIO_USE_EXT_DAC` to `1` in the active target config.
   - Define `RG_GPIO_SND_I2S_BCK`, `RG_GPIO_SND_I2S_WS`, and `RG_GPIO_SND_I2S_DATA`.
   - Choose GPIOs that are not used by the LCD, SD, buttons, battery ADC, USB,
     boot strapping, or the mini board's flash/PSRAM interface.
   - Leave `RG_AUDIO_USE_INT_DAC` at `0`; ESP32-S3 does not have the original
     ESP32 internal DAC.
   - Build first, then test the `Ext DAC` audio sink at low volume with an
     amplifier or powered headphones.

2. **ESP32-S3-N16R8 Mini Type-C development board**
   Product reference: [AliExpress ESP32-S3-N16R8 Mini board](https://www.aliexpress.com/item/1005013073195353.html)

   This board was selected as a smaller physical replacement for the current
   Waveshare ESP32-S3-DEV-KIT-N16R8-M, while retaining the important advertised
   characteristics: ESP32-S3, 16 MB flash, 8 MB OPI PSRAM, Wi-Fi/Bluetooth, and
   USB-C. The goal is to use the reduced board size to make the 3D-printed case
   smaller and give more freedom to place the LCD, joystick, DAC, battery, and
   controls.

   The mini board is not automatically pin-compatible with the current target.
   Before replacing the board in the case or firmware:
   - Identify the exact board revision and compare its printed pin labels with
     the seller's pinout/manual.
   - Confirm that GPIO33-GPIO37 remain reserved by the N16R8 OPI PSRAM design.
   - Remap LCD, SD, buttons, battery ADC, and future I2S pins from the verified
     mini-board pinout; never copy the current GPIO numbers blindly.
   - Check boot strapping pins, USB D+/D-, power input, 3.3 V output capacity,
     reset/boot buttons, antenna clearance, and battery/charger circuitry.
   - Confirm that the board really contains 8 MB OPI PSRAM before relying on
     the current memory configuration.

   The migration should be staged: first power and identify the mini board,
   then run a minimal ESP32-S3/PSRAM test, then validate the LCD and SD, then
   connect controls and battery, and only after that enable the UDA1334A audio
   path. Keep the existing Waveshare pin configuration as a known-good
   reference until the new board passes each stage.

## Repository structure

- `components/retro-go/`: shared Retro-Go GUI, display, input, storage, settings, and system code.
- `components/retro-go/targets/esp32-s3-handheld/`: target-specific pins, display setup, battery formula, and `sdkconfig` defaults.
- `launcher/`: launcher application.
- `retro-core/`: bundled NES, SNES, Game Boy, Game Boy Color, Game & Watch, PC Engine, Lynx, SMS, Game Gear, and ColecoVision cores.
- `prboom-go/`: DOOM application.
- `gwenesis/`: Mega Drive / Genesis application.
- `fmsx/`: MSX application.
- `themes/`: runtime SD-card themes. Theme files are not automatically embedded in the flashed firmware.
- `tools/`: image, font, release, and build helper scripts.
- `partitions.csv`: generated/used by the build orchestration; do not treat it as the source of target pin configuration.

## Required build workflow on macOS

Run all commands from the repository root. Start a fresh shell with ESP-IDF 4.4.8 exported:

```sh
source "$HOME/esp/esp-idf/export.sh"
```

Clean and build only the launcher image:

```sh
python3 rg_tool.py --target esp32-s3-handheld --no-networking clean launcher
python3 rg_tool.py --target esp32-s3-handheld --no-networking build-img launcher
```

Build and flash the complete handheld image:

```sh
python3 rg_tool.py \
  --target esp32-s3-handheld \
  --port /dev/cu.wchusbserial5B910348501 \
  --baud 921600 \
  --no-networking install
```

The usual serial port used with this handheld is
`/dev/cu.wchusbserial5B910348501`, at `921600` baud. Replace it if macOS
assigns the board a different port; check with `ls /dev/cu.*` after connecting
the board. The `install` command builds the selected applications, creates an
ESP32 image, writes it at flash offset `0x0`, verifies the hash, and hard-resets
the board. The default application set is `launcher retro-core prboom-go
gwenesis fmsx`.

For a smaller build, specify applications after the command, for example:

```sh
python3 rg_tool.py --target esp32-s3-handheld --no-networking build-img launcher
```

Use `python3 rg_tool.py --help` for all commands. `idf.py` alone is not sufficient for the normal workflow because the project contains multiple application partitions.

Build and flash caveats found on the device:

- Never pass a port other than the handheld's. `/dev/cu.usbmodem143243101` is a laser machine: never open, probe, or flash it, and never let esptool auto-detect a port.
- The ESP32 compiler (GCC 8.4) turns some warnings into errors that the macOS desktop build does not report (for example `-Werror=format-truncation`). Code that builds in the desktop preview can still fail here, so build for `esp32-s3-handheld` before flashing.
- With the Lua theme scripts, retro-core, prboom-go, gwenesis and fmsx are larger than the sizes in `PROJECT_APPS`. `mkfw.py` enlarges their partitions in the full image (the "File larger than partition" warnings), so `install` works. Flashing a single app (`rg_tool.py flash <app>`) is only safe on a device that already has the current full image.
- Any change to the target `sdkconfig` needs `rg_tool.py clean` (or `release`) first.
- During flashing the display keeps its last picture, so the console looks frozen until "Hard resetting via RTS pin". Do not unplug it before that.
- The boot log is on the same port at 115200 baud. The firmware prints a `STACK:... HEAP:... FPS:...` line every second; `STACK` is the free main-task stack in bytes (about 2.5 KB with the midnight theme, of 8 KB).

## Validation and troubleshooting

After changing C or target configuration, run the narrowest relevant build first. For launcher changes:

```sh
python3 rg_tool.py --target esp32-s3-handheld --no-networking build-img launcher
```

For a full firmware change, use `install` only when hardware validation is required. Do not flash merely to validate JSON or source syntax.

For a blank LCD with the backlight on:

1. Check LCD wiring against the table above.
2. Check that GPIO33-GPIO37 are unused externally.
3. Check the ILI9488 target and display configuration.
4. Look for `PSRAM ID read error`, MSPI timing failures, or watchdog resets in the boot log.

For SD failures, check FAT32 formatting, module power and logic levels, chip select, and the SPI wiring. Retro-Go expects ROMs under `/sd/roms/` and configuration/themes under `/sd/retro-go/`.

Display colors use numeric RGB565 values. Keep numeric pixel format and byte order conceptually separate; the ILI9488 target uses BGR channel order. Validate color changes with the existing display calibration behavior before changing unrelated surface or emulator formats.

## Runtime SD layout

```text
/sd/roms/nes/
/sd/roms/snes/
/sd/roms/gb/
/sd/roms/gbc/
/sd/roms/pce/
/sd/roms/lynx/
/sd/roms/sms/
/sd/roms/gg/
/sd/roms/col/
/sd/roms/genesis/
/sd/roms/msx/
/sd/roms/doom/
/sd/retro-go/bios/
/sd/retro-go/themes/<theme-name>/
```

Only use ROMs, BIOS files, and DOOM IWADs for which the user has legal rights.

## Theme and launcher model

Themes are loaded at runtime from `/sd/retro-go/themes/<theme-name>/`. A firmware flash does not copy the repository `themes/` directory to the SD card. The default theme is selected by the global Retro-Go setting; the source fallback is `default`.

The launcher supports theme images such as `background_<tab>.png`, `logo_<tab>.png`, and `banner_<tab>.png`, plus previews and color sections in `theme.json`. Themes can also include `theme.lua` (Lua 5.4) to redraw the launcher and menus with their own layout, a `font.rgf`, PNG transparency and `<W>x<H>/` folders per screen size; see `THEMING.md`. Theme changes can be previewed on macOS with `tools/build_sdl2_macos.sh`, but always confirm on the device: the SD card is far slower than the Mac's disk.

Theme scripts are aborted if one call takes over 3 s of Lua time (SD reads of images and fonts don't count). The launcher keeps up to 5 MB of decoded theme images in PSRAM (256 KB in games).

- `midnight`: scripted theme adapted from the Recalbox theme by Benoit Bounar. Verified on the device on 2026-11-16 (it is the active theme on the SD card).
- `simplelight`: scripted light theme adapted from the Recalbox theme by Nils Bonenberger and the Recalbox community.
- `b-m` (untracked): early Bounitos Midnight adaptation, colors only.

## Working rules for AI changes

- Inspect the target-specific config before changing pins, display behavior, ADC behavior, or memory settings.
- Preserve the OPI PSRAM pin constraint.
- Prefer the existing Retro-Go helpers and local patterns over new abstractions.
- Keep changes scoped; do not rewrite unrelated theme, emulator, or generated files.
- Build the smallest affected application immediately after the first code edit.
- Do not commit, push, or flash unless the user explicitly asks.
- Treat existing uncommitted changes as user work; inspect and preserve them.
- When reporting a build or flash, include the exact target, applications, serial port, baud rate, and whether the operation completed successfully.
