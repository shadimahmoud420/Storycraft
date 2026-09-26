"""Generates assets/icon/icon.png (1024, opaque) and icon_foreground.png
(adaptive-icon foreground with safe-zone padding). Run: python3 tool/make_icon.py"""
from PIL import Image, ImageDraw

S = 1024
SS = 4  # supersampling


def gradient(size):
    stops = [(0.0, (76, 42, 214)), (0.5, (140, 60, 230)), (1.0, (240, 98, 154))]
    img = Image.new("RGB", (size, size))
    px = img.load()
    for y in range(size):
        for x in range(size):
            t = (x + y) / (2 * (size - 1))
            for (t0, c0), (t1, c1) in zip(stops, stops[1:]):
                if t0 <= t <= t1:
                    k = (t - t0) / (t1 - t0)
                    px[x, y] = tuple(round(a + (b - a) * k) for a, b in zip(c0, c1))
                    break
    return img


def sparkle(d, cx, cy, r, fill):
    w = r * 0.28
    pts = [(cx, cy - r), (cx + w, cy - w), (cx + r, cy), (cx + w, cy + w),
           (cx, cy + r), (cx - w, cy + w), (cx - r, cy), (cx - w, cy - w)]
    d.polygon(pts, fill=fill)


def glyph(scale):
    """White story frame + sparkle + text lines on transparent canvas."""
    size = S * SS
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    u = size / 1024 * scale
    c = size / 2
    fw, fh = 380 * u, 640 * u
    box = (c - fw / 2, c - fh / 2, c + fw / 2, c + fh / 2)
    d.rounded_rectangle(box, radius=70 * u, outline="white", width=int(34 * u))
    sparkle(d, c + 30 * u, c - 110 * u, 105 * u, "white")
    sparkle(d, c - 95 * u, c - 185 * u, 48 * u, "white")
    for i, lw in enumerate((230, 170)):
        y = c + 120 * u + i * 70 * u
        d.rounded_rectangle((c - lw / 2 * u, y, c + lw / 2 * u, y + 32 * u),
                            radius=16 * u, fill="white")
    return layer.resize((S, S), Image.LANCZOS)


bg = gradient(S).convert("RGBA")
bg.alpha_composite(glyph(1.0))
bg.convert("RGB").save("assets/icon/icon.png")

# Adaptive icons crop to the inner ~66%; shrink the glyph accordingly.
glyph(0.62).save("assets/icon/icon_foreground.png")
print("icons written")
