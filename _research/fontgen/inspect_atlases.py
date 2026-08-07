"""Inspect vanilla vs mod font atlases: are the mod 4x overrides real upscales or nearest?"""
import os
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
VAN = r'C:\mohaa-coop-dev\build_out\fontgen\vanilla'
MOD = r'C:\mohaa-coop-dev\hzm-mohaa-coop-mod\gfx\fonts'

for f in ['courier-16', 'verdana-12', 'facfont-20', 'handle-23']:
    v = Image.open(os.path.join(VAN, f + '.tga')).convert('RGBA')
    m = Image.open(os.path.join(MOD, f + '.tga')).convert('RGBA')
    a = np.asarray(v)
    marr = np.asarray(m)
    bx = m.size[0] // v.size[0]
    by = m.size[1] // v.size[1]
    blocks = marr[:v.size[1] * by, :v.size[0] * bx].reshape(v.size[1], by, v.size[0], bx, 4).astype(float)
    blockvar = blocks.std(axis=(1, 3)).mean()
    va = a[..., 3]
    ma = marr[..., 3]
    print(f, 'v%s m%s' % (v.size, m.size),
          '| vanilla alpha levels:', len(np.unique(va)),
          '| mod alpha levels:', len(np.unique(ma)),
          '| mod intra-block stddev: %.3f' % blockvar)
    # also check RGB: white glyphs?
    ink = va > 128
    print('   vanilla ink RGB mean:', a[..., :3][ink].mean(axis=0) if ink.any() else 'none',
          'coverage %.1f%%' % (100.0 * ink.mean()))
