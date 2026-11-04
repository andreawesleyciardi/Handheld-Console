# Theming Retro-Go

This document should document what are themes, how they're structured, and how to make them.

Example themes can be found in the [themes](/themes/) folder of this project.


## Theme Structure

A theme is a folder placed in `sd:/retro-go/themes` containing the following files:

````
/retro-go/themes
└── example
    ├── background.png
    ├── background_*.png
    ├── banner_*.png
    ├── logo_*.png
    ├── preview.png
    ├── font.rgf
    ├── theme.json
    └── theme.lua
````

| Name | Format | Description | Required |
|--|--|--|--|
| `theme.json` | JSON | Contains the theme metadata (description, author, colors, etc) | Yes |
| `preview.png` | PNG 160x120 | Theme preview to be displayed in the theme selector | No |
| `background.png` | PNG 320x240 | Launcher's default background | No |
| `background_<tab_name>.png` | PNG 320x240 | Launcher's per-tab backgrounds | No |
| `banner_<tab_name>.png` | PNG 272x24 | Launcher's per-tab banners | No |
| `logo_<tab_name>.png` | PNG 46x50 | Launcher's per-tab logos | No |
| `theme.lua` | Lua 5.4 | Custom drawing code, see [Theme scripts](#theme-scripts-themelua) | No |
| `font.rgf` | Retro-Go font | Replaces the built-in font for all text, see [Theme fonts](#theme-fonts-fontrgf) | No |

PNG images can have transparency (this fork): transparent parts are blended with what's behind them.
In menus, which are drawn straight to the screen, they're blended with the `dialog` `background` color.

## Theme fonts (font.rgf)

*This is a feature of this fork (Handheld), upstream Retro-Go doesn't have it.*

A theme can bring its own font. `font.rgf` in the theme folder replaces Retro-Go's built-in font for all
text, in the launcher and in menus. Options → Font shows it as "(theme)". Picking another font there
switches back to the built-in fonts until the theme is selected again.

`.rgf` files are made from a TTF or OTF font with [`tools/make_theme_font.py`](tools/make_theme_font.py)
(needs Pillow: `pip install pillow`):

```sh
python3 tools/make_theme_font.py JosefinSans-SemiBold.ttf 14 themes/mytheme/font.rgf --name "Josefin Sans"
```

The size is in pixels: Retro-Go's normal fonts are 11 to 15 pixels high on a 480x320 screen. Glyphs are
1 bit per pixel (no smoothing), like the built-in fonts, so thin fonts read better in a semi-bold weight.
Other `.rgf` files in the theme folder can be used for some texts by `theme.lua`, for example a bigger
font for titles: `rg.text(x, y, "MENU", {font = "title.rgf"})`. Check the font's license before including
it in a theme.


### theme.json

The `theme.json` file contains the colors used by the theme, as well as some author meta data.

All fields are optional but it is not recommended to omit individual values because the fallback value that will be used is subject to change between retro-go versions. You are free to omit entire sections, however. For example if you only wish to retheme the launcher but not the dialogs, or vice-versa.

Colors are RGB565 and can be represented as integers or hex strings. The special value `transparent` is also accepted in some places.

<details>
  <summary>View example theme.json</summary>

````json
{
    "description": "Default Retro-Go Theme",
    "website": "https://github.com/ducalex/retro-go/",
    "author": "ducalex",
    "dialog": {
        "__comment": "This section contains global dialog colors",
        "background": "0x0010",
        "foreground": "0xFFFF",
        "border": "0x6B4D",
        "header": "0xFFFF",
        "scrollbar": "0xFFFF",
        "shadow": "none",
        "item_standard": "0xFFFF",
        "item_disabled": "0x8410",
        "item_message": "0xBDF7"
    },
    "launcher_1": {
        "__comment": "This section contains launcher colors variant 1",
        "background": "0x0000",
        "foreground": "0xFFDE",
        "list_standard_bg": "transparent",
        "list_standard_fg": "0x8410",
        "list_selected_bg": "transparent",
        "list_selected_fg": "0xFFFF"
    },
    "launcher_2": {
        "__comment": "This section contains launcher colors variant 2",
        "background": "0x0000",
        "foreground": "0xFFDE",
        "list_standard_bg": "transparent",
        "list_standard_fg": "0x8410",
        "list_selected_bg": "transparent",
        "list_selected_fg": "0x07E0"
    },
    "launcher_3": {
        "__comment": "This section contains launcher colors variant 3",
        "background": "0x0000",
        "foreground": "0xFFDE",
        "list_standard_bg": "transparent",
        "list_standard_fg": "0x8410",
        "list_selected_bg": "0xFFFF",
        "list_selected_fg": "0x0000"
    },
    "launcher_4": {
        "__comment": "This section contains launcher colors variant 4",
        "background": "0x0000",
        "foreground": "0xFFDE",
        "list_standard_bg": "transparent",
        "list_standard_fg": "0xAD55",
        "list_selected_bg": "0xFFFF",
        "list_selected_fg": "0x0000"
    }
}
````
</details>


### Images

It is highly recommended to keep the image files sizes as small as possible to ensure good loading speed. This can be achieved by using the lowest bit depth possible when saving your PNG file. Tools like [pngquant](https://pngquant.org/) can also help!

Magenta (rgb(255, 0, 255) / 0xF81F) is used as the transparency color in some situations.


## Theme scripts (theme.lua)

*This is a feature of this fork (Handheld), upstream Retro-Go doesn't have it.*

Images and colors only change how the built-in screens look. A theme can go further and redraw whole
screens with its own layout by adding a `theme.lua` file ([Lua 5.4](https://www.lua.org/manual/5.4/)).
The theme stays a plain folder: copy it to `sd:/retro-go/themes/` and select it in Options → Theme.
No firmware rebuild is needed.

The script defines *hook* functions with known names. When Retro-Go is about to draw something, it
calls the matching hook if the script defines it, otherwise it uses its built-in drawing. Every hook is
optional, and a hook can `return false` to let the built-in drawing run instead.

If the script fails (Lua error, a hook running longer than 3 seconds, or more than 1 MB of memory), the
error is written to the log and Retro-Go switches back to its built-in drawing until the theme is
selected again. A broken theme can't make the device unusable.

The [midnight](/themes/midnight/theme.lua) theme is a complete example.

The easiest way to work on a theme is the desktop preview (see the README). It reloads the theme as soon
as you save one of its files (`theme.lua`, `theme.json` or an image), so changes show up in the window
without restarting. Cmd+R (Ctrl+R on other systems, or F5) forces a reload, for example after a script error. Both only exist in the desktop
build made by `tools/build_sdl2_macos.sh`; they aren't in the firmware.

### Hooks

| Hook | Called for | Argument |
|--|--|--|
| `draw_launcher(tab)` | The whole launcher screen. If defined, the hooks below aren't called | `tab` |
| `draw_background(tab)` | Launcher background | `tab` |
| `draw_header(tab)` | Launcher header (system logo and name) | `tab` |
| `draw_status(tab)` | Launcher status line (game list only) | `tab` |
| `draw_list(tab)` | Launcher game list (game list only) | `tab` |
| `draw_preview(tab)` | Launcher cover/save preview (game list only) | `tab` |
| `draw_dialog(dialog)` | Every menu and dialog, in the launcher and in-game | `dialog` |

`tab` describes the current launcher tab:

| Field | Description |
|--|--|
| `name`, `desc` | Short name (`"nes"`) and full name (`"Nintendo Entertainment System"`) |
| `index`, `count` | Position of this tab and number of tabs. `tabs` is the list of all tab names |
| `visible_tabs`, `visible_index` | Tabs shown in the launcher (hidden ones left out), as a list of `{name, desc}`, and this tab's position in it |
| `initialized` | `false` until the tab was opened once: before that the game list isn't loaded and `list.count` is 0 |
| `browsing` | `true` on the game list, `false` on the system carousel |
| `logo`, `banner`, `background`, `preview` | Image handles for `rg.image()` (may be `nil`). `background` is only set for `draw_launcher` and `draw_background` |
| `status_left`, `status_right`, `navpath` | Status texts and current folder (may be `nil`) |
| `list.cursor`, `list.count`, `list.scroll_mode` | Selected entry (1-based), number of entries, `"center"` or `"paging"` |
| `item(i)` | Text of the i-th list entry (1-based) |
| `colors` | Launcher color scheme from `theme.json` (`background`, `foreground`, `standard_fg`, `standard_bg`, `selected_fg`, `selected_bg`) |

`dialog` has `title` (may be `nil`), `selected` (1-based) and `options`, a list of `{label, value, kind}`.
`value` is `nil` for plain items. `kind` is `"normal"`, `"disabled"`, `"message"`, `"skip"`,
`"separator"` or `"hidden"`. Retro-Go's own separators are `"skip"` items labeled `"----------"`.
`draw_dialog` should return the box position and size: `return x, y, width, height`.

### Drawing API

| Function | Description |
|--|--|
| `rg.rect(x, y, w, h, fill [, border_width, border_color])` | Filled rectangle, with optional border. `fill` can be `"none"` for just the border |
| `w, h = rg.text(x, y, text [, options])` | Draws text and returns its size |
| `w, h = rg.measure(text [, options])` | Size the text would take, without drawing |
| `h = rg.line_height([options])` | Height of one line of text |
| `w, h = rg.image(image, x, y [, w, h])` | Draws an image, resized if `w` and `h` are given. Draws nothing if the image is missing |
| `w, h = rg.image_size(image)` | Image size, or `nil` if missing |
| `color = rg.rgb(r, g, b)` | Color from 0-255 components |
| `color = rg.theme_color(section, key [, default])` | Color from this theme's `theme.json` |
| `rg.status_icons()` | Retro-Go's battery/status icons (top right corner) |
| `ms = rg.time_ms()` | Milliseconds since boot |
| `print(...)`, `rg.log(...)` | Write to the Retro-Go log |

Values: `rg.width`, `rg.height` (screen size), `rg.app` (`"launcher"`, `"retro-core"`, ...),
`rg.theme` (theme folder name), and position constants `rg.CENTER`, `rg.LEFT`, `rg.RIGHT`, `rg.TOP`,
`rg.BOTTOM`.

Things to know:

- **Coordinates:** negative x/y values count from the right/bottom edge, and the position constants can
  be used instead of a number (`rg.text(rg.CENTER, 10, ...)`).
- **Colors:** an RGB565 number (`0xFFFF`), `rg.rgb(...)`, a string `"#RRGGBB"`, `"transparent"` or
  `"none"`.
- **Text options:** a table with any of `color`, `bg`, `width` (clip/align width), `align` (`"left"`,
  `"center"`, `"right"`), `big`, `mono`, `multiline`, `padding` (`false` removes the 1px padding), `font`
  (a `.rgf` file in the theme folder, see [Theme fonts](#theme-fonts-fontrgf)).
- **Transparency:** in the launcher hooks, text backgrounds default to transparent. Dialogs are drawn
  straight to the screen, where transparency isn't possible: always pass a `bg` color in `draw_dialog`,
  otherwise the text box shows up as a solid magenta (`0xF81F`) rectangle.
- **Images:** an image argument is either a handle from `tab` or a file name in the theme folder
  (`rg.image("stars.png", 0, 0)`). Theme files are loaded once and cached (up to 2 MB, the least recently
  used ones are dropped first). PNG transparency is supported. Resizing is nearest neighbour, so for
  sharp results make the files at the size they're drawn.
- **Available Lua libraries:** `string`, `table`, `math`, `utf8`, `coroutine` and the basics. There's no
  file, OS or module access.
- **Performance:** hooks run on every redraw (a key press in menus). Precompute what you can at load time
  (outside the hooks), as the midnight theme does for its gradient and stars.
- **Testing:** the [desktop preview](README.md#desktop-preview-macos) runs the same code. Logs, including
  script errors with their line number, go to `stdout.txt`.
