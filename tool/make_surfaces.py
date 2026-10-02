"""Generates the product-studio surfaces (assets/surfaces/*.jpg).

Each scene is a 1080x1920 story: a softly lit wall and a tabletop seen at
an angle (the usual product-photo view), with depth of field. Textures are
procedural (fractal noise), so no third-party photos are needed.

Run: python3 tool/make_surfaces.py
"""
import os

import cv2
import numpy as np

W, H = 1080, 1920
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'surfaces')
rng = np.random.default_rng(7)


def noise(h, w, scale, octaves=5, seed=0):
    r = np.random.default_rng(seed)
    out = np.zeros((h, w), np.float32)
    amp, total = 1.0, 0.0
    for o in range(octaves):
        s = max(2, int(scale * 2 ** o))
        g = r.random((s, int(s * w / h) + 2)).astype(np.float32)
        out += cv2.resize(g, (w, h), interpolation=cv2.INTER_CUBIC) * amp
        total += amp
        amp *= 0.5
    return out / total


def turbulence(h, w, scale, octaves, seed):
    r = np.random.default_rng(seed)
    out = np.zeros((h, w), np.float32)
    amp, total = 1.0, 0.0
    for o in range(octaves):
        s = max(2, int(scale * 2 ** o))
        g = (r.random((s, s)).astype(np.float32) - 0.5) * 2
        out += np.abs(cv2.resize(g, (w, h), interpolation=cv2.INTER_CUBIC)) * amp
        total += amp
        amp *= 0.5
    return out / total


def marble(h, w, base, vein, seed, veins=2.2, sharp=22.0, strength=0.8):
    """Long diagonal veins with fine jagged detail, faint secondary veins
    and a soft cloudy base."""
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    d = (x * 0.75 + y * 0.66) / w
    turb = turbulence(h, w, 2, 7, seed)
    t = d * veins + turb * 1.6
    main = np.exp(-np.abs(np.sin(t * np.pi)) * sharp)
    t2 = d * veins * 2.7 + turbulence(h, w, 3, 7, seed + 5) * 2.2
    minor = np.exp(-np.abs(np.sin(t2 * np.pi)) * sharp * 1.6) * 0.45
    lines = np.clip(main + minor, 0, 1)
    lines = cv2.GaussianBlur(lines, (0, 0), 0.8)
    cloud = noise(h, w, 2, 5, seed + 1)
    img = np.array(base, np.float32)[None, None] * (0.95 + 0.07 * cloud[..., None])
    # A soft halo around veins, like real stone.
    halo = cv2.GaussianBlur(lines, (0, 0), 6) * 0.25
    k = np.clip(lines * strength + halo, 0, 1)[..., None]
    return img * (1 - k) + np.array(vein, np.float32)[None, None] * k


def wood(h, w, light, dark, seed, planks=5):
    """Planks running away from the viewer, grain along each plank."""
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    pw = w / planks
    plank = np.minimum((x / pw).astype(np.int32), planks - 1)
    r = np.random.default_rng(seed)
    shift = (r.random(planks) * 300)[plank]
    tone = (0.9 + r.random(planks) * 0.2)[plank]
    warp = noise(h, w, 3, 4, seed) * 60 + noise(h, w, 12, 3, seed + 2) * 8
    u = (x - plank * pw) + warp + shift
    # Irregular ring spacing: the phase drifts slowly along the plank.
    phase = u / 16.0 + noise(h, w, 2, 3, seed + 7) * 9.0 + np.sin(y / 260.0 + shift) * 1.5
    rings = (np.sin(phase) * 0.5 + 0.5) ** 4
    fine = noise(h, w, 90, 2, seed + 3)
    broad = noise(h, w, 5, 3, seed + 4)
    t = np.clip(0.38 * rings + 0.32 * fine + 0.4 * broad, 0, 1)[..., None]
    img = (np.array(light, np.float32) * (1 - t) + np.array(dark, np.float32) * t) * tone[..., None]
    seam = np.abs((x / pw) - np.round(x / pw)) * pw < 1.6
    img[seam] *= 0.55
    return img


def fabric(h, w, color, seed):
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    weave = (np.sin(x * 1.3) * np.sin(y * 1.3)) * 0.04
    slub = (noise(h, w, 60, 2, seed) - 0.5) * 0.12 + (noise(h, w, 4, 3, seed + 1) - 0.5) * 0.08
    return np.array(color, np.float32)[None, None] * (1 + weave + slub)[..., None]


def concrete(h, w, color, seed):
    n = noise(h, w, 6, 6, seed)
    pores = (rng.random((h, w)) > 0.997).astype(np.float32)
    pores = cv2.GaussianBlur(pores, (0, 0), 1.2) * 4
    img = np.array(color, np.float32)[None, None] * (0.86 + 0.24 * n[..., None])
    return img * (1 - np.clip(pores, 0, 0.5)[..., None])


def perspective(tex, horizon):
    """Lays a flat texture as a tabletop from y=horizon down to the bottom."""
    th, tw = tex.shape[:2]
    top = int(H * horizon)
    src = np.float32([[0, 0], [tw, 0], [tw, th], [0, th]])
    spread = W * 0.62
    dst = np.float32([[W / 2 - spread, top], [W / 2 + spread, top],
                      [W * 1.55, H], [-W * 0.55, H]])
    m = cv2.getPerspectiveTransform(src, dst)
    out = cv2.warpPerspective(tex, m, (W, H), flags=cv2.INTER_AREA,
                              borderMode=cv2.BORDER_REPLICATE)
    return out, top


