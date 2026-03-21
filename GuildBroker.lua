local addonName, ns = ...
local DGF = ns.addon
local LDB = LibStub("LibDataBroker-1.1")

---------------------------------------------------------------------------
-- Module setup
---------------------------------------------------------------------------

local GuildBroker = DGF:NewModule("GuildBroker", "AceEvent-3.0")
ns.GuildBroker = GuildBroker

-- Guild data cache
GuildBroker.guildCache = {}
GuildBroker.onlineCount = 0
GuildBroker.totalCount = 0
GuildBroker.guildName = ""

-- Tooltip frame and row pool (separate from friends)
local tooltipFrame = nil
local rowPool = {}
local ROW_HEIGHT = 16
local TOOLTIP_PADDING = 10
local HEADER_HEIGHT = 24

-- Status icons
local STATUS_STRINGS = {
    [0] = "",
    [1] = "|cffffcc00[AFK]|r ",
    [2] = "|cffff0000[DND]|r ",
}

local MOBILE_ICON = "|TInterface\\ChatFrame\\UI-ChatIcon-ArmoryChat:14|t "

---------------------------------------------------------------------------
-- LDB Data Object
---------------------------------------------------------------------------

local dataobj = LDB:NewDataObject("DGF-Guild", {
    type  = "data source",
    text  = "Guild: 0/0",
    icon  = "Interface\\GossipFrame\\TabardGossipIcon",
    label = "Guild",
    OnEnter = function(self)
        GuildBroker:ShowTooltip(self)
    end,
    OnLeave = function(self)
        GuildBroker:StartTooltipHideTimer()
    end,
    OnClick = function(self, button)
        if button == "LeftButton" and IsShiftKeyDown() then
            ToggleGuildFrame()
        end
    end,
})

GuildBroker.dataobj = dataobj

---------------------------------------------------------------------------
-- Module lifecycle
---------------------------------------------------------------------------

function GuildBroker:OnEnable()
    self:RegisterEvent("GUILD_ROSTER_UPDATE", "OnGuildUpdate")
    self:RegisterEvent("PLAYER_GUILD_UPDATE", "OnGuildUpdate")
    self:RegisterEvent("GUILD_MOTD", "OnGuildUpdate")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnPlayerEnteringWorld")

    -- Register minimap icon (optional, separate from friends icon)
    -- Users can disable via settings if they only want one icon
end

function GuildBroker:OnPlayerEnteringWorld()
    -- Request guild data from server
    if IsInGuild() then
        C_GuildInfo.GuildRoster()
        C_Timer.After(3, function()
            self:UpdateData()
        end)
    end
end

function GuildBroker:OnGuildUpdate()
    self:UpdateData()
end

---------------------------------------------------------------------------
-- Data collection
---------------------------------------------------------------------------

function GuildBroker:UpdateData()
    if not IsInGuild() then
        self.guildCache = {}
        self.onlineCount = 0
        self.totalCount = 0
        self.guildName = ""
        dataobj.text = "No Guild"
        return
    end

    local db = DGF.db.profile.guild
    local members = {}

    self.guildName = GetGuildInfo("player") or ""
    local totalMembers, onlineMembers = GetNumGuildMembers()
    self.totalCount = totalMembers or 0

    local onlineCount = 0
    for i = 1, totalMembers do
        local name, rank, rankIndex, level, _, zone, note, officerNote,
              connected, memberStatus, className, _, _, isMobile, _, _, guid =
              GetGuildRosterInfo(i)

        if not name then break end

        -- className from GetGuildRosterInfo is the class FILE token (e.g., "WARRIOR")
        local classToken = className

        -- Determine status
        local status = memberStatus or 0
        local isOnline = connected or isMobile

        -- Zone override for mobile-only users
        local displayZone = zone or ""
        if isMobile and not connected then
            displayZone = REMOTE_CHAT or "Mobile"
        end

        if isOnline then
            onlineCount = onlineCount + 1
            table.insert(members, {
                name       = name,
                level      = level or 0,
                classFile  = classToken,
                className  = className or "",
                area       = displayZone,
                rank       = rank or "",
                rankIndex  = rankIndex or 0,
                connected  = connected,
                isMobile   = isMobile,
                status     = status,
                afk        = (status == 1),
                dnd        = (status == 2),
                notes      = note or "",
                officerNote = officerNote or "",
                fullName   = name,
                guid       = guid,
            })
        end
    end

    self.onlineCount = onlineCount

    -- Sort
    self:SortMembers(members)

    -- Update cache
    self.guildCache = members

    -- Update LDB text
    dataobj.text = DGF:FormatLabel(db.labelFormat, self.onlineCount, self.totalCount)

    -- Refresh tooltip if visible
    if tooltipFrame and tooltipFrame:IsShown() then
        self:PopulateTooltip()
    end
