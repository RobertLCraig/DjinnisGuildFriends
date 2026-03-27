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
