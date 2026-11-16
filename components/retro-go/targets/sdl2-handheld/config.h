// Desktop (SDL2) preview of the esp32-s3-handheld target.
// Mirrors the handheld's screen size and button set so the UI can be tested without the device.
// Built by tools/build_sdl2_macos.sh, selected with -DRG_TARGET_SDL2 -DRG_TARGET_SDL2_HANDHELD.
#define RG_TARGET_NAME             "SDL2-HANDHELD"

// Storage
#define RG_STORAGE_ROOT             "./sd"  // Storage mount point (relative to the working directory)

// Audio
#define RG_AUDIO_USE_INT_DAC        0
#define RG_AUDIO_USE_EXT_DAC        0
#define RG_AUDIO_USE_SDL2           1   // The device has no audio, but sound is handy when testing on desktop

// Video (same resolution as the ILI9488 on the device, unless SIZE is given to the build script)
#define RG_SCREEN_DRIVER            99
#define RG_SCREEN_HOST              0
#define RG_SCREEN_SPEED             0
#define RG_SCREEN_BACKLIGHT         1
// Other sizes can be previewed with SIZE=320x240 tools/build_sdl2_macos.sh (sets RG_SDL_WIDTH/HEIGHT)
#ifndef RG_SDL_WIDTH
#define RG_SDL_WIDTH                480
#define RG_SDL_HEIGHT               320
#endif
#define RG_SCREEN_WIDTH             RG_SDL_WIDTH
#define RG_SCREEN_HEIGHT            RG_SDL_HEIGHT
#define RG_SCREEN_ROTATE            0
#define RG_SCREEN_VISIBLE_AREA      {0, 0, 0, 0}
#define RG_SCREEN_SAFE_AREA         {0, 0, 0, 0}
#define RG_SCREEN_INIT()
#define RG_SCREEN_SDL_SCALE         2   // Window is twice the screen size (960x640) so it is readable on a laptop
#define RG_SCREEN_SDL_NATIVE_ORDER  0   // Big-endian pixels like every driver gets (the device's ILI9488 driver swaps them back too)

// Input: the same buttons as the device. MENU is Esc (the device's Menu button) or Start+Select
// (Space + Backspace). Holding it for 2 seconds in a game opens the quit menu.
#define RG_GAMEPAD_KBD_MAP {\
    {RG_KEY_UP,     SDL_SCANCODE_UP},\
    {RG_KEY_RIGHT,  SDL_SCANCODE_RIGHT},\
    {RG_KEY_DOWN,   SDL_SCANCODE_DOWN},\
    {RG_KEY_LEFT,   SDL_SCANCODE_LEFT},\
    {RG_KEY_SELECT, SDL_SCANCODE_BACKSPACE},\
    {RG_KEY_START,  SDL_SCANCODE_SPACE},\
    {RG_KEY_A,      SDL_SCANCODE_X},\
    {RG_KEY_B,      SDL_SCANCODE_Z},\
    {RG_KEY_X,      SDL_SCANCODE_S},\
    {RG_KEY_Y,      SDL_SCANCODE_A},\
    {RG_KEY_L,      SDL_SCANCODE_Q},\
    {RG_KEY_R,      SDL_SCANCODE_W},\
    {RG_KEY_MENU,   SDL_SCANCODE_ESCAPE},\
}

#define RG_GAMEPAD_VIRT_MAP {\
    {RG_KEY_MENU,   .src = RG_KEY_START | RG_KEY_SELECT},\
}

#if !defined(__VERSION__) && defined(__TINYC__)
#define __VERSION__ "TinyC"
#endif

#undef app_main
#define app_main(...) main(int argc, char **argv)
