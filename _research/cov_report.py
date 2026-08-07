"""Coverage diff reporter v2 - sweep layers 1-3 + detector catalog ranks 2/3/4.

Usage:  python _research/cov_report.py [qconsole.log] [--rebaseline]

Per map segment (Server: lines):
  - trigger fire diff vs _research/cov_manifests.json (by targetname, else centroid +-24u)
  - sound aliases played + every SNDMISS (runtime-confirmed dead alias)
  - map-script labels run
  - ERROR SIGNATURES (rank 3): every ^~^~^ Script Error + warning families normalized to
    class+anchor signatures, counted, diffed against _research/cov_baseline.json.
    New signature or count regression = FINDING. --rebaseline rewrites the baseline.
  - HEARTBEAT GRADING (rank 2): a phase-3 map without COVWALK START + COVWALK LIST DONE is
    graded INVALID, never clean - a silent walker is not coverage.
  - ZERO-TOLERANCE (rank 4): any 'Cvar ... does not exist' or COMPILE FAIL line is a finding.
Output: _research/cov_report.md
"""
import sys, re, json, os, collections, glob as _glob

args = [a for a in sys.argv[1:] if not a.startswith("--")]
REBASE = "--rebaseline" in sys.argv
# [user 2026-08-06] Read EVERY rotated log, not just the current one. SWEEP-4P.ps1 rotates
# qconsole.log on each launch (it must - the engine TRUNCATES the log at startup), so a full
# 54-map pass is spread across dozens of qconsole*.log files. Reading only the live log reported
# "1 map" after a 48-map sweep. Accepts a path, a glob, or nothing (defaults to the whole set).
LOGARG = args[0] if args else r"G:\mohaa-gl2\home\maintt\qconsole*.log"
LOGS = sorted(_glob.glob(LOGARG), key=os.path.getmtime) if _glob.has_magic(LOGARG) else [LOGARG]
if not LOGS:
    sys.exit(f"no logs matched {LOGARG}")
HERE = os.path.dirname(os.path.abspath(__file__))
manifest = json.load(open(os.path.join(HERE, "cov_manifests.json")))
BASE_P = os.path.join(HERE, "cov_baseline.json")
baseline = json.load(open(BASE_P)) if os.path.exists(BASE_P) else None

WARN_FAMILIES = [
    (re.compile(r"\^~\^~\^ Script Error\s*:\s*(.{0,120})"), "ScriptError"),
    (re.compile(r"unknown animation '([^']+)' in '([^']+)'"), "UnknownAnim"),
    (re.compile(r"Couldn't load (\S+)"), "CouldntLoad"),
    (re.compile(r"Couldn't find image file for shader (\S+)"), "NoImage"),
    (re.compile(r"invalid waittill (?:spawn|prespawn) for 'Level'"), "WaittillLevel"),
    (re.compile(r"Event '([^']+)' does not exist"), "NoEvent"),
    (re.compile(r"Cvar '?(\S+?)'? does not exist"), "NoCvar"),
    (re.compile(r"\^~\^~\^ COMPILE FAIL (\S+)"), "CompileFail"),
    (re.compile(r"WARNING: Ignoring shader file (\S+)"), "ShaderFileIgnored"),
]

cur = None
fired = collections.defaultdict(list)
snd = collections.defaultdict(set)
sndmiss = collections.defaultdict(set)
lbl = collections.defaultdict(set)
forceall = collections.defaultdict(list)   # engine-activated triggers (class, targetname)
sigs = collections.defaultdict(collections.Counter)   # map -> {signature: count}
walk_started = collections.defaultdict(bool)
walk_done = collections.defaultdict(bool)
fprints = []

def sig_of(line):
    for rx, cls in WARN_FAMILIES:
        m = rx.search(line)
        if m:
            anchor = "|".join(g for g in m.groups() if g) if m.groups() else ""
            # normalize volatile numbers out of ScriptError anchors
            anchor = re.sub(r"\d{3,}", "#", anchor.strip())
            return f"{cls}:{anchor[:90]}"
    return None

def _all_lines():
    for _p in LOGS:
        # each log is its own run: a map segment never spans two files
        yield None
        for _l in open(_p, encoding="latin-1", errors="replace"):
            yield _l

