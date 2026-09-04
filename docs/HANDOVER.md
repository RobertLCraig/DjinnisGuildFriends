# HANDOVER: Djinni's Guild & Friends (DGF)

> A World of Warcraft Retail addon: LDB data brokers for the Friends List, Guild Roster and
> Communities, with interactive tooltips you can whisper, invite and whois from. **It has been
> superseded by `DjinnisDataTexts`.** Read this, then `docs/board/`, before changing anything.

**Stage:** superseded
**Category:** addon
**Status:** v1.0.5, `Interface: 120100`. The tree is clean and **three commits sit on `master`
unpushed** to `github.com/RobertLCraig/DjinnisGuildFriends`. Last commit `2026-08-15`,
"chore(12.1.0): declare Interface 120100 and invite over C_BattleNet".
**It is NOT installed in the game, and that is deliberate rather than neglect.**
`DjinnisDataTexts` states in its own handover that it absorbs and replaces this addon and migrates
its saved variables on first load, so running both is running the same brokers twice.
_Last updated: 2026-08-26 (board and handover created; no addon code was touched)_

## Goal & success criteria
**No PRD exists and one is probably not worth writing** now that the addon is superseded. What
follows is lifted from `README.md` and is not a spec Rob signed off.

Goal: put the friends list, guild roster and communities behind LDB brokers with rich, clickable
tooltips, usable from any LDB display. `README.md` says it is loosely inspired by the ElvUI Shadow
& Light friends list.

Success, as it appears to have operated: three brokers that work in any LDB display, with tooltips
that let you act on a person without opening the Blizzard frame.

## Canonical data shape
`DjinnisGuildFriendsDB`, one account-wide SavedVariables table declared in the `.toc`. **Its shape
lives in `Settings.lua` and nowhere else**, and it matters beyond this repository: **`DjinnisDataTexts`
reads and migrates this table on first load**, so changing its shape here breaks that migration.
Check `C:\Dev\WoWAddons\DjinnisDataTexts` before touching it.

## Architecture / stack
Lua against the Blizzard Retail API, LDB (`LibDataBroker-1.1`) for the brokers, with bundled
libraries under `Libs/`. `## OptionalDeps: ElvUI` is a compatibility declaration. 9 Lua files. No
build step beyond `release.ps1` and no test suite: **every check that matters happens in a live game
client, which no agent can run.**

## Key files / structure
- `Core.lua` - load, event wiring and the shared tooltip style.
- `FriendsBroker.lua`, `GuildBroker.lua`, `CommunitiesBroker.lua` - one file per broker.
- `DemoMode.lua` - fake data for screenshots. Useful, and a trap: a change that only works in demo
  mode looks like it works.
- `Settings.lua` - the options panel and `DjinnisGuildFriendsDB`.
- `Libs/` - bundled third-party libraries. **Tracked on purpose**, as `WoWAddons#0003` settled.
- `Docs/` - the screenshots `README.md` links.
- `deploy.ps1` and `release.ps1` - this addon owns its own, with their own exclusion lists.
- `CHANGELOG.md`, `RELEASE_NOTES.md` - **history, not a plan.**

## Decisions locked
- **Superseded by `DjinnisDataTexts`, which migrates this addon's saved variables.** New work on
  friends, guild or communities brokers belongs there, not here.
- **Any LDB display, not just ElvUI.** Nothing here may assume ElvUI is loaded.
- **`Libs/` is tracked.** See `WoWAddons#0003`.

## Current state
Out of the game and superseded. The 12.1.0 sweep updated the `.toc` and the `C_BattleNet` invite
path and **checked nothing else in a client**, so the 12.1.0 line is a claim rather than a check.
**Secret values are a live hazard for exactly this addon**: 12.1 can return an opaque value for a
unit or player identifier, and a secret may not be compared, concatenated or used as a table key -
which is what a roster keyed by name does all day. See `C:\Dev\WoWAddons\docs\DECISIONS.md`.

## What's next (in order)
**`docs/board/` owns this.** The board is empty, and for a superseded addon that is close to
correct: the honest next question is whether to retire the repository rather than what to build in
it.

## Blockers / open questions
- **Should this be retired?** It is superseded, out of the game, and still carries three unpushed
  commits and a public GitHub repo. Retiring or archiving it is Rob's call. `GitHub is not a
  backup`: a retired repository is zipped whole into `C:\Dev\_archive` and verified before the
  original is deleted.
- **Three unpushed commits on `master`.** `WoWAddons#0007` is the workspace card covering merge and
  push across the repos; check it before pushing from here.

## How to pick up
1. Read this file, then `docs/board/README.md` and any card in `docs/board/`.
2. **Check `C:\Dev\WoWAddons\DjinnisDataTexts` first.** If the work you were sent to do is about
   friends, guild or communities, it almost certainly belongs there.
3. Read `C:\Dev\WoWAddons\docs\DECISIONS.md` for the two 12.1 traps before touching event
   registration or anything keyed on a unit or a player name.
4. Deploy from the workspace and never edit the game folder:
   `C:\Dev\WoWAddons\bin\deploy.ps1 -WhatIf -Only DjinnisGuildFriends`, then the same without
   `-WhatIf`. **Deploying this alongside `DjinnisDataTexts` runs the same brokers twice.**

## Sibling docs
- `README.md` in the repository root is the goal statement until a `docs/PRD.md` exists.
- `C:\Dev\WoWAddons\DjinnisDataTexts\docs\HANDOVER.md` - the addon that replaced this one.
- Workspace: `C:\Dev\WoWAddons\docs\HANDOVER.md` and `docs\DECISIONS.md`.
- **Gaps:** no `PRD.md`, no `DATA-MODEL.md`, no `DECISIONS.md`, and none of them worth writing while
  the retire-or-keep question is open.

## Branch status
One branch, `master`. Clean, three commits ahead of `origin/master`.

## Session log
- **2026-08-26** Board and handover created, so this stops showing on `board:map` as an
  unidentifiable nested folder. No addon code was touched.
