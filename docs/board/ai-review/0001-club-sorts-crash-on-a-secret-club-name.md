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

- The member-name sorts in `ns.SORT_FUNCTIONS` themselves. (The original note
  here said the `UpdateData()` ingest loop sits inside a pcall. That is true in
  `DjinnisDataTexts` and was false here; see the 2026-09-29 comment. A secret
  name now never reaches those comparators because ingest drops it.)
- The Friends and Guild brokers. Same class of hazard, not this card.
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
- [x] #5 (added 2026-09-29) WHEN a club name, member name, member presence,
      zone, note or level comes back secret, THE BROKER SHALL ingest without
      throwing and SHALL NOT store the secret where the tooltip concatenates,
      compares or table-keys it. proves: `lua docs/build/check-secret-ingest.lua`, checks 2-4
- [x] #6 (added 2026-09-29) WHILE `C_ChatInfo.InChatMessagingLockdown()` is
      true, THE BROKER SHALL hold its last known roster and read nothing from
      `C_Club`. proves: `lua docs/build/check-secret-ingest.lua`, check 5
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

**2026-09-29** Adversarial review (unattended agent, not the builder). Verdict: **the sort fix holds, but
the card's promise did not.** Found and fixed a real gap; the card stays in `ai-review/` because the
reviewer wrote the fix, and the builder passing the builder is what this lane exists to stop. The
next reviewer should attack commit `fix(communities): drop secret values at ingest` and then move
the card.

What held: `ns.SortClubsByName` is sound. `clubId` is `NeverSecret = true` in `ClubInfo`
(`Blizzard_APIDocumentationGenerated/ClubDocumentation.lua`) and `Nilable = false`, so the
fallback key is always comparable. `check-club-sort.lua` passes; its mixed-list case is the right trap.

What broke: this card's "Not this card" said the `UpdateData()` member loop sits inside a pcall.
It does in `DjinnisDataTexts`; here it never did (no pcall anywhere outside the sort probe). And a
secret club name that survived the sort went straight into the tooltip: `clubName .. " (" ..`
concatenation, and `DGF:GetOrCreateGroupHeader(sc, clubName)` keying `parent.groupHeaders[name]`.
So hovering the broker, the very check the card asked for, would still have thrown. Every `C_Club`
read used there (`GetSubscribedClubs`, `GetClubMembers`, `GetMemberInfo`) is
`SecretInChatMessagingLockdown`, and `ClubMemberInfo.presence`, `name`, `zone`-style fields are not
`NeverSecret`, so member data is exposed the same way.

Fixed: `Core.lua` gains `ns.IsSecret` (`issecretvalue`) and `ns.InMessagingLockdown`
(`C_ChatInfo.InChatMessagingLockdown`, both checked in the generated docs, neither deprecated).
`UpdateData` now returns early in lockdown, holding the last roster; skips a club whose name is
secret; skips a member whose name or presence is secret; replaces a secret level, zone or note with a
plain fallback. New `docs/build/check-secret-ingest.lua` loads the real `Core.lua` and
`CommunitiesBroker.lua` with the game stubbed (a secret answers `"string"` to `type()`, as the
game's does). Five checks pass; against the pre-fix files it goes red on check 2. Criteria #5 and
#6 were added for it. The settings panel path needed nothing more: it only sorts (fixed) and
`SetText`s the name, keyed by `clubId`.

Security: **weakest point** is any string the game hands back reaching a comparison or table key;
ingest is now the one gate for this broker. **Unchecked:** `FriendsBroker.lua` and `GuildBroker.lua`
were not reviewed for the same fault (fenced out above). **Leaks:** nothing; no data leaves the client.

Also noticed, not fixed: the default `rightClick = "invite"` click action acts on a right-click, which
breaks the standing rule that right-click opens a menu. Moot while the addon is superseded and
uninstalled; belongs in the retire-or-not question on the handover.
