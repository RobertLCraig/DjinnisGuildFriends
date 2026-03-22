local addonName, ns = ...
local DGF = ns.addon
local LDB = LibStub("LibDataBroker-1.1")

---------------------------------------------------------------------------
-- Module setup
---------------------------------------------------------------------------

local GuildBroker = {}
ns.GuildBroker = GuildBroker

GuildBroker.guildCache = {}
GuildBroker.onlineCount = 0
GuildBroker.totalCount = 0
GuildBroker.guildName = ""

local tooltipFrame = nil
local rowPool = {}
local ROW_HEIGHT = 16
local TOOLTIP_PADDING = 10
local HEADER_HEIGHT = 24

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
-- Event handling
---------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")

function GuildBroker:Init()
    eventFrame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_ENTERING_WORLD" then
            GuildBroker:OnPlayerEnteringWorld()
        else
            GuildBroker:OnGuildUpdate()
        end
    end)
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("GUILD_ROSTER_UPDATE")
    eventFrame:RegisterEvent("PLAYER_GUILD_UPDATE")
    eventFrame:RegisterEvent("GUILD_MOTD")
end

function GuildBroker:OnPlayerEnteringWorld()
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

    local db = ns.db.guild
    local members = {}

    self.guildName = GetGuildInfo("player") or ""
    local totalMembers = GetNumGuildMembers()
    self.totalCount = totalMembers or 0

    local onlineCount = 0
    for i = 1, totalMembers do
        local name, rank, rankIndex, level, _, zone, note, officerNote,
              connected, memberStatus, classFile, _, _, isMobile =
              GetGuildRosterInfo(i)

        if not name then break end

        local status = memberStatus or 0
        local isOnline = connected or isMobile

        local displayZone = zone or ""
        if isMobile and not connected then
            displayZone = REMOTE_CHAT or "Mobile"
        end

        if isOnline then
            onlineCount = onlineCount + 1
            table.insert(members, {
                name      = name,
                level     = level or 0,
                classFile = classFile or "",
                area      = displayZone,
                rank      = rank or "",
                rankIndex = rankIndex or 0,
                connected = connected,
                isMobile  = isMobile,
                status    = status,
                afk       = (status == 1),
                dnd       = (status == 2),
                notes     = note or "",
                officerNote = officerNote or "",
                fullName  = name,
            })
        end
    end

    self.onlineCount = onlineCount

    self:SortMembers(members)
    self.guildCache = members

    dataobj.text = DGF:FormatLabel(db.labelFormat, self.onlineCount, self.totalCount, { guildname = self.guildName })

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
        if a.classFile == b.classFile then return a.name < b.name end
        return a.classFile < b.classFile
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
    local db = ns.db.guild
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

    f.header = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.header:SetPoint("TOPLEFT", f, "TOPLEFT", TOOLTIP_PADDING, -TOOLTIP_PADDING)
    f.header:SetPoint("TOPRIGHT", f, "TOPRIGHT", -TOOLTIP_PADDING, -TOOLTIP_PADDING)
    f.header:SetJustifyH("LEFT")
    f.header:SetHeight(HEADER_HEIGHT)

    f.motd = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.motd:SetPoint("TOPLEFT", f.header, "BOTTOMLEFT", 0, -2)
    f.motd:SetPoint("TOPRIGHT", f.header, "BOTTOMRIGHT", 0, -2)
    f.motd:SetJustifyH("LEFT")
    f.motd:SetWordWrap(true)
    f.motd:SetMaxLines(2)

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

    f.hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.hint:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", TOOLTIP_PADDING, TOOLTIP_PADDING)
    f.hint:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -TOOLTIP_PADDING, TOOLTIP_PADDING)
    f.hint:SetJustifyH("LEFT")

    f:SetScript("OnEnter", function()
        GuildBroker:CancelTooltipHideTimer()
    end)
    f:SetScript("OnLeave", function()
        GuildBroker:StartTooltipHideTimer()
    end)

    f:Hide()
    return f
end

