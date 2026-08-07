"""HD ground SEAM repair (user report 2026-07-28: "VERY obvious where this ground texture
has seams together").

Root cause (measured, not guessed): the AA_HD_Project upscales of e2l2's ground textures do
not wrap. Vanilla 512s hid the mismatch in noise; the 2048 upscales turn it into a crisp
line every tile. Measured edge-vs-interior ratio, vanilla -> HD:
    misc_outside/bocroad_full      1.0 / 0.8  ->  2.4 / 2.4     (the dirt path)
    misc_outside/bocroad_fulladam  1.3 / 0.7  ->  2.8 / 2.1
    wilderness/m3l3grass_1         0.9 / 1.0  ->  1.8 / 2.1
    wilderness/m3l3grass_1blast    1.4 / 1.3  ->  3.0 / 2.9
    wilderness/m3l3grass_1rough    1.1 / 1.0  ->  2.1 / 2.1
    wilderness/m3l3grass_1trans    1.0 / 1.7  ->  2.0 / 3.4
(ratio ~1 = the seam is indistinguishable from ordinary interior detail = invisible.)

Fix = the self-tiling mirror-blend band from the earlier seam work: near each edge, cross-fade
the image with its mirror so opposite edges converge, leaving the interior untouched. Output is
DXT .dds (the engine prefers .dds over .jpg/.tga, so only a .dds can win) plus a matching .jpg,
packed as zzzzzzzz_hd_seamfix.pk3 (8 z's -> sorts after every HD pack, and it must land in the
HOMEPATH too since homepath paks outrank all basepath paks).

Only textures e2l2 actually references are touched (list extracted from maps/e2l2.bsp), and only
those whose HD version measurably regressed vs vanilla.
"""
import os, sys, io, glob, zipfile
import numpy as np
from PIL import Image

sys.path.insert(0, r'C:\mohaa-coop-dev\_hd_staging\_work')
from hd_dds_build import write_dds

HERE = os.path.dirname(os.path.abspath(__file__))
PK3ROOT = os.path.join(HERE, 'seampk3')
PK3OUT = os.path.join(HERE, 'zzzzzzzz_hd_seamfix.pk3')
SEARCH = [r'G:\mohaa-gl2\maintt\*.pk3', r'G:\mohaa-gl2\main\*.pk3']

# entry path (lowercase, no extension) -> which axes tile and must be blended
TARGETS = {
    'textures/misc_outside/bocroad_full':     'both',
    'textures/misc_outside/bocroad_fulladam': 'both',
    'textures/wilderness/m3l3grass_1':        'both',
    'textures/wilderness/m3l3grass_1blast':   'both',
    'textures/wilderness/m3l3grass_1rough':   'both',
    'textures/wilderness/m3l3grass_1trans':   'both',
}
BAND_FRAC = 0.04          # blend band = 4% of the edge length (81px on a 2048)


def ratios(img):
    a = np.asarray(img.convert('RGB'), dtype=np.float32)
    vs = np.abs(a[:, -1, :] - a[:, 0, :]).mean()
    hs = np.abs(a[-1, :, :] - a[0, :, :]).mean()
    vb = np.abs(a[:, 1:, :] - a[:, :-1, :]).mean()
    hb = np.abs(a[1:, :, :] - a[:-1, :, :]).mean()
    return vs / max(vb, 0.5), hs / max(hb, 0.5)


def make_self_tiling(img, axes='both'):
    """Cross-fade each edge band with the mirrored opposite edge so the wrap is continuous.
    Interior (everything past the band) is bit-identical to the input."""
    a = np.asarray(img.convert('RGB'), dtype=np.float32)
    h, w, _ = a.shape

    def ramp(n, band):
        """weight 0.5 AT the edge falling to 0 `band` pixels in, on both ends."""
        i = np.arange(n, dtype=np.float32)
        d = np.minimum(i, n - 1 - i)                    # distance to nearest edge
        return 0.5 * np.clip(1.0 - d / float(band - 1), 0.0, 1.0)

    if axes in ('both', 'x'):
        bw = max(4, int(w * BAND_FRAC))
        wx = ramp(w, bw)[None, :, None]
        # blending with the horizontally mirrored image makes column 0 and column w-1
        # average to the SAME value, so the wrap is continuous by construction
        a = a * (1.0 - wx) + a[:, ::-1, :] * wx
    if axes in ('both', 'y'):
        bh = max(4, int(h * BAND_FRAC))
        wy = ramp(h, bh)[:, None, None]
        a = a * (1.0 - wy) + a[::-1, :, :] * wy
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), 'RGB')


def newest_source(base):
    """Highest-resolution deployed version of this texture (that is what the player sees)."""
    best = None
    for pat in SEARCH:
        for pk in glob.glob(pat):
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
                    best = (px, im.convert('RGB'), n, os.path.basename(pk))
    return best


def main():
    if os.path.isdir(PK3ROOT):
        for root, _, files in os.walk(PK3ROOT):
            for f in files:
                os.remove(os.path.join(root, f))
    made = []
    for base, axes in TARGETS.items():
        src = newest_source(base)
        if not src:
            print('MISSING', base)
            continue
        _, img, entry, pk = src
        before = ratios(img)
        fixed = make_self_tiling(img, axes)
        after = ratios(fixed)
        outdir = os.path.join(PK3ROOT, os.path.dirname(base))
        os.makedirs(outdir, exist_ok=True)
        write_dds(fixed, os.path.join(PK3ROOT, base + '.dds'), 'DXT1')
        fixed.save(os.path.join(PK3ROOT, base + '.jpg'), quality=94)
        made.append(base)
        print('%-42s %-9s %dx%d  seam %.1f/%.1f -> %.1f/%.1f   [%s]'
              % (base, axes, img.size[0], img.size[1], before[0], before[1],
                 after[0], after[1], pk))

    if os.path.exists(PK3OUT):
        os.remove(PK3OUT)
    with zipfile.ZipFile(PK3OUT, 'w', zipfile.ZIP_DEFLATED) as z:
        for root, _, files in os.walk(PK3ROOT):
            for f in files:
                full = os.path.join(root, f)
                z.write(full, os.path.relpath(full, PK3ROOT).replace('\\', '/'))
    print('\npacked %d textures -> %s' % (len(made), PK3OUT))


if __name__ == '__main__':
    main()