end

---------------------------------------------------------------------------
-- Sorting
---------------------------------------------------------------------------

local SORT_FUNCTIONS = {
    name = function(a, b) return a.name < b.name end,
    class = function(a, b)
        if a.className == b.className then return a.name < b.name end
        return a.className < b.className
    end,
    level = function(a, b)
        if a.level == b.level then return a.name < b.name end
        return a.level < b.level
    end,
    zone = function(a, b)
        if a.area == b.area then return a.name < b.name end
        return a.area < b.area
    end,
    rank = function(a, b)
        if a.rankIndex == b.rankIndex then return a.name < b.name end
        return a.rankIndex < b.rankIndex
    end,
    status = function(a, b)
        local sa = a.afk and 2 or a.dnd and 3 or 1
        local sb = b.afk and 2 or b.dnd and 3 or 1
        if sa == sb then return a.name < b.name end
        return sa < sb
    end,
}

function GuildBroker:SortMembers(members)
    local db = DGF.db.profile.guild
    local sortFunc = SORT_FUNCTIONS[db.sortBy] or SORT_FUNCTIONS.name
    local ascending = db.sortAscending

    table.sort(members, function(a, b)
        if ascending then
            return sortFunc(a, b)
        else
            return sortFunc(b, a)
        end
    end)
end

---------------------------------------------------------------------------
-- Tooltip frame creation
---------------------------------------------------------------------------

local function CreateTooltipFrame()
    local f = CreateFrame("Frame", "DGFGuildTooltip", UIParent, "BackdropTemplate")
    f:SetFrameStrata("TOOLTIP")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetSize(420, 100)

    f:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile     = true,
        tileSize = 16,
        edgeSize = 16,
        insets   = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    f:SetBackdropColor(0.05, 0.05, 0.05, 0.92)
    f:SetBackdropBorderColor(0.6, 0.6, 0.6, 0.8)

    -- Header (guild name + online count)
    f.header = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.header:SetPoint("TOPLEFT", f, "TOPLEFT", TOOLTIP_PADDING, -TOOLTIP_PADDING)
    f.header:SetPoint("TOPRIGHT", f, "TOPRIGHT", -TOOLTIP_PADDING, -TOOLTIP_PADDING)
    f.header:SetJustifyH("LEFT")
    f.header:SetHeight(HEADER_HEIGHT)

    -- MOTD line
    f.motd = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.motd:SetPoint("TOPLEFT", f.header, "BOTTOMLEFT", 0, -2)
    f.motd:SetPoint("TOPRIGHT", f.header, "BOTTOMRIGHT", 0, -2)
    f.motd:SetJustifyH("LEFT")
    f.motd:SetWordWrap(true)
    f.motd:SetMaxLines(2)

    -- Column headers (positioned after MOTD dynamically)
    f.colName = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.colName:SetText("|cffaaaaaaName|r")
    f.colName:SetJustifyH("LEFT")

    f.colLevel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.colLevel:SetText("|cffaaaaaaLvl|r")
    f.colLevel:SetWidth(30)
    f.colLevel:SetJustifyH("CENTER")

    f.colRank = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.colRank:SetText("|cffaaaaaaRank|r")
    f.colRank:SetJustifyH("LEFT")

    f.colZone = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.colZone:SetText("|cffaaaaaaZone|r")
    f.colZone:SetJustifyH("LEFT")

    f.colNote = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.colNote:SetPoint("RIGHT", f, "RIGHT", -TOOLTIP_PADDING, 0)
    f.colNote:SetText("|cffaaaaaaNotes|r")
    f.colNote:SetJustifyH("LEFT")

    -- Hint text at bottom
    f.hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.hint:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", TOOLTIP_PADDING, TOOLTIP_PADDING)
    f.hint:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -TOOLTIP_PADDING, TOOLTIP_PADDING)
    f.hint:SetJustifyH("LEFT")

    -- Mouse enter/leave for tooltip persistence
    f:SetScript("OnEnter", function()
        GuildBroker:CancelTooltipHideTimer()
    end)
    f:SetScript("OnLeave", function()
        GuildBroker:StartTooltipHideTimer()
    end)

    f:Hide()
    return f
