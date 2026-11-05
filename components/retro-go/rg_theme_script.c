// Theme scripts: lets a theme replace drawing functions with Lua code (theme.lua in the theme folder).
// The scripting API exposed to themes is documented in THEMING.md.
#include "rg_system.h"
#include "rg_theme_script.h"
#include "libs/lua/lualib.h"

#include <stdlib.h>
#include <string.h>

#ifdef ESP_PLATFORM
#include <esp_heap_caps.h>
#endif

#define SCRIPT_FILENAME     "theme.lua"
#define MEMORY_LIMIT        (1024 * 1024)       // A runaway script fails instead of exhausting memory
#define TIME_LIMIT_US       (3 * 1000 * 1000)   // A single call taking longer than this is aborted
#define MAX_REGISTERED      16
#define MAX_CACHED_IMAGES   64
#define MAX_CACHED_FONTS    8
#define IMAGE_CACHE_BUDGET  (2 * 1024 * 1024) // Bytes of decoded images kept; least recently used go first
#define IMAGE_CACHE_BUDGET_INGAME (256 * 1024) // In games, where emulators need the memory (only menus are themed)

static struct
{
    lua_State *L;
    size_t mem_used;
    int64_t call_deadline;
    bool busy;
    char theme_path[RG_PATH_MAX];
    struct
    {
        char name[64];
        rg_image_t *img; // NULL = file missing (cached too, to avoid hitting the SD card on every redraw)
        size_t bytes;
        uint32_t last_used;
    } images[MAX_CACHED_IMAGES];
    size_t images_bytes;
    uint32_t images_clock;
    struct
    {
        char name[64];
        rg_font_t *font; // NULL = file missing or invalid (cached too)
    } fonts[MAX_CACHED_FONTS];
    struct
    {
        const char *name;
        lua_CFunction func;
    } registered[MAX_REGISTERED];
    size_t registered_count;
} script;

// Memory for the Lua state goes to PSRAM when available, internal RAM is precious.
static void *script_alloc(void *ud, void *ptr, size_t osize, size_t nsize)
{
    size_t old_size = ptr ? osize : 0; // When ptr is NULL, osize is a type tag, not a size

    if (nsize == 0)
    {
        free(ptr);
        script.mem_used -= old_size;
        return NULL;
    }

    // Lua expects shrinking to never fail, so the limit only applies when growing
    if (nsize > old_size && script.mem_used - old_size + nsize > MEMORY_LIMIT)
        return NULL;

    void *new_ptr = NULL;
#ifdef ESP_PLATFORM
    new_ptr = heap_caps_realloc(ptr, nsize, MALLOC_CAP_SPIRAM | MALLOC_CAP_8BIT);
#endif
    if (!new_ptr)
        new_ptr = realloc(ptr, nsize);
    if (new_ptr)
        script.mem_used = script.mem_used - old_size + nsize;
    return new_ptr;
}

static void script_watchdog(lua_State *L, lua_Debug *ar)
{
    if (rg_system_timer() > script.call_deadline)
        luaL_error(L, "script took too long (infinite loop?)");
}

static int check_int(lua_State *L, int idx)
{
    return (int)luaL_checknumber(L, idx);
}

static int opt_int(lua_State *L, int idx, int def)
{
    return (int)luaL_optnumber(L, idx, def);
}

static rg_color_t rgb_to_color(int r, int g, int b)
{
    return ((r & 0xF8) << 8) | ((g & 0xFC) << 3) | ((b & 0xF8) >> 3);
}

// Colors are RGB565 numbers, or strings: "#RRGGBB", "transparent", "none".
static rg_color_t to_color(lua_State *L, int idx, rg_color_t def)
{
    int type = lua_type(L, idx);
    if (type == LUA_TNONE || type == LUA_TNIL)
        return def;
    if (type == LUA_TNUMBER)
        return (rg_color_t)lua_tointeger(L, idx);
    const char *str = luaL_checkstring(L, idx);
    if (strcmp(str, "transparent") == 0)
        return C_TRANSPARENT;
    if (strcmp(str, "none") == 0)
        return C_NONE;
    if (str[0] == '#' && strlen(str) == 7)
    {
        unsigned long rgb = strtoul(str + 1, NULL, 16);
        return rgb_to_color((rgb >> 16) & 0xFF, (rgb >> 8) & 0xFF, rgb & 0xFF);
    }
    return luaL_error(L, "invalid color '%s' (use rg.rgb(), \"#RRGGBB\", \"transparent\" or \"none\")", str);
}

