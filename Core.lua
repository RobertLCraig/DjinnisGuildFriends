local addonName, ns = ...

local DGF = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceEvent-3.0", "AceConsole-3.0")
ns.addon = DGF
ns.addonName = addonName

-- AceDB default profile settings
ns.defaults = {
    profile = {
        minimap = {
            hide = false,
        },
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
            clickActions = {
                leftClick = "whisper",
                rightClick = "invite",
                shiftLeftClick = "who",
                shiftRightClick = "copyname",
                middleClick = "none",
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
            clickActions = {
                leftClick = "whisper",
                rightClick = "invite",
                shiftLeftClick = "who",
                shiftRightClick = "copyname",
                middleClick = "none",
            },
        },
    },
}

-- Available click actions for settings dropdowns
ns.ACTION_VALUES = {
    whisper  = "Whisper",
    invite   = "Invite to Group",
    who      = "/who Lookup",
    copyname = "Copy Name to Chat",
    none     = "None",
}

---------------------------------------------------------------------------
-- Utility functions
---------------------------------------------------------------------------

--- Replace <online>, <total>, <offline> tokens in a format string
function DGF:FormatLabel(fmt, online, total)
    local offline = total - online
    local result = fmt
    result = result:gsub("<online>", tostring(online))
    result = result:gsub("<total>", tostring(total))
    result = result:gsub("<offline>", tostring(offline))
    return result
end

--- Get class color as r, g, b (0-1) with fallback
function DGF:GetClassColor(classFile)
    if classFile and RAID_CLASS_COLORS[classFile] then
        local c = RAID_CLASS_COLORS[classFile]
        return c.r, c.g, c.b
    end
    return 0.63, 0.63, 0.63 -- grey fallback
end

--- Wrap text in a color escape sequence
function DGF:ColorText(text, r, g, b)
    return ("|cff%02x%02x%02x%s|r"):format(r * 255, g * 255, b * 255, text)
end

--- Color text by class
function DGF:ClassColorText(text, classFile)
    local r, g, b = self:GetClassColor(classFile)
    return self:ColorText(text, r, g, b)
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------

function DGF:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("DjinnisGuildFriendsDB", ns.defaults, true)

    -- Minimap icon via LibDBIcon
    local icon = LibStub("LibDBIcon-1.0", true)
    if icon then
        ns.icon = icon
    end

    -- Register slash commands
    self:RegisterChatCommand("dgf", "SlashCommand")
    self:RegisterChatCommand("djfriends", "SlashCommand")

    -- Setup options (defined in Settings.lua)
    self:SetupOptions()
end

function DGF:OnEnable()
    -- Modules auto-enable via AceAddon
end

function DGF:SlashCommand(input)
    if input and input:trim() ~= "" then
        -- Future: handle sub-commands
        self:Print("Unknown command: " .. input)
    else
        -- Open settings panel
        Settings.OpenToCategory(self.optionsCategoryID)
    end
end
