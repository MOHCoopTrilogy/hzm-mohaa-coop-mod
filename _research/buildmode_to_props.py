"""Convert build-mode captures into a file the mod actually reloads.

THE GAP THIS CLOSES
    coop_mod/buildmode.scr:772 writes coop_mod/save/build_<map>.dat as paste-ready SCRIPT TEXT.
    Nothing in the mod ever reads it back.
    coop_mod/props.scr:46 reads coop_mod/save/props_<map>.dat, a DATA format, and spawns every row.
    Nothing in the mod ever writes props_<map>.dat.
    So everything placed in build mode is lost on the next map load, silently, with a saved-looking
    file sitting right there. (Same shape as snd_<map>.dat - see bug-1398.)

    This reads the build capture, extracts the placements, and appends them to the props file in
    the format props.scr already parses:

        <tik>|<x y z>|<pitch yaw roll>|<scale>|<solid>

USAGE
    python buildmode_to_props.py <mapname> [--save-dir DIR] [--dry-run]

Idempotent: a placement already present in the props file (same model, same position to 0.1u) is
skipped, so running it twice does not duplicate the map.
"""
import argparse, io, os, re, sys, shutil

DEFAULT_SAVE = r"G:\mohaa-gl2\home\maintt\coop_mod\save"

BLOCK = re.compile(
    r'local\.m\s*=\s*spawn\s+script_model(?P<body>.*?)(?=local\.m\s*=\s*spawn\s+script_model|\Z)',
    re.S | re.I)
RE_MODEL = re.compile(r'local\.m\s+model\s+"([^"]+)"', re.I)
RE_ORG   = re.compile(r'local\.m\.origin\s*=\s*\(\s*([-\d.eE]+)\s+([-\d.eE]+)\s+([-\d.eE]+)\s*\)', re.I)
RE_ANG   = re.compile(r'local\.m\.angles\s*=\s*\(\s*([-\d.eE]+)\s+([-\d.eE]+)\s+([-\d.eE]+)\s*\)', re.I)
RE_SCALE = re.compile(r'local\.m\s+scale\s+([-\d.eE]+)', re.I)
RE_SOLID = re.compile(r'local\.m\s+solid\b', re.I)


def parse_build(text):
    out = []
    for m in BLOCK.finditer(text):
        body = m.group("body")
        mo = RE_MODEL.search(body)
        og = RE_ORG.search(body)
        if not mo or not og:
            continue
        an = RE_ANG.search(body)
        sc = RE_SCALE.search(body)
        out.append({
            "tik":   mo.group(1),
            "pos":   tuple(float(x) for x in og.groups()),
            "ang":   tuple(float(x) for x in an.groups()) if an else (0.0, 0.0, 0.0),
            "scale": float(sc.group(1)) if sc else 1.0,
            "solid": 1 if RE_SOLID.search(body) else 0,
        })
    return out


def parse_props(text):
    """Existing rows -> a set of (tik, rounded pos) for dedupe."""
    seen = set()
    rows = []
    for line in text.splitlines():
        s = line.strip()
        if not s or s.startswith("//"):
            continue
        parts = s.split("|")
        if len(parts) < 2:
            continue
        try:
            p = tuple(round(float(v), 1) for v in parts[1].split()[:3])
        except ValueError:
            continue
        seen.add((parts[0].lower(), p))
        rows.append(s)
    return seen, rows


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("map")
    ap.add_argument("--save-dir", default=DEFAULT_SAVE)
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()

    bpath = os.path.join(a.save_dir, f"build_{a.map}.dat")
    ppath = os.path.join(a.save_dir, f"props_{a.map}.dat")
    if not os.path.exists(bpath):
        print(f"no build capture at {bpath}")
        return 1

    placements = parse_build(io.open(bpath, encoding="latin-1").read())
    print(f"build_{a.map}.dat -> {len(placements)} placement(s)")

    ptext = io.open(ppath, encoding="latin-1").read() if os.path.exists(ppath) else ""
    seen, rows = parse_props(ptext)
    print(f"props_{a.map}.dat -> {len(rows)} existing row(s)")

    added, dupes = [], 0
    for p in placements:
        key = (p["tik"].lower(), tuple(round(v, 1) for v in p["pos"]))
        if key in seen:
            dupes += 1
            continue
        seen.add(key)
        added.append("{tik}|{px:.3f} {py:.3f} {pz:.3f}|{ax:.0f} {ay:.0f} {az:.0f}|{sc:g}|{so}".format(
            tik=p["tik"], px=p["pos"][0], py=p["pos"][1], pz=p["pos"][2],
            ax=p["ang"][0], ay=p["ang"][1], az=p["ang"][2], sc=p["scale"], so=p["solid"]))

    print(f"  {len(added)} new, {dupes} already present")
    for ln in added:
        print("    +", ln)
    if a.dry_run or not added:
        if not added:
            print("nothing to do")
        return 0

    if os.path.exists(ppath):
        shutil.copy2(ppath, ppath + ".bak")
        print(f"  backup -> {os.path.basename(ppath)}.bak")

    body = ptext
    if body and not body.endswith("\n"):
        body += "\n"
    if not body:
        body = f"// HZM coop - props for {a.map}, reloaded by coop_mod/props.scr\n"
    body += "\n".join(added) + "\n"
    io.open(ppath, "w", encoding="latin-1", newline="\n").write(body)
    print(f"wrote {ppath}  ({len(rows) + len(added)} rows total)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
