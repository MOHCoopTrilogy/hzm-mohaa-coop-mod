import os, re, json, zipfile, sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = r"C:\mohaa-coop-dev\hzm-mohaa-coop-mod"

_idx = None


def idx():
    global _idx
    if _idx is None:
        with open(os.path.join(HERE, "nohat_index.json")) as f:
            raw = json.load(f)
        _idx = {k: [(tuple(p), pk, n) for p, pk, n in v] for k, v in raw.items()}
    return _idx


def winner(path):
    """Highest-priority pak entry for a virtual path. Returns (pakpath, member) or None."""
    v = idx().get(path.lower().replace("\\", "/"))
    if not v:
        return None
    return v[-1][1], v[-1][2]


def exists(path):
    return path.lower().replace("\\", "/") in idx()


_zc = {}


def read(path):
    """Read the winning copy of a virtual path as bytes."""
    w = winner(path)
    if w is None:
        return None
    pk, member = w
    z = _zc.get(pk)
    if z is None:
        z = _zc[pk] = zipfile.ZipFile(pk)
    return z.read(member)


def repo_path(vpath):
    p = os.path.join(REPO, vpath.replace("/", os.sep))
    return p if os.path.isfile(p) else None


TOK = re.compile(r'"[^"]*"|\S+')


def toks(line):
    return [t.strip('"') for t in TOK.findall(line)]


def strip_comments(text):
    # // line comments and /* */ blocks
    # keep the line count stable - a stripped block comment leaves its newlines behind
    text = re.sub(r"/\*.*?\*/", lambda m: "\n" * m.group(0).count("\n"), text, flags=re.S)
    out = []
    for ln in text.split("\n"):
        i = ln.find("//")
        if i >= 0:
            ln = ln[:i]
        out.append(ln)
    return "\n".join(out)


def parse_setup(text):
    """Return list of (kind, argtokens, rawline_index) for the setup block, plus the
    line span (start,end) of the setup body in the ORIGINAL (uncommented) line list."""
    lines = text.split("\n")
    clean = strip_comments(text).split("\n")
    # find "setup" then the following '{'
    start = None
    for i, ln in enumerate(clean):
        if re.match(r"^\s*setup\b", ln, re.I):
            start = i
            break
    if start is None:
        return None, None, lines
    # locate opening brace
    j = start
    depth = 0
    opened = False
    body_start = None
    while j < len(clean):
        for ch in clean[j]:
            if ch == "{":
                depth += 1
                if not opened:
                    opened = True
                    body_start = j
            elif ch == "}":
                depth -= 1
                if opened and depth == 0:
                    return body_start, j, lines
        j += 1
    return body_start, len(clean) - 1, lines
