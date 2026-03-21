# Djinni's Guild & Friends

A World of Warcraft (Retail) addon that provides LibDataBroker (LDB) data sources for your friends list, with a clickable tooltip for quick interaction. Works with any LDB display: EQOL Datapanels, FuBar, TitanPanel, ElvUI DataText, and more.

Loosely inspired by **ElvUI Shadow & Light** friends list.

---

## Features

- **LDB Data Source**: Shows configurable panel text (e.g., `Friends: 3/15`) in any LDB display
- **Clickable Tooltip**: Custom tooltip with per-friend rows — click to whisper, invite, /who, etc.
- **Configurable Click Actions**: Remap Left Click, Right Click, Shift+Click, Middle Click to any action
- **Blizzard Settings Integration**: All options accessible via Game Menu → Options → AddOns
- **Battle.net + WoW Friends**: Displays both character friends and BNet friends playing WoW
- **Sorting**: Sort by name, class, level, zone, or status
- **Class-Colored Names**: Friend names colored by their class
- **AFK/DND Indicators**: Visual status indicators for away/busy friends
- **Profile Support**: Per-character or shared profiles via AceDB

## Modular Architecture

The addon is designed as a modular system of LDB brokers:

| Module | Status | File |
|--------|--------|------|
| **Friends Broker** | ✅ Implemented | `FriendsBroker.lua` |
| **Guild Broker** | 🔮 Future | `GuildBroker.lua` |
| **Communities Broker** | 🔮 Future | `CommunitiesBroker.lua` |

Each broker is a self-contained module with its own LDB data object and tooltip.

---

## Panel Text Configuration

The panel text format supports these tokens:

| Token | Replaced With |
|-------|---------------|
| `<online>` | Number of online friends |
| `<total>` | Total number of friends |
| `<offline>` | Number of offline friends |

**Default**: `Friends: <online>/<total>`

Examples:
- `Friends: <online>/<total>` → `Friends: 3/15`
- `Online: <online>` → `Online: 3`
- `<online>/<total> (<offline> offline)` → `3/15 (12 offline)`

---

## Click Actions

All click actions are configurable in settings. Defaults:

| Input | Default Action | Description |
|-------|---------------|-------------|
| Left Click | Whisper | Opens whisper to the friend |
| Right Click | Invite | Invites friend to your group |
| Shift + Left Click | Who | Performs /who lookup (character+server) |
| Shift + Right Click | None | Configurable |
| Middle Click | None | Configurable |

Available actions: `whisper`, `invite`, `who`, `none`

---

## Sorting Options

| Sort Key | Description |
|----------|-------------|
| Name | Alphabetical by character name |
| Class | Grouped by class |
| Level | By character level |
| Zone | Alphabetical by current zone |
| Status | Online first, then AFK, then DND |

**Future**: Custom sorting and grouping via `#<groupname>` tags in friend notes.

---

## Settings Schema

```
Profile Settings:
├── General
│   ├── Panel Text Format (string, tokens: <online> <total> <offline>)
│   └── Show Minimap Icon (toggle)
├── Friends
│   ├── Sort By (select: name/class/level/zone/status)
│   ├── Sort Ascending (toggle)
│   ├── Show Battle.net Friends (toggle)
│   ├── Show Character Friends (toggle)
│   └── Click Actions
│       ├── Left Click (select: whisper/invite/who/none)
│       ├── Right Click (select)
│       ├── Shift + Left Click (select)
│       ├── Shift + Right Click (select)
│       └── Middle Click (select)
└── Profiles (AceDB profile management)
```

---

## Dependencies

All libraries are embedded (no external addon requirements):

- LibStub
- CallbackHandler-1.0
- AceAddon-3.0, AceDB-3.0, AceDBOptions-3.0
- AceConfig-3.0 (Registry + Dialog + Cmd)
- AceConsole-3.0, AceEvent-3.0
- LibDataBroker-1.1
- LibDBIcon-1.0

**Optional**: Works best with an LDB display addon (TitanPanel, ElvUI, EQOL Datapanels, FuBar, etc.)

---

## Key WoW APIs Used

### Friends Data
- `C_FriendList.GetNumFriends()` / `GetNumOnlineFriends()`
- `C_FriendList.GetFriendInfoByIndex(i)`
- `C_FriendList.ShowFriends()` — requests server data
- `BNGetNumFriends()`
- `C_BattleNet.GetFriendAccountInfo(i)`
- `C_BattleNet.GetFriendNumGameAccounts(i)`
- `C_BattleNet.GetFriendGameAccountInfo(friendIdx, accountIdx)`

### Actions
- `ChatFrame_SendTell(name)` / `ChatFrame_SendBNetTell(presenceName)`
- `C_PartyInfo.InviteUnit(name)`
- `BNInviteFriend(gameAccountID)`
- `C_FriendList.SendWho(query)`

### Events
- `FRIENDLIST_UPDATE`, `BN_FRIEND_INFO_CHANGED`
- `BN_FRIEND_LIST_SIZE_CHANGED`
- `BN_CONNECTED` / `BN_DISCONNECTED`
- `PLAYER_ENTERING_WORLD`

---

## Implementation Phases

### Phase 1: Skeleton ✅
TOC, Core.lua with AceAddon/AceDB, embedded libraries.

### Phase 2: LDB Panel Text ✅
FriendsBroker creates LDB data object, registers events, updates "Friends: X/Y" text.

### Phase 3: Clickable Tooltip ✅
Custom frame with Button rows per friend, class-colored, with column layout.

### Phase 4: Click Actions ✅
Action dispatcher with configurable key+button mapping.

### Phase 5: Settings Panel ✅
AceConfig options registered in Blizzard Settings → Addons.

### Phase 6: Polish ✅
All sort modes, AFK/DND indicators, minimap icon, edge cases.

### Phase 7 (Future): Guild Broker
`GuildBroker.lua` — same pattern, `GUILD_ROSTER_UPDATE` events.

### Phase 8 (Future): Communities Broker
`CommunitiesBroker.lua` — `C_Club.*` API, community picker in settings.

---

## Data Flow

```
WoW Server ──(events)──> FriendsBroker.UpdateData()
                                │
                                v
                         friendsCache[]
                          /          \
                    LDB .text    Tooltip Frame
                  "Friends: 3/15"  (clickable rows)
                        │              │
                        v              v
                  LDB Displays   Action Dispatch
               (Titan/ElvUI/…)  (whisper/invite/who)
```

---

## File Structure

```
DjinnisGuildFriends/
├── DjinnisGuildFriends.toc    -- Addon metadata and load order
├── Core.lua                   -- AceAddon bootstrap, AceDB init, utilities
├── FriendsBroker.lua          -- LDB data object, friends data, tooltip
├── Settings.lua               -- AceConfig options, Blizzard panel
├── README.md                  -- This file
└── Libs/                      -- Embedded libraries
    ├── LibStub/
    ├── CallbackHandler-1.0/
    ├── AceAddon-3.0/
    ├── AceDB-3.0/
    ├── AceDBOptions-3.0/
    ├── AceConfig-3.0/
    ├── AceConsole-3.0/
    ├── AceEvent-3.0/
    ├── LibDataBroker-1.1/
    └── LibDBIcon-1.0/
```
