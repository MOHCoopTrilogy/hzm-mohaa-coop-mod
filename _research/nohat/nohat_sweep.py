#!/usr/bin/env python3
"""bug-15xx: build the authoritative live corpus of models/player/*.tik and the
resolved winner for each, honouring MOHAA/OpenMOHAA pak precedence."""
import os, re, sys, zipfile, json, io

BASE = r"G:\GOG\Medal of Honor - Allied Assault War Chest"
HOME = r"C:\Users\curry\AppData\Roaming\openmohaa"
REPO = r"C:\mohaa-coop-dev\hzm-mohaa-coop-mod"

DIRRANK = {"main": 0, "mainta": 1, "maintt": 2}


def paks():
    out = []
    for root, hrank in ((BASE, 0), (HOME, 1)):
        for d, drank in DIRRANK.items():
            p = os.path.join(root, d)
            if not os.path.isdir(p):
                continue
            for f in os.listdir(p):
                if f.lower().endswith(".pk3"):
                    # priority: homepath > dir order > pak name (later name wins)
                    out.append(((hrank, drank, f.lower()), os.path.join(p, f)))
    out.sort(key=lambda t: t[0])
    return out


def build_index():
    """path(lower) -> list of (priority, pakpath, membername) sorted ascending prio."""
    idx = {}
    for prio, pk in paks():
        try:
            z = zipfile.ZipFile(pk)
        except Exception as e:
            print("SKIP", pk, e, file=sys.stderr)
            continue
        for n in z.namelist():
            if n.endswith("/"):
                continue
            key = n.lower().replace("\\", "/")
            idx.setdefault(key, []).append((prio, pk, n))
        z.close()
    return idx


def repo_files():
    out = {}
    for dp, _, fns in os.walk(REPO):
        for fn in fns:
            full = os.path.join(dp, fn)
            rel = os.path.relpath(full, REPO).replace("\\", "/").lower()
            out[rel] = full
    return out


if __name__ == "__main__":
    idx = build_index()
    rf = repo_files()
    with open(os.path.join(os.path.dirname(__file__), "nohat_index.json"), "w") as f:
        json.dump({k: [[list(p), pk, n] for p, pk, n in v] for k, v in idx.items()}, f)
    print("pak members:", len(idx))
    ptiks = [k for k in idx if k.startswith("models/player/") and k.endswith(".tik")]
    print("player tiks in paks:", len(ptiks))
    print("repo files:", len(rf))
