# Release Notes

<!-- ================================================================
  INSTRUCTIONS
  ============
  Edit this file before running release.ps1.

  - Set the version below (must match ## Version in the .toc file).
  - Fill in the sections. Delete any sections with nothing to report.
  - Run:  .\release.ps1
  - The script will prepend this entry to CHANGELOG.md, tag the commit,
    and produce a ready-to-upload zip in the /releases/ folder.
  ================================================================ -->

## Version: 1.0.1

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
