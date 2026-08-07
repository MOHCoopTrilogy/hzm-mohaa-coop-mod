"""Match each models/coop_helmets/*.skd container back to its source gear skd by
comparing per-surface vertex payloads (normal/uv/bone-local offset)."""
import os, glob, sys
import hgvfs, skdlib

OUT = r"C:\mohaa-coop-dev\hzm-mohaa-coop-mod\models\coop_helmets"

CANDIDATES = [
    "models/equipment/USGear/helmets/us_helmet.skd",
    "models/equipment/ukgear/helmets/uk_helmet.skd",
    "models/gear/bob_helmet_camo.skd",
    "models/gear/us_helmet_inside.skd",
    "models/abs/mk2.skd",
    "models/britpack/mk2.skd",
    "models/6abs/british_beret.skd",
    "models/6abs/british_para_helmet_mask.skd",
    "models/britpack/british_offcap2.skd",
    "models/dc/woolcap.skd",
    "models/equipment/britgear/AL_Brit_CMDHAT.skd",
    "models/equipment/britgear/SC_AL_BRIT_TankHat.skd",
    "models/equipment/germangear/creasecap.skd",
    "models/equipment/germangear/officer_hat.skd",
    "models/equipment/USGear/Af_P_Glasses.skd",
    "models/equipment/USGear/AL_US_TankHat.skd",
    "models/gear/g_headgear/coveredhelmet.skd",
    "models/human/brit-beret/brit-beret.skd",
    "models/human/gear/brit_tank_beret/brit_tank_beret.skd",
    "models/human/gear/SovietHat/SeamanHat.skd",
    "models/human/heads/AL_US_MaskHead.skd",
]


def sig(m):
    d = {}
    for s in m.surfaces:
        d[s.name.lower()] = (len(s.verts), len(s.tri_bytes) // 12,
                             tuple(round(c, 3) for (n, uv, wl, ml) in s.verts[:4] for c in uv))
    return d


def offs(m):
    """surface -> tuple of rounded bone-local offsets (first weight)"""
    d = {}
    for s in m.surfaces:
        t = []
        for (n, uv, wl, ml) in s.verts:
            if wl:
                t.append(tuple(round(c, 2) for c in wl[0][2]))
        d[s.name.lower()] = tuple(t)
    return d


src = {}
for c in CANDIDATES:
    b = hgvfs.read(c)
    if b is None:
        print("MISSING SOURCE", c)
        continue
    m = skdlib.read_skd(b)
    src[c] = m
    print("SRC %-58s bones=%-3d %s" % (c, m.numBones,
          [(s.name, len(s.verts)) for s in m.surfaces]))
    print("     bonenames:", [b_.name for b_ in m.bones])

print()
for f in sorted(glob.glob(os.path.join(OUT, "*.skd"))):
    m = skdlib.read_skd(open(f, "rb").read())
    o = offs(m)
    best = []
    for c, sm in src.items():
        so = offs(sm)
        for sn, sv in o.items():
            for tn, tv in so.items():
                if sv and sv == tv:
                    best.append((os.path.basename(f), sn, c, tn))
    print("%-26s %-46s -> %s" % (os.path.basename(f),
          str([(s.name, len(s.verts)) for s in m.surfaces]),
          best if best else "NO MATCH"))
