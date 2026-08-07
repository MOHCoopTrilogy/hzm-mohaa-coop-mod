"""Top-down render of e3l4_arena from the BSP, with the authored arena content overlaid.

Flying a camera up and screenshotting cannot work here: the map spans ~12000 units and the engine
farplane is 3000 (worldspawn), so a high shot fogs out. Projecting the BSP's own geometry has no
such limit and is exactly repeatable.

Layout facts (validated in scratchpad/bsp_locate.py against this same file):
    header 12B, 28 lumps; LUMP_SHADERS 0, LUMP_SURFACES 3, LUMP_DRAWVERTS 4, entities 14
    dshader_t 140B (name[64], surfaceFlags, contentFlags)
    surface stride 108; drawVert 44 (xyz, st[2], lm[2], normal, color[4])
firstVert/numVerts offset inside the surface record is discovered by validation, not assumed.
"""
import struct, sys, os, io, re, math
import numpy as np
from PIL import Image, ImageDraw

sys.stdout.reconfigure(encoding="utf-8", errors="replace")
BSP = r"G:\GOG\Medal of Honor - Allied Assault War Chest\maintt\maps\e3l4_arena.bsp"
SAVE = r"G:\mohaa-gl2\home\maintt\coop_mod\save"
OUT = os.path.dirname(os.path.abspath(__file__))

SURF_SKY, SURF_NODRAW = 0x4, 0x80

d = open(BSP, "rb").read()
lumps = [struct.unpack_from("<ii", d, 12 + i * 8) for i in range(28)]

