"""bug-15xx HATLESS ARMORY BODIES.

1. build 4 new exact-fit container skds (build_pieces recipe) for the headgear meshes that
   had no container yet
2. emit one coop_std_*.tik "Standard Issue" piece per distinct headgear signature
3. emit models/player/<skin>_nohat.tik for every armory skin, with the head-covering
   skelmodel/surface lines deleted (line-exact, everything else byte-identical)
"""
import os, re, json, struct, collections, sys
import nohat_lib as L
from nohat_dump import roster, groups
from nohat_plan import CONTAINER, HEADBEARING, HEADGEAR, shipped_pieces

ROOT = r"C:\mohaa-coop-dev\hzm-mohaa-coop-mod"
HELM = os.path.join(ROOT, "models", "coop_helmets")
PLAYER = os.path.join(ROOT, "models", "player")

BUG = "1544"

# ------------------------------------------------------------------ containers
NEW_CONTAINERS = [
    ("std_liner.skd", "models/gear/us_helmet_inside.skd", ["us_helmet_inside"],
     "the US helmet's inner liner shell - same 147-vert mesh as the worn us_helmet.skd,\n"
     "// different texture, stacked under it on the Band-of-Brothers airborne skins."),
    ("std_camo.skd", "models/gear/bob_helmet_camo.skd", ["bob_helmet_camo"],
     "the D-Day scrim/camo net cover worn over the helmet on the 101st/82nd airborne skins."),
    ("std_beret6abs.skd", "models/6abs/british_beret.skd", ["britberet"],
     "the 6th Airborne pack's British beret (allied_british_paratroops* / polish para)."),
    ("std_creasecap.skd", "models/equipment/germangear/creasecap.skd", ["creasecap"],
     "germangear/creasecap.skd - the crease cap worn by allied_Commanding_Officer and\n"
     "// allied_russian_Pvt. NOT the same mesh as the shipped ger_creasecap.skd piece, which\n"
     "// was lifted from models/gear/g_headgear/creasecap.skd (identical UVs, different verts)."),
]

REF = os.path.join(HELM, "us_helmetfit.skd")
BONE_BLOCK = open(REF, "rb").read()[148:264]
assert len(BONE_BLOCK) == 116 and BONE_BLOCK[0:6] == b"Box01\x00"


def build_skd(name, surfaces):
    blobs = []
    for (surfname, tri_bytes, verts) in surfaces:
        nT = len(tri_bytes) // 12
        nV = len(verts)
        vb = bytearray()
        for (normal, uv, off) in verts:
            vb += struct.pack("<3f2f2i", *normal, *uv, 1, 0)
            vb += struct.pack("<if3f", 0, 1.0, *off)
        assert len(vb) == nV * 48
        ofsTri = 100
        ofsVerts = ofsTri + nT * 12
        ofsColl = ofsVerts + nV * 48
        ofsCollIdx = ofsColl + nV * 4
        ofsEnd = ofsCollIdx + nV * 4
        sn = surfname.encode("latin-1")
        hdr = struct.pack("<4s64s8i", b"SKL ", sn + b"\x00" * (64 - len(sn)),
                          nT, nV, 0, ofsTri, ofsVerts, ofsColl, ofsEnd, ofsCollIdx)
        coll = struct.pack("<%di" % nV, *range(nV))
        collidx = struct.pack("<%di" % nV, *([0] * nV))
        blob = hdr + bytes(tri_bytes) + bytes(vb) + coll + collidx
        assert len(blob) == ofsEnd
        blobs.append(blob)
    body = b"".join(blobs)
    total = 148 + len(BONE_BLOCK) + len(body)
    nm = name.encode("latin-1")
    header = struct.pack("<4si64s5i10i4i", b"SKMD", 5, nm + b"\x00" * (64 - len(nm)),
                         len(surfaces), 1, 148, 148 + len(BONE_BLOCK), total,
                         *([0] * 10), 0, 0, 0, 0)
    assert len(header) == 148
    return header + BONE_BLOCK + body