end

--- Update tooltip and row widths based on configured width
local function UpdateTooltipLayout(tooltipWidth)
    if not tooltipFrame then return end

    local innerWidth = tooltipWidth - 2 * TOOLTIP_PADDING
    -- Column proportions: Name 25%, Lvl 30px, Rank 15%, Zone 22%, Notes remainder
    local nameW = math.floor(innerWidth * 0.25)
    local levelW = 30
    local rankW = math.floor(innerWidth * 0.15)
    local zoneW = math.floor(innerWidth * 0.22)
    local noteW = innerWidth - nameW - levelW - rankW - zoneW - 16 -- 16 = 4 gaps of 4px

    tooltipFrame:SetWidth(tooltipWidth)
    tooltipFrame.colName:SetWidth(nameW)
    tooltipFrame.colRank:SetWidth(rankW)
    tooltipFrame.colZone:SetWidth(zoneW)

    -- Update all existing rows
    for _, row in pairs(rowPool) do
        row:SetWidth(innerWidth)
        row.nameText:SetWidth(nameW)
        row.rankText:SetWidth(rankW)
        row.zoneText:SetWidth(zoneW)
        row.noteText:SetWidth(noteW)
    end

    return nameW, levelW, rankW, zoneW, noteW
end

local function GetOrCreateRow(parent, index)
    if rowPool[index] then
        rowPool[index]:Show()
        return rowPool[index]
    end

    local row = CreateFrame("Button", nil, parent)
    row:SetSize(400, ROW_HEIGHT)
    row:EnableMouse(true)
    row:RegisterForClicks("AnyUp")

    -- Highlight texture
    row.highlight = row:CreateTexture(nil, "HIGHLIGHT")
    row.highlight:SetAllPoints()
    row.highlight:SetColorTexture(1, 1, 1, 0.1)

    -- Name
    row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.nameText:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.nameText:SetWidth(130)
    row.nameText:SetJustifyH("LEFT")

    -- Level
    row.levelText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.levelText:SetPoint("LEFT", row.nameText, "RIGHT", 4, 0)
    row.levelText:SetWidth(30)
    row.levelText:SetJustifyH("CENTER")

    -- Rank
    row.rankText = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.rankText:SetPoint("LEFT", row.levelText, "RIGHT", 4, 0)
    row.rankText:SetWidth(70)
    row.rankText:SetJustifyH("LEFT")

    -- Zone
    row.zoneText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.zoneText:SetPoint("LEFT", row.rankText, "RIGHT", 4, 0)
    row.zoneText:SetWidth(100)
    row.zoneText:SetJustifyH("LEFT")

    -- Note
    row.noteText = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.noteText:SetPoint("LEFT", row.zoneText, "RIGHT", 4, 0)
    row.noteText:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    row.noteText:SetJustifyH("LEFT")
    row.noteText:SetWordWrap(false)

    row:SetScript("OnMouseUp", function(self, button)
        GuildBroker:OnRowClick(self, button)
    end)

    row:SetScript("OnEnter", function(self)
        GuildBroker:CancelTooltipHideTimer()
        if self.memberData then
            local hasNote = self.memberData.notes and self.memberData.notes ~= ""
            local hasONote = self.memberData.officerNote and self.memberData.officerNote ~= ""
            if hasNote or hasONote then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                if hasNote then
                    GameTooltip:AddLine("Note: " .. self.memberData.notes, 1, 1, 1, true)
                end
                if hasONote then
                    GameTooltip:AddLine("Officer: " .. self.memberData.officerNote, 1, 0.5, 0, true)
                end
                GameTooltip:Show()
            end
        end
    end)

    row:SetScript("OnLeave", function()
        GameTooltip:Hide()
        GuildBroker:StartTooltipHideTimer()
    end)

    rowPool[index] = row
    return row
