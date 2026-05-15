#!/usr/bin/env python3
"""Generate the BookApp app icon — light, dark, and tinted variants.

Renders a confident serif "B" — an editorial wordmark — in deep amber
on a warm cream radial gradient. Inspired by Apple's News and Books
glyph treatments. One 1024x1024 master PNG per appearance variant is
enough since iOS 17 because Xcode auto-derives the smaller sizes.

iOS 18 introduced the "Dark" and "Tinted" home-screen icon appearances.
The dark variant uses a near-black background with a softened amber B;
the tinted variant ships a luminance mask that the system colour-shifts
on the user's behalf.

Run:  python3 scripts/generate-icon.py
"""

from PIL import Image, ImageDraw, ImageFilter, ImageFont
from pathlib import Path
import math
import os

SIZE = 1024
OUT = Path(__file__).parent.parent / "BookApp" / "Resources" / "Assets.xcassets" / "AppIcon.appiconset"
OUT.mkdir(parents=True, exist_ok=True)

# Palette — kept in sync with Theme.Palette.
CREAM_TOP = (250, 244, 232)
CREAM_BOT = (235, 222, 199)
AMBER     = (194, 65, 12)     # ink tone, matches Theme.Palette.accent
AMBER_DK  = (138, 40, 10)
GLINT     = (255, 245, 220, 60)
RULE_INK  = (138, 88, 40, 100)


def radial_cream(size):
    """Soft radial gradient, brighter in the upper-third."""
    img = Image.new("RGB", (size, size), CREAM_TOP)
    px = img.load()
    cx, cy = size / 2, size * 0.42
    max_d = math.sqrt((size / 2) ** 2 + (size * 0.6) ** 2)
    for y in range(size):
        for x in range(size):
            d = math.sqrt((x - cx) ** 2 + (y - cy) ** 2) / max_d
            d = min(1.0, d)
            r = int(CREAM_TOP[0] * (1 - d) + CREAM_BOT[0] * d)
            g = int(CREAM_TOP[1] * (1 - d) + CREAM_BOT[1] * d)
            b = int(CREAM_TOP[2] * (1 - d) + CREAM_BOT[2] * d)
            px[x, y] = (r, g, b)
    return img


def find_serif_font(size_px):
    candidates = [
        "/System/Library/Fonts/Supplemental/Times New Roman Bold.ttf",
        "/System/Library/Fonts/Supplemental/Georgia Bold.ttf",
        "/System/Library/Fonts/Supplemental/Baskerville.ttc",
        "/System/Library/Fonts/Supplemental/Hoefler Text.ttc",
        "/System/Library/Fonts/NewYork.ttf",
        "/Library/Fonts/Georgia.ttf",
    ]
    for path in candidates:
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, size_px)
            except OSError:
                continue
    return ImageFont.load_default()


def radial_dark(size):
    """Radial gradient in deep ink with a faint amber halo — the dark variant."""
    img = Image.new("RGB", (size, size), (18, 14, 10))
    px = img.load()
    cx, cy = size / 2, size * 0.42
    max_d = math.sqrt((size / 2) ** 2 + (size * 0.6) ** 2)
    for y in range(size):
        for x in range(size):
            d = math.sqrt((x - cx) ** 2 + (y - cy) ** 2) / max_d
            d = min(1.0, d)
            r = int(36 * (1 - d) + 18 * d)
            g = int(28 * (1 - d) + 14 * d)
            b = int(20 * (1 - d) + 10 * d)
            px[x, y] = (r, g, b)
    return img


def render_glyph(canvas, color, draw_rules: bool, rule_color):
    """Composite the serif B + ornamental rules onto `canvas`."""
    draw = ImageDraw.Draw(canvas, "RGBA")
    font_size = int(SIZE * 0.78)
    font = find_serif_font(font_size)
    text = "B"
    bbox = draw.textbbox((0, 0), text, font=font)
    text_w = bbox[2] - bbox[0]
    text_h = bbox[3] - bbox[1]
    tx = (SIZE - text_w) / 2 - bbox[0]
    ty = (SIZE - text_h) / 2 - bbox[1] - SIZE * 0.02

    # Soft drop shadow underneath the glyph.
    shadow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.text((tx + 4, ty + 12), text, font=font, fill=(0, 0, 0, 70))
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=14))
    canvas = Image.alpha_composite(canvas, shadow)
    draw = ImageDraw.Draw(canvas, "RGBA")
    draw.text((tx, ty), text, font=font, fill=color)

    if draw_rules:
        rule_y_top = SIZE * 0.16
        rule_y_bot = SIZE - rule_y_top
        rule_inset = SIZE * 0.30
        draw.line(
            [(rule_inset, rule_y_top), (SIZE - rule_inset, rule_y_top)],
            fill=rule_color, width=4,
        )
        draw.line(
            [(rule_inset, rule_y_bot), (SIZE - rule_inset, rule_y_bot)],
            fill=rule_color, width=4,
        )
        for ry in (rule_y_top, rule_y_bot):
            d = 10
            draw.polygon(
                [(SIZE / 2, ry - d), (SIZE / 2 + d, ry),
                 (SIZE / 2, ry + d), (SIZE / 2 - d, ry)],
                fill=rule_color,
            )
    return canvas


