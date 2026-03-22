local addonName, ns = ...
local DGF = ns.addon
local LDB = LibStub("LibDataBroker-1.1")

---------------------------------------------------------------------------
-- Module setup
---------------------------------------------------------------------------

local CommunitiesBroker = {}
ns.CommunitiesBroker = CommunitiesBroker

CommunitiesBroker.clubsCache = {}   -- { clubId = { info=ClubInfo, members={...} } }
CommunitiesBroker.onlineCount = 0
CommunitiesBroker.totalOnline = 0

local tooltipFrame = nil
local rowPool = {}
local ROW_HEIGHT = 16
local TOOLTIP_PADDING = 10
local HEADER_HEIGHT = 24

local FIXED_TOP    = TOOLTIP_PADDING + HEADER_HEIGHT + 20  -- 54px: header + col headers row
local FIXED_BOTTOM = TOOLTIP_PADDING * 2 + 18              -- 38px: hint bar + padding

---------------------------------------------------------------------------
-- LDB Data Object
---------------------------------------------------------------------------

local dataobj = LDB:NewDataObject("DGF-Communities", {
    type  = "data source",
    text  = "Communities: 0",
    icon  = "Interface\\FriendsFrame\\UI-Toast-ChatInviteIcon",
    label = "Communities",
    OnEnter = function(self)
        CommunitiesBroker:ShowTooltip(self)
    end,
    OnLeave = function(self)
        CommunitiesBroker:StartTooltipHideTimer()
    end,
    OnClick = function(self, button)
        if button == "LeftButton" and IsShiftKeyDown() then
            ToggleCommunitiesFrame()
        end
    end,
})

CommunitiesBroker.dataobj = dataobj

---------------------------------------------------------------------------
-- Event handling
---------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")

function CommunitiesBroker:Init()
    eventFrame:SetScript("OnEvent", function(_, event, ...)
        if event == "PLAYER_ENTERING_WORLD" then
            CommunitiesBroker:OnPlayerEnteringWorld()
        else
            CommunitiesBroker:OnClubUpdate(event, ...)
        end
    end)
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("CLUB_MEMBER_PRESENCE_UPDATED")
    eventFrame:RegisterEvent("CLUB_MEMBER_UPDATED")
    eventFrame:RegisterEvent("CLUB_ADDED")
    eventFrame:RegisterEvent("CLUB_REMOVED")
    eventFrame:RegisterEvent("CLUB_STREAMS_LOADED")
    eventFrame:RegisterEvent("INITIAL_CLUB_DATA_LOADED")
end

function CommunitiesBroker:OnPlayerEnteringWorld()
    C_Timer.After(5, function()
        self:UpdateData()
    end)
end

function CommunitiesBroker:OnClubUpdate()
    self:UpdateData()
end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

--- Resolve classFile from a classID via C_CreatureInfo
local function ClassFileFromID(classID)
    if not classID or classID == 0 then return nil end
    local info = C_CreatureInfo and C_CreatureInfo.GetClassInfo(classID)
    return info and info.classFile or nil
end

--- Check if a club member is considered online
local function IsPresenceOnline(presence)
    return presence == Enum.ClubMemberPresence.Online
        or presence == Enum.ClubMemberPresence.OnlineMobile
        or presence == Enum.ClubMemberPresence.Away
        or presence == Enum.ClubMemberPresence.Busy
end

--- Check if a club should be shown (not disabled by user)
function CommunitiesBroker:IsClubEnabled(clubId)
    return not ns.db.communities.disabledClubs[clubId]
end

---------------------------------------------------------------------------
-- Data collection
---------------------------------------------------------------------------

