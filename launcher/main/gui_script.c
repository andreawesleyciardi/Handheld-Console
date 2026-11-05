// Launcher side of theme scripts (theme.lua): describes the launcher state to the script's hooks.
// The original drawing functions in gui.c are untouched, gui_redraw() tries the script first.
#include <rg_system.h>
#include <rg_theme_script.h>
#include <string.h>

#include "gui.h"

static const char *scroll_mode_name(int mode)
{
    return mode == SCROLL_MODE_PAGING ? "paging" : "center";
}

static void set_string(lua_State *L, const char *key, const char *value)
{
    if (value && value[0])
    {
        lua_pushstring(L, value);
        lua_setfield(L, -2, key);
    }
}

static void set_integer(lua_State *L, const char *key, lua_Integer value)
{
    lua_pushinteger(L, value);
    lua_setfield(L, -2, key);
}

static void set_image(lua_State *L, const char *key, const rg_image_t *img)
{
    rg_theme_script_push_image(L, img);
    lua_setfield(L, -2, key);
}

// tab.item(i) -> text of the i-th list entry (1-based), or nil
static int tab_item(lua_State *L)
{
    const tab_t *tab = lua_touserdata(L, lua_upvalueindex(1));
    lua_Integer index = luaL_checkinteger(L, 1) - 1;
    if (!tab || index < 0 || index >= tab->listbox.length)
        return 0;
    lua_pushstring(L, tab->listbox.items[index].text);
    return 1;
}

// Same image loading as gui_draw_background()/gui_draw_header(), without the shading
static void load_tab_images(tab_t *tab, bool need_background)
{
    if (!tab->logo)
        tab->logo = gui_get_image("logo", tab->name);
    if (!tab->banner)
        tab->banner = gui_get_image("banner", tab->name);

    if (need_background && !tab->background)
    {
        tab->background = gui_get_image("background", tab->name);
        if (!tab->background)
            tab->background = gui_get_image("background", NULL);
        tab->background_shade = 0;
        if (tab->background && (tab->background->width != gui.width || tab->background->height != gui.height))
        {
            rg_image_t *temp = rg_surface_resize(tab->background, gui.width, gui.height);
            if (temp)
            {
                rg_surface_free(tab->background);
                tab->background = temp;
            }
        }
    }
}

static void push_tab(lua_State *L, tab_t *tab, bool need_background)
{
    load_tab_images(tab, need_background);

    lua_createtable(L, 0, 20);
    set_string(L, "name", tab->name);
    set_string(L, "desc", tab->desc);
    set_integer(L, "index", gui.selected_tab + 1);
    set_integer(L, "count", gui.tabs_count);
    lua_pushboolean(L, gui.browse);
    lua_setfield(L, -2, "browsing");
    set_string(L, "navpath", tab->navpath);
    set_string(L, "status_left", tab->status[tab->status[1].left[0] ? 1 : 0].left);
    set_string(L, "status_right", tab->status[tab->status[1].right[0] ? 1 : 0].right);
    set_image(L, "logo", tab->logo);
    set_image(L, "banner", tab->banner);
    set_image(L, "preview", tab->preview);
    if (need_background)
        set_image(L, "background", tab->background);

    // Names of all tabs, for tab indicators
    lua_createtable(L, gui.tabs_count, 0);
    for (size_t i = 0; i < gui.tabs_count; ++i)
    {
        lua_pushstring(L, gui.tabs[i]->name);
        lua_rawseti(L, -2, i + 1);
    }
    lua_setfield(L, -2, "tabs");

    // Only the tabs shown in the launcher (hidden ones are skipped when switching), with this tab's position
    lua_createtable(L, gui.tabs_count, 0);
    for (size_t i = 0, n = 0; i < gui.tabs_count; ++i)
    {
        if (!gui.tabs[i]->enabled)
            continue;
        lua_createtable(L, 0, 2);
        set_string(L, "name", gui.tabs[i]->name);
        set_string(L, "desc", gui.tabs[i]->desc);
        lua_rawseti(L, -2, ++n);
    }
    lua_setfield(L, -2, "visible_tabs");
    for (size_t i = 0, n = 0; i < gui.tabs_count; ++i)
    {
        if (gui.tabs[i]->enabled)
            n++;
        if (gui.tabs[i] == tab)
        {
            set_integer(L, "visible_index", n);
            break;
        }
    }
    lua_pushboolean(L, tab->initialized);
    lua_setfield(L, -2, "initialized"); // false = the list wasn't loaded yet (list.count is 0 until the tab is opened)

    // Launcher color scheme selected in the options (launcher_1..4 in theme.json)
    lua_createtable(L, 0, 6);
    set_integer(L, "background", gui.theme->background);
    set_integer(L, "foreground", gui.theme->foreground);
    set_integer(L, "standard_bg", gui.theme->list.standard_bg);
    set_integer(L, "standard_fg", gui.theme->list.standard_fg);
    set_integer(L, "selected_bg", gui.theme->list.selected_bg);
    set_integer(L, "selected_fg", gui.theme->list.selected_fg);
    lua_setfield(L, -2, "colors");

    lua_createtable(L, 0, 3);
    set_integer(L, "cursor", tab->listbox.cursor + 1);
    set_integer(L, "count", tab->listbox.length);
    set_string(L, "scroll_mode", scroll_mode_name(gui.scroll_mode));
    lua_setfield(L, -2, "list");

    lua_pushlightuserdata(L, tab);
    lua_pushcclosure(L, tab_item, 1);
    lua_setfield(L, -2, "item");
}

// rg.redraw_in(ms): the launcher redraws after ms milliseconds, for animations (scrolling text, ...).
// Only the next redraw is scheduled: call it again from the hook to keep animating.
static int64_t redraw_at;

static int api_redraw_in(lua_State *L)
{
    lua_Integer ms = luaL_checkinteger(L, 1);
    int64_t when = rg_system_timer() + (int64_t)RG_MAX(ms, 0) * 1000;
    if (!redraw_at || when < redraw_at)
        redraw_at = when;
    return 0;
}

void gui_script_init(void)
{
    rg_theme_script_register("redraw_in", api_redraw_in);
}

bool gui_script_redraw_due(void)
{
    if (!redraw_at || rg_system_timer() < redraw_at)
        return false;
    redraw_at = 0;
    return true;
}

bool gui_script_draw(const char *hook, tab_t *tab)
{
    if (!tab)
        return false;
    lua_State *L = rg_theme_script_begin(hook);
    if (!L)
        return false;
    bool need_background = strcmp(hook, "draw_background") == 0 || strcmp(hook, "draw_launcher") == 0;
    push_tab(L, tab, need_background);
    return rg_theme_script_end(1, NULL, 0);
}