static void free_cached_image(size_t i)
{
    rg_surface_free(script.images[i].img);
    script.images_bytes -= script.images[i].bytes;
    script.images[i].img = NULL;
    script.images[i].bytes = 0;
    script.images[i].name[0] = 0;
}

static rg_image_t *get_cached_image(lua_State *L, const char *name)
{
    if (strstr(name, "..") || name[0] == '/')
        luaL_error(L, "image '%s': only files inside the theme folder can be used", name);

    for (size_t i = 0; i < MAX_CACHED_IMAGES; ++i)
    {
        if (script.images[i].name[0] && strcmp(script.images[i].name, name) == 0)
        {
            script.images[i].last_used = ++script.images_clock;
            return script.images[i].img;
        }
    }

    char path[RG_PATH_MAX];
    rg_gui_theme_file_path(script.theme_path, name, path, sizeof(path));
    rg_image_t *img = rg_surface_load_image_file(path, 0);
    if (!img)
        RG_LOGW("Theme image not found: '%s'", path);
    size_t bytes = img ? (size_t)img->width * img->height * (img->alpha ? 3 : 2) : 0;

    // Make room: a free slot, and stay under the memory budget. Least recently used images go first.
    while (true)
    {
        size_t free_slot = MAX_CACHED_IMAGES, oldest = MAX_CACHED_IMAGES;
        for (size_t i = 0; i < MAX_CACHED_IMAGES; ++i)
        {
            if (!script.images[i].name[0])
                free_slot = (free_slot == MAX_CACHED_IMAGES) ? i : free_slot;
            else if (oldest == MAX_CACHED_IMAGES || script.images[i].last_used < script.images[oldest].last_used)
                oldest = i;
        }
        size_t budget = rg_system_get_app()->isLauncher ? IMAGE_CACHE_BUDGET : IMAGE_CACHE_BUDGET_INGAME;
        if (free_slot != MAX_CACHED_IMAGES && (script.images_bytes + bytes <= budget || oldest == MAX_CACHED_IMAGES))
        {
            snprintf(script.images[free_slot].name, sizeof(script.images[free_slot].name), "%s", name);
            script.images[free_slot].img = img;
            script.images[free_slot].bytes = bytes;
            script.images[free_slot].last_used = ++script.images_clock;
            script.images_bytes += bytes;
            return img;
        }
        free_cached_image(oldest);
    }
}

// An image argument is either a handle given to the script by the app, or a file name in the theme folder.
static rg_image_t *to_image(lua_State *L, int idx)
{
    if (lua_islightuserdata(L, idx))
        return lua_touserdata(L, idx);
    if (lua_isnoneornil(L, idx))
        return NULL;
    return get_cached_image(L, luaL_checkstring(L, idx));
}

// Font files (.rgf) from the theme folder, for the `font` text option
static const rg_font_t *get_cached_font(lua_State *L, const char *name)
{
    if (strstr(name, "..") || name[0] == '/')
        luaL_error(L, "font '%s': only files inside the theme folder can be used", name);

    for (size_t i = 0; i < MAX_CACHED_FONTS; ++i)
    {
        if (script.fonts[i].name[0] && strcmp(script.fonts[i].name, name) == 0)
            return script.fonts[i].font;
    }
    for (size_t i = 0; i < MAX_CACHED_FONTS; ++i)
    {
        if (script.fonts[i].name[0] == 0)
        {
            char path[RG_PATH_MAX];
            rg_gui_theme_file_path(script.theme_path, name, path, sizeof(path));
            snprintf(script.fonts[i].name, sizeof(script.fonts[i].name), "%s", name);
            script.fonts[i].font = rg_gui_load_font_file(path);
            if (!script.fonts[i].font)
                RG_LOGW("Theme font not found or invalid: '%s'", path);
            return script.fonts[i].font;
        }
    }
    return luaL_error(L, "too many fonts (%d max)", MAX_CACHED_FONTS), NULL;
}

