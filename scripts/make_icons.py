"""Generate the SwipeClean app icon set.

Run with the bundled Python:
    python scripts/make_icons.py
"""

from __future__ import annotations

import json
import os
import sys

from PIL import Image, ImageDraw, ImageFilter

CANVAS = 1024
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "ios", "SwipeClean", "Assets.xcassets", "AppIcon.appiconset"))


def vertical_gradient(size, top, bottom):
    width, height = size
    strip = Image.new("RGB", (1, height))
    pixels = strip.load()
    for y in range(height):
        t = y / max(height - 1, 1)
        pixels[0, y] = tuple(round(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
    return strip.resize((width, height), Image.BILINEAR)


def rounded_mask(size, radius):
    mask = Image.new("L", size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle([0, 0, size[0] - 1, size[1] - 1], radius=radius, fill=255)
    return mask


def thick_line(draw, points, width, color):
    draw.line(points, fill=color, width=width, joint="curve")
    radius = width // 2
    for x, y in (points[0], points[-1]):
        draw.ellipse([x - radius, y - radius, x + radius, y + radius], fill=color)


def build_base():
    image = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 255))
    background = vertical_gradient((CANVAS, CANVAS), (26, 22, 40), (4, 4, 7))
    image.paste(background, (0, 0))

    # Soft purple glow behind the card.
    glow = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    glow_draw.ellipse([150, 120, 880, 900], fill=(120, 80, 255, 90))
    glow = glow.filter(ImageFilter.GaussianBlur(120))
    image = Image.alpha_composite(image, glow)

    # Back card, tilted, gives depth.
    back_size = (500, 640)
    back = Image.new("RGBA", back_size, (0, 0, 0, 0))
    back_draw = ImageDraw.Draw(back)
    back_draw.rounded_rectangle(
        [0, 0, back_size[0] - 1, back_size[1] - 1],
        radius=112,
        fill=(255, 255, 255, 34),
        outline=(255, 255, 255, 60),
        width=3,
    )
    back = back.rotate(-12, resample=Image.BICUBIC, expand=False)
    image.alpha_composite(back, (196, 128))

    # Front card with a purple -> pink gradient.
    card_size = (548, 676)
    card = Image.new("RGBA", card_size, (0, 0, 0, 0))
    gradient = vertical_gradient(card_size, (146, 106, 255), (232, 64, 148))
    card.paste(gradient, (0, 0))
    card.putalpha(rounded_mask(card_size, 128))

    # Shadow under the front card.
    shadow = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    shadow_mask = rounded_mask(card_size, 128)
    shadow_card = Image.new("RGBA", card_size, (0, 0, 0, 150))
    shadow.paste(shadow_card, (238, 176), shadow_mask)
    shadow = shadow.filter(ImageFilter.GaussianBlur(60))
    image = Image.alpha_composite(image, shadow)

    image.alpha_composite(card, (238, 176))

    # White swipe-up arrow.
    draw = ImageDraw.Draw(image)
    thick_line(draw, [(512, 640), (512, 418)], 58, (255, 255, 255, 255))
    thick_line(draw, [(410, 520), (512, 418), (614, 520)], 58, (255, 255, 255, 255))

    # Red trash badge.
    badge = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    badge_draw = ImageDraw.Draw(badge)
    cx, cy, r = 796, 792, 102
    badge_draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(240, 68, 82, 255))
    badge_draw.ellipse([cx - r, cy - r, cx + r, cy + r], outline=(255, 255, 255, 60), width=4)
    image = Image.alpha_composite(image, badge)

    trash = ImageDraw.Draw(image)
    body_w, body_h = 72, 78
    bx, by = cx - body_w // 2, cy - 14
    trash.rounded_rectangle([bx, by, bx + body_w, by + body_h], radius=14, fill=(255, 255, 255, 255))
    trash.rounded_rectangle([cx - 46, cy - 44, cx + 46, cy - 30], radius=7, fill=(255, 255, 255, 255))
    trash.rounded_rectangle([cx - 16, cy - 58, cx + 16, cy - 44], radius=7, fill=(255, 255, 255, 255))

    return image.convert("RGB")


SPECS = [
    ("20x20", "2x", "iphone", 40, "icon-20@2x.png"),
    ("20x20", "3x", "iphone", 60, "icon-20@3x.png"),
    ("29x29", "2x", "iphone", 58, "icon-29@2x.png"),
    ("29x29", "3x", "iphone", 87, "icon-29@3x.png"),
    ("40x40", "2x", "iphone", 80, "icon-40@2x.png"),
    ("40x40", "3x", "iphone", 120, "icon-40@3x.png"),
    ("60x60", "2x", "iphone", 120, "icon-60@2x.png"),
    ("60x60", "3x", "iphone", 180, "icon-60@3x.png"),
    ("1024x1024", "1x", "ios-marketing", 1024, "icon-1024.png"),
]


def main():
    os.makedirs(OUT, exist_ok=True)
    base = build_base()
    images = []
    for size_label, scale, idiom, pixels, filename in SPECS:
        resized = base.resize((pixels, pixels), Image.LANCZOS)
        resized.save(os.path.join(OUT, filename), "PNG")
        images.append({
            "size": size_label,
            "idiom": idiom,
            "filename": filename,
            "scale": scale,
        })

    contents = {"images": images, "info": {"author": "xcode", "version": 1}}
    with open(os.path.join(OUT, "Contents.json"), "w", encoding="utf-8") as handle:
        json.dump(contents, handle, indent=2)
        handle.write("\n")

    print("icons written to", OUT)
    for entry in images:
        print(" ", entry["filename"])


if __name__ == "__main__":
    sys.exit(main())
