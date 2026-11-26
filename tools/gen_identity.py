"""Gera a identidade visual do ASCII Fish Pet (ícone, banners do instalador e do README).

Uso:  python tools/gen_identity.py
Requer: Pillow. Fontes: Consolas (Windows).
"""
import random
import shutil
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "installer" / "assets"
DOCS = ROOT / "docs"
FONT = "C:/Windows/Fonts/consolab.ttf"
FONT_REG = "C:/Windows/Fonts/consola.ttf"

BG_TOP = (10, 42, 54)
BG_BOT = (4, 18, 26)
FISH = (255, 184, 77)
ACCENT = (90, 200, 250)
PLANT = (63, 166, 107)
BUBBLE = (127, 180, 214)
FG = (154, 164, 174)


def gradient(size, top=BG_TOP, bot=BG_BOT):
    w, h = size
    im = Image.new("RGB", size)
    d = ImageDraw.Draw(im)
    for y in range(h):
        t = y / max(1, h - 1)
        d.line([(0, y), (w, y)], fill=tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3)))
    return im


def font(size, path=FONT):
    return ImageFont.truetype(path, size)


def fit_text(draw, text, width, path=FONT):
    size = 10
    while draw.textlength(text, font=font(size + 2, path)) <= width:
        size += 2
    return font(size, path)