// Text options table: {color=, bg=, width=, align="left"|"center"|"right", big=, mono=, multiline=, padding=, font=}
// font is a .rgf file in the theme folder, NULL = the normal font. Call rg_gui_set_text_font(font) around drawing.
static uint32_t to_text_options(lua_State *L, int idx, rg_color_t *fg, rg_color_t *bg, int *width,
                                const rg_font_t **font)
{
    uint32_t flags = 0;
    *fg = C_WHITE;
    *bg = C_TRANSPARENT;
    *width = 0;
    *font = NULL;

    if (lua_isnoneornil(L, idx))
        return flags;
    luaL_checktype(L, idx, LUA_TTABLE);

    lua_getfield(L, idx, "font");
    if (!lua_isnil(L, -1))
        *font = get_cached_font(L, luaL_checkstring(L, -1));
    lua_pop(L, 1);

    lua_getfield(L, idx, "color");
    *fg = to_color(L, -1, C_WHITE);
    lua_getfield(L, idx, "bg");
    *bg = to_color(L, -1, C_TRANSPARENT);
    lua_getfield(L, idx, "width");
    *width = (int)luaL_optnumber(L, -1, 0);
    lua_getfield(L, idx, "align");
    const char *align = luaL_optstring(L, -1, "left");
    if (strcmp(align, "center") == 0)
        flags |= RG_TEXT_ALIGN_CENTER;
    else if (strcmp(align, "right") == 0)
        flags |= RG_TEXT_ALIGN_RIGHT;
    else
        flags |= RG_TEXT_ALIGN_LEFT;
    lua_getfield(L, idx, "big");
    if (lua_toboolean(L, -1))
        flags |= RG_TEXT_BIGGER;
    lua_getfield(L, idx, "mono");
    if (lua_toboolean(L, -1))
        flags |= RG_TEXT_MONOSPACE;
    lua_getfield(L, idx, "multiline");
    if (lua_toboolean(L, -1))
        flags |= RG_TEXT_MULTILINE;
    lua_getfield(L, idx, "padding");
    if (lua_isboolean(L, -1) && !lua_toboolean(L, -1))
        flags |= RG_TEXT_NO_PADDING;
    lua_pop(L, 8);

    return flags;
}

// rg.rect(x, y, w, h, fill [, border_width, border_color])
static int api_rect(lua_State *L)
{
    rg_gui_draw_rect(check_int(L, 1), check_int(L, 2), check_int(L, 3), check_int(L, 4), opt_int(L, 6, 0),
                     to_color(L, 7, C_NONE), to_color(L, 5, C_NONE));
    return 0;
}

// w, h = rg.text(x, y, text [, options])
static int api_text(lua_State *L)
{
    rg_color_t fg, bg;
    int width;
    const rg_font_t *font;
    uint32_t flags = to_text_options(L, 4, &fg, &bg, &width, &font);
    int x = check_int(L, 1), y = check_int(L, 2);
    const char *text = luaL_checkstring(L, 3);
    int scroll = 0;
    if (lua_istable(L, 4))
    {
        lua_getfield(L, 4, "scroll");
        scroll = (int)luaL_optinteger(L, -1, 0);
        lua_pop(L, 1);
    }
    rg_gui_set_text_font(font); // Nothing below can raise a Lua error, so these are always reset
    rg_gui_set_text_scroll(scroll);
    rg_rect_t rect = rg_gui_draw_text(x, y, width, text, fg, bg, flags);
    rg_gui_set_text_scroll(0);
    rg_gui_set_text_font(NULL);
    lua_pushinteger(L, rect.width);
    lua_pushinteger(L, rect.height);
    return 2;
}

// w, h = rg.measure(text [, options])
static int api_measure(lua_State *L)
{
    rg_color_t fg, bg;
    int width;
    const rg_font_t *font;
    uint32_t flags = to_text_options(L, 2, &fg, &bg, &width, &font);
    const char *text = luaL_checkstring(L, 1);
    rg_gui_set_text_font(font);
    rg_rect_t rect = rg_gui_draw_text(0, 0, width, text, fg, bg, flags | RG_TEXT_DUMMY_DRAW);
    rg_gui_set_text_font(NULL);
    lua_pushinteger(L, rect.width);
    lua_pushinteger(L, rect.height);
    return 2;
}

