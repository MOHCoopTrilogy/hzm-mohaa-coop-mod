"""SATELLITE render of a MOHAA map: real textures, orthographic top-down, z-buffered.

Why not screenshot it in-game: worldspawn sets farplane 3000 and the map is ~15000 units across, so
any camera high enough to frame it is fogged out; and MOHAA has no orthographic projection, so
stitched perspective tiles would disagree at the seams. Projecting the BSP ourselves has neither
problem and is exactly repeatable when arenas move.

Pipeline:
  1. shader lump -> texture file (289/299 names resolve directly to textures/<name>.<ext> in a pk3)
  2. world faces from LUMP_SURFACES, triangulated as a fan; UVs are drawVert.st (offset 12)
  3. terrain from LUMP_TERRAIN: 9x9 heightmap per patch, UV bilinear across the patch's texCoord
  4. orthographic XY projection with a real z-buffer, so the TOPMOST surface wins - which is what
     "seen from above" means. Painter's algorithm would fight over coincident faces.
  5. shading: lambert-ish term from |normal.z| (walls darker than roofs/ground) + a hillshade
     computed from the finished depth buffer, which is what makes terrain read as landscape.

drawVert (44B): xyz@0, st@12, lightmap@20, normal@28, color@40
cTerraPatch (388B stride): x@36, y@37, iBaseHeight@38, iShader@42, texCoord@4, heightmap@304
"""
import struct, sys, os, io, zipfile, glob, re, time, math
import numpy as np
from PIL import Image, ImageDraw, ImageFont

sys.stdout.reconfigure(encoding="utf-8", errors="replace")

MAP      = sys.argv[1] if len(sys.argv) > 1 else "e3l4_arena"
OUTW     = int(sys.argv[2]) if len(sys.argv) > 2 else 2048
BSP      = rf"G:\GOG\Medal of Honor - Allied Assault War Chest\maintt\maps\{MAP}.bsp"
SAVE     = r"G:\mohaa-gl2\home\maintt\coop_mod\save"
OUT      = os.path.dirname(os.path.abspath(__file__))
TEXSIZE  = 128
SURF_SKY, SURF_NODRAW = 0x4, 0x80
# Auto: only use baked lightmaps when they are actually well-exposed enough to carry detail.
# Threshold is measured against the mean of the LIT texels; see the note at the sampling site.
LM_MIN_MEAN = 0.16
t0 = time.time()

# ---------------------------------------------------------------- asset index
ROOTS = [r"G:\mohaa-gl2\maintt",
         r"G:\GOG\Medal of Honor - Allied Assault War Chest\maintt",
         r"G:\GOG\Medal of Honor - Allied Assault War Chest\main",
         r"G:\GOG\Medal of Honor - Allied Assault War Chest\mainta"]
index, zips = {}, {}
for r in ROOTS:
    for p in sorted(glob.glob(os.path.join(r, "*.pk3"))):
        try: z = zipfile.ZipFile(p)
        except Exception: continue
        zips[p] = z
        for n in z.namelist():
            index.setdefault(n.lower().replace("\\", "/"), (p, n))
print(f"[{time.time()-t0:5.1f}s] indexed {len(index)} assets from {len(zips)} pk3s")

def load_texture(name):
    """shader name -> TEXSIZE^2 RGB array, or None."""
    base = name.lower().replace("\\", "/")
    for ext in (".tga", ".jpg", ".jpeg", ".png"):
        hit = index.get(base + ext)
        if not hit: continue
        pk, member = hit
        try:
            with zips[pk].open(member) as fh:
                im = Image.open(io.BytesIO(fh.read())).convert("RGB")
            return np.asarray(im.resize((TEXSIZE, TEXSIZE), Image.BILINEAR), dtype=np.uint8)
        except Exception:
            continue
    return None

