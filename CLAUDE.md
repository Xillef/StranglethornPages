# Stranglethorn Pages — WoW Forever addon

Small checklist window for the 15 "Green Hills of Stranglethorn" pages: which
ones the character has, where the others are (bank, mailbox, mailed to X, on an
alt), and duplicates.

## Project basics

- Language: Lua 5.1, **WoW Forever** client only (`## Interface: 16001`,
  install `E:\World of Warcraft\_forever_`, client 1.60.x). Forever uses the
  modern API (`C_Container`, `C_Item`, `C_QuestLog`), not the old Classic globals.
- No build step, no automated tests.
- Repo layout: `StranglethornPages/` is the shipped addon. `CLAUDE.md`,
  `.luarc.json`, `CHANGELOG.md`, `curseforge/` and `release/` are dev-only.
- Changelog and CurseForge release run: as in `~/.claude/guides/wow-addon.md`.
- Never write into the WoW install. The user copies `StranglethornPages/` into
  `_forever_\Interface\AddOns` and tests in-game.
- Static check: LuaLS with the WoW annotations, config `.luarc.json`, command in
  `~/.claude/guides/wow-addon.md`. Accepted warnings: none so far.
- UI preview: the emulator at `K:\Projekte\VibeLab\WoW\WowAddonEmulator` (built for
  Retail; frame API is the same, game data is faked). Do not change the emulator;
  the only file of ours there is `scenarios/StranglethornPages/overview.lua`.
  Run from the emulator folder:
  `node server.js --addon "K:/Projekte/VibeLab/WoW/StranglethornPages/StranglethornPages"`,
  then http://localhost:8642/, scenario "overview". Headless:
  `node tools/headless.mjs "K:/Projekte/VibeLab/WoW/StranglethornPages/StranglethornPages" StranglethornPages scenarios/StranglethornPages/overview.lua --frames`.

## Load order and files

| File | Role |
|---|---|
| `Data.lua` | Quest/item IDs, chapters, **color table `ns.COLORS`** (change colors there), texts deDE/enUS |
| `Tracker.lua` | SavedVariables, scans (bags, bank, mailbox, sent mail, quest flags), `ns:GetPageStatus` |
| `UI.lua` | Window, minimap button, `/ghs` |

## How tracking works

Snapshots, not event bookkeeping: every character stores what it has in bags,
bank (only scanned while the bank is open) and mailbox (only while open), plus a
list of sent mail. A page's status is always recomputed from all snapshots, so a
sold or destroyed page simply disappears from the bag snapshot and shows as missing.
Sent-mail entries to a character are dropped when that character opens its
mailbox; entries to foreign characters stay until right-clicked away. Sent mail
is only shown and counted while no copy exists anywhere else (bags, bank, mailbox,
alts), because spare copies are mailed off to be sold.

## Sources

- Quest/item IDs: Wowhead Classic quests 338–342 (checked Nov 2026).
  Chapter I 339 → item 2756 (pages 2725, 2728, 2730, 2732), II 340 → 2757
  (2734, 2735, 2738, 2740), III 341 → 2758 (2742, 2744, 2745, 2748),
  IV 342 → 2759 (2749, 2750, 2751). Main quest 338, Barnil Stonepot (NPC 716).
- Interface number 16001: read from Forever addons installed in `_forever_`.
- CurseForge icon: the page item icon `inv_misc_note_06` (same as the minimap
  button, which reads it from item 2725 at runtime). `curseforge/icon_source.jpg` is
  the 56x56 original from wow.zamimg.com; `curseforge/icon.png` is it scaled 8x
  (448x448, nearest neighbor).

## Open / unverified (check in-game)

- IDs unchanged in Forever (no Forever-specific change found online).
- `C_Item.GetItemCount(id, true)` includes Forever's bank tabs while the bank is open.
- `GetSendMailItem` / `GetInboxItem` return shapes in Forever (code falls back to
  the item links); `SendMail` hook still sees the attachments.
- Whether Forever has an account bank; pages there would show as missing.
- Pages listed on the auction house show as missing (deliberately not tracked).