// h = rg.line_height([options])
static int api_line_height(lua_State *L)
{
    rg_color_t fg, bg;
    int width;
    const rg_font_t *font;
    uint32_t flags = to_text_options(L, 1, &fg, &bg, &width, &font);
    rg_gui_set_text_font(font);
    int height = rg_gui_draw_text(0, 0, 0, "Ag", fg, bg, flags | RG_TEXT_DUMMY_DRAW).height;
    rg_gui_set_text_font(NULL);
    lua_pushinteger(L, height);
    return 1;
}

// w, h = rg.image(image, x, y [, w, h])   (returns nothing and draws nothing if the image is missing)
static int api_image(lua_State *L)
{
    const rg_image_t *img = to_image(L, 1);
    if (!img)
        return 0;
    int width = opt_int(L, 4, 0), height = opt_int(L, 5, 0);
    bool resample = width && height && (width != img->width || height != img->height);
    rg_gui_draw_image(check_int(L, 2), check_int(L, 3), width, height, resample, img);
    lua_pushinteger(L, img->width);
    lua_pushinteger(L, img->height);
    return 2;
}

// w, h = rg.image_size(image)   (nil if the image is missing)
static int api_image_size(lua_State *L)
{
    const rg_image_t *img = to_image(L, 1);
    if (!img)
        return 0;
    lua_pushinteger(L, img->width);
    lua_pushinteger(L, img->height);
    return 2;
}

// color = rg.rgb(r, g, b)   (0-255 each)
static int api_rgb(lua_State *L)
{
    lua_pushinteger(L, rgb_to_color(check_int(L, 1), check_int(L, 2), check_int(L, 3)));
    return 1;
}

// color = rg.theme_color(section, key [, default])   (reads theme.json)
static int api_theme_color(lua_State *L)
{
    rg_color_t def = to_color(L, 3, C_WHITE);
    lua_pushinteger(L, rg_gui_get_theme_color(luaL_checkstring(L, 1), luaL_checkstring(L, 2), def));
    return 1;
}

// rg.status_icons()   (battery, network, etc, as drawn by Retro-Go in the top right corner)
static int api_status_icons(lua_State *L)
{
    rg_gui_draw_icons();
    return 0;
}

// ms = rg.time_ms()
static int api_time_ms(lua_State *L)
{
    lua_pushinteger(L, rg_system_timer() / 1000);
    return 1;
}

// print(...) / rg.log(...) write to the Retro-Go log
static int api_log(lua_State *L)
{
    luaL_Buffer buffer;
    luaL_buffinit(L, &buffer);
    for (int i = 1, n = lua_gettop(L); i <= n; i++)
    {
        if (i > 1)
            luaL_addchar(&buffer, ' ');
        luaL_tolstring(L, i, NULL);
        luaL_addvalue(&buffer);
    }
    luaL_pushresult(&buffer);
    RG_LOGI("[theme.lua] %s", lua_tostring(L, -1));
    return 0;
}

static const luaL_Reg api_functions[] = {
    {"rect", api_rect},
    {"text", api_text},
    {"measure", api_measure},
    {"line_height", api_line_height},
    {"image", api_image},
    {"image_size", api_image_size},
    {"rgb", api_rgb},
    {"theme_color", api_theme_color},
    {"status_icons", api_status_icons},
    {"time_ms", api_time_ms},
    {"log", api_log},
    {NULL, NULL},
};

static void push_api_table(lua_State *L)
{
    luaL_newlib(L, api_functions);

    for (size_t i = 0; i < script.registered_count; ++i)
    {
        lua_pushcfunction(L, script.registered[i].func);
        lua_setfield(L, -2, script.registered[i].name);
    }

    const struct {const char *name; int value;} constants[] = {
        {"width", rg_display_get_width()},
        {"height", rg_display_get_height()},
        {"CENTER", RG_GUI_CENTER},
        {"TOP", RG_GUI_TOP},
        {"BOTTOM", RG_GUI_BOTTOM},
        {"LEFT", RG_GUI_LEFT},
        {"RIGHT", RG_GUI_RIGHT},
        {"TRANSPARENT", C_TRANSPARENT},
        {"NONE", C_NONE},
    };
    for (size_t i = 0; i < RG_COUNT(constants); ++i)
    {
        lua_pushinteger(L, constants[i].value);
        lua_setfield(L, -2, constants[i].name);
    }

    lua_pushstring(L, rg_system_get_app()->name);
    lua_setfield(L, -2, "app");
    lua_pushstring(L, rg_gui_get_theme_name() ?: "");
    lua_setfield(L, -2, "theme");
}

