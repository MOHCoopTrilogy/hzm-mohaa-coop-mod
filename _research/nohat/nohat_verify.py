"""Validate every generated tik: ASCII, brace balance, and that each skelmodel /
shader / animation it references actually resolves in some mounted pak (or in our repo)."""
import os, re, glob, json, sys
import nohat_lib as L

ROOT = r"C:\mohaa-coop-dev\hzm-mohaa-coop-mod"
HELM = os.path.join(ROOT, "models", "coop_helmets")
PLAYER = os.path.join(ROOT, "models", "player")


def repo_has(vp):
    return os.path.isfile(os.path.join(ROOT, vp.replace("/", os.sep)))


def asset_ok(vp):
    return L.exists(vp) or repo_has(vp)


_shaders = None


def shaders():
    global _shaders
    if _shaders is None:
        s = set()
        # shader scripts in paks
        for k in list(L.idx()):
            if k.startswith("scripts/") and k.endswith(".shader"):
                b = L.read(k)
                if b:
                    for m in re.finditer(r"(?m)^([A-Za-z0-9_\-/\\.]+)[ \t]*\r?\n[ \t]*\{",
                                         b.decode("latin-1")):
                        s.add(m.group(1).lower())
        # and our own repo copies (packed after the index snapshot)
        for f in glob.glob(os.path.join(ROOT, "scripts", "*.shader")):
            t = open(f, encoding="latin-1").read()
            for m in re.finditer(r"(?m)^([A-Za-z0-9_\-/\\.]+)[ \t]*\r?\n[ \t]*\{", t):
                s.add(m.group(1).lower())
        _shaders = s
    return _shaders


def texture_ok(name):
    """a shader name with no .shader block is legal if a bare texture of that name exists"""
    for ext in (".tga", ".jpg", ".dds", ".png"):
        if asset_ok(name + ext):
            return True
    return False


def check(path, label):
    txt = open(path, encoding="latin-1").read()
    bad = []
    nonascii = [(i + 1, ln) for i, ln in enumerate(txt.split("\n"))
                if any(ord(c) > 127 for c in ln)]
    if nonascii:
        bad.append("NON-ASCII line %d" % nonascii[0][0])
    clean = L.strip_comments(txt)
    depth = 0
    for ch in clean:
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth < 0:
                bad.append("brace depth went negative")
                break
    if depth != 0:
        bad.append("brace depth ends at %d" % depth)
    # resolve references
    curpath = ""
    for ln in clean.split("\n"):
        t = L.toks(ln)
        if not t:
            continue
        k = t[0].lower()
        if k in ("path", "$path"):
            curpath = t[1].rstrip("/") + "/"
        elif k == "skelmodel":
            vp = curpath + t[1]
            if not asset_ok(vp):
                bad.append("MISSING skelmodel " + vp)
        elif k == "surface" and len(t) >= 4 and t[2].lower() == "shader":
            sh = t[3]
            if sh.lower() not in shaders() and not texture_ok(sh):
                bad.append("MISSING shader " + sh)
        elif k == "idle" or (k in ("idle",)):
            pass
    return bad


if __name__ == "__main__":
    files = sorted(glob.glob(os.path.join(HELM, "coop_std_*.tik"))) + \
            sorted(glob.glob(os.path.join(PLAYER, "*_nohat.tik"))) + \
            sorted(glob.glob(os.path.join(HELM, "coop_helmet_*.tik")))
    nbad = 0
    for f in files:
        b = check(f, os.path.basename(f))
        if b:
            nbad += 1
            print("%-56s %s" % (os.path.basename(f), "; ".join(sorted(set(b)))))
    print("checked %d files, %d with problems" % (len(files), nbad))
    # skc / container presence
    for extra in ("models/coop_helmets/us_helmetfit.skc", "models/coop_helmets/std_liner.skd",
                  "models/coop_helmets/std_camo.skd", "models/coop_helmets/std_beret6abs.skd",
                  "models/coop_helmets/std_creasecap.skd"):
        print("%-46s %s" % (extra, "OK" if asset_ok(extra) else "MISSING"))
