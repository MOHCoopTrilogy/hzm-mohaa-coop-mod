"""
HZM hi-DPI font generator for MOHAA RitualFont bitmap fonts.

Produces "<name>@3x" variants: same .RitualFont metrics (byte-identical copy of
vanilla -> zero layout drift; UVs are normalized, screen metrics are design-space),
plus a 4x-resolution glyph sheet TGA (1024-wide, power-of-two so the gl1 renderer
does not resample it).

Methods per font:
  - ttf:      re-render each glyph from a real Windows TrueType font with proper
              antialiasing, exact-fitted into the vanilla glyph's ink bounding box
              (scaled 4x). Guarantees identical layout/coverage, adds true detail.
              Used for verdana-* (verdana.ttf) and courier-* (cour.ttf) whose
              vanilla atlases are BILEVEL (1-bit, zero AA) -> the jagged menus.
  - upscale:  alpha-aware (premultiplied) Lanczos 4x + mild alpha unsharp +
              RGB dilation into transparent texels (halo prevention). Used for
              game-unique antialiased faces (facfont, handle, delima).
  - bilevel:  Lanczos 4x on alpha + smoothstep edge reconstruction. Used for the
              marlett symbol fonts (geometric widget glyphs, 1-bit vanilla).

Inputs:  vanilla/  (extracted from GOG paks by inspect/extract step; re-runnable)
Outputs: ../../fonts/<name>@3x.RitualFont  +  ../../gfx/fonts/<name>@3x.tga
         proof strips per font in out_preview/
Run:     python gen_hidpi_fonts.py
"""
import os
import shutil
import zipfile
import glob as globmod
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
# vanilla extracts + preview strips live OUTSIDE the mod tree: build.ps1 packs
# everything under hzm-mohaa-coop-mod (incl. _research) into shipping pk3s, and
# retail-extracted assets must never enter a redistributable pk3.
WORK = r'C:\mohaa-coop-dev\build_out\fontgen'
VAN = os.path.join(WORK, 'vanilla')
MOD_ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
OUT_FONTS = os.path.join(MOD_ROOT, 'fonts')
OUT_GFX = os.path.join(MOD_ROOT, 'gfx', 'fonts')
PREVIEW = os.path.join(WORK, 'out_preview')
SCALE = 4  # 4x keeps 1024-wide atlases power-of-two (gl1 force-resamples NPOT)

FONTS = {
    # name           method     ttf candidates (best density match wins)
    'verdana-12': ('ttf', ['verdana.ttf', 'verdanab.ttf']),
    'verdana-14': ('ttf', ['verdana.ttf', 'verdanab.ttf']),
    'courier-16': ('ttf', ['cour.ttf', 'courbd.ttf']),
    'courier-18': ('ttf', ['cour.ttf', 'courbd.ttf']),
    'courier-20': ('ttf', ['cour.ttf', 'courbd.ttf']),
    'facfont-20': ('ttf', ['bahnschrift.ttf']),   # HZM 07-28: USER CHOICE = Bahnschrift (DIN); sole candidate so the density matcher cannot override
    'handle-16': ('upscale', None),
    'handle-18': ('upscale', None),
    'handle-22': ('upscale', None),
    'handle-23': ('upscale', None),
    'delima-30': ('upscale', None),
    'marlett': ('bilevel', None),
    'marlett-20': ('bilevel', None),
}


def extract_vanilla():
    """Ensure vanilla RitualFont+tga pairs are present (pulled from GOG paks)."""
    os.makedirs(VAN, exist_ok=True)
    need = [n for n in FONTS
            if not (os.path.exists(os.path.join(VAN, n + '.RitualFont'))
                    and os.path.exists(os.path.join(VAN, n + '.tga')))]
    if not need:
        return
    paks = sorted(globmod.glob(r'G:\GOG\Medal of Honor - Allied Assault War Chest\main*\*.pk3'))
    for p in paks:
        if 'zzzzzz' in p.lower():
            continue  # vanilla only, never the mod's own paks
        z = zipfile.ZipFile(p)
        for entry in z.namelist():
            nl = entry.lower()
            base = os.path.splitext(os.path.basename(nl))[0]
            if base not in need:
                continue
            if nl.startswith('fonts/') and nl.endswith('.ritualfont'):
                dst = os.path.join(VAN, base + '.RitualFont')
                if not os.path.exists(dst):
                    open(dst, 'wb').write(z.read(entry))
            elif nl.startswith('gfx/fonts/') and nl.endswith('.tga'):
                dst = os.path.join(VAN, base + '.tga')
                if not os.path.exists(dst):
                    open(dst, 'wb').write(z.read(entry))