end

---------------------------------------------------------------------------
-- Tooltip display
---------------------------------------------------------------------------

function GuildBroker:ShowTooltip(anchor)
    if not tooltipFrame then
        tooltipFrame = CreateTooltipFrame()
    end

    self:CancelTooltipHideTimer()

    -- Request fresh data
    if IsInGuild() then
        C_GuildInfo.GuildRoster()
    end
    self:UpdateData()

    -- Anchor
    tooltipFrame:ClearAllPoints()
    tooltipFrame:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -4)

    -- Scale
    local scale = DGF.db.profile.guild.tooltipScale or 1.0
    tooltipFrame:SetScale(scale)

    -- Apply configurable width
    local tooltipWidth = DGF.db.profile.guild.tooltipWidth or 480
    UpdateTooltipLayout(tooltipWidth)

    self:PopulateTooltip()
    tooltipFrame:Show()
end

function GuildBroker:PopulateTooltip()
    if not tooltipFrame then return end

    local members = self.guildCache
    local db = DGF.db.profile.guild
    local useClassColors = db.classColorNames

    -- Header: Guild Name + online/total
    local headerText = DGF:ColorText(self.guildName .. "  ", 0.4, 0.78, 1)
        .. DGF:ColorText(tostring(self.onlineCount), 0, 1, 0)
        .. DGF:ColorText(" / " .. tostring(self.totalCount), 0.63, 0.63, 0.63)
    tooltipFrame.header:SetText(headerText)

    -- MOTD
    local motd = GetGuildRosterMOTD() or ""
    if motd ~= "" then
        tooltipFrame.motd:SetText("|cff888888MOTD: " .. motd .. "|r")
        tooltipFrame.motd:Show()
    else
        tooltipFrame.motd:SetText("")
        tooltipFrame.motd:Hide()
    end

    -- Position column headers after MOTD
    local motdHeight = 0
    if motd ~= "" then
        motdHeight = tooltipFrame.motd:GetStringHeight() + 4
    end

    local colY = -(TOOLTIP_PADDING + HEADER_HEIGHT + motdHeight + 4)
    tooltipFrame.colName:ClearAllPoints()
    tooltipFrame.colName:SetPoint("TOPLEFT", tooltipFrame, "TOPLEFT", TOOLTIP_PADDING, colY)
    tooltipFrame.colLevel:ClearAllPoints()
    tooltipFrame.colLevel:SetPoint("LEFT", tooltipFrame.colName, "RIGHT", 4, 0)
    tooltipFrame.colRank:ClearAllPoints()
    tooltipFrame.colRank:SetPoint("LEFT", tooltipFrame.colLevel, "RIGHT", 4, 0)
    tooltipFrame.colZone:ClearAllPoints()
    tooltipFrame.colZone:SetPoint("LEFT", tooltipFrame.colRank, "RIGHT", 4, 0)
    tooltipFrame.colNote:ClearAllPoints()
    tooltipFrame.colNote:SetPoint("LEFT", tooltipFrame.colZone, "RIGHT", 4, 0)

    -- Build hint text
    local hints = {}
    if db.clickActions.leftClick ~= "none" then
        table.insert(hints, "LClick: " .. (ns.ACTION_VALUES[db.clickActions.leftClick] or ""))
    end
    if db.clickActions.rightClick ~= "none" then
        table.insert(hints, "RClick: " .. (ns.ACTION_VALUES[db.clickActions.rightClick] or ""))
    end
    if db.clickActions.shiftLeftClick ~= "none" then
        table.insert(hints, "Shift+L: " .. (ns.ACTION_VALUES[db.clickActions.shiftLeftClick] or ""))
    end
    tooltipFrame.hint:SetText("|cff888888" .. table.concat(hints, "  |  ") .. "|r")

    -- Hide all existing rows
    for _, row in pairs(rowPool) do
        row:Hide()
    end

    local rowSpacing = db.rowSpacing or 4
    local rowStep = ROW_HEIGHT + rowSpacing

    local yOffset = colY - 16 -- after column headers
    for i, member in ipairs(members) do
        local row = GetOrCreateRow(tooltipFrame, i)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", tooltipFrame, "TOPLEFT", TOOLTIP_PADDING, yOffset)
        row.memberData = member

        -- Status prefix
        local status = STATUS_STRINGS[member.status] or ""
        if member.isMobile and not member.connected then
            status = MOBILE_ICON
        end

        -- Strip realm from name for display (guild members show Name-Realm)
        local displayName = member.name
        local dashPos = displayName:find("-")
        if dashPos then
            displayName = displayName:sub(1, dashPos - 1)
        end

        -- Apply class coloring if enabled
        if useClassColors and member.classFile then
            row.nameText:SetText(status .. DGF:ClassColorText(displayName, member.classFile))
        else
            row.nameText:SetText(status .. displayName)
        end

        row.levelText:SetText(member.level > 0 and tostring(member.level) or "")
        row.rankText:SetText(DGF:ColorText(member.rank, 0.7, 0.7, 0.7))
        row.zoneText:SetText(DGF:ColorText(member.area, 0.63, 0.82, 1))
        row.noteText:SetText(member.notes or "")

        yOffset = yOffset - rowStep
    end

    -- Empty state
    if #members == 0 then
        local row = GetOrCreateRow(tooltipFrame, 1)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", tooltipFrame, "TOPLEFT", TOOLTIP_PADDING, yOffset)
        row.memberData = nil
        row.nameText:SetText("|cff888888No guild members online|r")
        row.levelText:SetText("")
        row.rankText:SetText("")
        row.zoneText:SetText("")
        row.noteText:SetText("")
        yOffset = yOffset - rowStep
    end

    -- Size the tooltip
    local totalHeight = math.abs(yOffset) + TOOLTIP_PADDING + 20
    tooltipFrame:SetHeight(totalHeight)