function CommunitiesBroker:UpdateData()
    local db = ns.db.communities
    local clubs = C_Club.GetSubscribedClubs() or {}
    local totalOnline = 0
    local clubsData = {}

    for _, clubInfo in ipairs(clubs) do
        -- Only character and BNet communities (skip guild — handled by GuildBroker)
        if (clubInfo.clubType == Enum.ClubType.Character or clubInfo.clubType == Enum.ClubType.BattleNet)
           and self:IsClubEnabled(clubInfo.clubId) then

            local memberIds = C_Club.GetClubMembers(clubInfo.clubId) or {}
            local onlineMembers = {}

            for _, memberId in ipairs(memberIds) do
                local mInfo = C_Club.GetMemberInfo(clubInfo.clubId, memberId)
                if mInfo and IsPresenceOnline(mInfo.presence) then
                    local classFile = ClassFileFromID(mInfo.classID)
                    local memberName = mInfo.name or "Unknown"

                    -- Strip realm suffix for display
                    local displayName = memberName
                    local dash = memberName:find("-")
                    if dash then
                        displayName = memberName:sub(1, dash - 1)
                    end

                    table.insert(onlineMembers, {
                        name        = displayName,
                        fullName    = memberName,
                        level       = mInfo.level or 0,
                        classFile   = classFile,
                        area        = mInfo.zone or "",
                        notes       = mInfo.memberNote or "",
                        afk         = (mInfo.presence == Enum.ClubMemberPresence.Away),
                        dnd         = (mInfo.presence == Enum.ClubMemberPresence.Busy),
                        isMobile    = (mInfo.presence == Enum.ClubMemberPresence.OnlineMobile),
                        isSelf      = mInfo.isSelf,
                        clubId      = clubInfo.clubId,
                        clubName    = clubInfo.name,
                    })
                end
            end

            -- Sort members within each club
            self:SortMembers(onlineMembers)

            totalOnline = totalOnline + #onlineMembers
            clubsData[clubInfo.clubId] = {
                info = clubInfo,
                members = onlineMembers,
            }
        end
    end

    self.clubsCache = clubsData
    self.totalOnline = totalOnline

    dataobj.text = DGF:FormatLabel(db.labelFormat, totalOnline, totalOnline)

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
        local ac = a.classFile or ""
        local bc = b.classFile or ""
        if ac == bc then return a.name < b.name end
        return ac < bc
    end,
    level = function(a, b)
        if a.level == b.level then return a.name < b.name end
        return a.level < b.level
    end,
    zone = function(a, b)
        if a.area == b.area then return a.name < b.name end
        return a.area < b.area
    end,
}

function CommunitiesBroker:SortMembers(members)
    local db = ns.db.communities
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
    local f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
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

    -- Column headers
    f.colName = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.colName:SetPoint("TOPLEFT", f.header, "BOTTOMLEFT", 0, -4)
    f.colName:SetText("|cffaaaaaaName|r")
    f.colName:SetJustifyH("LEFT")

    f.colLevel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.colLevel:SetPoint("LEFT", f.colName, "RIGHT", 4, 0)
    f.colLevel:SetText("|cffaaaaaaLvl|r")
    f.colLevel:SetWidth(30)
    f.colLevel:SetJustifyH("CENTER")

    f.colZone = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.colZone:SetPoint("LEFT", f.colLevel, "RIGHT", 4, 0)
    f.colZone:SetText("|cffaaaaaaZone|r")
    f.colZone:SetJustifyH("LEFT")

    f.colNote = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.colNote:SetPoint("LEFT", f.colZone, "RIGHT", 4, 0)
    f.colNote:SetPoint("RIGHT", f, "RIGHT", -TOOLTIP_PADDING, 0)
    f.colNote:SetText("|cffaaaaaaNotes|r")
    f.colNote:SetJustifyH("LEFT")

    f.hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.hint:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", TOOLTIP_PADDING, TOOLTIP_PADDING)
    f.hint:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -TOOLTIP_PADDING, TOOLTIP_PADDING)
    f.hint:SetJustifyH("LEFT")

    -- Scrollable content area (clip frame + content frame)
    f.clipFrame = CreateFrame("Frame", nil, f)
    f.clipFrame:SetClipsChildren(true)
    f.scrollContent = CreateFrame("Frame", nil, f.clipFrame)
    f.scrollOffset = 0

    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel", function(self, delta)
        local contentH = self.scrollContent:GetHeight() or 0
        local clipH = self.clipFrame:GetHeight() or 0
        local maxScroll = math.max(0, contentH - clipH)
        self.scrollOffset = math.max(0, math.min(maxScroll, self.scrollOffset - delta * (ROW_HEIGHT + 4)))
        self.scrollContent:ClearAllPoints()
        self.scrollContent:SetPoint("TOPLEFT", self.clipFrame, "TOPLEFT", 0, self.scrollOffset)
    end)

    f:SetScript("OnEnter", function()
        CommunitiesBroker:CancelTooltipHideTimer()
    end)
    f:SetScript("OnLeave", function()
        CommunitiesBroker:StartTooltipHideTimer()
    end)

    f:Hide()
    return f
end