void rg_theme_script_unload(void)
{
    if (script.busy)
    {
        RG_LOGE("Can't unload the theme script while it's running!");
        return;
    }
    if (script.L)
    {
        lua_close(script.L);
        script.L = NULL;
        RG_LOGI("Theme script unloaded.");
    }
    for (size_t i = 0; i < MAX_CACHED_IMAGES; ++i)
        free_cached_image(i);
    for (size_t i = 0; i < MAX_CACHED_FONTS; ++i)
    {
        free(script.fonts[i].font);
        script.fonts[i].font = NULL;
        script.fonts[i].name[0] = 0;
    }
    script.mem_used = 0;
    script.theme_path[0] = 0;
}

void rg_theme_script_load(const char *theme_path)
{
    char path[RG_PATH_MAX];
    void *data = NULL;
    size_t data_len = 0;

    rg_theme_script_unload();

    if (!theme_path || !theme_path[0])
        return;

    snprintf(path, sizeof(path), "%s/%s", theme_path, SCRIPT_FILENAME);
    if (!rg_storage_read_file(path, &data, &data_len, 0))
        return; // No script, this theme only uses the built-in drawing functions

    lua_State *L = lua_newstate(script_alloc, NULL);
    if (!L)
    {
        RG_LOGE("Failed to create the Lua state for '%s'", path);
        free(data);
        return;
    }

    // Only safe libraries: no file, OS or module loading access
    const luaL_Reg libs[] = {
        {LUA_GNAME, luaopen_base},
        {LUA_TABLIBNAME, luaopen_table},
        {LUA_STRLIBNAME, luaopen_string},
        {LUA_MATHLIBNAME, luaopen_math},
        {LUA_UTF8LIBNAME, luaopen_utf8},
        {LUA_COLIBNAME, luaopen_coroutine},
    };
    for (size_t i = 0; i < RG_COUNT(libs); ++i)
    {
        luaL_requiref(L, libs[i].name, libs[i].func, 1);
        lua_pop(L, 1);
    }
    lua_pushnil(L), lua_setglobal(L, "dofile");
    lua_pushnil(L), lua_setglobal(L, "loadfile");
    lua_pushcfunction(L, api_log), lua_setglobal(L, "print");

    snprintf(script.theme_path, sizeof(script.theme_path), "%s", theme_path);
    push_api_table(L);
    lua_setglobal(L, "rg");

    lua_sethook(L, script_watchdog, LUA_MASKCOUNT, 10000);
    script.L = L;
    script.busy = true;
    script.call_deadline = rg_system_timer() + TIME_LIMIT_US;
    int err = luaL_loadbuffer(L, data, data_len, "@" SCRIPT_FILENAME) || lua_pcall(L, 0, 0, 0);
    script.busy = false;
    free(data);

    if (err != LUA_OK)
    {
        RG_LOGE("Theme script failed to load, using built-in drawing: %s", lua_tostring(L, -1));
        rg_theme_script_unload();
        return;
    }

    RG_LOGI("Theme script loaded: '%s' (%d KB)", path, (int)(script.mem_used / 1024));
}

void rg_theme_script_trim(void)
{
    if (!script.L || script.busy)
        return;
    for (size_t i = 0; i < MAX_CACHED_IMAGES; ++i)
        free_cached_image(i);
    lua_gc(script.L, LUA_GCCOLLECT);
}

bool rg_theme_script_is_loaded(void)
{
    return script.L != NULL;
}