# ---------------------------------------------------------------- bsp
d = open(BSP, "rb").read()
lumps = [struct.unpack_from("<ii", d, 12 + i * 8) for i in range(28)]
soff, slen = lumps[0]
shaders = []
for i in range(slen // 140):
    r = d[soff + i * 140: soff + (i + 1) * 140]
    shaders.append((r[:64].split(b"\x00")[0].decode("latin-1", "replace"),
                    *struct.unpack_from("<ii", r, 64)))

FALLBACK = np.full((TEXSIZE, TEXSIZE, 3), (150, 140, 120), dtype=np.uint8)

def _pyramid(t):
    """Mip chain, coarsest last. A terrain patch tiles its texture 2-5x across ~68 output pixels,
    so point-sampling the full-res image is far below Nyquist and aliases into moire banding.
    Picking a mip whose texel is about one output pixel is the standard fix."""
    mips, cur = [t], t
    while cur.shape[0] > 1:
        cur = np.asarray(Image.fromarray(cur).resize((max(cur.shape[1]//2, 1),
                                                      max(cur.shape[0]//2, 1)), Image.BOX),
                         dtype=np.uint8)
        mips.append(cur)
    return mips

texcache = {}
def tex_for(si):
    if si not in texcache:
        t = load_texture(shaders[si][0]) if 0 <= si < len(shaders) else None
        texcache[si] = _pyramid(FALLBACK if t is None else t)
    return texcache[si]

def pick_mip(mips, texels_per_px):
    lvl = 0 if texels_per_px <= 1 else min(int(math.log2(texels_per_px) + 0.5), len(mips) - 1)
    return mips[max(lvl, 0)]

# ---------------------------------------------------------------- lightmaps
# The map's own baked lighting. This is what stops the ground reading as copy-paste: the diffuse
# texture tiles every ~100px, but the lightmap is unique everywhere, so multiplying them together
# breaks the repeat AND restores the designer's baked sun, shadow and dirt/grass variation.
# LUMP_LIGHTMAPS is a flat array of 128x128 RGB images (4423680B / 49152 = 90 exactly).
LMS = 128
lmoff, lmlen = lumps[2]
NLM = lmlen // (LMS * LMS * 3)
LMAPS = (np.frombuffer(d, dtype=np.uint8, count=NLM * LMS * LMS * 3, offset=lmoff)
         .reshape(NLM, LMS, LMS, 3).astype(np.float32) / 255.0) if NLM else None
# mean over the LIT texels only - a lot of the atlas is unused padding at zero, and including it
# would drag the mean down and blow the normalised result out.
if NLM:
    _l = LMAPS.mean(axis=3)
    LM_MEAN = float(_l[_l > 0.02].mean()) if (_l > 0.02).any() else 1.0
else:
    LM_MEAN = 1.0
USE_LIGHTMAPS = bool(NLM) and LM_MEAN >= LM_MIN_MEAN
print(f"[{time.time()-t0:5.1f}s] lightmaps: {NLM} x {LMS}x{LMS}  mean(lit)={LM_MEAN:.4f}  "
      f"-> {'USED' if USE_LIGHTMAPS else 'SKIPPED (too dark / would amplify quantisation noise)'}")

voff, vlen = lumps[4]
nv_total = vlen // 44
vraw = np.frombuffer(d, dtype=np.float32, count=nv_total * 11, offset=voff).reshape(nv_total, 11)
VXYZ, VST, VNRM = vraw[:, 0:3], vraw[:, 3:5], vraw[:, 7:10]
VLM = vraw[:, 5:7]                       # lightmap st, drawVert offset 20/24

tris = []            # (xyz[3,3], uv[3,2], shaderIndex)
foff, FREC = lumps[3][0], 108
nf = lumps[3][1] // FREC
for k in range(nf):
    si = struct.unpack_from("<i", d, foff + k * FREC)[0]
    if not (0 <= si < len(shaders)): continue
    nm, sfl, _ = shaders[si]
    if sfl & (SURF_SKY | SURF_NODRAW): continue
    low = nm.lower()
    if any(t in low for t in ("caulk", "trigger", "clip", "hint", "portal", "nodraw")): continue
    fv, nvv = struct.unpack_from("<ii", d, foff + k * FREC + 12)
    if nvv < 3 or fv + nvv > nv_total: continue
    P, T = VXYZ[fv:fv+nvv], VST[fv:fv+nvv]
    Lm = VLM[fv:fv+nvv]
    # lightmapNum lives at surface offset 28 (76 distinct values, 95% inside [0,89] for 90 maps;
    # offset 4 is fogNum - always -1 here - and 8 is surfaceType)
    lmi = struct.unpack_from("<i", d, foff + k * FREC + 28)[0]
    if not (0 <= lmi < NLM): lmi = -1
    for j in range(1, nvv - 1):
        tris.append((np.array([P[0], P[j], P[j+1]]), np.array([T[0], T[j], T[j+1]]), si, False,
                     np.array([Lm[0], Lm[j], Lm[j+1]]), lmi))
print(f"[{time.time()-t0:5.1f}s] world: {nf} faces -> {len(tris)} triangles")

toff = lumps[22][0]
npatch = lumps[22][1] // 388
for pi in range(npatch):
    b = toff + pi * 388
    tc = struct.unpack_from("<8f", d, b + 4)
    px_, py_ = struct.unpack_from("<bb", d, b + 36)
    # iShader is at 40, iLightMap at 42 - reading 42 as the shader index gave every patch a
    # lightmap number instead, which is why the first render came out in horizontal colour bands
    # (lightmap ids vary slowly along a row of patches, so a whole row shared one wrong texture).
    zbase = struct.unpack_from("<h", d, b + 38)[0]
    ishad = struct.unpack_from("<H", d, b + 40)[0]
    hm = d[b + 304: b + 385]
    x0, y0 = px_ << 6, py_ << 6
    # texCoord[i][j] is the patch's FOUR corners (tr_terrain.c:769-776 reads s00/s01/s10/s11 and
    # t00/t01/t10/t11 out of it), NOT two opposite corners. Reading it as two made s constant across
    # every patch - s01-s00 is 0 because s varies with i, not j - which stretched the ground texture
    # infinitely along one axis and produced the horizontal streaking.
    s00, t00, s01, t01, s10, t10, s11, t11 = tc
    _fl, lmscale, ps_, pt_ = struct.unpack_from("<4B", d, b)
    ilm = struct.unpack_from("<H", d, b + 42)[0]
    if not (0 <= ilm < NLM): ilm = -1
    def LUV(ii, jj):
        # patch->s / patch->t are texel offsets into the 128px atlas; consecutive patches are 17
        # texels apart, i.e. 8 grid steps at lmapScale 2 plus the shared edge.
        return ((ps_ + ii * lmscale) / float(LMS), (pt_ + jj * lmscale) / float(LMS))
    for j in range(8):
        for i in range(8):
            def V(ii, jj):
                return (x0 + (ii << 6), y0 + (jj << 6), zbase + 2 * hm[jj * 9 + ii])
            def UV(ii, jj):
                u, v = ii / 8.0, jj / 8.0
                return ((s00*(1-u) + s10*u)*(1-v) + (s01*(1-u) + s11*u)*v,
                        (t00*(1-u) + t10*u)*(1-v) + (t01*(1-u) + t11*u)*v)
            a, bb, c, e = V(i, j), V(i+1, j), V(i+1, j+1), V(i, j+1)
            ua, ub, uc, ue = UV(i, j), UV(i+1, j), UV(i+1, j+1), UV(i, j+1)
            la, lb, lc, le = LUV(i, j), LUV(i+1, j), LUV(i+1, j+1), LUV(i, j+1)
            tris.append((np.array([a, bb, c], dtype=np.float32),
                         np.array([ua, ub, uc], dtype=np.float32), ishad, True,
                         np.array([la, lb, lc], dtype=np.float32), ilm))
            tris.append((np.array([a, c, e], dtype=np.float32),
                         np.array([ua, uc, ue], dtype=np.float32), ishad, True,
                         np.array([la, lc, le], dtype=np.float32), ilm))
print(f"[{time.time()-t0:5.1f}s] terrain: {npatch} patches -> {npatch*128} triangles; total {len(tris)}")

# ---------------------------------------------------------------- framing
allP = np.concatenate([t[0] for t in tris])
minx, maxx = allP[:, 0].min(), allP[:, 0].max()
miny, maxy = allP[:, 1].min(), allP[:, 1].max()
cx, cy = (minx + maxx) / 2, (miny + maxy) / 2
half = max(maxx - minx, maxy - miny) / 2 * 1.02
SS = 2                                   # supersample, then LANCZOS down - kills stair-stepping
W = H = OUTW * SS
scale = W / (2 * half)
ox, oy = cx - half, cy + half

color = np.zeros((H, W, 3), dtype=np.float32)
zbuf  = np.full((H, W), -1e30, dtype=np.float32)
terr  = np.zeros((H, W), dtype=bool)      # which pixels ended up terrain (for de-tiling below)

for P, UV, si, isterr, LMUV, lmi in tris:
    px = (P[:, 0] - ox) * scale
    py = (oy - P[:, 1]) * scale
    x_lo, x_hi = int(math.floor(px.min())), int(math.ceil(px.max()))
    y_lo, y_hi = int(math.floor(py.min())), int(math.ceil(py.max()))
    x_lo, y_lo = max(x_lo, 0), max(y_lo, 0)
    x_hi, y_hi = min(x_hi, W - 1), min(y_hi, H - 1)
    if x_hi < x_lo or y_hi < y_lo: continue

    x0f, y0f = px[0], py[0]
    e1x, e1y = px[1] - x0f, py[1] - y0f
    e2x, e2y = px[2] - x0f, py[2] - y0f
    det = e1x * e2y - e2x * e1y
    if abs(det) < 1e-9: continue

    xs = np.arange(x_lo, x_hi + 1, dtype=np.float32) + 0.5
    ys = np.arange(y_lo, y_hi + 1, dtype=np.float32) + 0.5
    gx, gy = np.meshgrid(xs, ys)
    rx, ry = gx - x0f, gy - y0f
    u = (rx * e2y - e2x * ry) / det
    v = (e1x * ry - rx * e1y) / det
    m = (u >= -1e-4) & (v >= -1e-4) & (u + v <= 1 + 1e-4)
    if not m.any(): continue

    w0 = 1.0 - u - v
    z = w0 * P[0, 2] + u * P[1, 2] + v * P[2, 2]
    sub = zbuf[y_lo:y_hi+1, x_lo:x_hi+1]
    m &= z > sub
    if not m.any(): continue

    tu = w0 * UV[0, 0] + u * UV[1, 0] + v * UV[2, 0]
    tv = w0 * UV[0, 1] + u * UV[1, 1] + v * UV[2, 1]

    # texture density for this triangle -> mip level. Screen area vs UV area gives texels/pixel.
    area_px = abs(det) * 0.5
    duv = abs((UV[1,0]-UV[0,0]) * (UV[2,1]-UV[0,1]) - (UV[2,0]-UV[0,0]) * (UV[1,1]-UV[0,1])) * 0.5
    tpp = math.sqrt(duv * TEXSIZE * TEXSIZE / area_px) if area_px > 1e-6 else 1.0
    T = pick_mip(tex_for(si), tpp)
    TS = T.shape[0]

    ti = (np.mod(tu[m] * TS, TS)).astype(np.int32)
    tj = (np.mod(tv[m] * TS, TS)).astype(np.int32)
    texel = T[tj, ti].astype(np.float32)

    # Modulate by the baked lightmap, but NORMALISED against its own mean rather than used as an
    # absolute brightness. e3l4 is a night mission (worldspawn ambientlight 6 6 7, suncolor 12 12 15)
    # so its lightmaps are genuinely almost black - applying them straight is faithful to the game
    # and useless as a map, which is exactly what the first attempt produced. Dividing by the mean
    # keeps what we actually want from them (unique per-surface variation that breaks the texture
    # tiling, plus the designer's baked shadows and dirt/grass shading) at daylight legibility.
    # DISABLED on this map, deliberately. Measured mean lit lightmap here is 0.0756 - e3l4 is a night
    # mission, so at 8 bits that is only ~19 usable levels. Used raw it renders the map almost black;
    # normalised against its own mean it multiplies every quantisation step by ~13 and the noise
    # erupts into vertical streaks. Neither is usable. Kept behind a switch because a DAYLIGHT map's
    # lightmaps would be well-exposed and would genuinely break the tiling, which is what this was for.
    if USE_LIGHTMAPS and lmi >= 0 and LMAPS is not None:
        lu = (w0 * LMUV[0, 0] + u * LMUV[1, 0] + v * LMUV[2, 0])[m]
        lv = (w0 * LMUV[0, 1] + u * LMUV[1, 1] + v * LMUV[2, 1])[m]
        li = np.clip((lu * LMS).astype(np.int32), 0, LMS - 1)
        lj = np.clip((lv * LMS).astype(np.int32), 0, LMS - 1)
        lmv = LMAPS[lmi][lj, li] / LM_MEAN
        texel *= np.clip(1.0 + 0.72 * (lmv - 1.0), 0.62, 1.55)

    # Flat-shade WORLD faces only. Terrain is a heightfield split into two triangles per 64-unit
    # quad; giving each its own face normal facets it, and because the quads step in Y that facetting
    # showed up as horizontal banding across every slope. Terrain relief comes from the hillshade
    # below instead, which is computed from a SMOOTHED depth buffer and so has no facets.
    if not isterr:
        n = np.cross(P[1] - P[0], P[2] - P[0])
        nl = np.linalg.norm(n)
        nz = abs(n[2] / nl) if nl > 1e-9 else 1.0
        texel *= (0.42 + 0.58 * nz)                   # verticals read darker from above

    sub[m] = z[m]
    csub = color[y_lo:y_hi+1, x_lo:x_hi+1]
    csub[m] = texel
    tsub = terr[y_lo:y_hi+1, x_lo:x_hi+1]
    tsub[m] = isterr
print(f"[{time.time()-t0:5.1f}s] rasterised {len(tris)} triangles")

# ---------------------------------------------------------------- fill the empty ground
# ~21% of the frame has no geometry at all: holes the BSP never covers, plus everything outside the
# playable boundary. Left blank it reads as a cut-out. Two different problems, so two treatments:
#   - near the geometry (small gaps, interior holes) -> nearest-neighbour inpaint, which continues
#     whatever texture was adjacent and, importantly, fills the DEPTH buffer too so the hillshade
#     below stays continuous instead of cliff-edging at every hole.
#   - far outside -> procedural woodland, since that is what the map is actually surrounded by.
from scipy.ndimage import distance_transform_edt, gaussian_filter

painted = zbuf > -1e29
dist, (iy, ix) = distance_transform_edt(~painted, return_distances=True, return_indices=True)
color = color[iy, ix]
zbuf  = zbuf[iy, ix]
terr  = terr[iy, ix]

rng = np.random.default_rng(20260805)

def value_noise(shape, cell, seed):
    """Cheap smooth noise: random lattice, bilinear up-sample. No external deps."""
    h = max(int(shape[0] / cell) + 2, 2); w = max(int(shape[1] / cell) + 2, 2)
    g = np.random.default_rng(seed).random((h, w)).astype(np.float32)
    return np.asarray(Image.fromarray(g, mode="F").resize((shape[1], shape[0]), Image.BICUBIC),
                      dtype=np.float32)

# The boundary must not be a straight line. The BSP's terrain coverage ends on a rectangular patch
# grid, so thresholding raw distance gives a staircase that instantly reads as machine-made. Jitter
# the threshold with low-frequency noise and cross-fade over a few pixels, and the treeline meanders.
edge = value_noise(zbuf.shape, 34 * SS, 21)
thr = 1.5 * SS + 9.0 * SS * edge
alpha = np.clip((dist - thr) / (14.0 * SS), 0, 1).astype(np.float32)
outer = alpha > 0.002
if outer.any():
    # clearings / density variation, so the treeline is not a uniform mat
    dens = (0.55 * value_noise(zbuf.shape, 70 * SS, 11)
            + 0.45 * value_noise(zbuf.shape, 26 * SS, 12))
    ramp = np.clip((dist - thr) / (30.0 * SS), 0, 1)               # thin at the edge, thick outside
    pc = np.clip((dens - 0.34) * 2.2, 0, 1) * (0.28 + 0.72 * ramp)

    # TWO crown scales. A single blob size reads as noise/mottling rather than woodland; mixing a
    # sparse large-crown layer with a dense small one is what makes it look like a canopy from above.
    def blobs(p, sigma, gain, seed):
        s = (np.random.default_rng(seed).random(zbuf.shape).astype(np.float32) < p)
        f = gaussian_filter(s.astype(np.float32), sigma)
        return np.clip(f / (f.max() + 1e-6) * gain, 0, 1)

    big   = blobs(pc * 0.0045, 4.0 * SS, 2.5, 31)
    small = blobs(pc * 0.0260, 1.7 * SS, 2.3, 32)
    canopy = np.clip(big * 0.75 + small * 0.75, 0, 1)
    scrub  = blobs(0.0130, 1.0 * SS, 3.0, 33)

    grain = value_noise(zbuf.shape, 3 * SS, 13)
    tint  = value_noise(zbuf.shape, 90 * SS, 14)                   # slow colour drift, not a flat mat
    # Blend the woodland FLOOR toward whatever the map's own ground is right there, fading to green
    # only well outside. A fixed green butted against the map's dirt is the hard tan/green seam that
    # made the fringe read as pasted on; `color` here is already the nearest-neighbour inpaint, so it
    # carries the adjacent ground colour outward for free.
    green = np.stack([116 + 28*grain + 14*tint, 120 + 30*grain + 12*tint,
                      76 + 22*grain], axis=-1).astype(np.float32)
    blend = np.clip((dist - thr) / (95.0 * SS), 0, 1)[:, :, None].astype(np.float32)
    ground = color * (1 - blend) + green * blend
    bush   = np.stack([70 + 22*grain, 94 + 26*grain, 48 + 18*grain], axis=-1).astype(np.float32)
    tree   = np.stack([38 + 30*grain + 10*tint, 66 + 34*grain + 12*tint,
                       32 + 20*grain], axis=-1).astype(np.float32)

    filled = ground * (1 - scrub[:, :, None]) + bush * scrub[:, :, None]
    # crowns sit ON the scrub, with a shadow thrown down-right (matching the NW hillshade sun) so
    # they read as volume rather than paint
    off = int(3 * SS)
    shadow = np.clip(np.roll(np.roll(canopy, off, 0), off, 1) - canopy, 0, 1)
    filled *= (1.0 - 0.42 * shadow)[:, :, None]
    filled = filled * (1 - canopy[:, :, None]) + tree * canopy[:, :, None]
    # sun-side rim on each crown, the other half of reading as 3D
    rim = np.clip(canopy - np.roll(np.roll(canopy, off, 0), off, 1), 0, 1)
    filled *= (1.0 + 0.20 * rim)[:, :, None]

    a3 = alpha[:, :, None]
    color = color * (1 - a3) + filled * a3
    # give the woodland real height so the hillshade sculpts it instead of reading a flat plate
    zbuf = zbuf + alpha * (34.0 * canopy + 8.0 * scrub)
    print(f"[{time.time()-t0:5.1f}s] filled {100.0*(alpha>0.5).mean():.1f}% outskirts with woodland")

# DE-TILE the ground. One 512-unit grass texture repeats 2-5x per patch across the whole map, and
# from straight above that regularity reads as plaid - the engine only gets away with it because
# lightmaps, props and viewing angle break it up in game. Modulate terrain luminance with two
# octaves of low-frequency noise: the tile is still there, but the eye stops locking onto the grid.
if terr.any():
    dt = (0.62 * value_noise(zbuf.shape, 34 * SS, 41)
          + 0.38 * value_noise(zbuf.shape, 115 * SS, 42))
    mod = (0.84 + 0.32 * dt).astype(np.float32)
    warm = np.stack([mod * 1.03, mod, mod * 0.95], axis=-1)     # slight colour drift, not just value
    color = np.where(terr[:, :, None], color * warm, color)
    print(f"[{time.time()-t0:5.1f}s] de-tiled {100.0*terr.mean():.1f}% terrain")

Zf = zbuf.astype(np.float32)

# Blur the depth buffer BEFORE differentiating it. Terrain z is piecewise-linear across each
# 64-unit quad, so the raw gradient is discontinuous exactly at quad edges - that was the fine
# horizontal striping over otherwise flat ground, one line per quad row.
# Wider blur than feels natural on purpose: rock brushwork in this era is faceted, hard-edged
# geometry, and differentiating it tightly renders every chamfer as a crease. Blurring the field
# the normals come from rounds the forms without touching the texture detail on top.
Zs = gaussian_filter(Zf, 4.5 * SS)

# Standard cartographic hillshade: light from the NW at 45 deg, which is the convention that makes
# relief read as raised rather than sunken.
upp   = (2.0 * half) / W                       # world units per pixel
dzdy, dzdx = np.gradient(Zs, upp)
slope = np.arctan(np.hypot(dzdx, dzdy))
aspect = np.arctan2(dzdy, -dzdx)
az, alt = math.radians(315.0), math.radians(45.0)
hs = (math.sin(alt) * np.cos(slope)
      + math.cos(alt) * np.sin(slope) * np.cos(az - aspect))
shade = np.clip(0.68 + 0.62 * hs, 0.55, 1.42).astype(np.float32)
color *= shade[:, :, None]

# ROCK FORMATIONS. A pure top-down texture render flattens them: the cliff faces are near-vertical
# so barely any pixels land on them, and what you see is the plan outline, which reads as a paper
# cut-out. Two depth-derived passes fix that without touching the geometry.
#
# 1. Ambient occlusion - a point far BELOW its own neighbourhood average sits in a crevice between
#    boulders and should be shadowed. This is what makes a scree field read as massed 3D forms.
Zbig = gaussian_filter(Zf, 9.0 * SS)
ao = np.clip(1.0 - (Zbig - Zf) / 210.0, 0.42, 1.0).astype(np.float32)
color *= ao[:, :, None]

# 2. A steep-slope darkening keyed to the same slope the hillshade uses, so faces pick up edge
#    definition where rock meets ground.
color *= np.clip(1.0 - 0.16 * np.sin(slope), 0.78, 1.0)[:, :, None]

# CAST SHADOWS. Hillshade only shades a surface by its own slope; it cannot make a building throw a
# shadow onto the ground beside it, which is exactly the cue that reads as "roof" from above. March
# the sun ray across the depth buffer instead: for each step toward the sun, a pixel is in shadow if
# the terrain that many steps away is higher than the ray climbing at tan(altitude).
# Sun at azimuth 315 (NW) matches the hillshade above. World +Y is north and image +y is south, so
# NW in image space is (-x, -y).
STEP, NSTEP = 2.0, 110
sdx, sdy = -math.sin(az), -math.cos(az)
rise = STEP * upp * math.tan(alt)
occl = np.zeros_like(Zf)
for k in range(1, NSTEP + 1):
    oy_, ox_ = int(round(-k * STEP * sdy)), int(round(-k * STEP * sdx))
    ahead = np.roll(np.roll(Zf, oy_, axis=0), ox_, axis=1)
    occl = np.maximum(occl, ahead - (Zf + k * rise))
shadow = np.clip(occl / 70.0, 0, 1)
shadow = gaussian_filter(shadow, 1.6 * SS)              # penumbra; hard shadows look like stencils
color *= (1.0 - 0.46 * shadow)[:, :, None]
print(f"[{time.time()-t0:5.1f}s] cast shadows: {100.0*(shadow>0.25).mean():.1f}% of frame shadowed")

# local contrast (unsharp on luminance only - keeps hue, sharpens rock and roof detail)
color = np.clip(color, 0, 255)
LW = np.array([0.299, 0.587, 0.114], dtype=np.float32)
lum = color @ LW
color = np.clip(color + (lum - gaussian_filter(lum, 2.0 * SS))[:, :, None] * 0.62, 0, 255)

# gentle grade: a little saturation so grass / rock / road separate, then lift the midtones
lum = color @ LW
color = np.clip(lum[:, :, None] + (color - lum[:, :, None]) * 1.24, 0, 255)
color = np.clip(255.0 * np.power(color / 255.0, 0.92), 0, 255)

img = Image.fromarray(color.astype(np.uint8), "RGB").resize((OUTW, OUTW), Image.LANCZOS)

# soft vignette - keeps the eye on the middle of the map, and hides the ragged BSP boundary
yy, xx = np.mgrid[0:OUTW, 0:OUTW].astype(np.float32)
r = np.hypot(xx - OUTW/2, yy - OUTW/2) / (OUTW * 0.72)
vig = np.clip(1.06 - 0.30 * r**2.4, 0.0, 1.0)[:, :, None]
img = Image.fromarray(np.clip(np.asarray(img, dtype=np.float32) * vig, 0, 255).astype(np.uint8))

p = os.path.join(OUT, f"{MAP}_satellite.png")
img.save(p)
W = H = OUTW
scale /= SS
print(f"[{time.time()-t0:5.1f}s] wrote {p}  {OUTW}x{OUTW}  "
      f"coverage {100.0*painted.mean():.1f}%  textures loaded {len(texcache)}")

# world->image transform, so overlays can be placed later without re-deriving it
with open(os.path.join(OUT, f"{MAP}_satellite.txt"), "w") as fh:
    fh.write(f"ox {ox}\noy {oy}\nscale {scale}\nW {W}\nH {H}\n")