local function UpdateTooltipLayout(tooltipWidth)
    if not tooltipFrame then return end

    local innerWidth = tooltipWidth - 2 * TOOLTIP_PADDING
    local nameW = math.floor(innerWidth * 0.30)
    local levelW = 30
    local zoneW = math.floor(innerWidth * 0.28)
    local noteW = innerWidth - nameW - levelW - zoneW - 12
    noteW = math.max(50, noteW)

    tooltipFrame:SetWidth(tooltipWidth)
    tooltipFrame.colName:SetWidth(nameW)
    tooltipFrame.colZone:SetWidth(zoneW)

    for _, row in pairs(rowPool) do
        row:SetWidth(innerWidth)
        row.nameText:SetWidth(nameW)
        row.zoneText:SetWidth(zoneW)
        row.noteText:SetWidth(noteW)
    end

    if tooltipFrame.scrollContent then
        tooltipFrame.scrollContent:SetWidth(innerWidth)
    end
end

local function GetOrCreateRow(parent, index)
    if rowPool[index] then
        rowPool[index]:Show()
        return rowPool[index]
    end

    local row = CreateFrame("Button", nil, parent)
    row:SetSize(360, ROW_HEIGHT)
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

    row.zoneText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.zoneText:SetPoint("LEFT", row.levelText, "RIGHT", 4, 0)
    row.zoneText:SetWidth(130)
    row.zoneText:SetJustifyH("LEFT")

    row.noteText = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.noteText:SetPoint("LEFT", row.zoneText, "RIGHT", 4, 0)
    row.noteText:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    row.noteText:SetJustifyH("LEFT")
    row.noteText:SetWordWrap(false)

    row:SetScript("OnMouseUp", function(self, button)
        CommunitiesBroker:OnRowClick(self, button)
    end)

    row:SetScript("OnEnter", function(self)
        CommunitiesBroker:CancelTooltipHideTimer()
        if self.memberData and self.memberData.notes and self.memberData.notes ~= "" then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(self.memberData.notes, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)

    row:SetScript("OnLeave", function()
        GameTooltip:Hide()
        CommunitiesBroker:StartTooltipHideTimer()
    end)

    rowPool[index] = row
    return row
end

---------------------------------------------------------------------------
-- Tooltip display
---------------------------------------------------------------------------

function CommunitiesBroker:ShowTooltip(anchor)
    if not tooltipFrame then
        tooltipFrame = CreateTooltipFrame()
    end

    self:CancelTooltipHideTimer()
    self:UpdateData()

    tooltipFrame:ClearAllPoints()
    tooltipFrame:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, 4)
    tooltipFrame:SetScale(ns.db.communities.tooltipScale or 1.0)
    UpdateTooltipLayout(ns.db.communities.tooltipWidth or 480)

    self:PopulateTooltip()
    tooltipFrame:Show()
end

