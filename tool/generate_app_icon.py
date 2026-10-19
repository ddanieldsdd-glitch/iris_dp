#!/usr/bin/env python3
"""Genera el icono de IRIS (diafragma grabado sobre negro cálido) en todos los tamaños.

Uso: python3 tool/generate_app_icon.py
Solo necesita Pillow. Escribe en assets/branding, ios, macos y web.
"""
import math
import os

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SS = 4  # supermuestreo

BG_EDGE = (17, 16, 14)
BG_CENTER = (31, 29, 26)
INK = (233, 225, 210)  # crema de grabado
INDEX = (214, 128, 52)  # marca índice ámbar
BLADES = 9


def _radial_background(size):
    """Viñeta suave: centro algo más claro, bordes casi negros."""
    small = 256
    img = Image.new("RGB", (small, small))
    px = img.load()
    c = (small - 1) / 2
    for y in range(small):
        for x in range(small):
            d = min(1.0, math.hypot(x - c, y - c) / (small * 0.62))
            t = d * d
            px[x, y] = tuple(round(a + (b - a) * t) for a, b in zip(BG_CENTER, BG_EDGE))
    return img.resize((size, size), Image.BICUBIC)


def _line(draw, a, b, w, fill):
    draw.line([a, b], fill=fill, width=w)
    r = w / 2
    for p in (a, b):
        draw.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], fill=fill)


def _mark(size):
    """Capa del grabado (RGBA) a tamaño `size`, sin fondo."""
    S = size * SS
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    cx = cy = S / 2
    ink = INK + (255,)
    ink_soft = INK + (95,)

    # Anillo exterior.
    ring_r = S * 0.335
    ring_w = round(S * 0.0068)
    d.ellipse([cx - ring_r, cy - ring_r, cx + ring_r, cy + ring_r], outline=ink, width=ring_w)

    # Escala de diafragma: marcas finas fuera del anillo.
    ticks = 36
    for i in range(ticks):
        a = -math.pi / 2 + 2 * math.pi * i / ticks
        if i == 0:
            continue
        r0 = S * 0.358
        r1 = S * (0.378 if i % 3 == 0 else 0.369)
        _line(
            d,
            (cx + r0 * math.cos(a), cy + r0 * math.sin(a)),
            (cx + r1 * math.cos(a), cy + r1 * math.sin(a)),
            max(1, round(S * 0.0032)),
            ink_soft,
        )

    # Láminas del diafragma: cada lado del polígono central se prolonga hasta el
    # círculo de las láminas, como en un diafragma real visto de frente.
    blade_r = ring_r
    open_r = S * 0.1
    rot = -math.pi / 2 + math.pi / BLADES
    verts = [
        (cx + open_r * math.cos(rot + 2 * math.pi * i / BLADES),
         cy + open_r * math.sin(rot + 2 * math.pi * i / BLADES))
        for i in range(BLADES)
    ]
    lw = round(S * 0.0058)
    for i in range(BLADES):
        ax, ay = verts[i]
        bx, by = verts[(i + 1) % BLADES]
        dx, dy = bx - ax, by - ay
        n = math.hypot(dx, dy)
        dx, dy = dx / n, dy / n
        # Intersección del rayo A + t·D con el círculo de radio blade_r.
        px, py = ax - cx, ay - cy
        bq = px * dx + py * dy
        cq = px * px + py * py - blade_r * blade_r
        t = -bq + math.sqrt(bq * bq - cq)
        _line(d, (ax, ay), (ax + dx * t, ay + dy * t), lw, ink)

    # Marca índice en lo alto, como en el barril de un objetivo.
    ir = S * 0.0115
    iy = cy - S * 0.373
    d.ellipse([cx - ir, iy - ir, cx + ir, iy + ir], fill=INDEX + (255,))

    return layer.resize((size, size), Image.LANCZOS)


def _grain(img, amount=0.18):
    """Grano de película: ruido gaussiano centrado en gris, sumado con signo."""
    noise = Image.effect_noise(img.size, 64).convert("RGB")
    gray = Image.new("RGB", img.size, (128, 128, 128))
    noise = Image.blend(gray, noise, amount)
    lighter = ImageChops.subtract(noise, gray)
    darker = ImageChops.subtract(gray, noise)
    return ImageChops.subtract(ImageChops.add(img, lighter), darker)


def full_bleed(size=1024):
    """Icono cuadrado sin transparencia (iOS, web, splash)."""
    bg = _radial_background(size)
    mark = _mark(size)
    bg.paste(mark, (0, 0), mark)
    return _grain(bg)


def macos_tile(size=1024):
    """Icono macOS: baldosa redondeada con margen y sombra suave."""
    tile = round(size * 824 / 1024)
    off = (size - tile) // 2
    radius = round(tile * 0.225)
    art = full_bleed(tile)

    mask = Image.new("L", (tile * SS, tile * SS), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, tile * SS - 1, tile * SS - 1], radius=radius * SS, fill=255
    )
    mask = mask.resize((tile, tile), Image.LANCZOS)

    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    sm = Image.new("L", (size, size), 0)
    sm.paste(mask, (off, off + round(size * 0.012)))
    shadow.putalpha(sm.point(lambda v: v * 0.45))
    shadow = shadow.filter(ImageFilter.GaussianBlur(size * 0.014))
    out.alpha_composite(shadow)
    art_rgba = art.convert("RGBA")
    art_rgba.putalpha(mask)
    out.alpha_composite(art_rgba, (off, off))
    return out


def main():
    master = full_bleed(1024)
    master.save(os.path.join(ROOT, "assets/branding/iris_logo_master.png"))

    ios = os.path.join(ROOT, "ios/Runner/Assets.xcassets/AppIcon.appiconset")
    for name in os.listdir(ios):
        if not name.endswith(".png"):
            continue
        dims = name.split("Icon-App-")[1].split("@")
        pt = float(dims[0].split("x")[0])
        scale = int(dims[1].split("x")[0])
        px = round(pt * scale)
        master.resize((px, px), Image.LANCZOS).save(os.path.join(ios, name))

    mac = os.path.join(ROOT, "macos/Runner/Assets.xcassets/AppIcon.appiconset")
    tile = macos_tile(1024)
    for px in (16, 32, 64, 128, 256, 512, 1024):
        tile.resize((px, px), Image.LANCZOS).save(os.path.join(mac, f"app_icon_{px}.png"))

    web = os.path.join(ROOT, "web")
    master.resize((32, 32), Image.LANCZOS).save(os.path.join(web, "favicon.png"))
    for px in (192, 512):
        img = master.resize((px, px), Image.LANCZOS)
        img.save(os.path.join(web, f"icons/Icon-{px}.png"))
        img.save(os.path.join(web, f"icons/Icon-maskable-{px}.png"))


if __name__ == "__main__":
    main()