def parse_ritualfont(path):
    toks = open(path, 'r', errors='replace').read().replace('{', ' { ').replace('}', ' } ').split()
    it = iter(toks)
    height = aspect = None
    indir = None
    locs = None
    for t in it:
        tl = t.lower()
        if tl == 'height':
            height = float(next(it))
        elif tl == 'aspect':
            aspect = float(next(it))
        elif tl == 'indirections':
            assert next(it) == '{'
            indir = [int(next(it)) for _ in range(256)]
            assert next(it) == '}'
        elif tl == 'locations':
            assert next(it) == '{'
            locs = []
            for _ in range(256):
                assert next(it) == '{'
                x, y, w, h = (float(next(it)) for _ in range(4))
                assert next(it) == '}'
                locs.append((x, y, w, h))
            assert next(it) == '}'
    return {'height': height, 'aspect': aspect, 'indirection': indir, 'locations': locs}


def cell_px(loc, aspect, W, H):
    """RitualFont design-space cell -> pixel rect in the actual atlas.
    U = x/256 of width; V = y*aspect/256 of height (see R_LoadFont_sgl)."""
    x, y, w, h = loc
    return (x * W / 256.0, y * aspect * H / 256.0,
            w * W / 256.0, h * aspect * H / 256.0)


def ink_bbox(alpha, thresh=32):
    ys, xs = np.nonzero(alpha > thresh)
    if len(xs) == 0:
        return None
    return (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)  # x0,y0,x1,y1


def rgb_dilate(arr, passes=12):
    """Flood ink RGB outward into transparent texels so bilinear sampling never
    blends toward stale/black background colors (halo prevention)."""
    rgb = arr[..., :3].astype(np.float32)
    a = arr[..., 3].astype(np.float32)
    known = a > 8
    for _ in range(passes):
        if known.all():
            break
        # 3x3 neighborhood average of known pixels
        acc = np.zeros_like(rgb)
        cnt = np.zeros(a.shape, np.float32)
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                sh = np.roll(np.roll(rgb * known[..., None], dy, 0), dx, 1)
                sc = np.roll(np.roll(known.astype(np.float32), dy, 0), dx, 1)
                acc += sh
                cnt += sc
        newly = (~known) & (cnt > 0)
        rgb[newly] = acc[newly] / cnt[newly, None]
        known = known | newly
    out = arr.copy()
    out[..., :3] = np.clip(rgb + 0.5, 0, 255).astype(np.uint8)
    return out


def upscale_aa(img, scale, sharpen=True):
    """Alpha-aware premultiplied Lanczos upscale of an antialiased RGBA atlas."""
    arr = np.asarray(img.convert('RGBA')).astype(np.float32)
    a = arr[..., 3:4] / 255.0
    prem = arr.copy()
    prem[..., :3] *= a
    big = Image.fromarray(prem.astype(np.uint8), 'RGBA').resize(
        (img.width * scale, img.height * scale), Image.LANCZOS)
    barr = np.asarray(big).astype(np.float32)
    ba = np.clip(barr[..., 3], 0, 255)
    if sharpen:
        # mild unsharp on alpha only: re-crispen edges softened by the upscale
        aimg = Image.fromarray(ba.astype(np.uint8), 'L').filter(
            ImageFilter.UnsharpMask(radius=2, percent=70, threshold=0))
        ba = np.asarray(aimg).astype(np.float32)
    # unpremultiply
    with np.errstate(divide='ignore', invalid='ignore'):
        rgb = np.where(barr[..., 3:4] > 1,
                       barr[..., :3] / (barr[..., 3:4] / 255.0), 0)
    out = np.zeros(barr.shape, np.uint8)
    out[..., :3] = np.clip(rgb, 0, 255).astype(np.uint8)
    out[..., 3] = np.clip(ba, 0, 255).astype(np.uint8)
    return rgb_dilate(out)