void rg_theme_script_register(const char *name, lua_CFunction func)
{
    RG_ASSERT_ARG(name && func);
    for (size_t i = 0; i < script.registered_count; ++i)
    {
        if (strcmp(script.registered[i].name, name) == 0)
        {
            script.registered[i].func = func;
            return;
        }
    }
    RG_ASSERT(script.registered_count < MAX_REGISTERED, "Too many theme script functions");
    script.registered[script.registered_count].name = name;
    script.registered[script.registered_count].func = func;
    script.registered_count++;

    if (script.L && !script.busy)
    {
        lua_getglobal(script.L, "rg");
        if (lua_istable(script.L, -1))
        {
            lua_pushcfunction(script.L, func);
            lua_setfield(script.L, -2, name);
        }
        lua_pop(script.L, 1);
    }
}

lua_State *rg_theme_script_begin(const char *hook)
{
    lua_State *L = script.L;
    if (!L || script.busy || !hook)
        return NULL;
    if (lua_getglobal(L, hook) != LUA_TFUNCTION)
    {
        lua_pop(L, 1);
        return NULL;
    }
    script.busy = true;
    return L;
}

bool rg_theme_script_end(int nargs, int *results, int max_results)
{
    lua_State *L = script.L;
    if (!L || !script.busy)
        return false;

    int base = lua_gettop(L) - nargs - 1; // Stack top before the function was pushed
    script.call_deadline = rg_system_timer() + TIME_LIMIT_US;

    if (lua_pcall(L, nargs, LUA_MULTRET, 0) != LUA_OK)
    {
        RG_LOGE("Theme script error, switching back to built-in drawing: %s", lua_tostring(L, -1));
        script.busy = false;
        rg_theme_script_unload();
        return false;
    }

    int nresults = lua_gettop(L) - base;
    bool handled = !(nresults >= 1 && lua_isboolean(L, base + 1) && !lua_toboolean(L, base + 1));
    for (int i = 0; i < nresults && i < max_results && results; ++i)
    {
        if (lua_isnumber(L, base + 1 + i))
            results[i] = (int)lua_tonumber(L, base + 1 + i);
    }
    lua_settop(L, base);
    script.busy = false;
    return handled;
}

void rg_theme_script_push_image(lua_State *L, const rg_image_t *img)
{
    if (img)
        lua_pushlightuserdata(L, (void *)img);
    else
        lua_pushnil(L);
}

static const char *option_kind(int flags)
{
    if (flags == RG_DIALOG_FLAG_MESSAGE)
        return "message";
    if (flags == RG_DIALOG_FLAG_SEPARATOR)
        return "separator";
    if (flags == RG_DIALOG_FLAG_HIDDEN)
        return "hidden";
    if (flags == RG_DIALOG_FLAG_NORMAL)
        return "normal";
    if ((flags & RG_DIALOG_FLAG_MODE_MASK) == RG_DIALOG_FLAG_SKIP)
        return "skip";
    return "disabled";
}

bool rg_theme_script_draw_dialog(const char *title, const rg_gui_option_t *options, size_t options_count,
                                 int sel, rg_rect_t *rect_out)
{
    lua_State *L = rg_theme_script_begin("draw_dialog");
    if (!L)
        return false;

    lua_createtable(L, 0, 3);
    if (title)
    {
        lua_pushstring(L, title);
        lua_setfield(L, -2, "title");
    }
    lua_pushinteger(L, sel + 1);
    lua_setfield(L, -2, "selected");
    lua_createtable(L, (int)options_count, 0);
    for (size_t i = 0; i < options_count; ++i)
    {
        lua_createtable(L, 0, 3);
        lua_pushstring(L, options[i].label ?: "");
        lua_setfield(L, -2, "label");
        if (options[i].value)
        {
            lua_pushstring(L, options[i].value);
            lua_setfield(L, -2, "value");
        }
        lua_pushstring(L, option_kind(options[i].flags));
        lua_setfield(L, -2, "kind");
        lua_rawseti(L, -2, (lua_Integer)i + 1);
    }
    lua_setfield(L, -2, "options");

    int rect[4] = {0, 0, rg_display_get_width(), rg_display_get_height()};
    if (!rg_theme_script_end(1, rect, 4))
        return false;
    if (rect_out)
        *rect_out = (rg_rect_t){rect[0], rect[1], rect[2], rect[3]};
    return true;
}
