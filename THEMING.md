# Theming Retro-Go

A theme changes how Retro-Go looks: the launcher (the systems screen and the game lists) and the menus,
in the launcher and in games. A theme is a folder on the SD card. Installing one doesn't need a firmware
rebuild.

There are three levels, and a theme can use any of them:

1. **Colors and images** (`theme.json` and PNG files): recolor the built-in screens and replace their
   backgrounds, logos and banners. This works in upstream Retro-Go too.
2. **A font** (`font.rgf`): replaces the built-in font for all text. *(this fork)*
3. **A script** (`theme.lua`): draws the launcher and the menus with a completely different layout.
   *(this fork)*

Example themes are in the [themes](/themes/) folder of this project:

| Theme | Shows |
|--|--|
| [default](/themes/default/), [classic](/themes/classic/) | Colors and images only |
| [midnight](/themes/midnight/) | A script with images, its own fonts, transparency, animated text and separate layouts for 480x320 and 320x240 screens |
| [simplelight](/themes/simplelight/) | A light theme: full-screen images with see-through white areas built into them, colored logos, and a separate layout for 320x240 screens |


## Making a theme, step by step

1. **Start from a copy** of the closest example in `themes/`, and rename the folder. The folder name is
   the theme's name in Options → Theme.
2. **Edit `theme.json`**: author, description and colors (see [theme.json](#themejson)).
3. **Add images** if you want them (see [Images](#images)). Make them at the size of the screen they're
   for.
4. **Optionally add a font** ([Theme fonts](#theme-fonts-fontrgf)) and a script
   ([Theme scripts](#theme-scripts-themelua)).
5. **Test it on your computer** with the [desktop preview](README.md#desktop-preview-macos): the repo's
   `themes/` folder is the preview's SD card themes folder. Select the theme in Options → Theme. Saved
   changes show up immediately (see [Testing](#testing)).
6. **Install it**: copy the folder to `/retro-go/themes/` on the SD card and select it in Options → Theme
   (open the menu with Start + Select). The theme list shows each theme's `preview.png` and the
   `description` and `author` from its `theme.json`.


## Theme structure

````
/retro-go/themes
└── mytheme
    ├── theme.json
    ├── preview.png
    ├── background.png
    ├── background_<tab>.png
    ├── banner_<tab>.png
    ├── logo_<tab>.png
    ├── font.rgf
    ├── theme.lua
    ├── (any other files used by theme.lua: images, fonts)
    └── 320x240/            (optional: files for one screen size)
````

| Name | Format | Description | Required |
|--|--|--|--|
| `theme.json` | JSON | Theme information (description, author) and colors | Yes |
| `preview.png` | PNG, screen size | Screenshot of the theme, shown full screen behind the list in Options → Theme when the theme is highlighted *(this fork)* | No |
| `background.png` | PNG, screen size | Launcher's default background | No |
| `background_<tab>.png` | PNG, screen size | Launcher's background for one tab | No |
| `banner_<tab>.png` | PNG 272x24 | Launcher's banner for one tab (next to the logo, built-in layout) | No |
| `logo_<tab>.png` | PNG 46x50 | Launcher's logo for one tab (built-in layout) | No |
| `font.rgf` | Retro-Go font | Replaces the built-in font for all text, see [Theme fonts](#theme-fonts-fontrgf) | No |
| `theme.lua` | Lua 5.4 | Custom drawing code, see [Theme scripts](#theme-scripts-themelua) | No |

`<tab>` is the launcher tab's short name:

| Tab | Name | Tab | Name |
|--|--|--|--|
| NES | `nes` | Master System | `sms` |
| Super Nintendo | `snes` | Game Gear | `gg` |
| Game Boy | `gb` | Mega Drive | `md` |
| Game Boy Color | `gbc` | ColecoVision | `col` |
| Game Boy Advance | `gba` | PC Engine | `pce` |
| Game & Watch | `gw` | Atari Lynx | `lnx` |
| DOOM | `doom` | MSX | `msx` |
| Favorites | `favorite` | Recently played | `recent` |

Files that are missing are simply not used: Retro-Go falls back to `background.png`, then to its built-in
images and colors.

`preview.png` looks best at the screen's size (put other sizes in [screen size folders](#screen-sizes)):
it's stretched to fill the screen if it's another size.

The splash image shown while Retro-Go starts isn't part of themes: it's the user's own
`/retro-go/splash.png` (see the README).

### Screen sizes

*The `<width>x<height>` folders are a feature of this fork.*

Retro-Go devices mostly have 320x240 screens, then 480x320 (like this handheld), 240x240 and portrait
ones. Images and fonts look best when they're made for the screen they're shown on, so a theme can have a
folder per screen size, named `<width>x<height>`, for example `320x240/background_nes.png` or
`320x240/font.rgf`. On a screen of that size, Retro-Go uses the files in that folder instead of the files
with the same name in the theme folder. This works for the launcher's images, `font.rgf` and every file
used by `theme.lua`. Files that aren't in the size folder still come from the theme folder.

`theme.lua` can also use a different layout per screen size, with `rg.width` and `rg.height`.
[midnight](/themes/midnight/theme.lua) keeps its 480x320 files in the theme folder and its 320x240 ones in
`320x240/`, and draws a different layout on 320x240 screens.


## theme.json

`theme.json` contains the theme's information and the colors used by Retro-Go's built-in drawing.

All fields are optional, but it isn't recommended to omit individual values, because the fallback values
may change between Retro-Go versions. Entire sections can be left out, for example to only change the
launcher and not the menus, or the other way around.

| Section | Used for |
|--|--|
| `description`, `website`, `author` | Information about the theme |
| `dialog` | Menus and dialogs: `background`, `foreground`, `border`, `header` (title), `scrollbar`, `shadow`, `item_standard`, `item_disabled`, `item_message` (texts that aren't options). `background` is also the color transparent images are blended with in menus |
| `launcher_1` to `launcher_4` | Four launcher color schemes, picked with the launcher's Options → Color theme: `background`, `foreground` (header and status texts), and the game list's `list_standard_fg`/`_bg` and `list_selected_fg`/`_bg` |

Colors can be written as:
- an RGB565 number or hex string with 4 digits: `"0xF81F"` (exact);
- an RGB888 hex string with 6 digits: `"0xFF00FF"` (converted to RGB565);
- `"transparent"` (where it makes sense, like list backgrounds) or `"none"`.

Scripts can read any value from `theme.json` with `rg.theme_color(section, key)`, so a theme can keep its
script's colors there too.

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


## Images

Images are PNG files. Keep them as small as possible so they load quickly from the SD card: use the
lowest bit depth that looks right, and tools like [pngquant](https://pngquant.org/) help. Images are
decoded into memory (2 bytes per pixel, plus 1 per pixel when they have transparency), so a full-screen
480x320 image takes about 300 KB.

- **Size:** make images at the size they're shown. Backgrounds are stretched to the screen size, and
  scripts resize images with the nearest pixel, which looks blocky or jagged. Use
  [screen size folders](#screen-sizes) for devices with other screens.
- **Transparency** *(this fork)*: PNG transparency (an alpha channel) is supported. Transparent parts are
  blended with what's already drawn: the launcher's screen, or the `dialog` `background` color in menus,
  which are drawn straight to the screen. Any image editor that exports PNG with transparency works.
  Upstream Retro-Go ignores the alpha channel.
- **Magenta** (rgb(255, 0, 255) / `0xF81F`) is treated as transparent in some places by Retro-Go's
  built-in drawing, so avoid it in images.
- **Game pictures** aren't part of the theme: the launcher shows the last save's screenshot or a cover from
  `/romart/<tab>/` on the SD card (`<game file name>.png`, or Retro-Go's cover packs). Scripts get it as
  `tab.preview`.


## Theme fonts (font.rgf)

*This is a feature of this fork, upstream Retro-Go doesn't have it.*

`font.rgf` in the theme folder replaces Retro-Go's built-in font for all text, in the launcher and in
menus. The font is part of the theme: Options → Font shows it as "(theme)" and can't change it. With a
theme that has no `font.rgf`, Options → Font picks one of the built-in fonts as usual.

`.rgf` files are made from a TTF or OTF font with [`tools/make_theme_font.py`](tools/make_theme_font.py)
(needs Pillow: `pip install pillow`):

```sh
python3 tools/make_theme_font.py JosefinSans-SemiBold.ttf 14 themes/mytheme/font.rgf --name "Josefin Sans"
```

- **Size** is in pixels. Retro-Go's normal fonts are 11 to 15 pixels high; midnight uses 14 on 480x320 and
  12 on 320x240 screens (in `320x240/font.rgf`).
- **Smoothing:** fonts are anti-aliased (smooth edges) by default. `--mono` makes a 1-bit font like the
  built-in ones: smaller files, but jagged edges.
- **Characters:** `--chars` picks the character codes (default `32-126, 160-255`: basic Latin and Latin-1).
- **Name:** `--name` is shown in Options → Font (15 characters max).
- **Other fonts:** `theme.lua` can use other `.rgf` files from the theme folder for some texts, for
  example a bigger font for titles: `rg.text(x, y, "MENU", {font = "title.rgf"})`.
- **License:** check the font's license allows including it in a theme. Most free fonts (like those on
  Google Fonts, SIL Open Font License) do.


## Theme scripts (theme.lua)

*This is a feature of this fork, upstream Retro-Go doesn't have it.*

Colors and images only change how the built-in screens look. With a `theme.lua` file
([Lua 5.4](https://www.lua.org/manual/5.4/)) a theme draws whole screens with its own layout.

The script defines *hook* functions with known names. When Retro-Go is about to draw something, it calls
the matching hook if the script defines it, otherwise it uses its built-in drawing. Every hook is
optional, and a hook can `return false` to let the built-in drawing run instead.

If the script fails (Lua error, a hook running longer than 3 seconds, or more than 1 MB of memory), the
error is written to the log and Retro-Go switches back to its built-in drawing until the theme is
selected again. A broken theme can't make the device unusable.

[midnight](/themes/midnight/theme.lua) and [simplelight](/themes/simplelight/theme.lua) are complete examples.

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

The launcher hooks run when the launcher redraws: after a key press, about once a second when idle, and
when the script asks for it with `rg.redraw_in()`. In games,
only `draw_dialog` is used (`rg.app` tells which app is running).

`tab` describes the current launcher tab:

| Field | Description |
|--|--|
| `name`, `desc` | Short name (`"nes"`) and full name (`"Nintendo Entertainment System"`) |
| `index`, `count` | Position of this tab and number of tabs. `tabs` is the list of all tab names |
| `visible_tabs`, `visible_index` | Tabs shown in the launcher (hidden ones left out), as a list of `{name, desc}`, and this tab's position in it |
| `initialized` | `false` until the tab was opened once: before that the game list isn't loaded and `list.count` is 0 |
| `browsing` | `true` on the game list, `false` on the systems screen |
| `logo`, `banner`, `background`, `preview` | Image handles for `rg.image()` (may be `nil`). `background` is only set for `draw_launcher` and `draw_background`. `preview` is the selected game's picture |
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
| `rg.redraw_in(ms)` | Launcher only: redraw after `ms` milliseconds, for animations. Only the next redraw is scheduled, so call it again from the hook to keep animating. It doesn't exist in games: check `if rg.redraw_in then` in code that also runs in `draw_dialog` |
| `print(...)`, `rg.log(...)` | Write to the Retro-Go log |

Values: `rg.width`, `rg.height` (screen size), `rg.app` (`"launcher"`, `"retro-core"`, ...),
`rg.theme` (theme folder name), and position constants `rg.CENTER`, `rg.LEFT`, `rg.RIGHT`, `rg.TOP`,
`rg.BOTTOM`.

### Things to know

- **Coordinates:** negative x/y values count from the right/bottom edge, and the position constants can
  be used instead of a number (`rg.text(rg.CENTER, 10, ...)`).
- **Colors:** an RGB565 number (`0xFFFF`), `rg.rgb(...)`, a string `"#RRGGBB"`, `"transparent"` or
  `"none"`.
- **Text options:** a table with any of:
  - `color`, `bg`;
  - `width` (clip/align width), `align` (`"left"`, `"center"`, `"right"`);
  - `big` (double height), `mono`, `multiline`, `padding` (`false` removes the 1px padding);
  - `font` (a `.rgf` file in the theme folder, see [Theme fonts](#theme-fonts-fontrgf));
  - `scroll` (`rg.text` only): shifts the text left by that many pixels, cut at the box edges. midnight
    uses it with `rg.redraw_in()` to scroll the selected game's name when it's too long.
- **Multiline text** breaks lines inside words. To break at spaces, split the text in the script (midnight
  has a `wrap_words` function).
- **Transparency:** in the launcher hooks, text backgrounds default to transparent. Dialogs are drawn
  straight to the screen, where transparency isn't possible: always pass a `bg` color in `draw_dialog`,
  otherwise the text box shows up as a solid magenta (`0xF81F`) rectangle.
- **Images:** an image argument is either a handle from `tab` or a file name in the theme folder
  (`rg.image("stars.png", 0, 0)`, or in a subfolder: `"logos/nes.png"`). Files are looked up in the
  [screen size folder](#screen-sizes) first. Theme files are loaded once and cached (up to 2 MB, the least
  recently used ones are dropped first). File names can't contain `..` or start with `/`.
- **Available Lua libraries:** `string`, `table`, `math`, `utf8`, `coroutine` and the basics. There's no
  file, OS or module access.
- **Performance:** hooks run on every redraw. Precompute what you can at load time (outside the hooks),
  such as tables of colors or positions, and only animate with `rg.redraw_in()` while
  something actually moves.

### Testing

The [desktop preview](README.md#desktop-preview-macos) runs the same code as the device:

- **Automatic reload:** saving one of the selected theme's files (`theme.lua`, `theme.json`, images,
  fonts) reloads the theme in the open window. Cmd+R (Ctrl+R, or F5) forces a reload, for example after
  a script error. Both only exist in the desktop build.
- **Logs:** script errors, with their line number, go to `stdout.txt`.
- **Other screen sizes:** `SIZE=320x240 tools/build_sdl2_macos.sh` builds the preview for another
  screen size. Build again without `SIZE` to go back to 480x320.
- **Screenshots and scripted key presses** for automated checks: `RG_SDL_SNAPSHOT` and `RG_SDL_INPUT`
  (see the README).


## Sharing a theme

Copy the theme folder to share it. Include a README with the author and license, especially when the
theme uses images or fonts made by others (see [midnight's README](/themes/midnight/README.md) for an
example), and a `preview.png` (a screenshot from the desktop preview, made with `RG_SDL_SNAPSHOT`, works
well).
