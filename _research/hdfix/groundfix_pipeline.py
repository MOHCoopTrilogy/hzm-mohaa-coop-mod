#!/usr/bin/env python
"""HZM coop - ground-texture de-worm fix (bug-1129).

Problem: our Real-ESRGAN x4 upscale of textures/wilderness/m3l3grass_bocroad_new
(the m3l2 farm-courtyard floor under BT: TAnatural.shader remaps shader
m3l3grass_bocroad -> image m3l3grass_bocroad_new; our zzzzzzz_dds_override.pk3
.dds wins the engine's dds-first lookup) hallucinated crunchy crosshatch "worms"
and crushed the dark wheel-rut bands.

Fix (option a): re-process from STOCK art with gentle 2x LANCZOS + mild unsharp
(no ESRGAN), write DXT1 .dds with a full mip chain (engine LoadDDS requires it),
pack as zzzzzzzz_hd_groundfix.pk3 (8 z's -> sorts after zzzzzzz_dds_override ->
same-extension pak priority wins).

Add more (stock_pk3, entry) rows to FIXES if further wormy textures are found.
Reuses the validated DDS writer from _hd_staging/_work/hd_dds_build.py.

DEPLOY (manual, not done by this script): copy zzzzzzzz_hd_groundfix.pk3 to BOTH
  G:\GOG\Medal of Honor - Allied Assault War Chest\maintt\
  %APPDATA%\openmohaa\maintt\
(homepath copy is REQUIRED - homepath maintt paks outrank all basepath maintt
paks, so a basepath-only copy would lose to homepath zzzzzzz_dds_override.pk3.)
Verify in-game on m3l2 farm courtyard (ui_dmmap m3l2, ui_startdmmap 2).
"""
import os, sys, io, zipfile
from PIL import Image, ImageFilter

sys.path.insert(0, r'C:\mohaa-coop-dev\_hd_staging\_work')
from hd_dds_build import write_dds   # validated full-mip DXT writer

GOG = r'G:\GOG\Medal of Honor - Allied Assault War Chest'
HERE = os.path.dirname(os.path.abspath(__file__))
PK3ROOT = os.path.join(HERE, 'pk3')
PK3OUT = os.path.join(HERE, 'zzzzzzzz_hd_groundfix.pk3')

# (stock pk3, entry in that pk3, output basename [no ext])
FIXES = [
    (GOG + r'\maintt\pak1.pk3', 'textures/wilderness/m3l3grass_bocroad_new.jpg',
     'textures/wilderness/m3l3grass_bocroad_new'),
]

def process(img):
    """Gentle 2x magnification: Lanczos + mild unsharp. No AI, no worms."""
    w, h = img.size
    up = img.resize((w * 2, h * 2), Image.LANCZOS)
    return up.filter(ImageFilter.UnsharpMask(radius=1.2, percent=55, threshold=3))

def main():
    made = []
    for pk3, entry, outbase in FIXES:
        data = zipfile.ZipFile(pk3).read(entry)
        img = Image.open(io.BytesIO(data)).convert('RGB')
        print(f'{entry}: stock {img.size[0]}x{img.size[1]} from {os.path.basename(pk3)}')
        fixed = process(img)
        dds_path = os.path.join(PK3ROOT, outbase + '.dds')
        write_dds(fixed, dds_path, 'DXT1')
        # also ship a matching .jpg so jpg-path lookups (dds compression off) agree
        jpg_path = os.path.join(PK3ROOT, outbase + '.jpg')
        fixed.save(jpg_path, quality=92)
        made.append((outbase, fixed.size))
        print(f'  -> {dds_path}')
        print(f'  -> {jpg_path}')

    # pack
    if os.path.exists(PK3OUT):
        os.remove(PK3OUT)
    with zipfile.ZipFile(PK3OUT, 'w', zipfile.ZIP_DEFLATED) as z:
        for root, _, files in os.walk(PK3ROOT):
            for f in files:
                full = os.path.join(root, f)
                arc = os.path.relpath(full, PK3ROOT).replace('\\', '/')
                z.write(full, arc)
    print('PACKED:', PK3OUT, os.path.getsize(PK3OUT), 'bytes')
    for b, s in made:
        print('  contains', b, s)

if __name__ == '__main__':
    main()
