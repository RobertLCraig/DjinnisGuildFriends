# Changelog

All notable changes to Djinni's Guild & Friends are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [1.0.0] - 2026-03-22

### Added
- Initial public release.
- LDB data broker for Friends list (WoW character friends + Battle.net friends).
- LDB data broker for Guild roster with MOTD display.
- LDB data broker for Communities (BattleNet and Character clubs).
- Interactive scrollable tooltips for all three brokers.
- Configurable click actions (whisper, invite, /who, copy name, copy Armory/Raider.IO/WarcraftLogs links, custom URLs).
- Grouping and sorting options per broker.
- Per-section Blizzard Settings UI with dropdowns, sliders, and checkboxes.
- Class-colored names, hint bar, row spacing, scale, width, and max-height controls.
- Community enable/disable toggles per club.
- Demo mode for UI screenshots.

---

## [1.0.4] - 2026-03-27

### Fixed
- Fixed tooltip notes truncating on the **first** hover after a reload. The root cause was a dual-anchor (`LEFT` + `RIGHT`) on `noteText` in `GetOrCreateRow` â€” WoW's layout engine was computing the width from the initial 400px row frame and ignoring subsequent `SetWidth()` calls. Removed the `RIGHT` anchor so `SetWidth()` in `PopulateTooltip` is the sole authority.
- Fixed Settings panel description text overlapping adjacent labels. `GetStringHeight()` was returning an incorrect value before the content frame resolved its final width. Now forces an explicit width before measuring, and increased top and bottom margins around descriptions.

### Added
- Settings panel "Panel Text" edit boxes now always show the current value on first open, using a `FontString` overlay (same technique as sliders) to work around a WoW scroll-child rendering quirk.

### Changed
- Level brackets updated to reflect the current expansion: `90+` is the top bracket (previously `80+`), with `80-89` added below it.
- Grouping and sorting dropdowns now always show **No Grouping / None** at the top of the list, with all other options sorted alphabetically.
- Improved `deploy.ps1`: replaced silent `robocopy` with per-file MD5 comparison; shows `+` new, `~` updated, `-` removed files and a summary count. Added missing exclusions (`release.ps1`, `releases/`, `RELEASE_NOTES.md`, `CHANGELOG.md`).


## [1.0.3] - 2026-03-27

### Fixed
- Fixed an issue where tooltip notes and text fields would inappropriately truncate (e.g., `Makory [...`) on their first render. Column widths are now explicitly applied to the rendering font strings before resolving their content, guaranteeing they populate accurately.

### Changed
- Updated guild tooltip to use modern `C_Club` API instead of the deprecated `GetGuildRosterInfo()` for WoW `12.0+` compatibility.
- Replaced `GetGuildRosterMOTD()` with `C_GuildInfo.GetMOTD()`.
- Replaced `ChatFrame1EditBox` usage with `ChatFrameUtil.OpenChat()` in Core.lua.
- Removed deprecated `ChatFrame_SendTell` and `ChatFrame_SendBNetTell` API calls.


## [1.0.1] - 2026-03-27

### Fixed
- Community broker: clubs whose server data hasn't loaded yet (fields
  return WoW "secret" protected values instead of strings) are now
  correctly skipped. The previous `if clubInfo.name` guard was truthy
  for secret values; replaced with `type(clubInfo.name) == "string"`.
- All C_Club API calls (`GetSubscribedClubs`, `GetClubMembers`,
  `GetMemberInfo`) now use explicit `type() == "table"` guards instead
  of `or {}` fallbacks, which don't catch WoW protected values.

### Changed
- Settings UI: migrated three deprecated WoW UI templates to their
  current equivalents (required for WoW 12.0+ compatibility):
  - `UIDropDownMenuTemplate` -> `WowStyle1DropdownTemplate` + `SetupMenu()`
  - `OptionsSliderTemplate` -> bare `Slider` with manual setup
  - `UIPanelScrollFrameTemplate` -> `ScrollFrameTemplate`
