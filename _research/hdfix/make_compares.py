"""Build side-by-side stock vs HD comparison crops for the m3l2 courtyard ground family.
Left = stock (512) upscaled to match; Right = HD pack version, same texel region.
Output: compare_<name>.png in this directory."""
import os
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
WORK = os.path.join(HERE, 'work')

PAIRS = [
    # name, stock file, hd file
    ('m3l3grass_bocroad_new', 'm3l3grass_bocroad_new.jpg', 'm3l3grass_bocroad_new.dds'),
    ('m3l3grass_1rough',      'm3l3grass_1rough.jpg',      'm3l3grass_1rough.dds'),
    ('m3l3grass_1',           'm3l3grass_1.jpg',           'm3l3grass_1.dds'),
    ('m3l3grass_1trans',      'm3l3grass_1trans.jpg',      'm3l3grass_1trans.dds'),
    ('m3l3grass_1blast',      'm3l3grass_1blast.jpg',      'm3l3grass_1blast.dds'),
    ('m3l3grass_set2rad',     'm3l3grass_set2rad.jpg',     'm3l3grass_set2rad.dds'),
    ('m3l3grass_bocroadt',    'm3l3grass_bocroadt.tga',    'm3l3grass_bocroadt.tga'),
    ('nu_grass_set2a_sp',     'nu_grass_set2a_sp.jpg',     'nu_grass_set2a_sp.dds'),
]

DISP = 640  # display size per half

for name, sfile, hfile in PAIRS:
    sp = os.path.join(WORK, 'stock', sfile)
    hp = os.path.join(WORK, 'hd', hfile)
    if not (os.path.exists(sp) and os.path.exists(hp)):
        print('skip', name); continue
    st = Image.open(sp).convert('RGB')
    hd = Image.open(hp).convert('RGB')
    # crop the same texel-relative region: center half of the texture
    def crop_center_half(im):
        w, h = im.size
        return im.crop((w//4, h//4, w//4 + w//2, h//4 + h//2))
    sc = crop_center_half(st).resize((DISP, DISP), Image.LANCZOS)
    hc = crop_center_half(hd).resize((DISP, DISP), Image.LANCZOS)
    canvas = Image.new('RGB', (DISP*2 + 12, DISP + 28), (20, 20, 20))
    canvas.paste(sc, (4, 24))
    canvas.paste(hc, (DISP + 8, 24))
    d = ImageDraw.Draw(canvas)
    d.text((6, 6), f'STOCK {st.size[0]}x{st.size[1]}  {sfile}', fill=(255, 255, 120))
    d.text((DISP + 10, 6), f'HD {hd.size[0]}x{hd.size[1]}  {hfile}', fill=(255, 160, 120))
    out = os.path.join(HERE, f'compare_{name}.png')
    canvas.save(out)
    print('wrote', out)
