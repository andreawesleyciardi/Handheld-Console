# simplelight for Retro-Go

A Retro-Go adaptation, for this 480x320 handheld, of **simplelight**, the Recalbox theme by the Recalbox
community (<https://www.recalbox.com/>), based on **Simple** by **Nils Bonenberger**
(<http://www.nilsbyte.de/>).

The system backgrounds and logos come from the original theme. They were resized for a 480x320 screen and
converted from JPG/SVG to PNG:

- `background_<system>.png`: the systems screen, with the white band behind the logo;
- `games_<system>.png`: the game list, washed out with white and with the white header, as in the original;
- `logos/<system>_sys.png` (systems screen) and `logos/<system>_head.png` (game list header).

The original has no ColecoVision or "recently played" art: those two have a gray background and a text
logo made for this adaptation. The `320x240` folder has the same images and fonts made for 320x240
screens, which get their own sizes in `theme.lua`. The layout and colors of `theme.lua` follow the
original theme's system view, detailed game list and menus. The original's footer logos and background
music aren't included.

## License

The original theme is licensed under Creative Commons Attribution-NonCommercial-ShareAlike
([CC BY-NC-SA](https://creativecommons.org/licenses/by-nc-sa/4.0/)). This adaptation, including its
images and `theme.lua`, is shared under the same license:

- Credit the original authors (Nils Bonenberger and the Recalbox community) and this adaptation when you
  share it.
- No commercial use.
- If you change it and share it, use the same license.

The fonts (`font.rgf`, `light.rgf`) are Open Sans Regular and Open Sans Light by Steve Matteson, included in
the original theme, converted with `tools/make_theme_font.py`. Open Sans is licensed under the
[Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0).

`preview.png` was made for this adaptation.

The system logos are trademarks of their respective owners.
