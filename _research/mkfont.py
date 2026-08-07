"""Regenerate a MOHAA RitualFont glyph atlas from a TTF, preserving the existing metrics exactly.

Why this works without touching the .RitualFont file at all:
  RitualFont locations are DESIGN-SPACE rects (a 256-wide space; v = y*aspect/256), parsed into
  normalized UVs at load. The shipped @3x atlas is 1024x512 = exactly 4x that 256x128 design space.
  So as long as every glyph is redrawn INSIDE its existing cell rect, the engine's advance widths,
  line height and UV math are all unchanged - only the ink inside each cell differs. That means a
  typeface swap needs ZERO metric edits and ZERO .urc changes (same rule that made the earlier HD
  upscales safe).

Consequence worth knowing: advance widths stay those of the ORIGINAL font, so this is a reskin,
not a re-metric. A condensed face (Oswald) sits comfortably inside the old wider cells; a wider
face would clip. Glyphs are drawn on a single shared baseline so letters line up properly rather
than each being independently stretched to its box.

RGB is forced pure white and the glyph lives in ALPHA - that's how the stock sheets are authored
and how the font shader samples them.
"""
import sys, re, os
from PIL import Image, ImageDraw, ImageFont

def parse_ritualfont(path):
    txt = open(path, 'r', encoding='latin-1').read()
    height = float(re.search(r'^height\s+([\d.]+)', txt, re.M).group(1))
    aspect = float(re.search(r'^aspect\s+([\d.]+)', txt, re.M).group(1))
    ind_txt = re.search(r'indirections\s*\{(.*?)\}', txt, re.S).group(1)
    indirections = [int(v) for v in ind_txt.split()]
    # NB: the locations block CONTAINS nested { } tuples, so a non-greedy match to the first '}'
    # would stop inside the very first entry - take everything from the keyword to end of file
    # and let the 4-float tuple pattern pick out the entries.
    loc_txt = txt[re.search(r'locations\s*\{', txt).end():]
    locs = [tuple(float(v) for v in m)
            for m in re.findall(r'\{\s*([\d.-]+)\s+([\d.-]+)\s+([\d.-]+)\s+([\d.-]+)\s*\}', loc_txt)]
    return height, aspect, indirections, locs

def build(ttf_path, ritual_path, out_tga, atlas_w, atlas_h, size_scale=1.0, preview=None):
    height, aspect, indirections, locs = parse_ritualfont(ritual_path)
    # design space is 256 wide; v = y*aspect/256 so design height = 256/aspect
    design_w = 256.0
    design_h = 256.0 / aspect
    sx = atlas_w / design_w
    sy = atlas_h / design_h

    # map location index -> the character that uses it (first wins; codes are latin-1)
    idx_char = {}
    for code, li in enumerate(indirections):
        if li >= 0 and li not in idx_char:
            idx_char[li] = code

    cell_h_px = max(1, int(round(height * sy)))
    # pick the largest font size whose ascent+descent still fits the cell, then apply size_scale
    fsize = cell_h_px
    while fsize > 4:
        f = ImageFont.truetype(ttf_path, fsize)
        a, d = f.getmetrics()
        if a + d <= cell_h_px:
            break
        fsize -= 1
    fsize = max(4, int(fsize * size_scale))
    font = ImageFont.truetype(ttf_path, fsize)
    ascent, descent = font.getmetrics()

    alpha = Image.new('L', (atlas_w, atlas_h), 0)

    drawn = clipped = 0
    for li, (x, y, w, h) in enumerate(locs):
        if w <= 0 or h <= 0:
            continue
        ch = idx_char.get(li)
        if ch is None:
            continue
        s = bytes([ch]).decode('latin-1')
        if not s.strip():
            continue

        X, Y = int(round(x * sx)), int(round(y * sy))
        W, H = int(round(w * sx)), int(round(h * sy))
        if W <= 0 or H <= 0:
            continue

        # render the glyph on its own, oversized canvas so nothing is cut off
        pad = fsize
        tmp = Image.new('L', (fsize * 3 + pad * 2, ascent + descent + pad * 2), 0)
        ImageDraw.Draw(tmp).text((pad, pad), s, font=font, fill=255)
        bb = tmp.getbbox()
        if bb is None:
            continue
        glyph = tmp.crop(bb)
        gw, gh = glyph.size

        # Fit the glyph to its cell WITHOUT breaking the shared baseline:
        #  - too tall  -> uniform scale (rare; preserves letterform, shifts baseline slightly)
        #  - too wide  -> HORIZONTAL squeeze only (keeps height + baseline exactly intact)
        # A couple of slightly-condensed wide caps (W/M/@/%) reads far better than a font where
        # every rescaled glyph sits on its own baseline (that shows up as random letters looking
        # superscripted mid-word).
        vscale = 1.0
        if gh > H:
            vscale = H / gh
            gw2, gh2 = max(1, int(gw * vscale)), max(1, int(gh * vscale))
            glyph = glyph.resize((gw2, gh2), Image.LANCZOS)
            gw, gh = gw2, gh2
            clipped += 1
        if gw > W:
            glyph = glyph.resize((max(1, W), gh), Image.LANCZOS)
            gw = W
            clipped += 1

        # shared baseline: place by the glyph's offset from the common text-top, so letters align
        top_in_tmp = bb[1] - pad          # glyph top relative to the text origin
        py = Y + int(round(top_in_tmp * vscale))
        # keep the ink inside its own cell no matter what
        py = max(Y, min(py, Y + H - gh))
        px = X + max(0, (W - gw) // 2)

        alpha.paste(glyph, (px, py))
        drawn += 1

    rgb = Image.new('RGB', (atlas_w, atlas_h), (255, 255, 255))
    out = Image.merge('RGBA', (*rgb.split(), alpha))
    out.save(out_tga)
    print(f"  {os.path.basename(out_tga)}: {drawn} glyphs (size {fsize}px, {clipped} scaled to fit)")

    if preview:
        pv = Image.new('RGB', (atlas_w, 260), (20, 20, 28))
        pv.paste((255, 255, 255), mask=alpha.crop((0, 0, atlas_w, 260)))
        pv.save(preview)

if __name__ == '__main__':
    ttf = sys.argv[1]
    ritual = sys.argv[2]
    out = sys.argv[3]
    aw, ah = int(sys.argv[4]), int(sys.argv[5])
    scale = float(sys.argv[6]) if len(sys.argv) > 6 else 1.0
    prev = sys.argv[7] if len(sys.argv) > 7 else None
    build(ttf, ritual, out, aw, ah, scale, prev)