def render_dark():
    """Dark home-screen icon: ink background, amber-tinted B."""
    canvas = radial_dark(SIZE).convert("RGBA")
    inner = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    di = ImageDraw.Draw(inner)
    di.rounded_rectangle(
        (12, 12, SIZE - 12, SIZE - 12),
        radius=180,
        outline=(220, 180, 130, 30),
        width=2,
    )
    canvas = Image.alpha_composite(canvas, inner)
    return render_glyph(canvas, (212, 110, 50, 255), True, (212, 150, 80, 110))


def render_tinted():
    """Tinted icon ships as a luminance mask. iOS substitutes the user's
    chosen tint at render time. We supply the mark in white on a dark
    background — the contrast that survives the tint pipeline best."""
    canvas = Image.new("RGBA", (SIZE, SIZE), (12, 12, 12, 255))
    return render_glyph(canvas, (240, 240, 240, 255), True, (240, 240, 240, 100))


def main():
    canvas = radial_cream(SIZE).convert("RGBA")

    # Soft inner stroke — very subtle, gives the icon a contained feel.
    inner = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    di = ImageDraw.Draw(inner)
    di.rounded_rectangle(
        (12, 12, SIZE - 12, SIZE - 12),
        radius=180,
        outline=(120, 80, 40, 24),
        width=2,
    )
    canvas = Image.alpha_composite(canvas, inner)

    # Light glint band across the upper portion — like sun on paper.
    glint = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glint)
    gd.ellipse(
        (-SIZE * 0.4, -SIZE * 0.6, SIZE * 1.4, SIZE * 0.5),
        fill=GLINT,
    )
    glint = glint.filter(ImageFilter.GaussianBlur(radius=80))
    canvas = Image.alpha_composite(canvas, glint)

    draw = ImageDraw.Draw(canvas, "RGBA")

    # The mark: a single serif "B" — bold, optical center.
    font_size = int(SIZE * 0.78)
    font = find_serif_font(font_size)

    text = "B"
    bbox = draw.textbbox((0, 0), text, font=font)
    text_w = bbox[2] - bbox[0]
    text_h = bbox[3] - bbox[1]
    # Optical centering: serif glyphs sit slightly low, so nudge up.
    tx = (SIZE - text_w) / 2 - bbox[0]
    ty = (SIZE - text_h) / 2 - bbox[1] - SIZE * 0.02

    # Subtle drop shadow.
    shadow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.text((tx + 4, ty + 12), text, font=font, fill=(60, 30, 8, 80))
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=14))
    canvas = Image.alpha_composite(canvas, shadow)
    draw = ImageDraw.Draw(canvas, "RGBA")

    # Main mark in amber.
    draw.text((tx, ty), text, font=font, fill=AMBER + (255,))

    # Dark amber inner shadow on the right edge of the B for ink depth.
    edge = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    ed = ImageDraw.Draw(edge)
    ed.text((tx + 5, ty + 4), text, font=font, fill=AMBER_DK + (90,))
    edge_mask = Image.new("L", (SIZE, SIZE), 0)
    em = ImageDraw.Draw(edge_mask)
    em.text((tx, ty), text, font=font, fill=255)
    edge.putalpha(edge_mask)
    canvas = Image.alpha_composite(canvas, edge)
    draw = ImageDraw.Draw(canvas, "RGBA")

    # Two thin rules above and below the mark — typographic ornament.
    rule_y_top = SIZE * 0.16
    rule_y_bot = SIZE - rule_y_top
    rule_inset = SIZE * 0.30
    draw.line(
        [(rule_inset, rule_y_top), (SIZE - rule_inset, rule_y_top)],
        fill=RULE_INK, width=4,
    )
    draw.line(
        [(rule_inset, rule_y_bot), (SIZE - rule_inset, rule_y_bot)],
        fill=RULE_INK, width=4,
    )
    # Tiny diamond ornament centered on each rule.
    for ry in (rule_y_top, rule_y_bot):
        d = 10
        draw.polygon(
            [(SIZE / 2, ry - d), (SIZE / 2 + d, ry),
             (SIZE / 2, ry + d), (SIZE / 2 - d, ry)],
            fill=AMBER_DK + (200,),
        )

    final_light = canvas.convert("RGB")
    light_path = OUT / "icon-1024.png"
    final_light.save(light_path, "PNG", optimize=True)
    print(f"Wrote {light_path}")

    dark_path = OUT / "icon-1024-dark.png"
    render_dark().convert("RGB").save(dark_path, "PNG", optimize=True)
    print(f"Wrote {dark_path}")

    tinted_path = OUT / "icon-1024-tinted.png"
    render_tinted().convert("RGB").save(tinted_path, "PNG", optimize=True)
    print(f"Wrote {tinted_path}")

    # iOS 18 appearance variants. Apple expects three image entries
    # under the same idiom/size, distinguished by an `appearances`
    # array. Without the dark + tinted variants the home screen falls
    # back to a cropped/fuzzy auto-rendered version of the light icon.
    contents = """{
  "images" : [
    {
      "filename" : "icon-1024.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    },
    {
      "appearances" : [
        { "appearance" : "luminosity", "value" : "dark" }
      ],
      "filename" : "icon-1024-dark.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    },
    {
      "appearances" : [
        { "appearance" : "luminosity", "value" : "tinted" }
      ],
      "filename" : "icon-1024-tinted.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
"""
    (OUT / "Contents.json").write_text(contents)
    print(f"Wrote {OUT/'Contents.json'}")


if __name__ == "__main__":
    main()