def wall(color, light, top_dark=0.75):
    y = np.linspace(0, 1, H)[:, None, None]
    x = np.linspace(0, 1, W)[None, :, None]
    g = np.array(color, np.float32) * (top_dark + (1 - top_dark) * y)
    # A soft window light from the upper right.
    glow = np.exp(-(((x - 0.78) / 0.35) ** 2 + ((y - 0.18) / 0.22) ** 2))
    return g + np.array(light, np.float32) * glow * 0.35


def compose(surface, wall_img, horizon, glossy, sheen=0.22, haze=6.0):
    tex, top = perspective(surface, horizon)
    img = wall_img.copy()
    # Depth of field on the wall.
    img = cv2.GaussianBlur(img, (0, 0), 14)
    y = np.arange(H)[:, None]
    # Table: progressively sharper toward the viewer.
    far = cv2.GaussianBlur(tex, (0, 0), haze)
    mid = cv2.GaussianBlur(tex, (0, 0), haze * 0.4)
    t = np.clip((y - top) / (H - top), 0, 1)[..., None]
    table = np.where(t < 0.35, far * (1 - t / 0.35) + mid * (t / 0.35),
                     mid * (1 - (t - 0.35) / 0.65) + tex * ((t - 0.35) / 0.65))
    # Light falloff: brighter far (near the window), a little darker in front.
    table *= (1.06 - 0.16 * t)
    if glossy:
        # Window reflection on a polished top.
        x = np.linspace(0, 1, W)[None, :, None]
        spec = np.exp(-(((x - 0.72) / 0.22) ** 2) - ((t - 0.12) / 0.18) ** 2)
        table += 255 * sheen * spec
    mask = (y >= top)[..., None]
    img = np.where(mask, table, img)
    # Soft edge where the table meets the wall.
    edge = np.exp(-((y - top) / 6.0) ** 2)[..., None]
    img = img * (1 - 0.25 * edge)
    # Vignette and grain.
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    v = 1 - 0.18 * (((xx - W / 2) / (W * 0.75)) ** 2 + ((yy - H * 0.6) / (H * 0.7)) ** 2)
    img *= v[..., None]
    img += rng.normal(0, 2.2, (H, W, 1))
    return np.clip(img, 0, 255).astype(np.uint8)


def studio(top_c, bottom_c, spot=(255, 255, 255)):
    """Seamless curved backdrop (no visible horizon)."""
    y = np.linspace(0, 1, H)[:, None, None]
    x = np.linspace(0, 1, W)[None, :, None]
    t = np.clip((y - 0.2) / 0.7, 0, 1)
    t = t * t * (3 - 2 * t)
    img = np.array(top_c, np.float32) * (1 - t) + np.array(bottom_c, np.float32) * t
    glow = np.exp(-(((x - 0.5) / 0.45) ** 2 + ((y - 0.62) / 0.3) ** 2))
    img = img + np.array(spot, np.float32) * glow * 0.18
    img += rng.normal(0, 1.6, (H, W, 1))
    return np.clip(img, 0, 255).astype(np.uint8)


def save(name, rgb):
    path = os.path.join(OUT, f'{name}.jpg')
    cv2.imwrite(path, cv2.cvtColor(rgb, cv2.COLOR_RGB2BGR), [cv2.IMWRITE_JPEG_QUALITY, 86])
    print(name, os.path.getsize(path) // 1024, 'KB')


def main():
    os.makedirs(OUT, exist_ok=True)
    th, tw = 1400, 1400
    save('white_marble', compose(
        marble(th, tw, (236, 234, 230), (150, 150, 155), 1),
        wall((222, 214, 204), (255, 245, 230)), 0.42, True))
    save('black_marble', compose(
        marble(th, tw, (34, 33, 36), (176, 152, 112), 2, veins=1.8, sharp=30, strength=0.55),
        wall((70, 64, 60), (255, 220, 170), 0.6), 0.42, True, sheen=0.16))
    save('oak_wood', compose(
        wood(th, tw, (196, 150, 104), (140, 96, 60), 3),
        wall((214, 200, 184), (255, 236, 210)), 0.42, False))
    save('walnut_wood', compose(
        wood(th, tw, (120, 78, 50), (70, 42, 26), 4),
        wall((60, 52, 48), (255, 210, 160), 0.6), 0.42, False))
    save('linen', compose(
        fabric(th, tw, (226, 214, 194), 5),
        wall((236, 228, 216), (255, 248, 236)), 0.40, False, haze=4))
    save('concrete', compose(
        concrete(th, tw, (176, 174, 170), 6),
        wall((196, 194, 190), (255, 255, 250)), 0.42, False))
    save('white_counter', compose(
        marble(th, tw, (246, 246, 244), (210, 210, 214), 8, veins=3, sharp=14),
        wall((236, 236, 234), (255, 255, 255)), 0.46, True, sheen=0.28))
    save('studio_cream', studio((246, 238, 226), (222, 206, 186)))
    save('studio_pink', studio((252, 222, 228), (236, 176, 190)))
    save('studio_blue', studio((214, 230, 246), (150, 184, 220)))
    save('studio_dark', studio((40, 40, 46), (14, 14, 18), spot=(120, 110, 100)))
    save('studio_sage', studio((222, 232, 214), (168, 190, 160)))


if __name__ == '__main__':
    main()
