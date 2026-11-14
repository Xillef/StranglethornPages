# Changelog (dev)

Every change gets a bullet here right away. The CurseForge changelog is generated
from the bullets after the last checkpoint marker (see `~/.claude/guides/wow-addon.md`).

## 1.0.0 — first public release

- Checklist window for the 15 "Green Hills of Stranglethorn" pages, grouped by chapter
  (quests 339–342), with a counter and a "Missing:" footer.
- Location per page: own bags, own bank, own mailbox, another character's bags/bank/
  mailbox, or mailed to a character. Snapshots per character in the account-wide
  SavedVariable `StranglethornPagesDB`; bank and mailbox are read only while open.
- Sold or destroyed pages drop back to missing; banked or mailed pages stay listed.
- Duplicates shown in a count column (x2, x3 ...).
- Chapters that are turned in, or whose chapter item exists, collapse with a check mark.
- Mail sent to another character is only shown and counted while no other copy exists
  (spare copies mailed off for selling don't count). Right-click forgets sent entries.
- Row tooltip lists every location with the age of its snapshot.
- Colors in one table `ns.COLORS` (Data.lua): missing gray, one copy dark green,
  several copies green, elsewhere yellow.
- Minimap button (draggable) and `/ghs`; window is movable, closes with Escape and
  remembers whether it was open.
- English and German texts.

--- CurseForge changelog generated through here (2026-11-14, v1.0.0)
