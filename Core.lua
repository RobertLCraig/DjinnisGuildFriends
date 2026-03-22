-- Djinni's Guild & Friends
-- LDB data brokers for friends, guild, and communities with interactive tooltips.
-- Uses: LibDataBroker-1.1
local addonName, ns = ...

---------------------------------------------------------------------------
-- Addon namespace
---------------------------------------------------------------------------

local DGF = {}
ns.addon = DGF
ns.addonName = addonName

-- Saved variables reference (populated in ADDON_LOADED)
ns.db = nil

-- Default settings (flat structure, no profiles)
ns.defaults = {
    friends = {
        labelFormat = "Friends: <online>/<total>",
        sortBy = "name",
        sortAscending = true,
        showBNetFriends = true,
        showWoWFriends = true,
        classColorNames = true,
        tooltipScale = 1.0,
        tooltipWidth = 420,
        rowSpacing = 4,
        groupBy = "none",
        groupCollapsed = {},
        clickActions = {
            leftClick = "whisper",
            rightClick = "invite",
            shiftLeftClick = "copyname",
            shiftRightClick = "who",
            middleClick = "openfriends",
        },
    },
    guild = {
        labelFormat = "Guild: <online>/<total>",
        sortBy = "name",
        sortAscending = true,
        classColorNames = true,
        tooltipScale = 1.0,
        tooltipWidth = 480,
        rowSpacing = 4,
        groupBy = "none",
        groupCollapsed = {},
        clickActions = {
            leftClick = "whisper",
            rightClick = "invite",
            shiftLeftClick = "copyname",
            shiftRightClick = "who",
            middleClick = "openguild",
        },
    },
    communities = {
        labelFormat = "Communities: <online>",
        sortBy = "name",
        sortAscending = true,
        classColorNames = true,
        tooltipScale = 1.0,
        tooltipWidth = 480,
        rowSpacing = 4,
        disabledClubs = {},
        clickActions = {
            leftClick = "whisper",
            rightClick = "invite",
            shiftLeftClick = "copyname",
            shiftRightClick = "who",
            middleClick = "opencommunities",
        },
    },
}

-- Available click actions
ns.ACTION_VALUES = {
    whisper         = "Whisper",
    invite          = "Invite to Group",
    who             = "/who Lookup",
    copyname        = "Copy Name to Chat",
    openfriends     = "Open Friends List",
    openguild       = "Open Guild Roster",
    opencommunities = "Open Communities",
    none            = "None",
}

-- Grouping modes
ns.FRIENDS_GROUP_VALUES = {
    none = "No Grouping",
    type = "BNet / In-Game Friends",
    zone = "Same Zone",
    note = "Friend Note (#tags)",
}

ns.GUILD_GROUP_VALUES = {
    none  = "No Grouping",
    rank  = "Guild Rank",
    level = "Level Bracket",
    zone  = "Same Zone",
}

---------------------------------------------------------------------------
-- Saved variables helpers
---------------------------------------------------------------------------

--- Deep-merge defaults into saved vars (only fills missing keys)
local function MergeDefaults(target, defaults)
    for k, v in pairs(defaults) do
        if type(v) == "table" then
            if type(target[k]) ~= "table" then
                target[k] = {}
            end
            MergeDefaults(target[k], v)
        elseif target[k] == nil then
            target[k] = v
        end
    end
end

---------------------------------------------------------------------------
-- Utility functions
---------------------------------------------------------------------------

--- Parse #GroupName tags from a note string (FriendGroups-compatible)
function DGF:ParseNoteGroups(note)
    if not note or note == "" then return {} end
    local groups = {}
    local tagSection = note:match("#.+")
    if tagSection then
        for tag in tagSection:gmatch("[^#]+") do
            local trimmed = tag:match("^%s*(.-)%s*$")
            if trimmed and trimmed ~= "" then
                table.insert(groups, trimmed)
            end
        end
    end
    return groups
end

--- Replace <token> placeholders in a format string
function DGF:FormatLabel(fmt, online, total, extra)
    local offline = total - online
    local result = fmt
    result = result:gsub("<online>", tostring(online))
    result = result:gsub("<total>", tostring(total))
    result = result:gsub("<offline>", tostring(offline))
    if extra then
        for k, v in pairs(extra) do
            result = result:gsub("<" .. k .. ">", tostring(v))
        end
    end
    return result
end

--- Get class color as r, g, b (0-1) with fallback
function DGF:GetClassColor(classFile)
    if classFile and RAID_CLASS_COLORS[classFile] then
        local c = RAID_CLASS_COLORS[classFile]
        return c.r, c.g, c.b
    end
    return 0.63, 0.63, 0.63
end

--- Wrap text in a color escape sequence
function DGF:ColorText(text, r, g, b)
    return ("|cff%02x%02x%02x%s|r"):format(r * 255, g * 255, b * 255, text)
end

--- Color text by class file token
function DGF:ClassColorText(text, classFile)
    local r, g, b = self:GetClassColor(classFile)
    return self:ColorText(text, r, g, b)
end

--- Copy shared display settings between modules
function DGF:CopyDisplaySettings(fromKey, toKey)
    local from = ns.db[fromKey]
    local to = ns.db[toKey]
    if not from or not to then return end
    to.tooltipScale = from.tooltipScale
    to.tooltipWidth = from.tooltipWidth
    to.rowSpacing = from.rowSpacing
    to.classColorNames = from.classColorNames
    to.sortAscending = from.sortAscending
end

--- Print a message to chat
function DGF:Print(msg)
    print("|cff33ff99" .. addonName .. "|r: " .. msg)
end

---------------------------------------------------------------------------
-- Initialization
---------------------------------------------------------------------------

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(_, _, loadedAddon)
    if loadedAddon ~= addonName then return end
    initFrame:UnregisterEvent("ADDON_LOADED")

    -- Load or create saved variables
    if not DjinnisGuildFriendsDB then
        DjinnisGuildFriendsDB = {}
    end
    MergeDefaults(DjinnisGuildFriendsDB, ns.defaults)
    ns.db = DjinnisGuildFriendsDB

    -- Setup settings UI (Settings.lua)
    DGF:SetupOptions()

    -- Slash commands
    SLASH_DGF1 = "/dgf"
    SLASH_DGF2 = "/djfriends"
    SlashCmdList["DGF"] = function(input)
        if input and input:trim() ~= "" then
            DGF:Print("Unknown command: " .. input)
        else
            Settings.OpenToCategory(DGF.settingsCategoryID)
        end
    end

    -- Initialize broker modules
    if ns.FriendsBroker then ns.FriendsBroker:Init() end
    if ns.GuildBroker then ns.GuildBroker:Init() end
    if ns.CommunitiesBroker then ns.CommunitiesBroker:Init() end
end)