def upscale_bilevel(img, scale):
    """1-bit source: Lanczos up + smoothstep contrast = vector-like edge rebuild."""
    arr = np.asarray(img.convert('RGBA'))
    a = Image.fromarray(arr[..., 3], 'L').resize(
        (img.width * scale, img.height * scale), Image.LANCZOS)
    af = np.asarray(a).astype(np.float32) / 255.0
    lo, hi = 0.35, 0.65
    t = np.clip((af - lo) / (hi - lo), 0, 1)
    af = t * t * (3 - 2 * t)
    out = np.zeros((a.height, a.width, 4), np.uint8)
    out[..., :3] = 255
    out[..., 3] = np.clip(af * 255 + 0.5, 0, 255).astype(np.uint8)
    return out


def render_ttf_atlas(name, ttf_candidates, rf, vanilla_img, scale):
    """Re-render every referenced glyph from a real TTF, exact-fitted into the
    vanilla ink bbox * scale. Falls back to bilevel-upscale per cell when the TTF
    render is empty but vanilla has ink."""
    W, H = vanilla_img.size
    van = np.asarray(vanilla_img.convert('RGBA'))
    out = np.zeros((H * scale, W * scale, 4), np.uint8)
    out[..., :3] = 255  # white everywhere; ink shape lives in alpha

    # cell -> representative character (first code pointing at it)
    cell_char = {}
    for code in range(32, 256):
        idx = rf['indirection'][code]
        if idx is None or idx < 0:
            continue
        if idx in cell_char:
            continue
        try:
            ch = bytes([code]).decode('cp1252')
        except UnicodeDecodeError:
            continue
        cell_char[idx] = ch

    RENDER_PX = 160  # supersampled master render size
    stats = {}
    for ttf in ttf_candidates:
        try:
            fnt = ImageFont.truetype(os.path.join(r'C:\Windows\Fonts', ttf), RENDER_PX)
        except OSError:
            continue
        # density check on 'HRBEo' vs vanilla to pick weight
        dens_diffs = []
        for probe in 'HRBEon':
            idx = rf['indirection'][ord(probe)]
            if idx is None or idx < 0:
                continue
            cx, cy, cw, chh = cell_px(rf['locations'][idx], rf['aspect'], W, H)
            cell = van[int(round(cy)):int(round(cy + chh)), int(round(cx)):int(round(cx + cw))]
            bb = ink_bbox(cell[..., 3])
            if bb is None:
                continue
            vdens = (cell[bb[1]:bb[3], bb[0]:bb[2], 3] > 127).mean()
            canvas = Image.new('L', (RENDER_PX * 3, RENDER_PX * 3), 0)
            d = ImageDraw.Draw(canvas)
            d.text((RENDER_PX, RENDER_PX), probe, font=fnt, fill=255)
            tb = ink_bbox(np.asarray(canvas))
            if tb is None:
                continue
            crop = canvas.crop(tb).resize((bb[2] - bb[0], bb[3] - bb[1]), Image.LANCZOS)
            tdens = (np.asarray(crop) > 127).mean()
            dens_diffs.append(abs(tdens - vdens))
        stats[ttf] = float(np.mean(dens_diffs)) if dens_diffs else 999.0
    if not stats:
        raise RuntimeError('no TTF candidates loadable for ' + name)
    best_ttf = min(stats, key=stats.get)
    fnt = ImageFont.truetype(os.path.join(r'C:\Windows\Fonts', best_ttf), RENDER_PX)

    fallbacks = []
    for idx, ch in sorted(cell_char.items()):
        cx, cy, cw, chh = cell_px(rf['locations'][idx], rf['aspect'], W, H)
        ix0, iy0 = int(round(cx)), int(round(cy))
        ix1, iy1 = int(round(cx + cw)), int(round(cy + chh))
        cell = van[iy0:iy1, ix0:ix1]
        vb = ink_bbox(cell[..., 3])
        if vb is None:
            continue  # blank cell (space etc.) stays blank
        tw, th = (vb[2] - vb[0]) * scale, (vb[3] - vb[1]) * scale

        canvas = Image.new('L', (RENDER_PX * 3, RENDER_PX * 3), 0)
        d = ImageDraw.Draw(canvas)
        d.text((RENDER_PX, RENDER_PX), ch, font=fnt, fill=255)
        tb = ink_bbox(np.asarray(canvas), thresh=8)
        if tb is None:
            fallbacks.append(ch)
            up = upscale_bilevel(Image.fromarray(cell, 'RGBA'), scale)
            oy, ox = iy0 * scale, ix0 * scale
            out[oy:oy + up.shape[0], ox:ox + up.shape[1]] = up
            continue
        glyph = canvas.crop(tb).resize((max(tw, 1), max(th, 1)), Image.LANCZOS)
        ga = np.asarray(glyph)
        # paste alpha into the atlas at vanilla-ink-bbox * scale, clipped to cell
        ox, oy = (ix0 + vb[0]) * scale, (iy0 + vb[1]) * scale
        cell_x1, cell_y1 = ix1 * scale, iy1 * scale
        pw = min(ga.shape[1], cell_x1 - ox)
        ph = min(ga.shape[0], cell_y1 - oy)
        region = out[oy:oy + ph, ox:ox + pw, 3]
        out[oy:oy + ph, ox:ox + pw, 3] = np.maximum(region, ga[:ph, :pw])
    return out, best_ttf, fallbacks