end

---------------------------------------------------------------------------
-- Tooltip hide timer
---------------------------------------------------------------------------

GuildBroker.hideTimer = nil

function GuildBroker:StartTooltipHideTimer()
    self:CancelTooltipHideTimer()
    self.hideTimer = C_Timer.NewTimer(0.15, function()
        if tooltipFrame then
            tooltipFrame:Hide()
        end
        self.hideTimer = nil
    end)
end

function GuildBroker:CancelTooltipHideTimer()
    if self.hideTimer then
        self.hideTimer:Cancel()
        self.hideTimer = nil
    end
end

---------------------------------------------------------------------------
-- Click action handling
---------------------------------------------------------------------------

function GuildBroker:OnRowClick(row, button)
    local member = row.memberData
    if not member then return end

    local db = DGF.db.profile.guild
    local action

    if button == "LeftButton" and IsShiftKeyDown() then
        action = db.clickActions.shiftLeftClick
    elseif button == "RightButton" and IsShiftKeyDown() then
        action = db.clickActions.shiftRightClick
    elseif button == "LeftButton" then
        action = db.clickActions.leftClick
    elseif button == "RightButton" then
        action = db.clickActions.rightClick
    elseif button == "MiddleButton" then
        action = db.clickActions.middleClick
    end

    if action and action ~= "none" then
        self:ExecuteAction(action, member)
    end
end

function GuildBroker:ExecuteAction(action, member)
    self:CancelTooltipHideTimer()

    -- Guild members are always WoW characters (never BNet entries)
    local name = member.fullName or member.name

    if action == "whisper" then
        if tooltipFrame then tooltipFrame:Hide() end
        if name and name ~= "" then
            if ChatFrameUtil and ChatFrameUtil.SendTell then
                ChatFrameUtil.SendTell(name)
            elseif ChatFrame_SendTell then
                ChatFrame_SendTell(name)
            else
                ChatFrameUtil.OpenChat("/w " .. name .. " ")
            end
        end
        return

    elseif action == "invite" then
        if name and name ~= "" then
            C_PartyInfo.InviteUnit(name)
        end

    elseif action == "who" then
        if name and name ~= "" then
            C_FriendList.SendWho(name)
        end

    elseif action == "copyname" then
        if name and name ~= "" then
            if not ChatFrame1EditBox:IsShown() then
                ChatFrameUtil.OpenChat("")
            end
            ChatFrame1EditBox:Insert(name)
        end
    end

    -- Hide tooltip after action (except whisper which returns early)
    if tooltipFrame then tooltipFrame:Hide() end
end
