"""Rewrite the generated armory browser cfgs for the hatless bodies (bug-1544).

There is NO generator for ui/loadout/skin/s*.cfg in the repo (only helm/h*.cfg has one,
scratchpad/gen_helm_pages.py), so these are patched in place, line-surgically.

  s<NN>.cfg : coop_loChar -> the *_nohat twin, plus
              set coop_loStdH  "<command that puts THIS skin's Standard Issue piece on the tile>"
              vstr coop_loHelmStdRef   (re-applies it iff the helmet browser is parked on page 1)
  h01.cfg   : Standard Issue is no longer a fixed tik - it is whatever coop_loStdH says.
  h<NN>.cfg : clear coop_loHelmStdRef so browsing away from page 1 stops the refresh.
"""
import os, re, json, glob

ROOT = r"C:\mohaa-coop-dev\hzm-mohaa-coop-mod"
SKIN = os.path.join(ROOT, "ui", "loadout", "skin")
HELM = os.path.join(ROOT, "ui", "loadout", "helm")
INIT = os.path.join(ROOT, "ui", "loadout", "init.cfg")

res = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                  "nohat_result.json")))
STD = res["stdmap"]
STDL = {k.lower(): v for k, v in STD.items()}

TAG = "// [user 08-07] bug-1544 hatless bodies"


def stdcmd(skin):
    piece = STDL.get(skin.lower())
    if piece is None:
        return None
    if piece == "":
        # blank tile: an empty value cannot ride a raw `set` (bug-773) - exec the clear cfg
        return "exec ui/loadout/helm/hclear.cfg"
    return "set coop_loHelm " + piece


def patch_skin(path):
    lines = open(path, encoding="latin-1").read().split("\n")
    m = None
    for ln in lines:
        m = re.match(r'\s*set coop_loChar "models/player/([^"]+)\.tik"', ln)
        if m:
            break
    if not m:
        return None, "no coop_loChar"
    skin = m.group(1)
    if skin.endswith("_nohat"):
        skin = skin[:-len("_nohat")]
    cmd = stdcmd(skin)
    if cmd is None:
        return skin, "NOT IN ROSTER"
    out = []
    for ln in lines:
        if re.match(r'\s*set coop_loChar "models/player/', ln):
            ln = 'set coop_loChar "models/player/%s_nohat.tik"' % skin
        if ln.startswith("set coop_loStdH ") or ln.strip() == "vstr coop_loHelmStdRef" \
                or ln.startswith(TAG):
            continue          # drop a previous run's lines so this is idempotent
        out.append(ln)
    while out and out[-1].strip() == "":
        out.pop()
    out.append(TAG + " - this skin's own Standard Issue headgear piece. The armory")
    out.append(TAG + " bodies are hatless at source, so the preview's helmet tile has to carry it;")
    out.append(TAG + " the vstr re-applies it only while the helmet browser sits on page 1.")
    out.append('set coop_loStdH "%s"' % cmd)
    out.append("vstr coop_loHelmStdRef")
    out.append("")
    open(path, "w", encoding="latin-1", newline="\n").write("\n".join(out))
    return skin, None


def patch_helm(path):
    n = int(re.search(r"h(\d+)\.cfg$", os.path.basename(path)).group(1))
    lines = open(path, encoding="latin-1").read().split("\n")
    out = []
    for ln in lines:
        if ln.startswith("set coop_loHelmStdRef ") or ln.startswith(TAG):
            continue
        if n == 1 and ln.startswith("set coop_loHelm "):
            out.append(TAG + " - Standard Issue is now per-skin: the armory bodies carry no")
            out.append(TAG + " baked headgear, so page 1 shows whatever the current skin page put in coop_loStdH.")
            out.append('set coop_loHelm ""')
            out.append("vstr coop_loStdH")
            continue
        out.append(ln)
    while out and out[-1].strip() == "":
        out.pop()
    out.append('set coop_loHelmStdRef "%s"' % ("vstr coop_loStdH" if n == 1 else ""))
    out.append("")
    open(path, "w", encoding="latin-1", newline="\n").write("\n".join(out))


def main():
    bad = []
    done = 0
    for f in sorted(glob.glob(os.path.join(SKIN, "s*.cfg"))):
        skin, err = patch_skin(f)
        if err:
            bad.append((os.path.basename(f), skin, err))
        else:
            done += 1
    print("skin pages patched: %d  problems: %s" % (done, bad))

    for f in sorted(glob.glob(os.path.join(HELM, "h*.cfg"))):
        if not re.search(r"h\d+\.cfg$", f):
            continue
        patch_helm(f)
    print("helm pages patched: %d" % len([f for f in glob.glob(os.path.join(HELM, "h*.cfg"))
                                          if re.search(r"h\d+\.cfg$", f)]))

    t = open(INIT, encoding="latin-1").read()
    t = t.replace('set coop_loChar "models/player/american_army.tik"',
                  'set coop_loChar "models/player/american_army_nohat.tik"\t'
                  '// bug-1544 hatless twin')
    t = re.sub(r'set coop_loHelm "models/coop_helmets/coop_helmet_plain\.tik"',
               'set coop_loHelm "%s"\nset coop_loStdH "set coop_loHelm %s"\n'
               'set coop_loHelmStdRef "vstr coop_loStdH"' % (STD["american_army"],
                                                             STD["american_army"]), t)
    open(INIT, "w", encoding="latin-1", newline="\n").write(t)
    print("init.cfg seeded with", STD["american_army"])


if __name__ == "__main__":
    main()
