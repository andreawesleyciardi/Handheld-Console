#!/bin/bash
# Desktop preview of the handheld (480x320, same buttons) on macOS, using SDL2.
#
# Requirements: Xcode command line tools, and SDL2 (`brew install sdl2`).
#
# Usage (from anywhere):
#   tools/build_sdl2_macos.sh            build launcher + retro-core, then run
#   tools/build_sdl2_macos.sh build      build only
#   tools/build_sdl2_macos.sh launcher   rebuild only the launcher, then run (fast, for UI/theme work)
#   tools/build_sdl2_macos.sh run        run without building
#
# Other screen sizes (to test themes for other devices): SIZE=320x240 tools/build_sdl2_macos.sh
# The size is built into the programs: build again without SIZE to go back to 480x320.
#
# The emulated SD card is ./sd (git-ignored), created on the first run with the files in ./sdcard
# and empty test games from tools/sdl2-macos/test-roms. Put ROMs in ./sd/roms/<system>/.
# ./sd/retro-go/themes is a symlink to ./themes, so theme edits in the repo show up immediately.
#
# Keys: arrows = D-pad, X = A, Z = B, S = X, A = Y, Q = L, W = R,
#       Space = Start, Backspace = Select, Esc or Space+Backspace = Menu (same as the device).
#
# Only the launcher and retro-core (NES, SNES, GB/GBC, PCE, SMS/GG, Lynx, G&W, Coleco) run on desktop.

set -e
cd "$(dirname "$0")/.."

if ! command -v sdl2-config >/dev/null; then
    echo "SDL2 not found. Install it with: brew install sdl2" >&2
    exit 1
fi

SIZE_FLAGS=""
if [ -n "$SIZE" ]; then
    if ! [[ "$SIZE" =~ ^[0-9]+x[0-9]+$ ]]; then
        echo "SIZE must look like 320x240" >&2
        exit 1
    fi
    SIZE_FLAGS="-DRG_SDL_WIDTH=${SIZE%x*} -DRG_SDL_HEIGHT=${SIZE#*x}"
    echo "Screen size: $SIZE"
fi

CC="clang"
CFLAGS="-O2 -g -DRG_TARGET_SDL2 -DRG_TARGET_SDL2_HANDHELD -DRETRO_GO -DCJSON_HIDE_SYMBOLS -DSDL_MAIN_HANDLED=1 \
        -DRG_BUILD_INFO=\"SDL2-macOS\" -Dapp_main=SDL_Main -DRG_SDL_DEV_TOOLS $SIZE_FLAGS \
        -Wno-error=implicit-function-declaration -Wno-deprecated-declarations \
        $(sdl2-config --cflags) -I$(brew --prefix)/include -Itools/sdl2-macos/include"
INCLUDES="-Icomponents/retro-go -Icomponents/retro-go/libs/cJSON -Icomponents/retro-go/libs/lodepng -Icomponents/retro-go/libs/miniz"
SRCFILES="components/retro-go/*.c components/retro-go/drivers/audio/*.c components/retro-go/fonts/*.c
          components/retro-go/libs/cJSON/*.c components/retro-go/libs/lodepng/*.c components/retro-go/libs/miniz/*.c components/retro-go/libs/lua/*.c"
LIBS="$(sdl2-config --libs) -lc++"

build_launcher() {
    echo "Building launcher..."
    $CC $CFLAGS $INCLUDES -Ilauncher/main $SRCFILES launcher/main/*.c $LIBS -o launcher.exe
}

build_retro_core() {
    echo "Building retro-core..."
    local R=retro-core/components
    $CC $CFLAGS $INCLUDES \
        -I$R/gnuboy -I$R/gw-emulator/src -I$R/gw-emulator/src/cpus -I$R/gw-emulator/src/gw_sys \
        -I$R/handy -I$R/nofrendo -I$R/pce-go -I$R/snes9x -I$R/snes9x/src -I$R/smsplus -Iretro-core/main \
        $SRCFILES \
        $R/gnuboy/*.c $R/gw-emulator/src/*.c $R/gw-emulator/src/cpus/*.c $R/gw-emulator/src/gw_sys/*.c \
        $R/handy/*.cpp $R/nofrendo/mappers/*.c $R/nofrendo/nes/*.c $R/nofrendo/*.c $R/pce-go/*.c \
        $R/snes9x/src/*.c $R/smsplus/*.c $R/smsplus/cpu/*.c $R/smsplus/sound/*.c \
        retro-core/main/*.c retro-core/main/*.cpp \
        $LIBS -o retro-core.exe
}

prepare_sd() {
    mkdir -p sd/retro-go/config sd/retro-go/bios
    for system in nes snes gb gbc pce lnx sms gg col gw; do
        mkdir -p "sd/roms/$system"
    done
    if [ ! -e sd/retro-go/themes ]; then
        ln -s ../../themes sd/retro-go/themes
    fi
    # The SD card's starting files (splash image) and empty test games for the game list.
    # Existing files are kept, so a splash or game you replaced in ./sd isn't overwritten.
    rsync -r --ignore-existing sdcard/ sd/
    rsync -r --ignore-existing tools/sdl2-macos/test-roms/ sd/roms/
}

# On the device, switching app saves the next app in boot.json and reboots into another flash
# partition. On desktop each app is a separate executable that exits with code 1 to "reboot",
# so this loop relaunches the right one. BootName empty = launcher, anything else = retro-core.
run() {
    prepare_sd
    local app=launcher
    while true; do
        echo "=== Starting $app ==="
        set +e
        "./$app.exe"
        local code=$?
        set -e
        if [ $code -ne 1 ]; then
            echo "=== $app exited with code $code, stopping ==="
            break
        fi
        local boot_name
        boot_name=$(python3 -I -c 'import json,sys
try: print(json.load(open(sys.argv[1])).get("BootName") or "")
except Exception: print("")' sd/retro-go/config/boot.json)
        if [ -n "$boot_name" ]; then app=retro-core; else app=launcher; fi
    done
}

case "${1:-all}" in
    all)       build_launcher; build_retro_core; run ;;
    build)     build_launcher; build_retro_core ;;
    launcher)  build_launcher; run ;;
    run)       run ;;
    *)         echo "Usage: $0 [all|build|launcher|run]" >&2; exit 1 ;;
esac
