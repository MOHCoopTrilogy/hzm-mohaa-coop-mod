"""FRANCHISE-WIDE HD ground seam repair (user 2026-07-28: "it may not hurt to roll it out
across the franchise").

Same measured defect as the e2l2 pass: AA_HD_Project / dds upscales of TILING ground art do not
wrap, so every tile boundary reads as a crisp line (vanilla 512s hid it in noise). This script
does the whole trilogy at once:

  1. read every maps/*.bsp in the installed paks and pull the texture names each map references
     (regex over printable "textures/..." strings - the EALA v21 lump directory is not Q3-shaped)
  2. keep the ground/terrain-ish TILING names (skip sky, portals, decals, sprites, models, UI)
  3. for each, take the highest-resolution DEPLOYED version (what the player actually sees)
  4. measure the edge-wrap ratio; fix only those that measurably regressed (> THRESH)
  5. mirror-blend the edges so opposite edges converge (interior untouched), preserving ALPHA
     when the texture actually uses it (DXT5), else DXT1
  6. pack zzzzzzzz_hd_seamfix.pk3 (8 z's = sorts after every HD pack) and report before/after

Verification is the measurement itself: a fixed texture reports 0.0/0.0 (bit-continuous wrap).
"""
import os, sys, io, re, glob, zipfile
import numpy as np
from PIL import Image

sys.path.insert(0, r'C:\mohaa-coop-dev\_hd_staging\_work')
from hd_dds_build import write_dds

HERE = os.path.dirname(os.path.abspath(__file__))
PK3ROOT = os.path.join(HERE, 'seampk3')
PK3OUT = os.path.join(HERE, 'zzzzzzzz_hd_seamfix.pk3')
GOG = r'G:\GOG\Medal of Honor - Allied Assault War Chest'
PAKS = []
for sub in ('main', 'mainta', 'maintt'):
    PAKS += sorted(glob.glob(os.path.join(GOG, sub, '*.pk3')))

THRESH = 1.5          # wrap ratio above this = visible seam worth fixing
BAND_FRAC = 0.04

TILING_HINT = re.compile(
    r'terrain|ground|dirt|grass|road|field|hay|straw|mud|sand|gravel|earth|soil|snow|'
    r'cobble|pavement|stone_floor|floor|rubble|path', re.I)
SKIP = re.compile(
    r'sky|portal|decal|sprite|models/|hud|menu|font|shader|caulk|clip|trigger|'
    r'water|lava|fog|light|glow|blood|flame|smoke', re.I)


def ratios(a):
    vs = np.abs(a[:, -1, :3] - a[:, 0, :3]).mean()
    hs = np.abs(a[-1, :, :3] - a[0, :, :3]).mean()
    vb = np.abs(a[:, 1:, :3] - a[:, :-1, :3]).mean()
    hb = np.abs(a[1:, :, :3] - a[:-1, :, :3]).mean()
    return vs / max(vb, 0.5), hs / max(hb, 0.5)


def self_tile(a):
    h, w, _ = a.shape

    def ramp(n, band):
        i = np.arange(n, dtype=np.float32)
        d = np.minimum(i, n - 1 - i)
        return 0.5 * np.clip(1.0 - d / float(band - 1), 0.0, 1.0)

    wx = ramp(w, max(4, int(w * BAND_FRAC)))[None, :, None]
    a = a * (1.0 - wx) + a[:, ::-1, :] * wx
    wy = ramp(h, max(4, int(h * BAND_FRAC)))[:, None, None]
    a = a * (1.0 - wy) + a[::-1, :, :] * wy
    return a


def map_textures():
    used = set()
    maps = 0
    for pk in PAKS:
        try:
            z = zipfile.ZipFile(pk)
        except Exception:
            continue
        for n in z.namelist():
            if not n.lower().endswith('.bsp'):
                continue
            maps += 1
            try:
                d = z.read(n)
            except Exception:
                continue
            for m in re.findall(rb'textures/[A-Za-z0-9_/\-\.]{3,90}', d):
                s = m.decode('ascii', 'ignore')
                s = os.path.splitext(s)[0].lower()
                used.add(s)
    return used, maps


def best_source(base):
    best = None
    for pk in PAKS:
        try:
            z = zipfile.ZipFile(pk)
        except Exception:
            continue
        for n in z.namelist():
            nl = n.lower()
            if os.path.splitext(nl)[0] != base:
                continue
            if not nl.endswith(('.jpg', '.tga', '.png', '.dds')):
                continue
            try:
                im = Image.open(io.BytesIO(z.read(n)))
                im.load()
            except Exception:
                continue
            px = im.size[0] * im.size[1]
            if not best or px > best[0]:
                best = (px, im, os.path.basename(pk))
    return best


def main():
    used, maps = map_textures()
    print('scanned %d bsp files -> %d referenced textures' % (maps, len(used)))
    cands = sorted(b for b in used if TILING_HINT.search(b) and not SKIP.search(b))
    print('tiling ground-ish candidates: %d' % len(cands))

    if os.path.isdir(PK3ROOT):
        for root, _, files in os.walk(PK3ROOT):
            for f in files:
                os.remove(os.path.join(root, f))

    fixed = skipped = 0
    for base in cands:
        src = best_source(base)
        if not src:
            continue
        _, im, pk = src
        has_alpha = im.mode in ('RGBA', 'LA') and im.getextrema()[-1][0] < 255
        arr = np.asarray(im.convert('RGBA' if has_alpha else 'RGB'), dtype=np.float32)
        before = ratios(arr)
        if max(before) < THRESH:
            skipped += 1
            continue
        out = self_tile(arr)
        after = ratios(out)
        img = Image.fromarray(np.clip(out, 0, 255).astype(np.uint8),
                              'RGBA' if has_alpha else 'RGB')
        os.makedirs(os.path.join(PK3ROOT, os.path.dirname(base)), exist_ok=True)
        write_dds(img, os.path.join(PK3ROOT, base + '.dds'), 'DXT5' if has_alpha else 'DXT1')
        if has_alpha:
            img.save(os.path.join(PK3ROOT, base + '.tga'))
        else:
            img.convert('RGB').save(os.path.join(PK3ROOT, base + '.jpg'), quality=94)
        fixed += 1
        print('%-52s %-10s %s  %.1f/%.1f -> %.1f/%.1f  [%s]'
              % (base, '%dx%d' % im.size, 'A' if has_alpha else ' ',
                 before[0], before[1], after[0], after[1], pk))

    if os.path.exists(PK3OUT):
        os.remove(PK3OUT)
    with zipfile.ZipFile(PK3OUT, 'w', zipfile.ZIP_DEFLATED) as z:
        for root, _, files in os.walk(PK3ROOT):
            for f in files:
                full = os.path.join(root, f)
                z.write(full, os.path.relpath(full, PK3ROOT).replace('\\', '/'))
    print('\nfixed %d, already-clean %d -> %s' % (fixed, skipped, PK3OUT))


if __name__ == '__main__':
    main()
