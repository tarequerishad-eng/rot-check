"""Generate the Rot Check PNG icon set from the same spec as icon.svg.

Renders at 4x then downsamples, which gives clean edges without needing
an SVG rasterizer on the machine. Run after any icon change:

    python tools/make-icons.py
"""
import os
from PIL import Image, ImageDraw

OUT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
S = 512          # design canvas
SS = 4           # supersample factor

GROUND_TOP = (42, 15, 38)
GROUND_BOT = (10, 3, 9)
PLUM_1 = (30, 11, 28)
PLUM_2 = (44, 17, 41)
LINE = (61, 27, 57)
MAGENTA = (255, 46, 136)
CYAN = (0, 229, 255)
YELLOW = (255, 230, 0)
INK = (18, 6, 15)


def rounded(draw, box, r, fill, outline=None, width=0):
    draw.rounded_rectangle(box, radius=r, fill=fill, outline=outline, width=width)


def chevron(draw, pts, color, w):
    """Thick polyline with round caps and joints."""
    draw.line(pts, fill=color, width=w, joint="curve")
    for (x, y) in pts:
        draw.ellipse([x - w // 2, y - w // 2, x + w // 2, y + w // 2], fill=color)


def build(size, maskable=False):
    n = S * SS
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))

    # diagonal-ish ground gradient
    grad = Image.new("RGB", (1, n))
    gd = ImageDraw.Draw(grad)
    for y in range(n):
        t = y / (n - 1)
        gd.point((0, y), fill=tuple(
            int(GROUND_TOP[i] + (GROUND_BOT[i] - GROUND_TOP[i]) * t) for i in range(3)
        ))
    grad = grad.resize((n, n))

    # Maskable: the launcher applies its own mask, so the background must be
    # full-bleed square and the art confined to the inner ~80% safe zone.
    radius = 0 if maskable else int(112 / S * n)
    mask = Image.new("L", (n, n), 0)
    rounded(ImageDraw.Draw(mask), [0, 0, n - 1, n - 1], radius, 255)
    img.paste(grad, (0, 0), mask)

    d = ImageDraw.Draw(img)
    k = n / S                      # design units -> pixels
    scale = 0.80 if maskable else 1.0
    cx = cy = n / 2

    def P(x, y):
        return (cx + (x - 256) * k * scale, cy + (y - 256) * k * scale)

    def BOX(x, y, w, h):
        a = P(x, y); b = P(x + w, y + h)
        return [a[0], a[1], b[0], b[1]]

    def R(v):
        return int(v * k * scale)

    # card stack behind
    for box, fill, rot in (
        ((142, 150, 228, 228), PLUM_1, -9),
        ((150, 142, 228, 228), PLUM_2, 5),
    ):
        layer = Image.new("RGBA", (n, n), (0, 0, 0, 0))
        ld = ImageDraw.Draw(layer)
        rounded(ld, BOX(*box), R(34), fill + (235,), outline=LINE + (255,), width=max(1, R(4)))
        layer = layer.rotate(-rot, resample=Image.BICUBIC, center=(cx, cy))
        img.alpha_composite(layer)

    d = ImageDraw.Draw(img)

    # top card: split magenta / cyan on the diagonal
    card = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    cd = ImageDraw.Draw(card)
    rounded(cd, BOX(146, 138, 220, 220), R(34), MAGENTA + (255,))
    tri = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    td = ImageDraw.Draw(tri)
    td.polygon([P(146, 358), P(366, 138), P(366, 358)], fill=CYAN + (255,))
    cardmask = Image.new("L", (n, n), 0)
    rounded(ImageDraw.Draw(cardmask), BOX(146, 138, 220, 220), R(34), 255)
    card.paste(tri, (0, 0), Image.composite(cardmask, Image.new("L", (n, n), 0), tri.split()[3]))
    img.alpha_composite(card)

    d = ImageDraw.Draw(img)
    w = R(22)
    chevron(d, [P(232, 214), P(196, 248), P(232, 282)], INK, w)
    chevron(d, [P(280, 214), P(316, 248), P(280, 282)], INK, w)

    # hazard bar: the sponsored slot
    rounded(d, BOX(176, 392, 160, 26), R(13), YELLOW)

    return img.resize((size, size), Image.LANCZOS)


TARGETS = [
    ("icon-192.png", 192, False),
    ("icon-512.png", 512, False),
    ("icon-180.png", 180, False),          # apple-touch-icon
    ("icon-maskable-512.png", 512, True),
    ("favicon-32.png", 32, False),
]

for name, size, maskable in TARGETS:
    path = os.path.join(OUT, name)
    build(size, maskable).save(path)
    print("wrote", name, size)
