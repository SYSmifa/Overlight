#!/usr/bin/env python3
"""Overlight - esporta le icone dell'app da un'immagine quadrata (simbolo bianco su blu scuro).

Uso: python3 export_app_icons.py SORGENTE.png OUTDIR
"""
import sys, os
import numpy as np
from PIL import Image, ImageDraw

SRC, OUT = sys.argv[1], sys.argv[2]
BG = (7, 16, 51)
SAFE = 0.60

src = Image.open(SRC).convert('RGB')
S = 1024
full = src.resize((S, S), Image.LANCZOS)

a = np.asarray(src, float)
# symbol = everything that is not the background; it keeps its own colours (cyan ring, white ship, magenta trails)
bgarr = np.array(BG, float)
dist = np.abs(a - bgarr).max(axis=2)
alpha = np.clip(dist / 120.0, 0, 1)
ys, xs = np.where(alpha > 0.5)
x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
cx, cy, d = (x0 + x1) / 2, (y0 + y1) / 2, max(x1 - x0, y1 - y0)
al = alpha[..., None]
rgb = np.clip((a - (1 - al) * bgarr) / np.maximum(al, 1e-3), 0, 255)
sym = Image.fromarray(np.dstack([rgb, alpha * 255]).astype(np.uint8), 'RGBA')
side = d / SAFE
box = (int(cx - side / 2), int(cy - side / 2), int(cx + side / 2), int(cy + side / 2))
fg = sym.crop(box).resize((S, S), Image.LANCZOS)
bg = Image.new('RGB', (S, S), BG)
comp = bg.convert('RGBA'); comp.alpha_composite(fg)

def mk(path): os.makedirs(os.path.dirname(path), exist_ok=True); return path

full.save(mk(f'{OUT}/assets/icon-only.png'))
fg.save(f'{OUT}/assets/icon-foreground.png')
bg.save(f'{OUT}/assets/icon-background.png')

full.resize((512, 512), Image.LANCZOS).save(mk(f'{OUT}/stores/play-store-512.png'))
full.convert('RGB').save(f'{OUT}/stores/app-store-1024.png')

legacy = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}
adaptive = {k: v * 108 // 48 for k, v in legacy.items()}
for dens, px in legacy.items():
    sq = Image.new('RGBA', (px, px), (0, 0, 0, 0))
    m = Image.new('L', (px * 4, px * 4), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, px * 4 - 1, px * 4 - 1], radius=int(px * 4 * 0.2), fill=255)
    m = m.resize((px, px), Image.LANCZOS)
    sq.paste(full.resize((px, px), Image.LANCZOS), (0, 0), m)
    sq.save(mk(f'{OUT}/android/res/mipmap-{dens}/ic_launcher.png'))
    rm = Image.new('L', (px * 4, px * 4), 0)
    ImageDraw.Draw(rm).ellipse([0, 0, px * 4 - 1, px * 4 - 1], fill=255)
    rm = rm.resize((px, px), Image.LANCZOS)
    rd = Image.new('RGBA', (px, px), (0, 0, 0, 0))
    rd.paste(comp.resize((px, px), Image.LANCZOS), (0, 0), rm)
    rd.save(f'{OUT}/android/res/mipmap-{dens}/ic_launcher_round.png')
    ap = adaptive[dens]
    fg.resize((ap, ap), Image.LANCZOS).save(f'{OUT}/android/res/mipmap-{dens}/ic_launcher_foreground.png')

xml = '''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
'''
os.makedirs(f'{OUT}/android/res/mipmap-anydpi-v26', exist_ok=True)
for n in ('ic_launcher', 'ic_launcher_round'):
    open(f'{OUT}/android/res/mipmap-anydpi-v26/{n}.xml', 'w').write(xml)
os.makedirs(f'{OUT}/android/res/values', exist_ok=True)
open(f'{OUT}/android/res/values/ic_launcher_background.xml', 'w').write(
    '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n    <color name="ic_launcher_background">#%02X%02X%02X</color>\n</resources>\n' % BG)

sheet = Image.new('RGB', (3 * 360 + 80, 400), (30, 30, 36))
for i, (img, mode) in enumerate(((full, 'round'), (comp, 'circle'), (comp, 'squircle'))):
    t = img.resize((340, 340), Image.LANCZOS).convert('RGBA')
    m = Image.new('L', (340, 340), 0); dd = ImageDraw.Draw(m)
    if mode == 'circle': dd.ellipse([0, 0, 339, 339], fill=255)
    else: dd.rounded_rectangle([0, 0, 339, 339], radius=int(340 * (0.225 if mode == 'round' else 0.3)), fill=255)
    sheet.paste(t, (20 + i * 360, 30), m)
sheet.save(f'{OUT}/preview.png')
print('ok')
