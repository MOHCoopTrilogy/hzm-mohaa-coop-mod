"""MODERN satellite render of a MOHAA map.

satellite.py samples the map's actual 128px 2002-era textures. That is faithful, but those textures
tile every ~100 output pixels and no amount of post-processing hides it. This version keeps the
GEOMETRY - which is the part worth having, and which we now extract correctly - and throws the
textures away, repainting every surface with a procedural material generated at full output
resolution. Nothing tiles, because nothing is tiled: the noise is evaluated once across the frame.

What drives the look:
  * a material id per pixel, classified from the surface's shader NAME (80 distinct in this map)
  * a real z-buffer, so the topmost surface wins
  * roof detection from local height, so buildings read as buildings from above
  * cast shadows marched across the height field, hillshade, and depth-derived ambient occlusion

Geometry extraction is identical to satellite.py and its hard-won offsets:
  drawVert (44B): xyz@0, st@12, lightmap@20, normal@28
  surface (108B): shaderNum@0, fogNum@4, surfaceType@8, firstVert@12, numVerts@16, lightmapNum@28
  cTerraPatch (388B): lmapScale@1, s@2, t@3, texCoord@4, x@36, y@37, iBaseHeight@38, iShader@40,
                      iLightMap@42, heightmap@304 ; world x0 = x<<6, z = iBaseHeight + 2*height
"""
import struct, sys, os, io, zipfile, glob, time, math, re
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter
from scipy.ndimage import (distance_transform_edt, gaussian_filter, binary_dilation,
                           label as cc_label)

sys.stdout.reconfigure(encoding="utf-8", errors="replace")
MAP  = sys.argv[1] if len(sys.argv) > 1 else "e3l4_arena"
OUTW = int(sys.argv[2]) if len(sys.argv) > 2 else 2048
OUTH = int(sys.argv[3]) if len(sys.argv) > 3 else OUTW
FIT  = sys.argv[4] if len(sys.argv) > 4 else "map"    # map | auto
# DEFAULT IS WHOLE-MAP. Framing tight on one holdout looks better in isolation, but every
# further position has to be markable on the same image, so the whole level must stay in
# frame. On a wide display the side margins are invented countryside, not empty filler.
BSP  = rf"G:\GOG\Medal of Honor - Allied Assault War Chest\maintt\maps\{MAP}.bsp"
SAVE = r"G:\mohaa-gl2\home\maintt\coop_mod\save"
OUT  = os.path.dirname(os.path.abspath(__file__))
SS   = 2
SURF_SKY, SURF_NODRAW = 0x4, 0x80
t0 = time.time()

# ---------------------------------------------------------------- material classes
GRASS, DIRT, ROAD, ROCK, STONE, COBBLE, WOOD, RUBBLE, METAL, CRATE, TREE, ROOF = range(12)
def classify(nm):
    """Specific MATERIAL words must beat the folder heuristic.

    Ordering bug found in review: 'textures/it_terrain/winekegside' is a wooden barrel, but the
    it_terrain folder rule ran first and painted 2059 triangles of it as grass - which is why the
    building at the top of the map appeared to have a grass roof. Folder is only a fallback now.
    """
    n = nm.lower()
    if "runway" in n or "road" in n or "path" in n:               return ROAD
    if "keg" in n or "barrel" in n:                               return WOOD
    if "crate" in n or "items_various" in n:                      return CRATE
    if "cobble" in n:                                             return COBBLE
    if "rubble" in n or "blasted" in n:                           return RUBBLE
    if "rck" in n or "rock" in n or "cliff" in n:                 return ROCK
    if "wood" in n or "joist" in n or "trunk" in n or "plank" in n: return WOOD
    if "pipe" in n or "metal" in n or "minen" in n or "argent" in n: return METAL
    if "tree" in n or "tanatural" in n or "foliage" in n:         return TREE
    if any(k in n for k in ("wall", "stone", "castle", "ruins", "structure", "exterior",
                            "interior", "boot", "berlin", "whsflr", "roof", "tile")): return STONE
    if "grass" in n or "it_terrain" in n:                         return GRASS   # folder fallback
    return DIRT

# base / highlight colour pairs, then per-material noise character.
# Chosen to read at a glance from directly overhead: cool greys for rock and stone so warm ground
# separates from it, and a deliberately distinct slate for roofs.
MATDEF = {
    GRASS : ((58, 74, 34),   (124, 130, 70),  (22, 8, 2.6), 0.70),
    DIRT  : ((116, 98, 70),  (156, 136, 100), (26, 7, 2.5), 0.42),
    ROAD  : ((132, 122, 100),(170, 162, 140), (18, 5, 2.0), 0.30),
    ROCK  : ((84, 84, 86),   (146, 144, 138), (14, 4, 1.8), 0.85),
    STONE : ((124, 118, 108),(176, 170, 158), (20, 6, 2.2), 0.55),
    COBBLE: ((104, 100, 96), (146, 142, 136), (9,  3, 1.6), 0.45),
    WOOD  : ((96, 68, 42),   (150, 112, 70),  (22, 6, 2.0), 0.40),
    RUBBLE: ((110, 102, 92), (152, 144, 132), (8,  3, 1.5), 0.70),
    METAL : ((88, 90, 94),   (132, 136, 142), (16, 5, 2.0), 0.35),
    CRATE : ((124, 96, 58),  (166, 136, 92),  (12, 4, 1.8), 0.35),
    TREE  : ((26, 46, 22),   (76, 100, 44),   (9,  3.4, 2.2), 0.90),
    ROOF  : ((92, 62, 52),   (140, 100, 84),  (16, 5, 2.0), 0.45),
}