local function UpdateTooltipLayout(tooltipWidth)
    if not tooltipFrame then return end

    local innerWidth = tooltipWidth - 2 * TOOLTIP_PADDING
    local nameW = math.floor(innerWidth * 0.25)
    local levelW = 30
    local rankW = math.floor(innerWidth * 0.15)
    local zoneW = math.floor(innerWidth * 0.22)
    local noteW = innerWidth - nameW - levelW - rankW - zoneW - 16

    tooltipFrame:SetWidth(tooltipWidth)
    tooltipFrame.colName:SetWidth(nameW)
    tooltipFrame.colRank:SetWidth(rankW)
    tooltipFrame.colZone:SetWidth(zoneW)

    for _, row in pairs(rowPool) do
        row:SetWidth(innerWidth)
        row.nameText:SetWidth(nameW)
        row.rankText:SetWidth(rankW)
        row.zoneText:SetWidth(zoneW)
        row.noteText:SetWidth(noteW)
    end
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

    row.highlight = row:CreateTexture(nil, "HIGHLIGHT")
    row.highlight:SetAllPoints()
    row.highlight:SetColorTexture(1, 1, 1, 0.1)

    row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.nameText:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.nameText:SetWidth(130)
    row.nameText:SetJustifyH("LEFT")

    row.levelText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.levelText:SetPoint("LEFT", row.nameText, "RIGHT", 4, 0)
    row.levelText:SetWidth(30)
    row.levelText:SetJustifyH("CENTER")

    row.rankText = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.rankText:SetPoint("LEFT", row.levelText, "RIGHT", 4, 0)
    row.rankText:SetWidth(70)
    row.rankText:SetJustifyH("LEFT")

    row.zoneText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.zoneText:SetPoint("LEFT", row.rankText, "RIGHT", 4, 0)
    row.zoneText:SetWidth(100)
    row.zoneText:SetJustifyH("LEFT")

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

    if IsInGuild() then
        C_GuildInfo.GuildRoster()
    end
    self:UpdateData()

    tooltipFrame:ClearAllPoints()
    tooltipFrame:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, 4)
    tooltipFrame:SetScale(ns.db.guild.tooltipScale or 1.0)
    UpdateTooltipLayout(ns.db.guild.tooltipWidth or 480)

    self:PopulateTooltip()
    tooltipFrame:Show()
end

