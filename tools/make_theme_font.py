#!/usr/bin/env python3
"""
Converts a TTF/OTF font to a Retro-Go font file (.rgf) that a theme can include.

    python3 tools/make_theme_font.py JosefinSans-Regular.ttf 14 themes/mytheme/font.rgf

A theme's font.rgf replaces Retro-Go's built-in font for all text. Other .rgf files in the theme folder can
be used by theme.lua with rg.text(x, y, text, {font = "title.rgf"}). See THEMING.md.

Requires Pillow (pip install pillow). Fonts are anti-aliased (smooth edges, 4 bits per pixel). With
--mono they're 1 bit per pixel like the built-in fonts (tools/font_converter.py), smaller but jagged.

File format: "RGF1", name (16 bytes, NUL padded), type (1 = proportional, 2 = proportional anti-aliased),
width (0), height, 0, then the glyphs like the .data of a built-in font (fonts/*.c), ending with 0x00 0x00.
Glyph = code (2 bytes LE), y offset, width, height, x offset, advance, then the pixels row by row:
1 bit each (type 1, high bit first) or 4 bits each (type 2, high nibble first, 0 = empty, 15 = full).
"""
import argparse
import struct
import sys

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    sys.exit("Pillow is required: pip install pillow")


def char_list(ranges):
    chars = set()
    for part in ranges.replace(" ", "").split(","):
        if "-" in part:
            first, last = part.split("-")
            chars.update(range(int(first), int(last) + 1))
        elif part:
            chars.add(int(part))
    return sorted(chars)


def render_glyphs(font_path, size, chars, smooth):
    font = ImageFont.truetype(font_path, size)
    name = " ".join(font.getname())
    glyphs = []
    for code in chars:
        char = chr(code)
        image = Image.new("L" if smooth else "1", (size * 2, size * 2), 0)
        draw = ImageDraw.Draw(image)
        draw.text((1, 0), char, font=font, fill=255)  # At x=1 so nothing gets clipped (removed below)
        bbox = image.getbbox()
        if bbox is None:  # Space and other empty glyphs
            width = height = ofs_x = ofs_y = 0
        else:
            x0, y0, x1, y1 = bbox
            width, height, ofs_x, ofs_y = x1 - x0, y1 - y0, max(0, x0 - 1), y0
        try:
            advance = max(int(draw.textlength(char, font=font)), width + ofs_x)
        except Exception:
            advance = width + ofs_x
        bitmap = bytearray()
        if width and height:
            crop = image.crop(bbox)
            pixels = [crop.getpixel((x, y)) for y in range(height) for x in range(width)]
            if smooth:
                levels = [min(15, (p * 15 + 127) // 255) for p in pixels] + [0]
                for i in range(0, len(pixels), 2):
                    bitmap.append((levels[i] << 4) | levels[i + 1])
            else:
                bits = [1 if p else 0 for p in pixels]
                for i in range(0, len(bits), 8):
                    chunk = bits[i:i + 8] + [0] * (8 - len(bits[i:i + 8]))
                    bitmap.append(int("".join(map(str, chunk)), 2))
        glyphs.append({"code": code, "ofs_y": ofs_y, "w": width, "h": height, "ofs_x": ofs_x,
                       "adv": advance, "bitmap": bytes(bitmap)})

    # Remove top padding that every glyph has (same as font_converter.py), so the height isn't bigger than needed
    if max(g["ofs_y"] + g["h"] for g in glyphs) > size:
        min_ofs_y = min((g["ofs_y"] for g in glyphs if g["h"] > 0), default=0)
        for g in glyphs:
            if min_ofs_y > 0 and g["ofs_y"] >= min_ofs_y:
                g["ofs_y"] -= min_ofs_y
    height = max(size, max(g["ofs_y"] + g["h"] for g in glyphs))
    return name, height, glyphs


def main():
    parser = argparse.ArgumentParser(description="Convert a TTF/OTF font to a Retro-Go theme font (.rgf)")
    parser.add_argument("font", help="TTF or OTF file")
    parser.add_argument("size", type=int, help="size in pixels (Retro-Go's normal fonts are 11 to 15)")
    parser.add_argument("output", help="output .rgf file, for example themes/mytheme/font.rgf")
    parser.add_argument("--name", help="name shown in Options > Font (15 characters max)")
    parser.add_argument("--chars", default="32-126, 160-255", help="character codes (default: %(default)s)")
    parser.add_argument("--mono", action="store_true", help="1 bit per pixel, no anti-aliasing")
    args = parser.parse_args()

    name, height, glyphs = render_glyphs(args.font, args.size, char_list(args.chars), not args.mono)
    name = (args.name or f"{name.split(' ')[0]} {args.size}")[:15]
    if height > 255 or any(g["w"] > 255 or g["h"] > 255 or g["adv"] > 255 for g in glyphs):
        sys.exit("Font size too big")

    data = bytearray(b"RGF1")
    data += name.encode("utf-8")[:15].ljust(16, b"\0")
    data += bytes([1 if args.mono else 2, 0, height, 0])
    for g in glyphs:
        data += struct.pack("<HBBBBB", g["code"], g["ofs_y"], g["w"], g["h"], g["ofs_x"] & 0xFF, g["adv"])
        data += g["bitmap"]
    data += b"\0\0"

    with open(args.output, "wb") as f:
        f.write(data)
    print(f"{args.output}: '{name}', height {height}, {len(glyphs)} glyphs, {len(data)} bytes")


if __name__ == "__main__":
    main()
