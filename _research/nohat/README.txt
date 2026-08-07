bug-1545 HATLESS ARMORY BODIES - generator set.

Run order (from this directory, python 3):
  nohat_sweep.py     build nohat_index.json: every file in every mounted pak, with the
                     precedence a running engine would use (homepath > maintt > mainta >
                     main, later pak name wins). MUST be re-run after build.ps1 deploys.
  nohat_dump.py      parse every armory-roster player tik into ordered
                     (path, skelmodel, [surface/shader]) groups. Reads the roster straight
                     out of coop_mod/helmet.scr so it cannot drift.
  nohat_plan.py      classify head-covering groups by SKELMODEL/PATH (never by surface name -
                     see the CONTAINER table) and dedupe against the shipped coop_helmet_*.tik.
  nohat_build.py     write the 4 container skds, the coop_std_*.tik pieces, and every
                     models/player/<skin>_nohat.tik. THIS is the file to re-run when the
                     armory roster grows; then paste the printed table into
                     helmet.scr::armory_skin_build (see nohat_table generation in the buglog).
  nohat_ui.py        patch ui/loadout/skin/s*.cfg + helm/h*.cfg + init.cfg.
  nohat_verify.py    ASCII / brace-balance / reference-resolution check on everything written.
  verify_containers.py  proves which shipped coop_helmets/*.skd container came from which
                     source gear skd, by comparing vertex payloads as multisets.

skdlib.py / hgvfs.py are copies of the bug-1534/1540 SKD reader + pak VFS.