def take(skdpath, surfnames):
    import hgvfs, skdlib
    m = skdlib.read_skd(hgvfs.read(skdpath))
    got = []
    for want in surfnames:
        s = next(x for x in m.surfaces if x.name.lower() == want.lower())
        verts = []
        for (normal, uv, wl, ml) in s.verts:
            assert len(wl) == 1 and not ml, (skdpath, want)
            assert abs(wl[0][1] - 1.0) < 1e-4
            verts.append((normal, uv, wl[0][2]))
        got.append((s.name, s.tri_bytes, verts))
    return got


def do_containers():
    import skdlib
    for (skdname, src, surfs, note) in NEW_CONTAINERS:
        got = take(src, surfs)
        data = build_skd(skdname, got)
        open(os.path.join(HELM, skdname), "wb").write(data)
        # re-parse + verify byte-identical geometry
        m = skdlib.read_skd(data)
        assert m.numSurfaces == len(got) and m.numBones == 1
        for s, (sn, tb, vs) in zip(m.surfaces, got):
            assert s.name == sn and len(s.verts) == len(vs)
            assert s.tri_bytes == tb
            nTri = len(tb) // 12
            idxs = struct.unpack("<%di" % (nTri * 3), tb)
            assert min(idxs) >= 0 and max(idxs) < len(vs), (skdname, sn)
            for (n2, uv2, wl2, ml2) in s.verts:
                assert len(wl2) == 1 and wl2[0][0] == 0
        print("  container %-20s %7d bytes  %s" % (skdname, len(data),
              [(s.name, len(s.verts)) for s in m.surfaces]))


# ------------------------------------------------------------------ signatures
def skin_sig(name):
    d = groups("models/player/%s.tik" % name)
    sig = []
    for g in d["groups"]:
        k = ((g["path"] or "") + "/" + g["skel"]).lower()
        if k not in HEADGEAR:
            continue
        cont, smap = CONTAINER[k]
        drop = HEADBEARING.get(k)
        for (sn, sh, _ln) in g["surfaces"]:
            if drop and sn.lower() == drop.lower():
                continue
            sig.append((cont, smap[sn.lower()], sh))
    return sig


def san(s):
    return re.sub(r"[^A-Za-z0-9]+", "_", s).strip("_").lower()


TIK_HEAD = """TIKI
// HZM coop [user 08-07] bug-{bug}: STANDARD ISSUE headgear piece for the hatless armory
// bodies (models/player/*_nohat.tik). The armory bodies no longer carry any baked headgear,
// so "Standard Issue" attaches this - the SAME mesh and the SAME shader the body used to
// carry, so the default look is unchanged. Geometry container: see the piece it reuses.
// Worn by: {skins}
setup
{{
\tscale 0.52
{body}}}

animations
{{
\tidle\t\t{idle}
}}
"""


def emit_std(sig, skins):
    """sig: [(container, surface, shader)] -> writes coop_std_<key>.tik, returns its vpath"""
    lines = []
    seen = []
    curpath = None
    for (cont, surf, sh) in sig:
        if cont.startswith("="):
            src = cont[1:]
            p, s = src.rsplit("/", 1)
        else:
            p, s = "models/coop_helmets", cont
        if (p, s) not in seen:
            seen.append((p, s))
            if p != curpath:
                lines.append("\tpath %s\n" % p)
                curpath = p
            lines.append("\tskelmodel %s\n" % s)
        lines.append("\tsurface %s shader %s\n" % (surf, sh))
    # the animations block inherits the LAST setup `path` (tiki_script.cpp ProcessCommand /
    # tiki_parse.cpp:471), so park it back on models/coop_helmets for the shared idle skc.
    if curpath != "models/coop_helmets":
        lines.append("\tpath models/coop_helmets\n")
    idle = "us_helmetfit.skc"
    key = san(sig[0][2])
    fn = "coop_std_%s.tik" % key
    txt = TIK_HEAD.format(bug=BUG, skins=", ".join(skins), body="".join(lines), idle=idle)
    return fn, txt