soff, slen = lumps[0]
shaders = []
for i in range(slen // 140):
    r = d[soff + i * 140: soff + (i + 1) * 140]
    shaders.append((r[:64].split(b"\x00")[0].decode("latin-1", "replace"),
                    *struct.unpack_from("<ii", r, 64)))

voff, vlen = lumps[4]
nverts = vlen // 44
verts = np.frombuffer(d, dtype=np.float32, count=nverts * 11, offset=voff).reshape(nverts, 11)[:, :3]

foff, flen = lumps[3]
FREC, nf = 108, (lumps[3][1] // 108)

best = None
for fv_off in range(8, 100, 4):
    ok = 0
    for k in range(0, min(nf, 800)):
        fv, nv = struct.unpack_from("<ii", d, foff + k * FREC + fv_off)
        if 0 <= fv < nverts and 0 < nv <= 1024 and fv + nv <= nverts:
            ok += 1
    if ok > 760 and (best is None or ok > best[1]):
        best = (fv_off, ok)
FV = best[0]
print(f"shaders={len(shaders)} faces={nf} verts={nverts}  firstVert@{FV} ({best[1]}/800 valid)")

# ---- collect drawable world faces -------------------------------------------------
polys = []
for k in range(nf):
    sn = struct.unpack_from("<i", d, foff + k * FREC)[0]
    if not (0 <= sn < len(shaders)):
        continue
    name, sflags, cflags = shaders[sn]
    if sflags & (SURF_SKY | SURF_NODRAW):
        continue
    low = name.lower()
    if "caulk" in low or "trigger" in low or "clip" in low or "hint" in low or "portal" in low:
        continue
    fv, nv = struct.unpack_from("<ii", d, foff + k * FREC + FV)
    if nv < 3 or fv + nv > nverts:
        continue
    p = verts[fv:fv + nv]
    polys.append((float(p[:, 2].mean()), p[:, 0].copy(), p[:, 1].copy()))

print(f"drawable brush faces: {len(polys)}")

# ---- TERRAIN (LUMP_TERRAIN 22) -----------------------------------------------------
# MOHAA keeps terrain out of LUMP_SURFACES entirely, so a surfaces-only render shows bare
# parchment where the ground is. cTerraPatch_t (qfiles.h:435) is 385 bytes of fields padded to a
# 388 stride by its float texCoord members - confirmed against this lump: 311564 / 388 = 803 exact.
# Field offsets follow from that layout: x@36, y@37, iBaseHeight@38, heightmap@304.
# World transform is the engine's own (cm_terrain.c:253-259, navigation_bsp_load_terrain.cpp:1074):
#     x0 = x << 6 ; y0 = y << 6 ; z = iBaseHeight + 2 * heightmap[j*9+i]
# so each patch is a 9x9 grid on 64-unit spacing = 512 units square.
toff, tlen = lumps[22]
TSTRIDE, npatch = 388, tlen // 388
tquads = 0
for pi in range(npatch):
    base = toff + pi * TSTRIDE
    px_, py_ = struct.unpack_from("<bb", d, base + 36)
    zbase = struct.unpack_from("<h", d, base + 38)[0]
    hm = d[base + 304: base + 304 + 81]
    x0, y0 = px_ << 6, py_ << 6
    for j in range(8):
        for i in range(8):
            zs4 = (zbase + 2 * hm[j * 9 + i],       zbase + 2 * hm[j * 9 + i + 1],
                   zbase + 2 * hm[(j + 1) * 9 + i + 1], zbase + 2 * hm[(j + 1) * 9 + i])
            xa, xb = x0 + (i << 6), x0 + ((i + 1) << 6)
            ya, yb = y0 + (j << 6), y0 + ((j + 1) << 6)
            polys.append((sum(zs4) / 4.0,
                          np.array([xa, xb, xb, xa], dtype=np.float32),
                          np.array([ya, ya, yb, yb], dtype=np.float32)))
            tquads += 1
print(f"terrain: {npatch} patches -> {tquads} quads")
print(f"total drawable: {len(polys)}")
allx = np.concatenate([p[1] for p in polys]); ally = np.concatenate([p[2] for p in polys])
print(f"world extent  X {allx.min():.0f}..{allx.max():.0f}   Y {ally.min():.0f}..{ally.max():.0f}")

# ---- authored arena content --------------------------------------------------------
def read(p):
    try: return io.open(os.path.join(SAVE, p), encoding="latin-1").read()
    except Exception: return ""

walls = []
for line in read("walls_e3l4_arena.dat").splitlines():
    line = line.strip()
    if not line or line.startswith("//"): continue
    f = line.split("|")[0].split()
    if len(f) >= 3:
        try: walls.append(tuple(float(x) for x in f[:3]))
        except Exception: pass

props = []
for line in read("props_e3l4_arena.dat").splitlines():
    line = line.strip()
    if not line or line.startswith("//"): continue
    parts = line.split("|")
    if len(parts) >= 2:
        f = parts[1].split()
        if len(f) >= 3:
            try: props.append((parts[0], tuple(float(x) for x in f[:3])))
            except Exception: pass

checkpoint, enemies = None, []
ho = read("holdout_e3l4_arena.dat").strip()
if ho:
    seg = ho.split(",")
    if len(seg) >= 4:
        try: checkpoint = tuple(float(x) for x in seg[1].split()[:3])
        except Exception: pass
        for chunk in seg[3].split("|"):
            f = chunk.split()
            if len(f) >= 3:
                try: enemies.append(tuple(float(x) for x in f[:3]))
                except Exception: pass

sounds = []
for m in re.finditer(r"origin = \(\s*([-\d.]+)\s+([-\d.]+)\s+([-\d.]+)\s*\)", read("snd_e3l4_arena.dat")):
    sounds.append(tuple(float(g) for g in m.groups()))

print(f"authored: {len(walls)} barriers, {len(props)} props, {len(enemies)} enemy spawns, "
      f"{len(sounds)} sounds, checkpoint={checkpoint}")

# ---- render -------------------------------------------------------------------------
def render(name, cx, cy, half, px=2048, label=""):
    x0, x1, y0, y1 = cx - half, cx + half, cy - half, cy + half
    scale = px / (2.0 * half)
    img = Image.new("RGB", (px, px), (234, 222, 197))       # parchment
    dr = ImageDraw.Draw(img, "RGBA")

    def T(wx, wy):                                           # world -> image (Y up = north)
        return ((wx - x0) * scale, (y1 - wy) * scale)

    sel = [p for p in polys if p[1].max() >= x0 and p[1].min() <= x1
                            and p[2].max() >= y0 and p[2].min() <= y1]
    zs = np.array([p[0] for p in sel]) if sel else np.array([0.0])
    zlo, zhi = np.percentile(zs, 2), np.percentile(zs, 98)
    span = max(zhi - zlo, 1.0)

    for z, xs, ys in sorted(sel, key=lambda t: t[0]):        # painter's: low first
        t = min(max((z - zlo) / span, 0.0), 1.0)
        # parchment -> sepia -> deep umber as elevation rises
        r = int(214 - 96 * t); g = int(196 - 104 * t); b = int(160 - 96 * t)
        dr.polygon([T(a, bb) for a, bb in zip(xs, ys)], fill=(r, g, b, 226))

    def ring(p, rad, col, w=5):
        x, y = T(p[0], p[1]); dr.ellipse([x-rad, y-rad, x+rad, y+rad], outline=col, width=w)
    def dot(p, rad, col):
        x, y = T(p[0], p[1]); dr.ellipse([x-rad, y-rad, x+rad, y+rad], fill=col)

    for w_ in walls:   dot(w_, 3, (40, 60, 120, 200))                 # barrier line
    for _, p in props: dot(p, 4, (40, 110, 60, 210))                  # props
    for s in sounds:   ring(s, 9, (150, 110, 30, 220), 3)             # ambience
    for e in enemies:  ring(e, 26, (168, 32, 32, 255), 7); dot(e, 7, (168, 32, 32, 255))
    if checkpoint:
        ring(checkpoint, 34, (20, 70, 160, 255), 8); dot(checkpoint, 10, (20, 70, 160, 255))

    img.save(os.path.join(OUT, name))
    print(f"  wrote {name}  ({label}) center=({cx:.0f},{cy:.0f}) half={half}u  faces drawn={len(sel)}")

# whole map, and the authored arena
wcx, wcy = (allx.min()+allx.max())/2, (ally.min()+ally.max())/2
whalf = max(allx.max()-allx.min(), ally.max()-ally.min())/2 * 1.02
render("e3l4_full.png", wcx, wcy, whalf, 2048, "whole map")

axs = [w[0] for w in walls] + [e[0] for e in enemies] + ([checkpoint[0]] if checkpoint else [])
ays = [w[1] for w in walls] + [e[1] for e in enemies] + ([checkpoint[1]] if checkpoint else [])
acx, acy = (min(axs)+max(axs))/2, (min(ays)+max(ays))/2
ahalf = max(max(axs)-min(axs), max(ays)-min(ays))/2 * 1.18
render("e3l4_arena_zone.png", acx, acy, ahalf, 2048, "arena + all enemy spawns")

# TIGHT crop on the barrier ring itself. The enemy spawns are deliberately OUTSIDE the perimeter
# (they are approach points), so including them nearly doubles the crop and buries the playable
# area in empty ground. This framing is the one worth styling into a loading screen.
if walls:
    wxs = [w[0] for w in walls]; wys = [w[1] for w in walls]
    bcx, bcy = (min(wxs)+max(wxs))/2, (min(wys)+max(wys))/2
    bhalf = max(max(wxs)-min(wxs), max(wys)-min(wys))/2 * 1.15
    render("e3l4_arena_tight.png", bcx, bcy, bhalf, 2048, "barrier ring only")
    print(f"\nbarrier ring: center ({bcx:.0f} {bcy:.0f})  half-extent {bhalf:.0f}u  "
          f"({2*bhalf:.0f}u across)")
