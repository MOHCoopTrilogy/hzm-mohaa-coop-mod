import os, re, json, sys
import nohat_lib as L

HERE = os.path.dirname(os.path.abspath(__file__))
HELMET = r"C:\mohaa-coop-dev\hzm-mohaa-coop-mod\coop_mod\helmet.scr"


def roster():
    out = []
    txt = open(HELMET, encoding="utf-8").read()
    for m in re.finditer(r'level\.coop_armorySkins\[(\d+)\]\s*=\s*"([^"]+)"', txt):
        out.append((int(m.group(1)), m.group(2)))
    return out


def groups(vpath):
    """Parse a player tik into ordered groups.
    Each group = dict(path=, skel=, lines=[line indices], surfaces=[(name,shader)])
    Also returns preamble line indices (scale/etc) and the raw line list."""
    b = L.read(vpath)
    if b is None:
        return None
    text = b.decode("latin-1")
    bs, be, lines = L.parse_setup(text)
    if bs is None:
        return None
    clean = L.strip_comments(text).split("\n")
    cur_path = None
    gs = []
    other = []
    g = None
    for i in range(bs + 1, be):
        t = L.toks(clean[i])
        if not t:
            continue
        k = t[0].lower()
        if k == "$path":      # retail tiks use both spellings; the engine treats them alike
            k = "path"
        if k == "path":
            cur_path = t[1] if len(t) > 1 else ""
            other.append(("path", i, cur_path))
            g = None
        elif k == "skelmodel":
            g = dict(path=cur_path, skel=t[1] if len(t) > 1 else "", lines=[i],
                     surfaces=[], pathline=None)
            gs.append(g)
        elif k == "surface":
            if g is not None:
                g["lines"].append(i)
                g["surfaces"].append((t[1] if len(t) > 1 else "",
                                      t[3] if len(t) > 3 and t[2].lower() == "shader" else None,
                                      i))
            else:
                other.append(("orphan_surface", i, clean[i].strip()))
        else:
            other.append((k, i, clean[i].strip()))
    return dict(vpath=vpath, groups=gs, other=other, lines=lines, bs=bs, be=be,
                text=text, clean=clean)


if __name__ == "__main__":
    r = roster()
    print("roster entries:", len(r))
    missing = []
    dump = {}
    for idx, name in r:
        vp = "models/player/%s.tik" % name
        d = groups(vp)
        if d is None:
            missing.append((idx, name, L.exists(vp)))
            continue
        dump[name] = dict(
            win=L.winner(vp)[0],
            groups=[dict(path=g["path"], skel=g["skel"],
                         surfaces=[(s[0], s[1]) for s in g["surfaces"]]) for g in d["groups"]],
        )
    print("missing:", missing)
    with open(os.path.join(HERE, "nohat_dump.json"), "w") as f:
        json.dump(dump, f, indent=1)
    print("dumped", len(dump))