def save_tga(arr, path):
    """Write the EXACT vanilla MOHAA TGA layout: bare 18-byte header (no ID field),
    type 2 uncompressed, 32bpp BGRA, bottom-up rows, descriptor 0x00, NO footer.
    (PIL's writer adds a TRUEVISION-XFILE footer and sets descriptor alpha bits;
    the engine tolerates both, but byte-identical layout removes all doubt.)"""
    import struct
    h, w = arr.shape[:2]
    hdr = struct.pack('<BBBHHBHHHHBB', 0, 0, 2, 0, 0, 0, 0, 0, w, h, 32, 0)
    bgra = arr[::-1, :, [2, 1, 0, 3]]  # bottom-up rows, RGBA -> BGRA
    with open(path, 'wb') as f:
        f.write(hdr)
        f.write(np.ascontiguousarray(bgra).tobytes())


# Vanilla scripts/gfx.shader (Pak0) defines an explicit shader for every font sheet;
# WITHOUT one, R_FindShader builds a default OPAQUE shader and glyphs draw as solid
# black bars (observed in gl2, 2026-07-27). Ship identical bodies for the @3x names.
SHADER_OUT = os.path.join(MOD_ROOT, 'scripts', 'coop_fonts_hi3x.shader')
SHADER_BODY = """gfx/fonts/%(n)s
{
\tnopicmip
\tnomipmaps
\t{
\t\tmap gfx/fonts/%(n)s.tga
\t\tblendFunc GL_SRC_ALPHA GL_ONE_MINUS_SRC_ALPHA
\t\trgbGen identity%(extra)s
\t}
}
"""


def write_shader_script(names):
    blocks = []
    for n in names:
        # vanilla verdana-14 def additionally carries nodepthtest; mirror it
        extra = '\n\t\tnodepthtest' if n.startswith('verdana-14') else ''
        blocks.append(SHADER_BODY % {'n': n, 'extra': extra})
    with open(SHADER_OUT, 'w', newline='\n') as f:
        f.write('// HZM hi-DPI font shaders: @3x glyph sheets need the same explicit\n'
                '// shader bodies the vanilla fonts get in scripts/gfx.shader, otherwise\n'
                '// the renderer builds a default opaque shader -> solid black text.\n')
        f.write('\n'.join(blocks))