function GuildBroker:PopulateTooltip()
    if not tooltipFrame then return end

    local members = self.guildCache
    local db = ns.db.guild
    local useClassColors = db.classColorNames

    tooltipFrame.header:SetText(
        DGF:ColorText(self.guildName .. "  ", 0.4, 0.78, 1) ..
        DGF:ColorText(tostring(self.onlineCount), 0, 1, 0) ..
        DGF:ColorText(" / " .. tostring(self.totalCount), 0.63, 0.63, 0.63)
    )

    local motd = GetGuildRosterMOTD() or ""
    if motd ~= "" then
        tooltipFrame.motd:SetText("|cff888888MOTD: " .. motd .. "|r")
        tooltipFrame.motd:Show()
    else
        tooltipFrame.motd:SetText("")
        tooltipFrame.motd:Hide()
    end

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

    for _, row in pairs(rowPool) do
        row:Hide()
    end
    if tooltipFrame.groupHeaders then
        for _, hdr in pairs(tooltipFrame.groupHeaders) do
            hdr:Hide()
        end
    end

    local rowSpacing = db.rowSpacing or 4
    local rowStep = ROW_HEIGHT + rowSpacing
    local groupBy = db.groupBy or "none"
    local groups, groupOrder = self:BuildGroups(members, groupBy)

    local yOffset = colY - 16
    local rowIdx = 0

    local function RenderMember(member)
        rowIdx = rowIdx + 1
        local row = GetOrCreateRow(tooltipFrame, rowIdx)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", tooltipFrame, "TOPLEFT", TOOLTIP_PADDING, yOffset)
        row.memberData = member

        local status = STATUS_STRINGS[member.status] or ""
        if member.isMobile and not member.connected then
            status = MOBILE_ICON
        end

        local displayName = member.name
        local dashPos = displayName:find("-")
        if dashPos then
            displayName = displayName:sub(1, dashPos - 1)
        end

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

    if groupBy == "none" then
        for _, member in ipairs(members) do
            RenderMember(member)
        end
    else
        for _, groupName in ipairs(groupOrder) do
            local groupMembers = groups[groupName]
            if groupMembers and #groupMembers > 0 then
                yOffset = yOffset - 4
                local hdr = self:GetOrCreateGroupHeader(tooltipFrame, groupName)
                hdr:ClearAllPoints()
                hdr:SetPoint("TOPLEFT", tooltipFrame, "TOPLEFT", TOOLTIP_PADDING, yOffset)
                hdr:SetText(DGF:ColorText(groupName .. " (" .. #groupMembers .. ")", 1, 0.82, 0))
                hdr:Show()
                yOffset = yOffset - 16

                if not db.groupCollapsed[groupName] then
                    for _, member in ipairs(groupMembers) do
                        RenderMember(member)
                    end
                end
            end
        end
    end

    if #members == 0 then
        rowIdx = rowIdx + 1
        local row = GetOrCreateRow(tooltipFrame, rowIdx)
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

    tooltipFrame:SetHeight(math.abs(yOffset) + TOOLTIP_PADDING + 20)
end

---------------------------------------------------------------------------
-- Grouping
---------------------------------------------------------------------------

function GuildBroker:GetOrCreateGroupHeader(parent, name)
    if not parent.groupHeaders then parent.groupHeaders = {} end
    if parent.groupHeaders[name] then return parent.groupHeaders[name] end

    local hdr = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hdr:SetJustifyH("LEFT")
    hdr:SetHeight(14)
    hdr:SetPoint("RIGHT", parent, "RIGHT", -TOOLTIP_PADDING, 0)
    parent.groupHeaders[name] = hdr
    return hdr
end

function GuildBroker:BuildGroups(members, groupBy)
    if groupBy == "none" then return {}, {} end

    local groups = {}
    local groupSet = {}
    local playerZone = GetRealZoneText() or ""

    for _, member in ipairs(members) do
        local groupName

        if groupBy == "rank" then
            groupName = member.rank or "Unknown"
        elseif groupBy == "level" then
            local lvl = member.level or 0
            if     lvl >= 80 then groupName = "80+"
            elseif lvl >= 70 then groupName = "70-79"
            elseif lvl >= 60 then groupName = "60-69"
            elseif lvl >= 50 then groupName = "50-59"
            elseif lvl >= 40 then groupName = "40-49"
            elseif lvl >= 30 then groupName = "30-39"
            elseif lvl >= 20 then groupName = "20-29"
            elseif lvl >= 10 then groupName = "10-19"
            else                  groupName = "1-9"
            end
        elseif groupBy == "zone" then
            if member.area == playerZone and playerZone ~= "" then
                groupName = "Same Zone: " .. playerZone
            else
                groupName = member.area ~= "" and member.area or "Unknown"
            end
        else
            groupName = "Other"
        end

        if not groups[groupName] then
            groups[groupName] = {}
            groupSet[groupName] = true
        end
        table.insert(groups[groupName], member)
    end

    local order = {}
    for name in pairs(groupSet) do
        table.insert(order, name)
    end

    if groupBy == "rank" then
        table.sort(order, function(a, b)
            local ai = groups[a][1] and groups[a][1].rankIndex or 99
            local bi = groups[b][1] and groups[b][1].rankIndex or 99
            return ai < bi
        end)
    elseif groupBy == "level" then
        table.sort(order, function(a, b) return a > b end)
    elseif groupBy == "zone" then
        table.sort(order, function(a, b)
            local aLocal = a:find("^Same Zone")
            local bLocal = b:find("^Same Zone")
            if aLocal and not bLocal then return true end
            if bLocal and not aLocal then return false end
            return a < b
        end)
    else
        table.sort(order)
    end

    return groups, order
end

---------------------------------------------------------------------------
-- Tooltip hide timer
---------------------------------------------------------------------------

GuildBroker.hideTimer = nil

function GuildBroker:StartTooltipHideTimer()
    self:CancelTooltipHideTimer()
    self.hideTimer = C_Timer.NewTimer(0.15, function()
        if tooltipFrame then tooltipFrame:Hide() end
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

    local db = ns.db.guild
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

    elseif action == "openguild" then
        ToggleGuildFrame()

    elseif action == "openfriends" then
        ToggleFriendsFrame()

    elseif action == "opencommunities" then
        ToggleCommunitiesFrame()
    end

    if tooltipFrame then tooltipFrame:Hide() end
end