# ------------------------------------------------------------------ nohat tiks
def emit_nohat(name):
    vp = "models/player/%s.tik" % name
    d = groups(vp)
    kill = set()          # line index -> delete
    replace = {}          # line index -> replacement text
    for g in d["groups"]:
        k = ((g["path"] or "") + "/" + g["skel"]).lower()
        if k not in HEADGEAR:
            continue
        drop = HEADBEARING.get(k)
        if drop:
            # head-bearing skd (the gas-mask head): the FACE lives on the same skelmodel, so
            # the skelmodel stays and only the covering surface is baked off with a TIKI-level
            # `flags nodraw` (tiki_parse.cpp:1082 TIKI_ParseSurfaceFlag).
            for (sn, sh, ln) in g["surfaces"]:
                if sn.lower() != drop.lower():
                    replace[ln] = "\tsurface %s shader %s flags nodraw" % (sn, sh)
            continue
        kill.update(g["lines"])
    lines = d["lines"]
    out = []
    for i, ln in enumerate(lines):
        if i in kill:
            continue
        out.append(replace.get(i, ln))
    hdr = ("// HZM coop [user 08-07] bug-%s GENERATED HATLESS VARIANT of %s -\n"
           "// identical to the original with the head-covering skelmodel/surface lines removed,\n"
           "// so the helmet switcher's chosen piece is the only thing on the head. Regenerate with\n"
           "// scratchpad/nohat_build.py; do not hand-edit. Standard Issue re-attaches the original\n"
           "// headgear as a coop_std_*.tik piece (coop_mod/helmet.scr::level.coop_skinStdHelmet).\n"
           % (BUG, vp))
    txt = "\n".join(out)
    # splice the header in after the leading TIKI line
    m = re.match(r"^(\s*TIKI\s*?\r?\n)", txt)
    assert m, name
    txt = m.group(1) + hdr + txt[m.end():]
    return txt


def main():
    print("== containers")
    do_containers()

    r = roster()
    ship = shipped_pieces()
    shipidx = {}
    for tik, (skd, surfs) in ship.items():
        shipidx[(skd, tuple(sorted((a.lower(), b.lower()) for a, b in surfs)))] = tik
    # default-shader pieces (no surface line in the tik = the skd's own surface name)
    shipidx[("=models/human/brit-beret/brit-beret.skd", (("brit_beret", "brit_beret"),))] = \
        "models/coop_helmets/coop_helmet_brit_beret.tik"
    shipidx[("=models/human/gear/SovietHat/SeamanHat.skd", (("hat", "seamanhat"),))] = \
        "models/coop_helmets/coop_helmet_soviet_hat.tik"

    stdmap = {}
    need = collections.OrderedDict()
    hatless = []
    for idx, name in r:
        sig = skin_sig(name)
        if not sig:
            hatless.append(name)
            stdmap[name] = ""
            continue
        conts = sorted(set(c for c, s, sh in sig))
        k = (tuple(conts), tuple(sorted((s.lower(), sh.lower()) for c, s, sh in sig)))
        if len(conts) == 1:
            hit = shipidx.get((conts[0], k[1]))
            if hit:
                stdmap[name] = hit
                continue
        need.setdefault(k, [sig, []])[1].append(name)

    print("== std pieces")
    used = set()
    for k, (sig, names) in need.items():
        fn, txt = emit_std(sig, names)
        n = 2
        base = fn
        while fn in used:
            fn = base[:-4] + "_%d.tik" % n
            n += 1
            txt = txt  # name only
        used.add(fn)
        assert all(ord(c) < 128 for c in txt), fn
        open(os.path.join(HELM, fn), "w", newline="\n").write(txt)
        for nm in names:
            stdmap[nm] = "models/coop_helmets/" + fn
    print("  wrote %d coop_std_*.tik" % len(used))

    print("== hatless bodies")
    for idx, name in r:
        txt = emit_nohat(name)
        assert all(ord(c) < 128 for c in txt), name
        open(os.path.join(PLAYER, "%s_nohat.tik" % name), "w", newline="\n").write(txt)
    print("  wrote %d models/player/*_nohat.tik (%d of them already hatless: %s)"
          % (len(r), len(hatless), ", ".join(hatless)))

    json.dump({"stdmap": stdmap, "hatless": hatless,
               "pieces": sorted(used)}, open("nohat_result.json", "w"), indent=1)


if __name__ == "__main__":
    main()
