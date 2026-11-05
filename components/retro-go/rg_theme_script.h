#pragma once

// Theme scripts: a theme folder may contain a `theme.lua` file that replaces some of the drawing
// functions (launcher screens, dialogs, ...). See THEMING.md for the script API.
//
// How a drawing function uses it:
//
//     lua_State *L = rg_theme_script_begin("draw_list");   // NULL when the theme has no such function
//     if (L) {
//         ...push arguments with the Lua C API...
//         if (rg_theme_script_end(2, NULL, 0))
//             return;                                         // The script drew it
//     }
//     ...original drawing code...
//
// A script function that fails (Lua error, too slow, out of memory) disables the theme script, the
// error is logged and the original drawing functions are used from then on.

#include <stdbool.h>
#include <stddef.h>

#include "rg_gui.h"
#include "libs/lua/lua.h"
#include "libs/lua/lauxlib.h"

// Loads <theme_path>/theme.lua, replacing any previously loaded script. NULL unloads.
void rg_theme_script_load(const char *theme_path);
void rg_theme_script_unload(void);
bool rg_theme_script_is_loaded(void);
// Frees the cached images and the script's unused memory (the script stays loaded). Used when a menu
// closes in games, so the emulator gets the memory back.
void rg_theme_script_trim(void);

// Adds a function to the `rg` table of every script loaded from now on (and of the current one).
// Used by apps to expose app-specific helpers (eg: the launcher).
void rg_theme_script_register(const char *name, lua_CFunction func);

// Pushes the global function `hook` and returns the Lua state, or returns NULL if there's no
// script or it doesn't define `hook`. Every non-NULL return must be followed by rg_theme_script_end().
lua_State *rg_theme_script_begin(const char *hook);

// Calls the function pushed by rg_theme_script_begin() with `nargs` arguments.
// Returns true when the script handled the drawing: no error, and it didn't return `false`.
// Up to `max_results` integer return values are copied to `results` (missing ones are left untouched).
bool rg_theme_script_end(int nargs, int *results, int max_results);

// Pushes an image handle for scripts (nil if img is NULL). The caller keeps ownership of img
// and must keep it alive until the script call returns.
void rg_theme_script_push_image(lua_State *L, const rg_image_t *img);

// Hook for rg_gui_draw_dialog(): calls the script's `draw_dialog(dialog)` if it defines it.
bool rg_theme_script_draw_dialog(const char *title, const rg_gui_option_t *options, size_t options_count,
                                 int sel, rg_rect_t *rect_out);
