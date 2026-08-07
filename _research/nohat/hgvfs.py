"""Read-only VFS over every mounted MOHAA pk3 (main/mainta/maintt + zzzz addons)."""
import zipfile, glob, os, sys

GOG = r"G:\GOG\Medal of Honor - Allied Assault War Chest"
_GLOBS = [
    os.path.join(GOG, "main", "*.pk3"),
    os.path.join(GOG, "mainta", "*.pk3"),
    os.path.join(GOG, "maintt", "*.pk3"),
    os.path.join(GOG, "*.pk3"),
]

_index = None   # lower/slash path -> list of (pakpath, internal_name)


def build():
    global _index
    if _index is not None:
        return _index
    _index = {}
    paks = []
    seen = set()
    for g in _GLOBS:
        for p in sorted(glob.glob(g)):
            rp = os.path.normcase(os.path.abspath(p))
            if rp not in seen:
                seen.add(rp)
                paks.append(p)
    for pak in paks:
        try:
            with zipfile.ZipFile(pak, "r") as z:
                for n in z.namelist():
                    if n.endswith("/"):
                        continue
                    key = n.lower().replace("\\", "/")
                    _index.setdefault(key, []).append((pak, n))
        except Exception as e:
            print(f"[vfs] skip {pak}: {e}", file=sys.stderr)
    print(f"[vfs] {len(paks)} paks, {len(_index)} files", file=sys.stderr)
    return _index


def sources(path):
    return build().get(path.lower().replace("\\", "/"), [])


def read(path):
    """Return bytes of the highest-priority copy (last pak alphabetically wins, like the engine)."""
    srcs = sources(path)
    if not srcs:
        raise KeyError(path)
    pak, name = srcs[-1]
    with zipfile.ZipFile(pak, "r") as z:
        return z.read(name)


def read_from(path, pakhint):
    for pak, name in sources(path):
        if pakhint.lower() in os.path.basename(pak).lower():
            with zipfile.ZipFile(pak, "r") as z:
                return z.read(name)
    raise KeyError((path, pakhint))


def glob_paths(prefix="", suffix=""):
    prefix = prefix.lower().replace("\\", "/")
    suffix = suffix.lower()
    return sorted(k for k in build() if k.startswith(prefix) and k.endswith(suffix))
