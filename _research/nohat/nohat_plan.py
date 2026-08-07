"""Plan: per-armory-skin headgear -> (container skd, [(surface, shader)]) signature,
deduped against the 47 shipped coop_helmets pieces."""
import os, re, json, collections
import nohat_lib as L
from nohat_dump import roster, groups

HELMDIR = r"C:\mohaa-coop-dev\hzm-mohaa-coop-mod\models\coop_helmets"

# source gear skd (lowercased virtual path) -> (container skd, {source surface -> container surface})
# "=" container means: attach the SOURCE skd directly (proven recipe, pieces 30/31/32).
CONTAINER = {
    "models/equipment/usgear/helmets/us_helmet.skd":
        ("us_helmetfit.skd", {"us_helmet": "us_helmetstatic"}),
    "models/gear/us_helmet_inside.skd":
        ("std_liner.skd", {"us_helmet_inside": "us_helmet_inside"}),
    "models/gear/bob_helmet_camo.skd":
        ("std_camo.skd", {"bob_helmet_camo": "bob_helmet_camo"}),
    "models/equipment/ukgear/helmets/uk_helmet.skd":
        ("uk_helmet.skd", {"us_helmet": "us_helmet"}),
    "models/abs/mk2.skd":       ("brit_mk2.skd", {"helmet_mk2a": "helmet_mk2a"}),
    "models/britpack/mk2.skd":  ("brit_mk2.skd", {"helmet_mk2a": "helmet_mk2a"}),
    "models/6abs/british_beret.skd":
        ("std_beret6abs.skd", {"britberet": "britberet"}),
    "models/6abs/british_para_helmet_mask.skd":
        ("brit_paramask.skd", {"britparamask": "britparamask"}),
    "models/britpack/british_offcap2.skd":
        ("brit_offcap2.skd", {"offcap2": "offcap2"}),
    "models/dc/woolcap.skd":    ("woolcap.skd", {"woolcap": "woolcap"}),
    "models/equipment/britgear/al_brit_cmdhat.skd":
        ("brit_cmdhat.skd", {"al_brit_cmdhat": "AL_BRIT_CMDHAT"}),
    "models/equipment/britgear/sc_al_brit_tankhat.skd":
        ("brit_tankhat.skd", {"brittankhat": "BritTankHat"}),
    "models/equipment/germangear/creasecap.skd":
        ("std_creasecap.skd", {"creasecap": "creasecap"}),
    "models/equipment/germangear/officer_hat.skd":
        ("ger_offhat_sh.skd", {"officer_hat": "officer_hat"}),
    "models/equipment/usgear/af_p_glasses.skd":
        ("avglasses.skd", {"af_p_glasses": "Af_P_Glasses", "af_p_lens": "Af_P_Lens"}),
    "models/equipment/usgear/al_us_tankhat.skd":
        ("us_tankhat.skd", {"lambert8": "lambert8"}),
    "models/gear/g_headgear/coveredhelmet.skd":
        ("ger_covered.skd", {"outside": "outside", "inside": "inside"}),
    "models/human/brit-beret/brit-beret.skd":
        ("=models/human/brit-beret/brit-beret.skd", {"brit_beret": "brit_beret"}),
    "models/human/gear/brit_tank_beret/brit_tank_beret.skd":
        ("brit_tankberet.skd", {"beret": "beret", "goggles": "goggles"}),
    "models/human/gear/soviethat/seamanhat.skd":
        ("=models/human/gear/SovietHat/SeamanHat.skd", {"hat": "hat"}),
    "models/human/heads/al_us_maskhead.skd":
        ("us_gasmask.skd", {"al_us_mask": "AL_US_Mask"}),
}
# the head-bearing special case: this skd also carries the FACE, so it is not removed
# wholesale - only its mask surface is dropped (tik-level `flags nodraw`).
HEADBEARING = {"models/human/heads/al_us_maskhead.skd": "AL_US_MaskHead"}

HEADGEAR = set(CONTAINER)


def shipped_pieces():
    """coop_helmet_*.tik -> (skd or =path, ((surface, shader), ...))"""
    out = {}
    for fn in sorted(os.listdir(HELMDIR)):
        if not fn.startswith("coop_helmet_") or not fn.endswith(".tik"):
            continue
        txt = open(os.path.join(HELMDIR, fn), encoding="latin-1").read()
        d = L.strip_comments(txt).split("\n")
        path, skel, surfs = None, None, []
        for ln in d:
            t = L.toks(ln)
            if not t:
                continue
            if t[0].lower() == "path":
                path = t[1]
            elif t[0].lower() == "skelmodel":
                skel = t[1]
            elif t[0].lower() == "surface" and len(t) >= 4:
                surfs.append((t[1], t[3]))
        key = skel if path and path.lower() == "models/coop_helmets" else "=" + path + "/" + skel
        out["models/coop_helmets/" + fn] = (key, tuple(surfs))
    return out


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
            if sn.lower() not in smap:
                raise SystemExit("unmapped surface %s on %s (%s)" % (sn, k, name))
            sig.append((cont, smap[sn.lower()], sh))
    return sig


def sigkey(sig):
    """collapse to (container, ((surf, shader),...)) - only single-container sigs allowed
    to reuse a shipped piece; multi-container sigs need a merged container."""
    conts = [c for c, s, sh in sig]
    return tuple(sig)


if __name__ == "__main__":
    r = roster()
    ship = shipped_pieces()
    # index shipped pieces by (skd, frozenset of (surface,shader))
    shipidx = {}
    for tik, (skd, surfs) in ship.items():
        shipidx[(skd, tuple(sorted((a.lower(), b.lower()) for a, b in surfs)))] = tik

    per = {}
    need = collections.OrderedDict()
    hatless = []
    for idx, name in r:
        sig = skin_sig(name)
        if not sig:
            hatless.append(name)
            per[name] = None
            continue
        conts = sorted(set(c for c, s, sh in sig))
        k = (tuple(conts), tuple(sorted((s.lower(), sh.lower()) for c, s, sh in sig)))
        if len(conts) == 1:
            hit = shipidx.get((conts[0], k[1]))
            if hit:
                per[name] = hit
                continue
        need.setdefault(k, (sig, []))[1].append(name)

    print("=== skins already hatless (%d): %s" % (len(hatless), hatless))
    print("=== exact reuse of a shipped piece (%d):" % sum(1 for v in per.values() if v))
    for n, v in sorted(per.items()):
        if v:
            print("    %-46s %s" % (n, v))
    print("=== new std pieces needed (%d distinct):" % len(need))
    for k, (sig, names) in need.items():
        print("    %-70s  x%d  %s" % (str(sig), len(names), names[:4]))
    json.dump({"hatless": hatless,
               "reuse": {n: v for n, v in per.items() if v},
               "need": [[list(map(list, sig)), names] for (sig, names) in need.values()]},
              open("nohat_plan.json", "w"), indent=1)