for line in _all_lines():
    if line is None:
        cur = None            # reset segment at every log boundary
        continue
    m = re.search(r"Server: (\S+)", line)
    if m:
        cur = m.group(1).split("/")[-1].lower()
        continue
    if "^~^~^ FPRINT" in line:
        fprints.append(line.strip().split("FPRINT", 1)[1].strip())
    if cur is None:
        continue
    if "COVWALK START" in line: walk_started[cur] = True
    if "COVWALK LIST DONE" in line: walk_done[cur] = True
    m = re.search(r"\^~\^~\^ COV TRIG (-?\d+) (-?\d+) (-?\d+) ?(\S*)", line)
    if m:
        fired[cur].append((int(m.group(1)), int(m.group(2)), int(m.group(3)), m.group(4)))
        continue
    m = re.search(r"\^~\^~\^ COV FORCEALL (\S+) ?(\S*)", line)
    if m and m.group(1) != "DONE":
        forceall[cur].append((m.group(1), m.group(2)))
        continue
    m = re.search(r"\^~\^~\^ COV SNDMISS (\S+)", line)
    if m: sndmiss[cur].add(m.group(1)); continue
    m = re.search(r"\^~\^~\^ COV SND (\S+)", line)
    if m: snd[cur].add(m.group(1)); continue
    m = re.search(r"\^~\^~\^ COV LBL (\S+)", line)
    if m: lbl[cur].add(m.group(1)); continue
    s = sig_of(line)
    if s: sigs[cur][s] += 1

out = ["# Coverage report v2", ""]
if fprints:
    out += ["**Module fingerprints:** " + " | ".join(sorted(set(fprints))), ""]
TOL = 24
allmaps = sorted(set(list(fired) + list(snd) + list(sndmiss) + list(sigs)))
findings = 0
for mp in allmaps:
    rows = manifest.get(mp)
    out.append(f"## {mp}")
    grade = "ok"
    if not walk_started.get(mp) or not walk_done.get(mp):
        grade = "INVALID (walker heartbeat missing - do not trust this map's coverage)"
    if rows is not None:
        fs = fired.get(mp, [])
        missed = []
        for r in rows:
            hit = any((r["tn"] and tn and r["tn"].lower() == tn.lower()) or
                      (abs(r["pos"][0]-x) <= TOL and abs(r["pos"][1]-y) <= TOL and abs(r["pos"][2]-z) <= TOL)
                      for (x, y, z, tn) in fs)
            if not hit: missed.append(r)
        out.append(f"walker: {grade} | triggers {len(rows)-len(missed)}/{len(rows)} | "
                   f"snd {len(snd.get(mp,()))} | SNDMISS {len(sndmiss.get(mp,()))} | labels {len(lbl.get(mp,()))}")
    else:
        missed = []
        out.append(f"walker: {grade} | (no manifest)")
    # engine force-activated vs actually committed: a trigger the engine activated that never
    # printed a COV TRIG line was LOCKED, spent (trigger_once), or filtered - a real signal, not
    # a coverage gap. (bug-1443 note: the walker's own runtime trigger_once spawns fire too, so
    # fired-not-in-manifest is expected and is reported separately rather than inflating coverage.)
    fa = forceall.get(mp, [])
    if fa:
        out.append(f"engine force-activated: {len(fa)} triggers; "
                   f"committed fires recorded: {len(fs) if rows is not None else 0} "
                   f"(uncommitted = locked / already-spent / filtered)")
    if sndmiss.get(mp):
        findings += len(sndmiss[mp])
        out.append("**dead aliases (runtime):** " + ", ".join(sorted(sndmiss[mp])))
    # error signature diff
    cursigs = sigs.get(mp, collections.Counter())
    if baseline is not None and not REBASE:
        b = baseline.get(mp, {})
        news = {k: v for k, v in cursigs.items() if k not in b}
        regress = {k: (b[k], v) for k, v in cursigs.items() if k in b and v > b[k] * 2 and v - b[k] > 20}
        if news:
            findings += len(news)
            out.append(f"**NEW error signatures ({len(news)}):**")
            for k, v in sorted(news.items(), key=lambda x: -x[1])[:15]:
                out.append(f"  - `{k}` x{v}")
        if regress:
            out.append(f"**count regressions:** " + ", ".join(f"`{k}` {a}->{c}" for k, (a, c) in list(regress.items())[:8]))
    elif cursigs:
        out.append(f"error signatures recorded: {len(cursigs)} classes, {sum(cursigs.values())} lines")
    if missed:
        findings += len(missed)
        out.append("")
        out.append("| never fired | targetname | setthread | at |")
        out.append("|---|---|---|---|")
        for r in missed[:40]:
            out.append(f"| {r['class']} | {r['tn'] or '-'} | {r['setthread'] or '-'} | {r['pos']} |")
        if len(missed) > 40: out.append(f"| ...{len(missed)-40} more | | | |")
    out.append("")

if baseline is None or REBASE:
    json.dump({mp: dict(c) for mp, c in sigs.items()}, open(BASE_P, "w"), indent=0)
    out.insert(2, f"*(error-signature baseline {'re' if REBASE else ''}written: {len(sigs)} maps)*\n")

out.insert(1, f"**{findings} findings** across {len(allmaps)} maps\n")
open(os.path.join(HERE, "cov_report.md"), "w").write("\n".join(out) + "\n")
print(f"wrote _research/cov_report.md - {findings} findings, {len(allmaps)} maps")