def draw_fish(img, box, text="<o)))><", color=FISH, glow=True):
    """Desenha o peixe ASCII centralizado dentro de box=(x0,y0,x1,y1)."""
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img)
    f = fit_text(d, text, x1 - x0)
    bb = d.textbbox((0, 0), text, font=f)
    w, h = bb[2] - bb[0], bb[3] - bb[1]
    x = x0 + (x1 - x0 - w) / 2 - bb[0]
    y = y0 + (y1 - y0 - h) / 2 - bb[1]
    if glow:
        from PIL import ImageFilter
        g = Image.new("RGBA", img.size, (0, 0, 0, 0))
        ImageDraw.Draw(g).text((x, y), text, font=f, fill=color + (150,))
        g = g.filter(ImageFilter.GaussianBlur(max(2, f.size // 8)))
        img.paste(g, (0, 0), g)
        d = ImageDraw.Draw(img)
    d.text((x, y), text, font=f, fill=color)
    return f


def make_icon(size=1024):
    img = gradient((size, size)).convert("RGBA")
    d = ImageDraw.Draw(img)
    # bolhas
    rnd = random.Random(7)
    for cx, cy, r in [(0.72, 0.28, 0.035), (0.80, 0.18, 0.025), (0.66, 0.15, 0.018)]:
        d.ellipse([cx * size - r * size, cy * size - r * size, cx * size + r * size, cy * size + r * size],
                  outline=BUBBLE, width=max(2, size // 90))
    # alga
    f = font(int(size * 0.16))
    for i, ch in enumerate(")(\n"[:2]):
        pass
    for i in range(3):
        d.text((size * 0.10 + (i % 2) * size * 0.03, size * (0.62 + i * 0.1)), ")" if i % 2 else "(", font=f, fill=PLANT)
    draw_fish(img, (size * 0.08, size * 0.33, size * 0.92, size * 0.67))
    # areia
    d.rectangle([0, size * 0.90, size, size], fill=(107, 91, 69))
    # máscara arredondada
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, size - 1, size - 1], radius=int(size * 0.22), fill=255)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(img, (0, 0), mask)
    return out


def paste_logo(img, width, center_x=None, y=0, right=None):
    """Cola a logo da Whiskline (branca/verde, ideal p/ fundo escuro) com largura `width`."""
    logo = Image.open(ASSETS / "whiskline.png").convert("RGBA")
    logo = logo.crop(logo.getbbox())
    logo = logo.resize((width, int(logo.height * width / logo.width)), Image.LANCZOS)
    x = right - width if right is not None else int(center_x - width / 2)
    img.paste(logo, (x, y), logo)


def make_wizard_large(scale=1):
    """164x314 (x scale): peixe grande, título em 3 linhas e logo, sem poluição."""
    w, h = 164, 314
    s = 6 * 2
    img = gradient((w * s, h * s)).convert("RGBA")
    d = ImageDraw.Draw(img)
    # poucas bolhas, só no topo
    for cx, cy, r in [(118, 30, 6), (132, 52, 3.5), (104, 64, 2.5)]:
        d.ellipse([(cx - r) * s, (cy - r) * s, (cx + r) * s, (cy + r) * s], outline=BUBBLE, width=max(1, s // 3))
    # peixe
    draw_fish(img, (14 * s, 84 * s, (w - 14) * s, 124 * s))
    # título
    for i, (t, c) in enumerate([("ASCII", (233, 254, 255)), ("FISH", (233, 254, 255)), ("PET", ACCENT)]):
        f = fit_text(d, t, 112 * s)
        f = font(min(f.size, 30 * s))
        bb = d.textbbox((0, 0), t, font=f)
        d.text(((w * s - (bb[2] - bb[0])) / 2 - bb[0], (148 + i * 34) * s), t, font=f, fill=c)
    # divisória de capim + logo
    fs = font(9 * s, FONT_REG)
    line = "^v" * 20
    d.text(((w * s - d.textlength(line, font=fs)) / 2, 238 * s), line, font=fs, fill=PLANT)
    paste_logo(img, 104 * s, center_x=w * s / 2, y=260 * s)
    return img.resize((round(w * scale), round(h * scale)), Image.LANCZOS).convert("RGB")


def make_wizard_small():
    """55x55: cabeçalho do instalador (fundo branco no tema moderno)."""
    s = 8
    icon = make_icon(55 * s).resize((55, 55), Image.LANCZOS)
    bg = Image.new("RGB", (55, 55), (255, 255, 255))
    bg.paste(icon, (0, 0), icon)
    return bg


def make_banner(w=1280, h=400):
    img = gradient((w, h)).convert("RGBA")
    d = ImageDraw.Draw(img)
    rnd = random.Random(11)
    fb = font(26, FONT_REG)
    for _ in range(40):
        x, y = rnd.randint(0, w), rnd.randint(0, h - 80)
        if (40 < x < 980 and 40 < y < 345) or (x > 900 and y < 160):
            continue
        d.text((x, y), rnd.choice("o°.O"), font=fb, fill=BUBBLE + (120,))
    for x in range(0, w, 18):
        d.text((x, h - 70 + (x // 18 % 2) * 6), "^" if (x // 18) % 3 else "|", font=fb, fill=PLANT)
    d.rectangle([0, h - 28, w, h], fill=(107, 91, 69))
    draw_fish(img, (60, 70, 560, 190), "<o)))><")
    draw_fish(img, (700, 230, 940, 290), "><(((º>", color=ACCENT, glow=False)
    f = font(76)
    d.text((60, 205), "ASCII Fish Pet", font=f, fill=(233, 254, 255))
    d.text((64, 305), "um aquário que vive na sua área de trabalho", font=font(26, FONT_REG), fill=FG)
    paste_logo(img, 260, right=w - 50, y=40)
    return img.convert("RGB")


def main():
    ASSETS.mkdir(parents=True, exist_ok=True)
    DOCS.mkdir(exist_ok=True)
    icon = make_icon(1024)
    icon.resize((512, 512), Image.LANCZOS).save(ASSETS / "app_icon.png")
    sizes = [16, 24, 32, 48, 64, 128, 256]
    ico = ASSETS / "app_icon.ico"
    icon.save(ico, sizes=[(s, s) for s in sizes])
    for sc, suf in [(1, ""), (1.5, "-150"), (2, "-200")]:
        make_wizard_large(sc).save(ASSETS / f"wizard-large{suf}.bmp")
    make_wizard_small().save(ASSETS / "wizard-small.bmp")
    make_banner().save(DOCS / "banner.png")
    for dest in [ROOT / "windows/runner/resources/app_icon.ico", ROOT / "assets/app_icon.ico"]:
        shutil.copy(ico, dest)
    print("ok")


if __name__ == "__main__":
    main()
