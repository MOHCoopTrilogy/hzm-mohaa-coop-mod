import os, json, zipfile, glob
GOG = r"G:\GOG\Medal of Honor - Allied Assault War Chest"
# BT mounts main + mainta + maintt; scan all, order by (dir, filename) so later-loaded = winner (last).
dirs = ["main", "mainta", "maintt"]
paks = []
for d in dirs:
    for pk in sorted(glob.glob(os.path.join(GOG, d, "*.pk3"))):
        paks.append(pk)
idx = {}
for pk in paks:  # load order: main, mainta, maintt; within each, alphabetical; winner = last appended
    try:
        z = zipfile.ZipFile(pk)
    except Exception as e:
        print("skip", pk, e); continue
    for m in z.namelist():
        if m.endswith("/"): continue
        v = m.lower().replace("\\", "/")
        idx.setdefault(v, []).append([[0], pk, m])
json.dump(idx, open("nohat_index.json", "w"))
print("indexed %d virtual paths from %d paks" % (len(idx), len(paks)))
