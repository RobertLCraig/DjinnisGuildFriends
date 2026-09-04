# Both club sorts would crash on a 12.1 secret club name

## What I need from you

**Nothing yet, and nothing was deployed.** This addon is not installed in the
game folder, so deploying it would newly install a dormant addon. The check is
owed only if it is ever installed again: open the settings panel and hover the
Communities broker, and neither should throw.

## Why

The crash was reported in the sibling addon `DjinnisDataTexts` on 2026-09-04:

    Communities.lua:858: attempt to compare a secret string value
      (execution tainted by 'DjinnisDataTexts')

`C_Club.GetSubscribedClubs()` now returns clubs whose `name` is a 12.1 secret
string, and comparing two secrets throws. The guard in front of the sort was
`type(clubInfo.name) == "string"`, which **cannot see a secret**: `type()` still
answers `"string"`. There it took down the whole options panel.

This addon carried the identical comparator in two places, `Settings.lua:538`
and `CommunitiesBroker.lua:418`, so it has the same fault. It has not been seen
because the addon is not currently installed.

## What was done

One helper, `ns.SortClubsByName(list, GetInfo)`, in `Core.lua`, used by both
sorts. It probes each name once with a pcall, and if any name is unreadable it
orders the **whole** list by `clubId`.

Ordering the whole list matters. A comparator that guards each pair and falls
back per pair is inconsistent when some names are readable and some are not, and
`table.sort` errors on an inconsistent comparator by itself.

Club names are still displayed. `SetText` accepts a secret; only comparing one
throws.

## Not this card

- The member-name sorts in `ns.SORT_FUNCTIONS`. Member names can be secret too,
  but the ingest loop in `CommunitiesBroker:UpdateData()` sits inside a pcall, so
  a secret name never reaches those comparators. Worth a card if that goes.
- Installing or deploying this addon. It is dormant on purpose.
- The `Docs/` to `docs/` rename and the handover staged in this repo. Older work,
  unrelated, already staged before this change.

## Acceptance
<!-- AC:BEGIN -->
- [x] #1 WHEN a subscribed club has a secret name, THE APP SHALL order the club
      list without throwing.
- [x] #2 WHEN every club name is readable, THE APP SHALL still order the list
      alphabetically by name.
- [x] #3 IF some club names are readable and some are not, THEN THE APP SHALL
      order the whole list by `clubId` rather than mixing the two orderings.
- [x] #4 IF a club has no name at all, THE APP SHALL NOT throw.
<!-- AC:END -->

## Tasks

- [x] Replace both club sorts with the shared helper in `Core.lua`
- [x] Regression check at `docs/build/check-club-sort.lua`, which lifts the real
      function out of `Core.lua` between the `[club-sort]` markers, so reverting
      the fix fails it
- [x] `loadfile` clean on all three changed files
- [ ] Deploy. **Deliberately not done**: the addon is not installed and
      `bin/deploy.ps1` would newly install it.
- [ ] In-game check, owed only if the addon is installed again
- [ ] Adversarial and security pass

## Links

**Relates to**
- `djinnisdatatexts#0012` - the same bug, reported there in a live client, with
  the error text and the reasoning behind the fallback ordering.

## Comments

**2026-09-04** Fixed in step with `DjinnisDataTexts`, from that addon's crash
report rather than one seen here. Run the check with
`lua docs/build/check-club-sort.lua` from the addon root; it takes an optional
path, so it can be pointed at a doctored copy to prove it goes red. The version
of this check in `DjinnisDataTexts` was seen to fail against the pre-fix
comparator with the exact error Rob saw.
