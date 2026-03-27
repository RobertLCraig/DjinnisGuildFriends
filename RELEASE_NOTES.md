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

## Version: 1.0.4

### Fixed
- Fixed tooltip notes truncating on the **first** hover after a reload. The root cause was a dual-anchor (`LEFT` + `RIGHT`) on `noteText` in `GetOrCreateRow` — WoW's layout engine was computing the width from the initial 400px row frame and ignoring subsequent `SetWidth()` calls. Removed the `RIGHT` anchor so `SetWidth()` in `PopulateTooltip` is the sole authority.
- Fixed Settings panel description text overlapping adjacent labels. `GetStringHeight()` was returning an incorrect value before the content frame resolved its final width. Now forces an explicit width before measuring, and increased top and bottom margins around descriptions.

### Added
- Settings panel "Panel Text" edit boxes now always show the current value on first open, using a `FontString` overlay (same technique as sliders) to work around a WoW scroll-child rendering quirk.

### Changed
- Level brackets updated to reflect the current expansion: `90+` is the top bracket (previously `80+`), with `80-89` added below it.
- Grouping and sorting dropdowns now always show **No Grouping / None** at the top of the list, with all other options sorted alphabetically.
- Improved `deploy.ps1`: replaced silent `robocopy` with per-file MD5 comparison; shows `+` new, `~` updated, `-` removed files and a summary count. Added missing exclusions (`release.ps1`, `releases/`, `RELEASE_NOTES.md`, `CHANGELOG.md`).
