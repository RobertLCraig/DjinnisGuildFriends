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

## Version: 1.0.3

### Fixed
- Fixed an issue where tooltip notes and text fields would inappropriately truncate (e.g., `Makory [...`) on their first render. Column widths are now explicitly applied to the rendering font strings before resolving their content, guaranteeing they populate accurately.

### Changed
- Updated guild tooltip to use modern `C_Club` API instead of the deprecated `GetGuildRosterInfo()` for WoW `12.0+` compatibility.
- Replaced `GetGuildRosterMOTD()` with `C_GuildInfo.GetMOTD()`.
- Replaced `ChatFrame1EditBox` usage with `ChatFrameUtil.OpenChat()` in Core.lua.
- Removed deprecated `ChatFrame_SendTell` and `ChatFrame_SendBNetTell` API calls.