def preview_strip(rf, atlas_rgba, text, screen_scale=3.0, bg=(40, 44, 52)):
    """Simulate the engine draw: per glyph, sample the cell rect and bilinear-blit
    a quad of (w*scale x height*scale) screen pixels, exactly like R_DrawString."""
    A = Image.fromarray(atlas_rgba, 'RGBA') if isinstance(atlas_rgba, np.ndarray) else atlas_rgba
    W, H = A.size
    # atlas may be any density; UV mapping is normalized
    hgt = int(round(rf['height'] * screen_scale))
    xs = 4
    quads = []
    for ch in text:
        code = ord(ch)
        idx = rf['indirection'][code] if code < 256 else -1
        if ch == ' ' or idx is None or idx < 0:
            quads.append((None, int(round(6 * screen_scale))))
            continue
        x, y, w, h = rf['locations'][idx]
        u0, v0 = x / 256.0, y * rf['aspect'] / 256.0
        u1, v1 = u0 + w / 256.0, v0 + h * rf['aspect'] / 256.0
        src = A.crop((int(round(u0 * W)), int(round(v0 * H)),
                      int(round(u1 * W)), int(round(v1 * H))))
        dw = int(round(w * screen_scale))
        quad = src.resize((max(dw, 1), max(hgt, 1)), Image.BILINEAR)
        quads.append((quad, dw))
    total = sum(d for _, d in quads) + 2 * xs
    strip = Image.new('RGBA', (total, hgt + 8), bg + (255,))
    cx = xs
    for quad, dw in quads:
        if quad is not None:
            strip.alpha_composite(quad, (cx, 4))
        cx += dw
    return strip


def main():
    extract_vanilla()
    os.makedirs(OUT_FONTS, exist_ok=True)
    os.makedirs(OUT_GFX, exist_ok=True)
    os.makedirs(PREVIEW, exist_ok=True)
    report = []
    for name, (method, ttfs) in FONTS.items():
        rf_path = os.path.join(VAN, name + '.RitualFont')
        tga_path = os.path.join(VAN, name + '.tga')
        if not (os.path.exists(rf_path) and os.path.exists(tga_path)):
            report.append((name, method, 'MISSING VANILLA SOURCE - skipped'))
            continue
        rf = parse_ritualfont(rf_path)
        img = Image.open(tga_path).convert('RGBA')
        if method == 'ttf':
            arr, used, fb = render_ttf_atlas(name, ttfs, rf, img, SCALE)
            note = 'ttf=%s fallback_cells=%d' % (used, len(fb))
        elif method == 'bilevel':
            arr = upscale_bilevel(img, SCALE)
            note = 'bilevel reconstruct'
        else:
            arr = upscale_aa(img, SCALE)
            note = 'aa lanczos+unsharp'
        # write assets
        save_tga(arr, os.path.join(OUT_GFX, name + '@3x.tga'))
        shutil.copyfile(rf_path, os.path.join(OUT_FONTS, name + '@3x.RitualFont'))
        # per-font preview: old (vanilla atlas) vs new at 3x screen scale
        sample = 'SERVICE RECORD  Advanced GFX  Anisotropic Filter 0123'
        old = preview_strip(rf, np.asarray(img), sample)
        new = preview_strip(rf, arr, sample)
        pane = Image.new('RGBA', (max(old.width, new.width),
                                  old.height + new.height + 4), (25, 27, 31, 255))
        pane.alpha_composite(old, (0, 0))
        pane.alpha_composite(new, (0, old.height + 4))
        pane.save(os.path.join(PREVIEW, name + '_oldnew.png'))
        report.append((name, method, note + ' -> %dx%d' % (arr.shape[1], arr.shape[0])))
        print('%-12s %-8s %s' % (name, method, note))
    write_shader_script([n + '@3x' for n in FONTS])
    print('wrote', SHADER_OUT)
    print()
    for r in report:
        print(r)


if __name__ == '__main__':
    main()
