#include <SDL2/SDL.h>

static SDL_Window *window;
static SDL_Surface *surface, *canvas;
static int win_left, win_top, win_width, win_height, cursor;
static uint16_t lcd_buffer[LCD_BUFFER_LENGTH];

#ifndef RG_SCREEN_SDL_SCALE
#define RG_SCREEN_SDL_SCALE 1 // Window size multiplier, the emulated screen keeps its real resolution
#endif

// Optional: RG_SDL_SNAPSHOT=<file.bmp> saves the emulated screen (at its real resolution) to that
// file whenever it changed, checked twice per second. Handy to inspect the UI without a screenshot tool.
static const char *snapshot_path;
static volatile bool snapshot_dirty;

static Uint32 snapshot_timer_cb(Uint32 interval, void *arg)
{
    if (snapshot_dirty)
    {
        snapshot_dirty = false;
        SDL_SaveBMP(canvas, snapshot_path);
    }
    return interval;
}

static void lcd_init(void)
{
    window = SDL_CreateWindow("Retro-Go", SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
                              RG_SCREEN_WIDTH * RG_SCREEN_SDL_SCALE, RG_SCREEN_HEIGHT * RG_SCREEN_SDL_SCALE, 0);
    surface = SDL_GetWindowSurface(window);
    canvas = SDL_CreateRGBSurfaceWithFormat(0, RG_SCREEN_WIDTH, RG_SCREEN_HEIGHT, 16, SDL_PIXELFORMAT_RGB565);
    snapshot_path = getenv("RG_SDL_SNAPSHOT");
    if (snapshot_path && snapshot_path[0])
        SDL_AddTimer(500, snapshot_timer_cb, NULL);
}

static void lcd_deinit(void)
{
}

static void lcd_set_window(int left, int top, int width, int height)
{
    int right = left + width - 1;
    int bottom = top + height - 1;
    if (left < 0 || top < 0 || right >= RG_SCREEN_WIDTH || bottom >= RG_SCREEN_HEIGHT)
        RG_LOGW("Bad lcd window (x0=%d, y0=%d, x1=%d, y1=%d)\n", left, top, right, bottom);
    win_left = left;
    win_top = top;
    win_width = width;
    win_height = height;
    cursor = 0;
}

static void lcd_set_backlight(float percent)
{
}

static inline uint16_t *lcd_get_buffer(size_t length)
{
    return lcd_buffer;
}

static inline void lcd_send_buffer(uint16_t *buffer, size_t length)
{
    int bpp = canvas->format->BytesPerPixel;
    int pitch = canvas->pitch;
    void *pixels = canvas->pixels;
    for (size_t i = 0; i < length; ++i) {
        int real_top = win_top + (cursor / win_width);
        int real_left = win_left + (cursor % win_width);
        if (real_top >= RG_SCREEN_HEIGHT || real_left >= RG_SCREEN_WIDTH)
            return;
        uint16_t *dst = (void*)pixels + (real_top * pitch) + (real_left * bpp);
        uint16_t pixel = buffer[i];
#if RG_SCREEN_SDL_NATIVE_ORDER
        *dst = pixel; // Same pixel order as the handheld's ILI9488 driver (see targets/sdl2-handheld)
#else
        *dst = ((pixel & 0xFF) << 8) | ((pixel & 0xFF00) >> 8);
#endif
        cursor++;
    }
}

static volatile bool present_pending;

// Copies the emulated screen to the window. Must run on the main thread (macOS requirement),
// it's called from rg_system_sdl2_pump() and directly by lcd_sync() when already on the main thread.
void rg_display_sdl2_present(void)
{
    if (!present_pending || !window)
        return;
    present_pending = false;
#if RG_SCREEN_SDL_SCALE != 1
    SDL_BlitScaled(canvas, NULL, surface, NULL);
#else
    SDL_BlitSurface(canvas, NULL, surface, NULL);
#endif
    SDL_UpdateWindowSurface(window);
}

static void lcd_sync(void)
{
    snapshot_dirty = true;
    present_pending = true;
    if (rg_system_sdl2_is_main_thread())
        rg_display_sdl2_present();
}

const rg_display_driver_t rg_display_driver_sdl2 = {
    .name = "sdl2",
};