function CommunitiesBroker:PopulateTooltip()
    if not tooltipFrame then return end

    local db = ns.db.communities
    local useClassColors = db.classColorNames
    local sc = tooltipFrame.scrollContent

    -- Count enabled clubs
    local clubCount = 0
    for _ in pairs(self.clubsCache) do clubCount = clubCount + 1 end

    tooltipFrame.header:SetText(
        DGF:ColorText("Communities Online: ", 1, 0.82, 0) ..
        DGF:ColorText(tostring(self.totalOnline), 0, 1, 0)
    )

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
    if sc.groupHeaders then
        for _, hdr in pairs(sc.groupHeaders) do
            hdr:Hide()
        end
    end

    local rowSpacing = db.rowSpacing or 4
    local rowStep = ROW_HEIGHT + rowSpacing
    local yOffset = 0
    local rowIdx = 0

    -- Sort clubs alphabetically by name
    local sortedClubs = {}
    for clubId, data in pairs(self.clubsCache) do
        table.insert(sortedClubs, data)
    end
    table.sort(sortedClubs, function(a, b)
        return a.info.name < b.info.name
    end)

    local hasAnyMembers = false

    for _, clubData in ipairs(sortedClubs) do
        local members = clubData.members
        if #members > 0 then
            hasAnyMembers = true

            -- Community header
            yOffset = yOffset - 4
            local hdr = self:GetOrCreateGroupHeader(sc, clubData.info.name)
            hdr:ClearAllPoints()
            hdr:SetPoint("TOPLEFT", sc, "TOPLEFT", 0, yOffset)
            hdr:SetText(DGF:ColorText(clubData.info.name .. " (" .. #members .. ")", 0.4, 0.78, 1))
            hdr:Show()
            yOffset = yOffset - 16

            for _, member in ipairs(members) do
                rowIdx = rowIdx + 1
                local row = GetOrCreateRow(sc, rowIdx)
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", sc, "TOPLEFT", 0, yOffset)
                row.memberData = member

                local status = ""
                if member.afk then
                    status = "|cffffcc00[AFK]|r "
                elseif member.dnd then
                    status = "|cffff0000[DND]|r "
                end

                if useClassColors and member.classFile then
                    row.nameText:SetText(status .. DGF:ClassColorText(member.name, member.classFile))
                else
                    row.nameText:SetText(status .. member.name)
                end

                row.levelText:SetText(member.level > 0 and tostring(member.level) or "")
                row.zoneText:SetText(DGF:ColorText(member.area, 0.63, 0.82, 1))
                row.noteText:SetText(member.notes or "")

                yOffset = yOffset - rowStep
            end
        end
    end

    if not hasAnyMembers then
        rowIdx = rowIdx + 1
        local row = GetOrCreateRow(sc, rowIdx)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", sc, "TOPLEFT", 0, yOffset)
        row.memberData = nil
        row.nameText:SetText("|cff888888No community members online|r")
        row.levelText:SetText("")
        row.zoneText:SetText("")
        row.noteText:SetText("")
        yOffset = yOffset - rowStep
    end

    -- Scroll geometry
    local contentH = math.max(math.abs(yOffset), ROW_HEIGHT)
    local maxH = ns.db.communities.tooltipMaxHeight or 500
    local innerWidth = (ns.db.communities.tooltipWidth or 480) - 2 * TOOLTIP_PADDING
    local scrollAreaH = math.min(contentH, math.max(ROW_HEIGHT, maxH - FIXED_TOP - FIXED_BOTTOM))

    tooltipFrame.clipFrame:ClearAllPoints()
    tooltipFrame.clipFrame:SetPoint("TOPLEFT", tooltipFrame, "TOPLEFT", TOOLTIP_PADDING, -FIXED_TOP)
    tooltipFrame.clipFrame:SetSize(innerWidth, scrollAreaH)
    tooltipFrame.scrollContent:SetSize(innerWidth, contentH)
    tooltipFrame.scrollOffset = 0
    tooltipFrame.scrollContent:ClearAllPoints()
    tooltipFrame.scrollContent:SetPoint("TOPLEFT", tooltipFrame.clipFrame, "TOPLEFT", 0, 0)
    tooltipFrame:SetHeight(FIXED_TOP + scrollAreaH + FIXED_BOTTOM)
end

---------------------------------------------------------------------------
-- Group headers (community names)
---------------------------------------------------------------------------

function CommunitiesBroker:GetOrCreateGroupHeader(parent, name)
    if not parent.groupHeaders then parent.groupHeaders = {} end
    if parent.groupHeaders[name] then return parent.groupHeaders[name] end

    local hdr = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hdr:SetJustifyH("LEFT")
    hdr:SetHeight(14)
    hdr:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
    parent.groupHeaders[name] = hdr
    return hdr
end

---------------------------------------------------------------------------
-- Tooltip hide timer
---------------------------------------------------------------------------

CommunitiesBroker.hideTimer = nil

function CommunitiesBroker:StartTooltipHideTimer()
    self:CancelTooltipHideTimer()
    self.hideTimer = C_Timer.NewTimer(0.15, function()
        if tooltipFrame then tooltipFrame:Hide() end
        self.hideTimer = nil
    end)
end

function CommunitiesBroker:CancelTooltipHideTimer()
    if self.hideTimer then
        self.hideTimer:Cancel()
        self.hideTimer = nil
    end
end

---------------------------------------------------------------------------
-- Click action handling
---------------------------------------------------------------------------

function CommunitiesBroker:OnRowClick(row, button)
    local member = row.memberData
    if not member then return end

    local db = ns.db.communities
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

function CommunitiesBroker:ExecuteAction(action, member)
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

    elseif action == "opencommunities" then
        ToggleCommunitiesFrame()

    elseif action == "openfriends" then
        ToggleFriendsFrame()

    elseif action == "openguild" then
        ToggleGuildFrame()
    end

    if tooltipFrame then tooltipFrame:Hide() end
end
