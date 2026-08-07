"""Compose proof.png: old (vanilla atlas) vs new (@3x atlas) sample strings at
3x screen scale (= what a 3440x1440 uniform-scaled menu draws), per key font."""
import os
import numpy as np
from PIL import Image, ImageDraw

import gen_hidpi_fonts as G

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, 'proof.png')

SAMPLES = ['SERVICE RECORD', 'ADVANCED GFX', 'Anisotropic Filter']
FONTS = ['facfont-20', 'courier-16', 'verdana-12', 'verdana-14', 'handle-23']

rows = []
maxw = 0
for name in FONTS:
    rf = G.parse_ritualfont(os.path.join(G.VAN, name + '.RitualFont'))
    old_atlas = np.asarray(Image.open(os.path.join(G.VAN, name + '.tga')).convert('RGBA'))
    new_atlas = np.asarray(Image.open(os.path.join(G.OUT_GFX, name + '@3x.tga')).convert('RGBA'))
    text = '   '.join(SAMPLES)
    old = G.preview_strip(rf, old_atlas, text)
    new = G.preview_strip(rf, new_atlas, text)
    rows.append((name, old, new))
    maxw = max(maxw, old.width, new.width)

LABEL_W = 150
pad = 6
row_h = sum(o.height + n.height + 2 * pad + 22 for _, o, n in rows)
sheet = Image.new('RGBA', (LABEL_W + maxw + 2 * pad, row_h + pad), (18, 20, 24, 255))
d = ImageDraw.Draw(sheet)
y = pad
for name, old, new in rows:
    d.text((8, y + 4), name, fill=(255, 210, 120, 255))
    d.text((8, y + 20), 'old | new', fill=(150, 150, 150, 255))
    sheet.alpha_composite(old, (LABEL_W, y))
    sheet.alpha_composite(new, (LABEL_W, y + old.height + 4))
    y += old.height + new.height + 2 * pad + 22
    d.line([(0, y - pad), (sheet.width, y - pad)], fill=(60, 60, 70, 255))
sheet.convert('RGB').save(OUT)
print('wrote', OUT, sheet.size)