# ---------------------------------------------------------------- bsp
d = open(BSP, "rb").read()
lumps = [struct.unpack_from("<ii", d, 12 + i * 8) for i in range(28)]
soff, slen = lumps[0]
shaders = []
for i in range(slen // 140):
    r = d[soff + i * 140: soff + (i + 1) * 140]
    shaders.append((r[:64].split(b"\x00")[0].decode("latin-1", "replace"),
                    *struct.unpack_from("<ii", r, 64)))
SMAT = [classify(s[0]) for s in shaders]

voff, vlen = lumps[4]
nvt = vlen // 44
vraw = np.frombuffer(d, dtype=np.float32, count=nvt * 11, offset=voff).reshape(nvt, 11)
VXYZ = vraw[:, 0:3]

tris = []                                   # (xyz[3,3], matid, isTerrain)
foff, FREC = lumps[3][0], 108
nf = lumps[3][1] // FREC
for k in range(nf):
    si = struct.unpack_from("<i", d, foff + k * FREC)[0]
    if not (0 <= si < len(shaders)): continue
    nm, sfl, _ = shaders[si]
    if sfl & (SURF_SKY | SURF_NODRAW): continue
    low = nm.lower()
    # 'nosprite*' and 'tallen*' are TREE-IMPOSTOR / occluder brushes: flat cards floating ~1300
    # units above the ground (mean z 3080 vs a p99 terrain of 1786) that fake distant treetops when
    # seen from inside the level. From directly overhead they win the z-buffer as big rectangular
    # plates and throw hard rectangular shadows - that was the "building with a grass roof".
    if any(t in low for t in ("caulk", "trigger", "clip", "hint", "portal", "nodraw", "sky",
                              "nosprite", "tallen")):
        continue
    fv, nvv = struct.unpack_from("<ii", d, foff + k * FREC + 12)
    if nvv < 3 or fv + nvv > nvt: continue
    P = VXYZ[fv:fv + nvv]
    for j in range(1, nvv - 1):
        tris.append((np.array([P[0], P[j], P[j + 1]]), SMAT[si], False))
print(f"[{time.time()-t0:5.1f}s] world: {nf} faces -> {len(tris)} tris")

toff = lumps[22][0]
npatch = lumps[22][1] // 388
for pi in range(npatch):
    b = toff + pi * 388
    px_, py_ = struct.unpack_from("<bb", d, b + 36)
    zbase = struct.unpack_from("<h", d, b + 38)[0]
    ishad = struct.unpack_from("<H", d, b + 40)[0]
    mid = SMAT[ishad] if 0 <= ishad < len(SMAT) else GRASS
    hm = d[b + 304: b + 385]
    x0, y0 = px_ << 6, py_ << 6
    for j in range(8):
        for i in range(8):
            def V(ii, jj): return (x0 + (ii << 6), y0 + (jj << 6), zbase + 2 * hm[jj * 9 + ii])
            a, bb, c, e = V(i, j), V(i+1, j), V(i+1, j+1), V(i, j+1)
            tris.append((np.array([a, bb, c], dtype=np.float32), mid, True))
            tris.append((np.array([a, c, e], dtype=np.float32), mid, True))
print(f"[{time.time()-t0:5.1f}s] terrain: {npatch} patches; total {len(tris)} tris")

# ---------------------------------------------------------------- rasterise (z-buffer, ids only)
allP = np.concatenate([t[0] for t in tris])
minx, maxx = allP[:, 0].min(), allP[:, 0].max()
miny, maxy = allP[:, 1].min(), allP[:, 1].max()
# FRAMING. Two different jobs, so two modes.
#  'map'  - the whole level fits, for an overview of every holdout position.
#  'auto' - centre on the authored holdout(s) and frame tight enough that the playable ground fills
#           the screen. On a 21:9 display, fitting a roughly square map to the HEIGHT leaves the map
#           stranded in the middle of two screens' worth of filler woodland; a loading screen wants
#           the place you are about to fight over, not a hectare of trees.
aspect = OUTW / float(OUTH)
_hold = []
try:
    for _ln in io.open(os.path.join(SAVE, f"holdout_{MAP}.dat"), encoding="latin-1").read().splitlines():
        _sg = _ln.strip().split(",")
        if len(_sg) >= 3:
            _hold.append(tuple(float(v) for v in _sg[1].split()[:3]))
except Exception:
    pass

if FIT == "auto" and _hold:
    hx_ = [h[0] for h in _hold]; hy_ = [h[1] for h in _hold]
    cx, cy = (min(hx_) + max(hx_)) / 2, (min(hy_) + max(hy_)) / 2
    span = max(max(hx_) - min(hx_), max(hy_) - min(hy_))
    halfy = max(span * 1.5, 2400.0)                 # a single position still gets useful context
    halfx = halfy * aspect
    # never frame wider than the level actually is
    if halfx > (maxx - minx) / 2 * 1.05:
        halfx = (maxx - minx) / 2 * 1.05
        halfy = halfx / aspect
    cx = min(max(cx, minx + halfx), maxx - halfx) if (maxx - minx) > 2 * halfx else cx
    cy = min(max(cy, miny + halfy), maxy - halfy) if (maxy - miny) > 2 * halfy else cy
    print(f"[{time.time()-t0:5.1f}s] framing on {len(_hold)} holdout(s) @ ({cx:.0f} {cy:.0f}) "
          f"half {halfx:.0f}x{halfy:.0f}")
else:
    cx, cy = (minx + maxx) / 2, (miny + maxy) / 2
    halfy = max(maxx - minx, maxy - miny) / 2 * 1.02
    halfx = halfy * aspect
W, H = OUTW * SS, OUTH * SS
scale = W / (2 * halfx)
half = halfx                                   # world units per pixel is derived from this
ox, oy = cx - halfx, cy + halfy

zbuf = np.full((H, W), -1e30, dtype=np.float32)
mbuf = np.full((H, W), -1, dtype=np.int16)
tbuf = np.zeros((H, W), dtype=bool)
nzb  = np.ones((H, W), dtype=np.float32)

for P, mid, isterr in tris:
    px = (P[:, 0] - ox) * scale
    py = (oy - P[:, 1]) * scale
    x_lo, x_hi = max(int(math.floor(px.min())), 0), min(int(math.ceil(px.max())), W - 1)
    y_lo, y_hi = max(int(math.floor(py.min())), 0), min(int(math.ceil(py.max())), H - 1)
    if x_hi < x_lo or y_hi < y_lo: continue
    x0f, y0f = px[0], py[0]
    e1x, e1y, e2x, e2y = px[1]-x0f, py[1]-y0f, px[2]-x0f, py[2]-y0f
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
    z = (1 - u - v) * P[0, 2] + u * P[1, 2] + v * P[2, 2]
    sub = zbuf[y_lo:y_hi+1, x_lo:x_hi+1]
    m &= z > sub
    if not m.any(): continue
    n = np.cross(P[1] - P[0], P[2] - P[0]); nl = np.linalg.norm(n)
    sub[m] = z[m]
    mbuf[y_lo:y_hi+1, x_lo:x_hi+1][m] = mid
    tbuf[y_lo:y_hi+1, x_lo:x_hi+1][m] = isterr
    nzb[y_lo:y_hi+1, x_lo:x_hi+1][m] = abs(n[2] / nl) if nl > 1e-9 else 1.0
print(f"[{time.time()-t0:5.1f}s] rasterised")

# ---------------------------------------------------------------- fill, then paint
painted = zbuf > -1e29
dist, (iy, ix) = distance_transform_edt(~painted, return_distances=True, return_indices=True)
zbuf, mbuf, tbuf, nzb = zbuf[iy, ix], mbuf[iy, ix], tbuf[iy, ix], nzb[iy, ix]

def noise(cell, seed):
    h = max(int(H / cell) + 2, 2); w = max(int(W / cell) + 2, 2)
    g = np.random.default_rng(seed).random((h, w)).astype(np.float32)
    return np.asarray(Image.fromarray(g, mode="F").resize((W, H), Image.BICUBIC), dtype=np.float32)

# everything beyond the map edge becomes woodland
edge = 0.65 * noise(120 * SS, 21) + 0.35 * noise(42 * SS, 22)
alpha_out = np.clip((dist - (1.0 * SS + 38.0 * SS * edge)) / (26.0 * SS), 0, 1)
outer = alpha_out > 0.5
mbuf = np.where(outer, TREE, mbuf)
zbuf = zbuf + alpha_out * 26.0
fakeh = np.zeros((H, W), dtype=np.float32)          # height of invented structures

if outer.any():
    rngo = np.random.default_rng(1177)

    # ---- HEDGEROW FIELDS ------------------------------------------------------------------
    # Contour bands of two low-frequency noise fields give irregular, curving enclosure lines -
    # much closer to real field boundaries than a grid, and free of any repeating motif.
    def contours(field, k, wdt):
        v = field * k
        return np.abs(v - np.round(v)) < wdt

    # Sum two octaves BEFORE contouring. A single bicubic-upsampled lattice has straight spans
    # between control points, so its contours come out as hard-edged polygons; adding a finer
    # octave bends every boundary and gives the wandering hedge lines you actually see from the air.
    f1 = 0.68 * noise(86 * SS, 601) + 0.32 * noise(34 * SS, 611)
    f2 = 0.68 * noise(62 * SS, 602) + 0.32 * noise(25 * SS, 612)
    f3 = 0.70 * noise(150 * SS, 603) + 0.30 * noise(60 * SS, 613)
    hedge = contours(f1, 15.0, 0.013) | contours(f2, 12.0, 0.011)
    woodblock = f3 > 0.63                            # genuine copses, not everywhere
    is_wood = outer & (woodblock | hedge)
    is_field = outer & ~is_wood
    mbuf = np.where(is_field, GRASS, mbuf)
    mbuf = np.where(is_wood, TREE, mbuf)

    # a few fields under crop/plough read lighter than pasture
    plough = outer & is_field & ((0.7*noise(70*SS, 604) + 0.3*noise(28*SS, 614)) > 0.58)
    mbuf = np.where(plough, DIRT, mbuf)

    # ---- ROCKY GROUND ---------------------------------------------------------------------
    rocky_patch = outer & ((0.7*noise(96*SS, 605) + 0.3*noise(38*SS, 615)) > 0.72)
    mbuf = np.where(rocky_patch, ROCK, mbuf)

    # ---- HAMLETS --------------------------------------------------------------------------
    # Farmsteads sit in fields, not in the woods, and cluster with their outbuildings.
    def put_rect(ccx, ccy, hw, hh, ang, mat, height):
        rr = int(math.hypot(hw, hh)) + 2
        x0 = max(int(ccx - rr), 0); x1 = min(int(ccx + rr), W)
        y0 = max(int(ccy - rr), 0); y1 = min(int(ccy + rr), H)
        if x1 - x0 < 2 or y1 - y0 < 2:
            return
        yy_ = np.arange(y0, y1, dtype=np.float32)[:, None] - ccy
        xx_ = np.arange(x0, x1, dtype=np.float32)[None, :] - ccx
        ca, sa = math.cos(-ang), math.sin(-ang)
        lx = xx_ * ca - yy_ * sa
        ly = xx_ * sa + yy_ * ca
        inside = (np.abs(lx) <= hw) & (np.abs(ly) <= hh)
        if not inside.any():
            return
        mbuf[y0:y1, x0:x1][inside] = mat
        fk = fakeh[y0:y1, x0:x1]
        np.maximum(fk, np.where(inside, height, 0.0), out=fk)

    nham = 0
    tries = 0
    upp_est = (2.0 * halfx) / W                      # world units per pixel
    while nham < 22 and tries < 9000:
        tries += 1
        jx = int(rngo.integers(0, W)); jy = int(rngo.integers(0, H))
        if not (outer[jy, jx] and mbuf[jy, jx] in (GRASS, DIRT)):
            continue
        nb = int(rngo.integers(2, 6))
        base_ang = float(rngo.uniform(0, math.pi))
        for k in range(nb):
            ox_ = jx + float(rngo.uniform(-46, 46)) * SS
            oy_ = jy + float(rngo.uniform(-46, 46)) * SS
            # a farmhouse is ~9-20 m on a side; convert through world units per pixel
            # a farmstead is ~9-22 m on a side; 1 world unit ~= 1 inch
            w_ = max(float(rngo.uniform(360, 880)) / max(upp_est, 1e-3) * 0.5, 2.5)
            h_ = w_ * float(rngo.uniform(0.42, 0.78))
            put_rect(ox_, oy_, w_, h_, base_ang + float(rngo.uniform(-0.35, 0.35)),
                     ROOF, float(rngo.uniform(120, 190)))
        nham += 1

    zbuf = zbuf + fakeh
    print(f"[{time.time()-t0:5.1f}s] outskirts: fields+hedges, {int(rocky_patch.sum()*100/max(outer.sum(),1))}% rocky, {nham} hamlets")

# ROOFS: a non-terrain surface sitting well above its own neighbourhood, facing up. This is the cue
# the user asked for - from above a building is only legible if its top is a different material.
ground = gaussian_filter(zbuf, 26.0 * SS)
buildingish = np.isin(mbuf, [STONE, WOOD, COBBLE, METAL, CRATE])
roof = (~tbuf) & buildingish & (zbuf - ground > 34.0) & (nzb > 0.62)
mbuf = np.where(roof, ROOF, mbuf)
print(f"[{time.time()-t0:5.1f}s] roofs: {100.0*roof.mean():.2f}% of frame")

# ---------------------------------------------------------------- run the roads off the map
# The BSP's roads stop dead at the edge of the playable area, so the network reads as a closed loop
# that begins nowhere. Find each road's terminating tip, then continue it outward through the
# treeline and off the frame, so it looks like it arrives from somewhere.
roadm = mbuf == ROAD
rwidth = distance_transform_edt(roadm)
lbl, nlab = cc_label(roadm)
rngr = np.random.default_rng(9090)
extended = 0
if nlab:
    cxp, cyp = W / 2.0, H / 2.0
    for li in range(1, nlab + 1):
        ys, xs = np.nonzero(lbl == li)
        if ys.size < 400:                       # ignore specks
            continue
        # the tip is the road pixel farthest from the frame centre - i.e. the one heading outward
        dd = (xs - cxp) ** 2 + (ys - cyp) ** 2
        ti = int(np.argmax(dd))
        tx, ty = float(xs[ti]), float(ys[ti])
        # local tangent: away from the mean of nearby road pixels
        near = ((xs - tx) ** 2 + (ys - ty) ** 2) < (70.0 * SS) ** 2
        if near.sum() < 12:
            continue
        vx, vy = tx - float(xs[near].mean()), ty - float(ys[near].mean())
        vl = math.hypot(vx, vy)
        if vl < 1e-3:
            vx, vy, vl = tx - cxp, ty - cyp, math.hypot(tx - cxp, ty - cyp)
        vx, vy = vx / vl, vy / vl
        rad = max(float(rwidth[int(ty), int(tx)]), 2.5 * SS)

        # walk outward with a slow wander so it is not a ruled line
        px_, py_ = tx, ty
        ang = math.atan2(vy, vx)
        drift = rngr.uniform(-0.010, 0.010)
        for step in range(4000):
            ang += drift + rngr.uniform(-0.012, 0.012)
            drift *= 0.995
            px_ += math.cos(ang) * 1.6
            py_ += math.sin(ang) * 1.6
            if px_ < -60 or py_ < -60 or px_ > W + 60 or py_ > H + 60:
                break
            r = rad * (1.0 + 0.10 * math.sin(step * 0.02))
            x0 = max(int(px_ - r) - 1, 0); x1 = min(int(px_ + r) + 2, W)
            y0 = max(int(py_ - r) - 1, 0); y1 = min(int(py_ + r) + 2, H)
            if x1 <= x0 or y1 <= y0:
                continue
            yy = np.arange(y0, y1, dtype=np.float32)[:, None] - py_
            xx = np.arange(x0, x1, dtype=np.float32)[None, :] - px_
            disc = (xx * xx + yy * yy) < r * r
            sub = mbuf[y0:y1, x0:x1]
            sub[disc] = ROAD
        extended += 1
print(f"[{time.time()-t0:5.1f}s] extended {extended} road(s) to the map edge")

# three octaves shared by every material, plus a fine grain - evaluated ONCE across the whole frame,
# which is precisely why nothing tiles.
oc = {}
for cell, seed in ((3, 1), (4, 2), (5, 3), (8, 4), (9, 5), (10, 6), (12, 7), (14, 8), (16, 9),
                   (18, 10), (20, 11), (22, 12), (26, 13), (34, 14)):
    oc[cell] = noise(cell * SS, 100 + seed)
big = 0.6 * noise(90 * SS, 200) + 0.4 * noise(180 * SS, 201)

color = np.zeros((H, W, 3), dtype=np.float32)
for mid, (c0, c1, (o1, o2, o3), rough) in MATDEF.items():
    sel = mbuf == mid
    if not sel.any(): continue
    n1 = oc.get(o1, oc[16]); n2 = oc.get(o2, oc[4]); n3 = oc.get(o3 if o3 in oc else 3, oc[3])
    f = np.clip(0.52 * n1 + 0.30 * n2 + 0.18 * n3, 0, 1)
    f = np.clip((f - 0.5) * (0.7 + rough) + 0.5 + 0.16 * (big - 0.5), 0, 1)
    a = np.array(c0, dtype=np.float32); bcol = np.array(c1, dtype=np.float32)
    col = a[None, None, :] + (bcol - a)[None, None, :] * f[:, :, None]
    color = np.where(sel[:, :, None], col, color)
gsel = mbuf == GRASS
vegh = np.zeros((H, W), dtype=np.float32)
if gsel.any():
    dry = np.clip(0.62 * noise(150 * SS, 300) + 0.38 * noise(58 * SS, 301), 0, 1)
    dry = np.clip((dry - 0.44) * 2.0, 0, 1)[:, :, None]
    parched = np.array([150, 142, 84], dtype=np.float32)[None, None, :]
    color = np.where(gsel[:, :, None], color * (1 - 0.50 * dry) + parched * (0.50 * dry), color)

# ---------------------------------------------------------------- DISCRETE FLORA AND BOULDERS
# A noise field can only ever produce texture. A tree seen from above is an OBJECT: a roughly round
# crown with a lobed edge, brighter on the sun side, throwing a shadow of its own. So stamp actual
# domes - each with a jittered radius, a lobed silhouette and its own colour - into the height field
# and the albedo, and let the lighting stage below treat them exactly like terrain.
rngv = np.random.default_rng(4242)
ANG = np.linspace(0, 2*math.pi, 33)

def stamp(mask, spacing, rmin, rmax, hmin, hmax, pal_dark, pal_light, lobe, dome, seedbase):
    """Place objects on a jittered lattice wherever mask allows, one local window each.

    The lattice alone reads as synthetic: even jitter within each cell still yields near-uniform
    global coverage, and real vegetation doesn't work that way - it clumps where conditions favor
    it and leaves real gaps elsewhere. CLUMP (a low-frequency field, two octaves blended per-species
    via seedbase so trees/bushes/boulders don't all cluster identically) modulates each cell's
    SURVIVAL PROBABILITY, not just its jitter - dense patches keep nearly every candidate, thin
    patches drop most of them, so the result reads as an actual landscape rather than a grid.
    """
    placed = 0
    step = max(int(spacing), 3)
    clump = np.clip(0.55 * oc[26] + 0.45 * (0.6 * noise(70 * SS, 500 + seedbase)
                                             + 0.4 * noise(140 * SS, 600 + seedbase)), 0, 1)
    for gy in range(0, H, step):
        for gx in range(0, W, step):
            jy = gy + int(rngv.integers(0, step)); jx = gx + int(rngv.integers(0, step))
            if jy >= H or jx >= W or not mask[jy, jx]:
                continue
            # survival probability from the clump field: 0.12 in the thinnest patches (never a
            # perfectly hard edge) up to ~1.0 in the densest - so clearings are real, not just gaps
            # between two otherwise-identical trees.
            if rngv.random() > 0.12 + 0.88 * clump[jy, jx]:
                continue
            r = float(rngv.uniform(rmin, rmax))
            y0, y1 = max(int(jy - r) - 1, 0), min(int(jy + r) + 2, H)
            x0, x1 = max(int(jx - r) - 1, 0), min(int(jx + r) + 2, W)
            if y1 - y0 < 3 or x1 - x0 < 3:
                continue
            yy = np.arange(y0, y1, dtype=np.float32)[:, None] - jy
            xx = np.arange(x0, x1, dtype=np.float32)[None, :] - jx
            d = np.hypot(xx, yy)
            th = np.arctan2(yy, xx)
            # lobed outline: a few harmonics so no two crowns share a silhouette
            k1, k2 = rngv.uniform(0, 6.28), rngv.uniform(0, 6.28)
            n1, n2 = rngv.integers(3, 6), rngv.integers(6, 11)
            redge = r * (1.0 - lobe + lobe * (0.5 + 0.25*np.cos(n1*th + k1) + 0.25*np.cos(n2*th + k2)))
            inside = d < redge
            if not inside.any():
                continue
            t = np.clip(1.0 - (d / np.maximum(redge, 1e-3))**2, 0, 1)
            hgt = (t ** dome) * float(rngv.uniform(hmin, hmax))
            f = float(rngv.uniform(0, 1))
            col = np.array(pal_dark, np.float32) + (np.array(pal_light, np.float32)
                                                    - np.array(pal_dark, np.float32)) * f
            # internal break-up so a crown is not a flat disc of one colour
            gr = 0.82 + 0.36 * np.clip(t, 0, 1) + 0.10 * rngv.random(d.shape).astype(np.float32)
            hs, cs = vegh[y0:y1, x0:x1], color[y0:y1, x0:x1]
            sel = inside & (hgt > hs)
            hs[sel] = hgt[sel]
            cs[sel] = (col[None, None, :] * gr[:, :, None])[sel]
            placed += 1
    return placed

# where flora wants to be: clumped, with genuine clearings, dense on the fringe
want = np.clip(0.60 * noise(120 * SS, 500) + 0.40 * noise(40 * SS, 501), 0, 1)
open_ok = gsel & (np.clip((want - 0.52) * 3.0, 0, 1) > rngv.random((H, W)))
fringe   = (mbuf == TREE)

nt  = stamp(fringe,  9*SS,  7*SS, 15*SS,  46, 78, (30, 52, 24), (74, 104, 44), 0.34, 0.62, 1)
nt += stamp(open_ok, 26*SS, 6*SS, 13*SS, 40, 70, (34, 56, 26), (82, 110, 48), 0.34, 0.62, 2)
nb  = stamp(fringe,  6*SS,  3*SS,  6*SS, 12, 22, (44, 62, 30), (86, 104, 52), 0.42, 0.75, 3)
nb += stamp(open_ok, 15*SS, 2.5*SS, 5*SS, 10, 20, (48, 66, 32), (92, 112, 58), 0.42, 0.75, 4)

# Boulders. The map's rock is angular 2002 brushwork and reads as folded paper from above; the user
# is happy for these not to be faithful, so overlay rounded stone on top of the rock footprints.
rock_mask = binary_dilation((mbuf == ROCK) | (mbuf == RUBBLE), iterations=int(4 * SS))
nr  = stamp(rock_mask, 11*SS, 4*SS, 11*SS, 30, 62, (104, 102, 98), (168, 164, 156), 0.26, 0.48, 5)
nr += stamp(rock_mask, 6*SS,  2*SS,  5*SS, 12, 26, (112, 110, 104), (176, 172, 164), 0.30, 0.55, 6)
print(f"[{time.time()-t0:5.1f}s] stamped {nt} trees, {nb} bushes, {nr} boulders")
print(f"[{time.time()-t0:5.1f}s] painted {len(MATDEF)} materials")

# ---------------------------------------------------------------- light
# HYPER-REAL PASS. Flat colour + hillshade reads as a diagram because every surface has the same
# microstructure: none. Real materials differ at millimetre scale, and it is that micro-relief
# catching a directional sun that the eye reads as "grass" or "rock" rather than "green" or "grey".
# So: build a per-material micro height field, add it to the macro geometry, differentiate THAT for
# per-pixel normals, and light with a proper sun + sky rig instead of a cartographic hillshade.
upp = (2.0 * half) / W                       # world units per pixel

# micro-relief amplitude (world units) and feature size (px) per material
MICRO = {
    GRASS : (2.6, (2.0, 5.0, 13.0)),   DIRT  : (1.8, (2.0, 6.0, 16.0)),
    ROAD  : (0.9, (2.0, 5.0, 14.0)),   ROCK  : (16.0, (3.0, 9.0, 26.0)),
    STONE : (3.4, (2.0, 7.0, 20.0)),   COBBLE: (2.2, (1.6, 3.4, 9.0)),
    WOOD  : (1.6, (2.0, 8.0, 22.0)),   RUBBLE: (7.0, (2.0, 5.0, 12.0)),
    METAL : (0.8, (2.0, 6.0, 16.0)),   CRATE : (1.4, (2.4, 7.0, 18.0)),
    TREE  : (9.0, (2.4, 6.0, 15.0)),   ROOF  : (2.0, (2.0, 6.0, 17.0)),
}
micro = np.zeros((H, W), dtype=np.float32)
ncache = {}
def oct_noise(cell, seed):
    k = (round(cell, 2), seed)
    if k not in ncache: ncache[k] = noise(cell * SS, seed)
    return ncache[k]
for mid, (amp, cells) in MICRO.items():
    sel = mbuf == mid
    if not sel.any(): continue
    f = (0.55 * oct_noise(cells[0], 400 + mid) +
         0.30 * oct_noise(cells[1], 430 + mid) +
         0.15 * oct_noise(cells[2], 460 + mid)) - 0.5
    micro = np.where(sel, f * amp, micro)

# TREE CROWNS. A forest from above is thousands of discrete lit domes, not a green sheet - give the
# canopy real height so the same sun that lights the terrain sculpts each crown.
tsel = mbuf == TREE
if tsel.any():
    rng2 = np.random.default_rng(7788)
    crowns = np.zeros((H, W), dtype=np.float32)
    for sigma, prob, gain in ((3.2 * SS, 0.0035, 165.0), (1.7 * SS, 0.0170, 95.0)):
        sd = (rng2.random((H, W)).astype(np.float32) < prob) & tsel
        crowns += gaussian_filter(sd.astype(np.float32), sigma) * gain
    crowns = np.clip(crowns, 0, 60.0)
    micro = np.where(tsel, micro + crowns, micro)
micro = micro + vegh                       # shrubs/trees scattered over the open ground too

# The rock brushes are hard-edged wedges, and their folds drive the shading no matter what is
# painted on top - which is why they still read as sharp triangles. Replace their macro relief with
# a smoothed version and let the stamped boulder domes above carry the form instead. The user has
# said fidelity to the game's rocks is not required here, so this is a free win.
rocky = binary_dilation((mbuf == ROCK) | (mbuf == RUBBLE), iterations=int(2 * SS))
zbuf = np.where(rocky, gaussian_filter(zbuf.astype(np.float32), 7.0 * SS), zbuf)

# WALLS. The low brick/stone walls that run along the roads are partly sunk into the terrain, so
# from above only a thin strip clears the ground and they nearly vanish. Give them real height in
# the relief so they catch the sun on one side and throw a shadow on the other - which is the only
# thing that makes a wall legible from directly overhead.
wallish = ((mbuf == STONE) | (mbuf == COBBLE)) & (~roof) & (~tbuf)
wall = wallish & (zbuf - ground > -20.0)
if wall.any():
    vegh = np.where(wall, np.maximum(vegh, 34.0), vegh)
    color = np.where(wall[:, :, None], np.clip(color * 1.12 + 10.0, 0, 255), color)
    print(f"[{time.time()-t0:5.1f}s] walls raised on {100.0*wall.mean():.2f}% of frame")

# total relief in world units, then per-pixel normals
Htot = gaussian_filter(zbuf.astype(np.float32), 1.6 * SS) + micro
dhy, dhx = np.gradient(Htot, upp)
nx, ny = -dhx, dhy                            # image +y is world -y
nl = np.sqrt(nx*nx + ny*ny + 1.0)
nx, ny, nz = nx/nl, ny/nl, 1.0/nl

az, alt = math.radians(315.0), math.radians(46.0)
Lx, Ly, Lz = math.cos(alt)*math.sin(az), math.cos(alt)*math.cos(az), math.sin(alt)
ndl = np.clip(nx*Lx + ny*Ly + nz*Lz, 0, 1)

# cast shadows across the macro height field (crowns/micro must not self-shadow at this scale)
Zf = gaussian_filter(zbuf.astype(np.float32), 1.2 * SS)
STEP, NSTEP = 2.0, 110
sdx, sdy = -math.sin(az), -math.cos(az)
rise = STEP * upp * math.tan(alt)
occl = np.zeros_like(Zf)
for k in range(1, NSTEP + 1):
    ahead = np.roll(np.roll(Zf, int(round(-k*STEP*sdy)), 0), int(round(-k*STEP*sdx)), 1)
    occl = np.maximum(occl, ahead - (Zf + k * rise))
shadow = gaussian_filter(np.clip(occl / 70.0, 0, 1), 1.5 * SS)
print(f"[{time.time()-t0:5.1f}s] shadows {100.0*(shadow>0.25).mean():.1f}%")

# ambient occlusion from macro relief, and a tighter one from the micro field for contact shading
ao_macro = np.clip(1.0 - (gaussian_filter(zbuf.astype(np.float32), 9.0*SS) - zbuf) / 210.0, 0.42, 1.0)
ao_micro = np.clip(1.0 - (gaussian_filter(Htot, 3.0*SS) - Htot) / 26.0, 0.55, 1.0)
ao = (ao_macro * ao_micro).astype(np.float32)

# sun + sky rig: warm low sun, cool sky dome fill, faint warm bounce from the ground
SUN  = np.array([1.00, 0.94, 0.82], dtype=np.float32) * 1.62
SKY  = np.array([0.55, 0.66, 0.92], dtype=np.float32) * 0.52
BNC  = np.array([0.42, 0.38, 0.28], dtype=np.float32) * 0.20
sky_v = (0.5 + 0.5 * nz)[:, :, None]
lit = (SUN[None, None, :] * (ndl * (1.0 - 0.86 * shadow))[:, :, None]
       + SKY[None, None, :] * sky_v * ao[:, :, None]
       + BNC[None, None, :] * (1.0 - sky_v))
color = color * lit

# a whisper of specular so wet-ish stone and metal glint, keyed off the same normals
half_v = np.array([Lx, Ly, Lz + 1.0], dtype=np.float32); half_v /= np.linalg.norm(half_v)
spec = np.clip(nx*half_v[0] + ny*half_v[1] + nz*half_v[2], 0, 1) ** 42.0
gloss = np.zeros((H, W), dtype=np.float32)
for mid, g in ((ROCK, 0.10), (STONE, 0.13), (METAL, 0.34), (COBBLE, 0.11), (ROAD, 0.07)):
    gloss = np.where(mbuf == mid, g, gloss)
color += (spec * gloss * (1.0 - shadow))[:, :, None] * 255.0

# atmospheric depth: a touch of aerial haze in the hollows reads as real distance/scale
depth = np.clip((np.percentile(zbuf, 96) - zbuf) / max(np.ptp(zbuf), 1.0), 0, 1)[:, :, None]
color = color * (1 - 0.045 * depth) + np.array([146, 162, 184], np.float32)[None, None, :] * (0.045 * depth)

# filmic tonemap - keeps highlights off the clip and gives the whole frame a photographic roll-off
x = np.clip(color / 255.0, 0, 4.0) * 0.92
color = np.clip(((x * (2.51*x + 0.03)) / (x * (2.43*x + 0.59) + 0.14)), 0, 1) * 255.0

LW = np.array([0.299, 0.587, 0.114], dtype=np.float32)
lum = color @ LW
color = np.clip(color + (lum - gaussian_filter(lum, 1.6 * SS))[:, :, None] * 0.42, 0, 255)
lum = color @ LW
color = np.clip(lum[:, :, None] + (color - lum[:, :, None]) * 1.26, 0, 255)
color = np.clip(255.0 * np.power(np.clip(color,0,255) / 255.0, 1.06), 0, 255)
print(f"[{time.time()-t0:5.1f}s] lit + graded")

img = Image.fromarray(color.astype(np.uint8), "RGB").resize((OUTW, OUTH), Image.LANCZOS)
yy, xx = np.mgrid[0:OUTH, 0:OUTW].astype(np.float32)
r = np.hypot((xx - OUTW/2)/max(aspect,1.0), (yy - OUTH/2)) / (OUTH * 0.74)
img = Image.fromarray(np.clip(np.asarray(img, np.float32) *
                              np.clip(1.05 - 0.26 * r**2.4, 0, 1)[:, :, None], 0, 255).astype(np.uint8))
# ---------------------------------------------------------------- 1940s AERIAL RECON TREATMENT
# Panchromatic film, a warm silver-gelatin print, optical softness toward the corners, grain, and
# grease-pencil annotation over the top - the way a photo-interpreter would have marked it up.
A = np.asarray(img, dtype=np.float32)
Hh, Ww = A.shape[:2]

# Panchromatic response: period film rendered green foliage noticeably darker than the eye sees it.
pan = A[:, :, 0]*0.34 + A[:, :, 1]*0.42 + A[:, :, 2]*0.24
pan = np.clip((pan - 128.0) * 1.26 + 122.0, 0, 255)          # print contrast
# warm paper stock
tone = np.stack([pan * 1.030 + 10.0, pan * 0.988 + 5.0, pan * 0.905 + 2.0], axis=-1)

rg = np.random.default_rng(1944)
grain = rg.normal(0.0, 6.2, (Hh, Ww)).astype(np.float32)
grain = gaussian_filter(grain, 0.6) * 1.5
tone += grain[:, :, None]

# optical falloff: lenses of the day were soft and dim at the edges
yy, xx = np.mgrid[0:Hh, 0:Ww].astype(np.float32)
rr = np.hypot((xx - Ww/2)/max(Ww/float(Hh),1.0), (yy - Hh/2)) / (Hh * 0.62)
soft = gaussian_filter(tone, (1.9, 1.9, 0))
blend = np.clip((rr - 0.55) * 1.5, 0, 1)[:, :, None]
tone = tone * (1 - blend) + soft * blend
tone *= np.clip(1.06 - 0.42 * rr**2.3, 0.30, 1.0)[:, :, None]

# emulsion blemishes
for _ in range(220):
    sx, sy = int(rg.integers(0, Ww)), int(rg.integers(0, Hh))
    rad = int(rg.integers(1, 4)); val = 255.0 if rg.random() < 0.45 else 40.0
    tone[max(sy-rad,0):sy+rad, max(sx-rad,0):sx+rad] = val
streak = gaussian_filter(rg.normal(0, 1, (Hh, 1)).astype(np.float32), 3.0) * 3.0
tone += streak[:, :, None]

# ---- PRINT DAMAGE ------------------------------------------------------------------------------
# A wartime recon print is a physical object that was folded into a map case, handled with dirty
# gloves and stored badly. Grain alone reads as a filter; folds, chemical staining and edge wear are
# what make it read as an artefact.
DMG = np.random.default_rng(1943)

# uneven development / chemical staining - broad, soft, multiplicative
stain = np.zeros((Hh, Ww), dtype=np.float32)
for cell, amp, sd in ((260.0, 1.00, 61), (120.0, 0.62, 62), (46.0, 0.34, 63)):
    g = np.random.default_rng(sd).random((max(int(Hh/cell)+2, 2), max(int(Ww/cell)+2, 2))).astype(np.float32)
    stain += amp * np.asarray(Image.fromarray(g, mode="F").resize((Ww, Hh), Image.BICUBIC), dtype=np.float32)
stain /= 1.96
tone *= np.clip(0.80 + 0.34 * stain, 0.62, 1.14)[:, :, None]
# a couple of dark tide-marks, as if it got damp
for _ in range(3):
    cxs, cys = DMG.uniform(0, Ww), DMG.uniform(0, Hh)
    rad = DMG.uniform(0.18, 0.42) * min(Ww, Hh)
    dd = np.hypot(xx - cxs, yy - cys) / rad
    ring = np.exp(-((dd - 1.0) ** 2) / 0.010) * 0.30 + np.clip(1.0 - dd, 0, 1) * 0.10
    tone *= (1.0 - ring)[:, :, None]

# FOLD CREASES - a bright ridge with a dark valley beside it, the way a crease catches light
ncre = 3
for i in range(ncre):
    horiz = (i % 2 == 0)
    if horiz:
        y_at = DMG.uniform(0.22, 0.78) * Hh
        tilt = DMG.uniform(-0.045, 0.045)
        dline = np.abs(yy - (y_at + tilt * (xx - Ww / 2)))
    else:
        x_at = DMG.uniform(0.22, 0.78) * Ww
        tilt = DMG.uniform(-0.045, 0.045)
        dline = np.abs(xx - (x_at + tilt * (yy - Hh / 2)))
    wob = 0.0
    g = np.random.default_rng(70 + i).random((16, 16)).astype(np.float32)
    wob = (np.asarray(Image.fromarray(g, mode="F").resize((Ww, Hh), Image.BICUBIC),
                      dtype=np.float32) - 0.5) * 26.0
    dline = np.abs(dline + wob)
    ridge = np.exp(-(dline / 2.4) ** 2)
    valley = np.exp(-((dline - 5.0) / 4.0) ** 2)
    tone += (ridge * 30.0 - valley * 22.0)[:, :, None]
    tone *= (1.0 - np.exp(-(dline / 26.0) ** 2) * 0.06)[:, :, None]

# SCRATCHES and HAIRS, drawn as strokes then softened
scr = Image.new("F", (Ww, Hh), 0.0)
sd_ = ImageDraw.Draw(scr)
for _ in range(46):                                   # emulsion scratches: bright
    x_, y_ = DMG.uniform(0, Ww), DMG.uniform(0, Hh)
    ln = DMG.uniform(0.03, 0.30) * Ww
    an = DMG.uniform(0, 6.28)
    sd_.line([(x_, y_), (x_ + math.cos(an)*ln, y_ + math.sin(an)*ln)],
             fill=float(DMG.uniform(18, 46)), width=int(DMG.integers(1, 3)))
scr_a = gaussian_filter(np.asarray(scr, dtype=np.float32), 0.7)
tone += scr_a[:, :, None]

hair = Image.new("F", (Ww, Hh), 0.0)
hd_ = ImageDraw.Draw(hair)
for _ in range(7):                                    # hairs / fibres on the platen: dark
    x_, y_ = DMG.uniform(0, Ww), DMG.uniform(0, Hh)
    pts, an = [(x_, y_)], DMG.uniform(0, 6.28)
    for _k in range(int(DMG.integers(12, 40))):
        an += DMG.uniform(-0.45, 0.45)
        x_ += math.cos(an) * 7.0; y_ += math.sin(an) * 7.0
        pts.append((x_, y_))
    hd_.line(pts, fill=float(DMG.uniform(26, 52)), width=1)
tone -= gaussian_filter(np.asarray(hair, dtype=np.float32), 0.6)[:, :, None]

# EDGE WEAR - handled corners rub light, the extreme border darkens and chips
eg = np.random.default_rng(77).random((14, 14)).astype(np.float32)
egf = np.asarray(Image.fromarray(eg, mode="F").resize((Ww, Hh), Image.BICUBIC), dtype=np.float32)
edge = np.minimum.reduce([xx, yy, Ww - 1 - xx, Hh - 1 - yy]) / (0.055 * min(Ww, Hh))
edge = np.clip(edge + (egf - 0.5) * 0.9, 0, 1)
tone = tone * (0.34 + 0.66 * edge)[:, :, None] + (1.0 - edge)[:, :, None] * 26.0 * egf[:, :, None]

img = Image.fromarray(np.clip(tone, 0, 255).astype(np.uint8), "RGB")
dr = ImageDraw.Draw(img, "RGBA")

def F(path, size):
    for c in (path, "consola.ttf", "arial.ttf"):
        try: return ImageFont.truetype(c, size)
        except Exception: pass
    return ImageFont.load_default()
STEN = lambda n: F("STENCIL.TTF", n)
TYPE = lambda n: F("consola.ttf", n)

S = min(OUTW, OUTH) / 2048.0
# --- holdout locations, world -> image
holds = []
try:
    for line in io.open(os.path.join(SAVE, f"holdout_{MAP}.dat"), encoding="latin-1").read().splitlines():
        seg = line.strip().split(",")
        if len(seg) >= 3:
            holds.append(tuple(float(v) for v in seg[1].split()[:3]))
except Exception:
    pass
sc = scale / SS
def W2I(wx, wy): return ((wx - ox) * sc, (oy - wy) * sc)

# Red chinagraph. The photo itself is monochrome, so the interpreter's marks are the only
# colour on the print - which is both period-correct and the fastest possible read.
# Slightly desaturated and darkened so it sits ON the paper rather than glowing above it.
CHINA = (188, 44, 36, 240)
PHONETIC = ["ABLE", "BAKER", "CHARLIE", "DOG", "EASY", "FOX", "GEORGE", "HOW",
            "ITEM", "JIG", "KING", "LOVE", "MIKE", "NAN", "OBOE", "PETER"]
# Per-mark label override - a list of exact strings (index-aligned to holds, in file order).
# None (default) keeps the "POINT <PHONETIC>" order-of-battle labelling. Set to override, e.g.
# a single non-route mark like a named target ("OFFICER") that shouldn't read as a checkpoint.
MARK_LABELS = None

# Single-stroke hand-printed alphabet: each glyph is a list of polylines in a 0..1 box (y down).
# A font - even warped - keeps its even stroke weight and perfect repeats, which is exactly what
# gives away machine lettering. Drawing the strokes lets every letter differ and the pen wander.
GLYPH = {
 "A": [[(0,1),(.5,0),(1,1)],[(.2,.62),(.8,.62)]],
 "B": [[(0,0),(0,1)],[(0,0),(.72,.1),(.72,.42),(0,.5)],[(0,.5),(.78,.6),(.78,.92),(0,1)]],
 "C": [[(1,.16),(.52,0),(.1,.3),(.1,.72),(.52,1),(1,.86)]],
 "D": [[(0,0),(0,1)],[(0,0),(.74,.22),(.74,.8),(0,1)]],
 "E": [[(1,0),(0,0),(0,1),(.98,1)],[(0,.5),(.7,.5)]],
 "F": [[(1,0),(0,0),(0,1)],[(0,.5),(.66,.5)]],
 "G": [[(1,.16),(.52,0),(.1,.3),(.1,.72),(.52,1),(1,.8),(1,.56),(.56,.56)]],
 "H": [[(0,0),(0,1)],[(1,0),(1,1)],[(0,.52),(1,.52)]],
 "I": [[(.5,0),(.5,1)]],
 "J": [[(.82,0),(.82,.78),(.44,1),(.06,.8)]],
 "K": [[(0,0),(0,1)],[(.92,0),(0,.56)],[(.26,.44),(.96,1)]],
 "L": [[(0,0),(0,1),(.9,1)]],
 "M": [[(0,1),(.1,0),(.5,.62),(.9,0),(1,1)]],
 "N": [[(0,1),(.06,0),(.94,1),(1,0)]],
 "O": [[(.5,0),(.1,.3),(.1,.72),(.5,1),(.9,.72),(.9,.3),(.5,0)]],
 "P": [[(0,1),(0,0),(.76,.12),(.76,.44),(0,.56)]],
 "R": [[(0,1),(0,0),(.76,.12),(.76,.44),(0,.56)],[(.3,.56),(.96,1)]],
 "S": [[(.96,.14),(.5,0),(.12,.22),(.5,.5),(.9,.72),(.55,1),(.06,.86)]],
 "T": [[(0,0),(1,0)],[(.5,0),(.5,1)]],
 "U": [[(0,0),(.06,.76),(.5,1),(.94,.76),(1,0)]],
 "V": [[(0,0),(.5,1),(1,0)]],
 "W": [[(0,0),(.22,1),(.5,.42),(.78,1),(1,0)]],
 "X": [[(0,0),(1,1)],[(1,0),(0,1)]],
 "Y": [[(0,0),(.5,.56),(1,0)],[(.5,.56),(.5,1)]],
 "Z": [[(0,0),(1,0),(0,1),(1,1)]],
}

def hand_text(draw, text, cx_, top, size, col):
    """Grease-pencil lettering: per-glyph jitter, baseline drift and a wandering pen."""
    hr = np.random.default_rng(abs(hash(text)) % (2**31))
    adv = size * 0.78
    total = sum(adv * (0.55 if ch == " " else 1.0) for ch in text)
    x = cx_ - total / 2.0
    for ch in text.upper():
        if ch == " ":
            x += adv * 0.55
            continue
        strokes = GLYPH.get(ch)
        if not strokes:
            x += adv
            continue
        # per-letter personality: slant, size wobble, baseline drift, rotation
        sl = hr.uniform(-0.16, 0.06)
        sy = size * hr.uniform(0.90, 1.10)
        sx = size * 0.62 * hr.uniform(0.88, 1.12)
        dy = hr.uniform(-0.07, 0.07) * size
        rot = hr.uniform(-0.10, 0.10)
        ca, sa = math.cos(rot), math.sin(rot)
        for poly in strokes:
            # resample so the pen can wander between the control points
            pts = []
            for k in range(len(poly) - 1):
                ax, ay = poly[k]; bx, by = poly[k+1]
                seg = max(int(math.hypot((bx-ax)*sx, (by-ay)*sy) / 3.0), 2)
                for t in np.linspace(0, 1, seg, endpoint=(k == len(poly)-2)):
                    pts.append((ax + (bx-ax)*t, ay + (by-ay)*t))
            out, ph = [], hr.uniform(0, 6.28)
            for j, (gx_, gy_) in enumerate(pts):
                w = 0.014 * math.sin(j * 0.55 + ph) + 0.010 * math.sin(j * 1.7 + ph * 2)
                px_ = (gx_ + w) * sx + (0.5 - gy_) * sl * sx
                py_ = (gy_ + w * 0.7) * sy + dy
                out.append((x + px_ * ca - py_ * sa, top + px_ * sa + py_ * ca))
            if len(out) < 2:
                continue
            # variable pressure: two overlapping passes at slightly different weights
            draw.line(out, fill=(46, 10, 8, 170), width=max(int(size*0.135), 3), joint="curve")
            draw.line([(a+1.6, b+1.6) for a, b in out], fill=col,
                      width=max(int(size*0.115), 3), joint="curve")
            if hr.random() < 0.75:
                draw.line([(a+0.8, b-0.8) for a, b in out], fill=(col[0], col[1], col[2], 90),
                          width=max(int(size*0.060), 1), joint="curve")
        x += adv * hr.uniform(0.93, 1.07)
    return total
# THE ROUTE. The holdout is sequential - hold Able through its waves, then fall back to Baker -
# so the image should read as an order of battle, not a scatter of positions. Dashed grease-pencil
# advance line between consecutive points, drawn UNDER the rings.
if len(holds) > 1:
    for i in range(len(holds) - 1):
        ax, ay = W2I(holds[i][0], holds[i][1])
        bx, by = W2I(holds[i+1][0], holds[i+1][1])
        seg = math.hypot(bx-ax, by-ay)
        if seg < 1:
            continue
        ux, uy = (bx-ax)/seg, (by-ay)/seg
        R0 = 128 * S
        t_ = R0
        while t_ < seg - R0:
            dl = min(26*S, seg - R0 - t_)
            jx_, jy_ = rg.uniform(-2.5*S, 2.5*S), rg.uniform(-2.5*S, 2.5*S)
            dr.line([(ax+ux*t_+jx_, ay+uy*t_+jy_),
                     (ax+ux*(t_+dl)+jx_, ay+uy*(t_+dl)+jy_)],
                    fill=(CHINA[0], CHINA[1], CHINA[2], 190), width=max(int(3.4*S), 2))
            t_ += dl + 20*S
        # arrowhead into the next position
        hxq, hyq = bx - ux*R0, by - uy*R0
        for sgn in (1, -1):
            ang2 = math.atan2(uy, ux) + sgn * 2.55
            dr.line([(hxq, hyq), (hxq + math.cos(ang2)*22*S, hyq + math.sin(ang2)*22*S)],
                    fill=CHINA, width=max(int(3.4*S), 2))

for i, h in enumerate(holds, 1):
    hx, hy = W2I(h[0], h[1])
    R = 118 * S
    # grease pencil: two wobbling passes, never a true circle
    for pas in range(2):
        pts, ph = [], rg.uniform(0, 6.28)
        for a in np.linspace(0, 2*math.pi, 190):
            w = (1.0 + 0.021*math.sin(3*a + ph) + 0.013*math.sin(7*a + pas)
                 + 0.008*math.sin(11*a + ph*2))
            pts.append((hx + math.cos(a)*R*w + pas*1.6*S, hy + math.sin(a)*R*w + pas*1.6*S))
        dr.line(pts + [pts[0]], fill=CHINA, width=max(int(4*S), 2), joint="curve")
    fn = STEN(int(40*S))
    num = str(i)
    dr.text((hx + R*0.72 + 3*S, hy - R*0.86 + 3*S), num, font=fn, fill=(46, 10, 8, 150))
    dr.text((hx + R*0.72, hy - R*0.86), num, font=fn, fill=CHINA)
    if MARK_LABELS is not None and (i - 1) < len(MARK_LABELS):
        label_text = MARK_LABELS[i - 1]
    else:
        label_text = f"POINT {PHONETIC[(i - 1) % len(PHONETIC)]}"
    tw = hand_text(dr, label_text, hx, hy + R + 46*S, 62*S, CHINA)
    # leader tick from the circle up to the writing
    dr.line([(hx, hy + R), (hx, hy + R + 16*S)], fill=CHINA, width=max(int(3*S), 1))

# --- title block, stencilled like a photo-interpretation print
MAPNAME = "MONTE BATTAGLIA"
pad = int(44 * S)
t1, t2 = STEN(int(74*S)), TYPE(int(30*S))
# A crisp translucent rectangle behind the title reads as a software UI panel, not a shadow on a
# photograph - real underexposure/vignetting has no straight edges. Blur a rough rectangle into a
# soft-edged pool of shade instead, composited as one layer so it never shows a hard boundary.
vig = Image.new("L", (OUTW, OUTH), 0)
vdr = ImageDraw.Draw(vig)
vdr.rectangle([pad-int(6*S), pad+int(4*S), pad+int(920*S), pad+int(170*S)], fill=150)
vig = vig.filter(ImageFilter.GaussianBlur(int(30*S)))
shade = Image.new("RGB", (OUTW, OUTH), (14, 12, 9))
img_rgba = Image.composite(shade, img.convert("RGB"), vig)
img.paste(img_rgba)
dr.text((pad, pad), MAPNAME, font=t1, fill=(246, 242, 230, 245))
dr.text((pad+int(3*S), pad+int(86*S)), "OPERATION  —  HOLDOUT", font=t2, fill=(238, 232, 214, 225))
dr.text((pad+int(3*S), pad+int(126*S)),
        f"AERIAL RECONNAISSANCE   —   {len(holds)} POSITION" + ("S" if len(holds) != 1 else ""),
        font=t2, fill=(226, 220, 202, 205))

# --- typed data strip, bottom left
t3 = TYPE(int(26*S))
info = ["SORTIE 4117 / FRAME 12", "ALT 8,000 FT   F/L 24 IN", "SCALE APPROX 1:4000", "SECRET"]
for i, ln in enumerate(info):
    dr.text((pad, OUTH - pad - int((len(info)-i)*34*S)), ln, font=t3, fill=(232, 226, 208, 200))

# --- frame + corner registration marks
dr.rectangle([int(16*S), int(16*S), OUTW-int(16*S), OUTH-int(16*S)],
             outline=(236, 230, 212, 120), width=max(int(3*S), 1))
m = int(54*S)
for (cxm, cym) in ((m, m), (OUTW-m, m), (m, OUTH-m), (OUTW-m, OUTH-m)):
    dr.line([(cxm-int(20*S), cym), (cxm+int(20*S), cym)], fill=(240, 234, 216, 190), width=max(int(3*S),1))
    dr.line([(cxm, cym-int(20*S)), (cxm, cym+int(20*S))], fill=(240, 234, 216, 190), width=max(int(3*S),1))

print(f"[{time.time()-t0:5.1f}s] recon treatment + {len(holds)} annotated position(s)")

p = os.path.join(OUT, f"{MAP}_recon.png")
img.save(p)
with open(os.path.join(OUT, f"{MAP}_modern.txt"), "w") as fh:
    fh.write(f"ox {ox}\noy {oy}\nscale {scale/SS}\nW {OUTW}\nH {OUTW}\n")
print(f"[{time.time()-t0:5.1f}s] wrote {p}  {OUTW}x{OUTH}")
