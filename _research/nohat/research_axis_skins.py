"""[deep research] Enumerate every AXIS (german/italian) 3P player model, classify its headgear group,
suggest a coop_helmets Standard-Issue piece, and flag viability for the MP skin roster. Output a report."""
import json, re, os
import nohat_dump as D
import nohat_lib as L

idx = json.load(open("nohat_index.json"))
# headgear skd basename (lowercased, no .skd) -> coop_helmets piece stem (must exist in models/coop_helmets)
SKD2PIECE = {
    "stahlhelm":"coop_helmet_ger_helmet", "germanhelmet":"coop_helmet_ger_helmet",
    "coveredhelm_new":"coop_helmet_ger_covered", "coveredhelmet":"coop_helmet_ger_covered",
    "officerhat_new":"coop_helmet_ss_officerhat", "officercap":"coop_helmet_ger_officercap",
    "officer_hat":"coop_helmet_ger_offhat_sh", "ssncocap":"coop_helmet_ssncocap",
    "creasecap":"coop_helmet_ger_creasecap", "hat":"coop_helmet_ger_hat",
    "crusher":"coop_helmet_ger_crusher", "ss_crusher":"coop_helmet_ger_crusher",
    "ger_beret":"coop_helmet_ger_beret", "beret":"coop_helmet_ger_beret",
    "ss_mutze":"coop_helmet_ss_mutze", "mutze":"coop_helmet_ss_mutze",
    "splinter":"coop_helmet_ger_splinter", "tankhat":"coop_helmet_ger_tankhat",
    "panzerhat":"coop_helmet_ger_tankhat", "dak":"coop_helmet_dak_hat", "dakcap":"coop_helmet_dak_hat",
    "ax_it_volhat":"coop_helmet_ital_volhat", "ax_ital_infhat":"coop_helmet_ital_infhat",
    "volhat":"coop_helmet_ital_volhat", "infhat":"coop_helmet_ital_infhat", "para":"coop_helmet_ital_para",
}
HELMDIR = "../../models/coop_helmets"
PIECES = set(f[:-4] for f in os.listdir(HELMDIR) if f.endswith(".tik"))
HG_PATHS = ("models/gear/g_headgear", "models/equipment/germangear", "models/equipment/italiangear",
            "models/gear/heer", "models/gear/ss", "models/gear/dak", "models/gear/panzer")
USED = {"german_wehrmacht_soldier","german_waffenss_shutze","german_waffenss_officer","german_afrika_private",
 "german_afrika_officer","german_panzer_shutze","german_panzer_tankcommander","german_elite_ss_officer",
 "german_feldgendarmerie","german_kriegsmarine","it_ax_ital_vol","sc_ax_ital_inf","german_afrika_nco",
 "german_elite_gestapo","german_dday_colonel","german_kradshutzen","german_wehrmacht_officer","german_wehrmacht_nco"}

# candidate 3P models (exclude _fps and the 18 already used)
cands=set()
for v in idx:
    m=re.match(r'models/player/([a-z0-9_]+)\.tik$', v)
    if not m: continue
    stem=m.group(1)
    if stem.endswith("_fps"): continue
    if not (stem.startswith("german_") or "ital" in stem or stem.startswith("it_ax") or stem.startswith("sc_ax")): continue
    if stem in USED: continue
    cands.add(stem)

viable=[]; unmapped=[]; noface=[]; nohg=[]
for stem in sorted(cands):
    d=D.groups("models/player/%s.tik"%stem)
    if d is None: continue
    face=any((g["path"] or "").lower()=="models/human/heads" for g in d["groups"])
    hg=[]
    for g in d["groups"]:
        p=(g["path"] or "").lower()
        if any(p.startswith(h) for h in HG_PATHS):
            skd=g["skel"].lower().replace(".skd","")
            # only count it as HEADGEAR if we recognise the skd as headgear (not a belt/holster/clip)
            if skd in SKD2PIECE:
                hg.append((g["path"]+"/"+g["skel"], skd, SKD2PIECE[skd]))
    if not face: noface.append(stem); continue
    if not hg: nohg.append(stem); continue
    # take the first recognised headgear group; verify its suggested piece exists
    key,skd,piece = hg[0]
    if piece not in PIECES:
        unmapped.append((stem,skd,piece)); continue
    viable.append((stem,skd,piece))

out=["AXIS SKIN RESEARCH - candidates beyond the 18 already in MP","="*90,
     "VIABLE (separate headgear skelmodel + face + a matching coop_helmets piece exists): %d"%len(viable),""]
for stem,skd,piece in viable:
    out.append("  %-42s headgear=%-18s -> %s" % (stem, skd, piece))
out += ["","NO RECOGNISED HEADGEAR GROUP (bareheaded, or headgear skd not classified): %d"%len(nohg),
        "  "+", ".join(nohg)]
out += ["","NO FACE GROUP (skip - would break): %d"%len(noface), "  "+", ".join(noface)]
if unmapped:
    out += ["","MAPPED PIECE MISSING (needs a piece): %d"%len(unmapped)]
    for stem,skd,piece in unmapped: out.append("  %-42s %s -> %s (MISSING)"%(stem,skd,piece))
open("axis_skin_research.txt","w").write("\n".join(out)+"\n")
print("\n".join(out[:4]))
print("... full report: _research/nohat/axis_skin_research.txt")
print("VIABLE=%d  no-headgear=%d  no-face=%d  unmapped=%d"%(len(viable),len(nohg),len(noface),len(unmapped)))
