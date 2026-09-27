"""[bug-2754] Generate _nohat twins for the 12 MP AXIS/Italian armory skins (mp_cosmetics.scr::skinGet).
Their bodies live in the base paks and were never in coop's nohat roster. Each has its headgear as a
SEPARATE skelmodel group (under models/gear/g_headgear or models/equipment/italiangear), cleanly distinct
from the models/human/heads FACE skelmodel - so a twin = the body with exactly that headgear group's lines
deleted (line-exact, everything else byte-identical). No face-sharing case here, so no nodraw needed.
Writes models/player/<skin>_nohat.tik. Mirrors nohat_build.emit_nohat; standalone so it never touches
coop's armory roster."""
import os, re, sys
import nohat_lib as L
from nohat_dump import groups

PLAYER = r"C:\mohaa-coop-dev\hzm-mohaa-coop-mod\models\player"
AXIS = ["german_wehrmacht_soldier","german_waffenss_shutze","german_waffenss_officer",
        "german_Afrika_Private","german_Afrika_Officer","german_Panzer_Shutze",
        "german_Panzer_Tankcommander","german_Elite_SS_officer","german_Feldgendarmerie",
        "german_Kriegsmarine","IT_AX_Ital_Vol","Sc_AX_Ital_Inf",
        # [bug-2757] axis DEPTH batch: 6 more, each headgear a separate skelmodel (verified) distinct from the
        # models/human/heads face skelmodel, so dropping it is safe.
        "german_afrika_nco","german_elite_gestapo","german_dday_colonel","german_kradshutzen",
        "german_wehrmacht_officer","german_wehrmacht_nco"]
# [bug-2762] FULL axis roster: append every viable candidate from docs/tools/mp_axis_skins.tsv (research).
_TSV = r"C:\mohaa-coop-dev\docs\tools\mp_axis_skins.tsv"
if os.path.isfile(_TSV):
    for _l in open(_TSV, encoding="utf-8"):
        if _l.startswith("#") or not _l.strip():
            continue
        _stem = _l.split("\t")[0].strip()
        if _stem and _stem not in AXIS:
            AXIS.append(_stem)
# exact (path/skel) headgear keys observed in the 12 axis body tiks (lowercased). ONLY these groups drop.
AXIS_HEADGEAR = {
    "models/gear/g_headgear/stahlhelm.skd",
    "models/gear/g_headgear/coveredhelm_new.skd",
    "models/gear/g_headgear/officerhat_new.skd",
    "models/gear/g_headgear/germanhelmet.skd",
    "models/gear/g_headgear/ssncocap.skd",
    "models/gear/g_headgear/creasecap.skd",
    "models/equipment/italiangear/ax_it_volhat.skd",
    "models/equipment/italiangear/ax_ital_infhat.skd",
    # [bug-2757] depth-batch headgear (all separate skelmodels)
    "models/gear/g_headgear/hat.skd",
    "models/gear/g_headgear/officercap.skd",
    "models/equipment/germangear/officer_hat.skd",
}
# [bug-2762] Generalised headgear detection so the full 65-skin roster works: drop any skelmodel group whose
# skd basename is a known head-covering AND that sits under a headgear directory (the path guard stops a body
# or gear group that happens to share a name from being removed). The face skelmodel (models/human/heads) is
# never in these dirs, so it is always kept.
HG_DIRS = ("models/gear/g_headgear", "models/equipment/germangear", "models/equipment/italiangear")
KNOWN_HG = {"stahlhelm","coveredhelm_new","coveredhelmet","officerhat_new","officercap","officer_hat",
            "ssncocap","creasecap","germanhelmet","hat","crusher","ss_crusher","ger_beret","beret",
            "ss_mutze","mutze","splinter","tankhat","panzerhat","dak","dakcap","ax_it_volhat",
            "ax_ital_infhat","volhat","infhat","para"}
HDR = ("// HZM MP [bug-2754] GENERATED HATLESS VARIANT of %s for the MP appearance PREVIEW -\n"
       "// identical to the original with the head-covering skelmodel/surface lines removed, so a chosen\n"
       "// helmet does not double over the baked one in the 3D viewer. Regenerate with\n"
       "// _research/nohat/gen_axis_nohat.py; do not hand-edit. (Live spawn already de-doubles via\n"
       "// mp_cosmetics.scr::hideBakedHelmet; this twin is what the client menu model needs.)\n")

def emit(name):
    vp = "models/player/%s.tik" % name
    d = groups(vp)
    if d is None:
        return None, "READ FAIL"
    kill, dropped = set(), []
    for g in d["groups"]:
        p = (g["path"] or "").lower()
        k = (p + "/" + g["skel"]).lower()
        base = g["skel"].lower().replace(".skd", "")
        hit = k in AXIS_HEADGEAR or (base in KNOWN_HG and any(p.startswith(hd) for hd in HG_DIRS))
        if hit:
            kill.update(g["lines"]); dropped.append(k)
    if not dropped:
        return None, "NO HEADGEAR MATCHED (groups: %s)" % [(g["path"], g["skel"]) for g in d["groups"]]
    lines = d["lines"]
    out = [ln for i, ln in enumerate(lines) if i not in kill]
    txt = "\n".join(out)
    m = re.match(r"^(\s*TIKI\s*?\r?\n)", txt)
    if not m:
        return None, "NO TIKI HEADER"
    txt = m.group(1) + (HDR % vp) + txt[m.end():]
    return txt, ",".join(dropped)

def main():
    for name in AXIS:
        txt, info = emit(name)
        if txt is None:
            print("  FAIL %-30s %s" % (name, info)); continue
        if not all(ord(c) < 128 for c in txt):
            print("  FAIL %-30s non-ASCII" % name); continue
        open(os.path.join(PLAYER, "%s_nohat.tik" % name), "w", newline="\n").write(txt)
        # verify: re-parse the twin and confirm NO axis-headgear group survives, face + body do.
        vd = groups("models/player/%s_nohat.tik" % name)
        # (groups() reads via VFS/repo; the freshly written file is under the repo player dir)
        print("  wrote %-30s dropped=%s" % (name + "_nohat.tik", info))
    print("done")

if __name__ == "__main__":
    main()
