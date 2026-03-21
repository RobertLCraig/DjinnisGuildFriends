local addonName, ns = ...
local DGF = ns.addon
local LDB = LibStub("LibDataBroker-1.1")

---------------------------------------------------------------------------
-- Module setup
---------------------------------------------------------------------------

local FriendsBroker = DGF:NewModule("FriendsBroker", "AceEvent-3.0")
ns.FriendsBroker = FriendsBroker

-- Friends data cache
FriendsBroker.friendsCache = {}
FriendsBroker.onlineCount = 0
FriendsBroker.totalCount = 0

-- Tooltip frame and row pool
local tooltipFrame = nil
local rowPool = {}
local ROW_HEIGHT = 16
local TOOLTIP_PADDING = 10
local HEADER_HEIGHT = 24

-- Status icons/text
local STATUS_STRINGS = {
    afk = "|cffffcc00[AFK]|r ",
    dnd = "|cffff0000[DND]|r ",
}

-- BNet client constant
local BNET_CLIENT_WOW = "WoW"

-- Build localized class name -> token lookup table
-- The WoW API only returns localized class names (e.g., "Paladin"), not tokens ("PALADIN")
-- We need this map to resolve class colors from localized names
local localizedClassMap = {}
if LOCALIZED_CLASS_NAMES_MALE then
    for token, name in pairs(LOCALIZED_CLASS_NAMES_MALE) do
        if type(name) == "string" and name ~= "" then
            localizedClassMap[name] = token
        end
    end
end
if LOCALIZED_CLASS_NAMES_FEMALE then
    for token, name in pairs(LOCALIZED_CLASS_NAMES_FEMALE) do
        if type(name) == "string" and name ~= "" and not localizedClassMap[name] then
            localizedClassMap[name] = token
        end
    end
end

--- Resolve a class token from whatever fields are available
local function ResolveClassToken(classToken, classID, localizedName)
    -- Direct token field (if present)
    if type(classToken) == "string" and classToken ~= "" then
        local token = classToken:upper()
        if RAID_CLASS_COLORS[token] then return token end
        -- Maybe it's a localized name in the token field
        if localizedClassMap[classToken] then return localizedClassMap[classToken] end
    end

    -- By classID via C_CreatureInfo
    if classID and C_CreatureInfo and C_CreatureInfo.GetClassInfo then
        local info = C_CreatureInfo.GetClassInfo(classID)
        if info and info.classFile and RAID_CLASS_COLORS[info.classFile] then
            return info.classFile
        end
    end

    -- By localized name
    if type(localizedName) == "string" and localizedName ~= "" then
        local token = localizedClassMap[localizedName]
        if token then return token end
    end

    return nil
end

---------------------------------------------------------------------------
-- LDB Data Object
---------------------------------------------------------------------------

local dataobj = LDB:NewDataObject("DGF-Friends", {
    type  = "data source",
    text  = "Friends: 0/0",
    icon  = "Interface\\FriendsFrame\\UI-Toast-FriendOnlineIcon",
    label = "Friends List",
    OnEnter = function(self)
        FriendsBroker:ShowTooltip(self)
    end,
    OnLeave = function(self)
        FriendsBroker:StartTooltipHideTimer()
    end,
    OnClick = function(self, button)
        if button == "LeftButton" and IsShiftKeyDown() then
            -- Toggle friends panel
            ToggleFriendsFrame()
        end
    end,
})

FriendsBroker.dataobj = dataobj

---------------------------------------------------------------------------
-- Module lifecycle
---------------------------------------------------------------------------

function FriendsBroker:OnEnable()
    self:RegisterEvent("FRIENDLIST_UPDATE", "OnFriendsUpdate")
    self:RegisterEvent("BN_FRIEND_INFO_CHANGED", "OnFriendsUpdate")
    self:RegisterEvent("BN_FRIEND_LIST_SIZE_CHANGED", "OnFriendsUpdate")
    self:RegisterEvent("BN_CONNECTED", "OnFriendsUpdate")
    self:RegisterEvent("BN_DISCONNECTED", "OnFriendsUpdate")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnPlayerEnteringWorld")

    -- Register minimap icon
    if ns.icon and dataobj then
        ns.icon:Register("DGF-Friends", dataobj, DGF.db.profile.minimap)
    end
end

function FriendsBroker:OnPlayerEnteringWorld()
    -- Request friends data from server
    C_FriendList.ShowFriends()
    -- Small delay then update, since data may not be immediately available
    C_Timer.After(2, function()
        self:UpdateData()
    end)
end

function FriendsBroker:OnFriendsUpdate()
    self:UpdateData()
end

---------------------------------------------------------------------------
-- Data collection
---------------------------------------------------------------------------

function FriendsBroker:UpdateData()
    local db = DGF.db.profile.friends
    local friends = {}

    -- WoW Character Friends
    if db.showWoWFriends then
        local numFriends = C_FriendList.GetNumFriends()
        for i = 1, numFriends do
            local info = C_FriendList.GetFriendInfoByIndex(i)
            if info then
                local rawToken = info.classTag or info.classFileName or info.classFile or info.classToken
                local localizedName = info.className or info.classLocalized or info.class or ""
                local classToken = ResolveClassToken(rawToken, info.classID, localizedName)

                local entry = {
                    name       = info.name or "Unknown",
                    level      = info.level or 0,
                    classFile  = classToken,
                    className  = localizedName,
                    area       = info.area or "",
                    connected  = info.connected,
                    afk        = info.afk,
                    dnd        = info.dnd,
                    notes      = info.notes or "",
                    isBNet     = false,
                    fullName   = info.name,
                }
                table.insert(friends, entry)
            end
        end
    end

    -- Battle.net Friends
    if db.showBNetFriends then
        local numBNet = BNGetNumFriends()
        for i = 1, numBNet do
            local accountInfo = C_BattleNet.GetFriendAccountInfo(i)
            if accountInfo then
                local gameInfo = accountInfo.gameAccountInfo
                local isWoW = gameInfo and gameInfo.clientProgram == BNET_CLIENT_WOW
                local isOnline = gameInfo and gameInfo.isOnline

                if isWoW and isOnline then
                    -- Check for multiple game accounts
                    local numGameAccounts = C_BattleNet.GetFriendNumGameAccounts(i)
                    if numGameAccounts and numGameAccounts > 1 then
                        for j = 1, numGameAccounts do
                            local gameAccountInfo = C_BattleNet.GetFriendGameAccountInfo(i, j)
                            if gameAccountInfo and gameAccountInfo.clientProgram == BNET_CLIENT_WOW and gameAccountInfo.isOnline then
                                local entry = self:BuildBNetEntry(accountInfo, gameAccountInfo)
                                table.insert(friends, entry)
                            end
                        end
                    else
                        local entry = self:BuildBNetEntry(accountInfo, gameInfo)
                        table.insert(friends, entry)
                    end
                end
            end
        end
    end

    -- Sort
    self:SortFriends(friends)

    -- Update cache
    self.friendsCache = friends

    -- Count online/total
    local wowOnline = C_FriendList.GetNumOnlineFriends() or 0
    local wowTotal = C_FriendList.GetNumFriends() or 0
    local bnTotal, bnOnline = BNGetNumFriends()
    bnTotal = bnTotal or 0
    bnOnline = bnOnline or 0

    self.onlineCount = wowOnline + bnOnline
    self.totalCount = wowTotal + bnTotal

    -- Update LDB text
    dataobj.text = DGF:FormatLabel(db.labelFormat, self.onlineCount, self.totalCount)

    -- Refresh tooltip if visible
    if tooltipFrame and tooltipFrame:IsShown() then
        self:PopulateTooltip()
    end
end

function FriendsBroker:BuildBNetEntry(accountInfo, gameInfo)
    local rawToken = gameInfo.classTag or gameInfo.classFile or gameInfo.classToken
    local className = gameInfo.className or gameInfo.classLocalized or gameInfo.class or ""
    local classToken = ResolveClassToken(rawToken, gameInfo.classID, className)

    -- Build the full character-realm name for actions
    local charName = gameInfo.characterName or ""
    local realmName = gameInfo.realmDisplayName or gameInfo.realmName or ""
    local fullName = ""
    if charName ~= "" and realmName ~= "" then
        fullName = charName .. "-" .. realmName
    elseif charName ~= "" then
        fullName = charName
    end

    return {
        name          = charName ~= "" and charName or accountInfo.accountName or "Unknown",
        level         = gameInfo.characterLevel or 0,
        classFile     = classToken,
        className     = className,
        area          = gameInfo.areaName or "",
        connected     = true,
        afk           = accountInfo.isAFK or (gameInfo.isGameAFK == true) or false,
        dnd           = accountInfo.isDND or (gameInfo.isGameBusy == true) or false,
        notes         = accountInfo.note or "",
        isBNet        = true,
        accountName   = accountInfo.accountName,
        gameAccountID = gameInfo.gameAccountID,
        realmName     = realmName,
        fullName      = fullName,
        battleTag     = accountInfo.battleTag or "",
    }
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
    status = function(a, b)
        local sa = a.afk and 2 or a.dnd and 3 or 1
        local sb = b.afk and 2 or b.dnd and 3 or 1
        if sa == sb then return a.name < b.name end
        return sa < sb
    end,
}

function FriendsBroker:SortFriends(friends)
    local db = DGF.db.profile.friends
    local sortFunc = SORT_FUNCTIONS[db.sortBy] or SORT_FUNCTIONS.name
    local ascending = db.sortAscending

    table.sort(friends, function(a, b)
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
    local f = CreateFrame("Frame", "DGFFriendsTooltip", UIParent, "BackdropTemplate")
    f:SetFrameStrata("TOOLTIP")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetSize(400, 100)

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

    -- Header
    f.header = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.header:SetPoint("TOPLEFT", f, "TOPLEFT", TOOLTIP_PADDING, -TOOLTIP_PADDING)
    f.header:SetPoint("TOPRIGHT", f, "TOPRIGHT", -TOOLTIP_PADDING, -TOOLTIP_PADDING)
    f.header:SetJustifyH("LEFT")
    f.header:SetHeight(HEADER_HEIGHT)

    -- Column headers (widths set dynamically in UpdateTooltipLayout)
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

    -- Hint text at bottom
    f.hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.hint:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", TOOLTIP_PADDING, TOOLTIP_PADDING)
    f.hint:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -TOOLTIP_PADDING, TOOLTIP_PADDING)
    f.hint:SetJustifyH("LEFT")

    -- Mouse enter/leave for tooltip persistence
    f:SetScript("OnEnter", function()
        FriendsBroker:CancelTooltipHideTimer()
    end)
    f:SetScript("OnLeave", function()
        FriendsBroker:StartTooltipHideTimer()
    end)

    f:Hide()
    return f
end

--- Update tooltip and row widths based on configured width
local function UpdateTooltipLayout(tooltipWidth)
    if not tooltipFrame then return end

    local innerWidth = tooltipWidth - 2 * TOOLTIP_PADDING
    -- Column proportions: Name 30%, Lvl fixed 30px, Zone 28%, Notes remainder
    local nameW = math.floor(innerWidth * 0.30)
    local levelW = 30
    local zoneW = math.floor(innerWidth * 0.28)
    local noteW = innerWidth - nameW - levelW - zoneW - 12 -- 12 = 3 gaps of 4px

    tooltipFrame:SetWidth(tooltipWidth)
    tooltipFrame.colName:SetWidth(nameW)
    tooltipFrame.colZone:SetWidth(zoneW)

    -- Update all existing rows
    for _, row in pairs(rowPool) do
        row:SetWidth(innerWidth)
        row.nameText:SetWidth(nameW)
        row.zoneText:SetWidth(zoneW)
        row.noteText:SetWidth(noteW)
    end

    return nameW, levelW, zoneW, noteW
end

local function GetOrCreateRow(parent, index)
    if rowPool[index] then
        rowPool[index]:Show()
        return rowPool[index]
    end

    local row = CreateFrame("Button", nil, parent)
    row:SetSize(360, ROW_HEIGHT) -- width updated by UpdateTooltipLayout
    row:EnableMouse(true)
    row:RegisterForClicks("AnyUp")

    -- Highlight texture
    row.highlight = row:CreateTexture(nil, "HIGHLIGHT")
    row.highlight:SetAllPoints()
    row.highlight:SetColorTexture(1, 1, 1, 0.1)

    -- Status + Name
    row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.nameText:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.nameText:SetWidth(130)
    row.nameText:SetJustifyH("LEFT")

    -- Level
    row.levelText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.levelText:SetPoint("LEFT", row.nameText, "RIGHT", 4, 0)
    row.levelText:SetWidth(30)
    row.levelText:SetJustifyH("CENTER")

    -- Zone
    row.zoneText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.zoneText:SetPoint("LEFT", row.levelText, "RIGHT", 4, 0)
    row.zoneText:SetWidth(130)
    row.zoneText:SetJustifyH("LEFT")

    -- Note
    row.noteText = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.noteText:SetPoint("LEFT", row.zoneText, "RIGHT", 4, 0)
    row.noteText:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    row.noteText:SetJustifyH("LEFT")
    row.noteText:SetWordWrap(false)

    -- Use OnMouseUp instead of OnClick for more reliable click handling
    -- OnClick on Button frames can have issues in TOOLTIP strata
    row:SetScript("OnMouseUp", function(self, button)
        FriendsBroker:OnRowClick(self, button)
    end)

    row:SetScript("OnEnter", function(self)
        FriendsBroker:CancelTooltipHideTimer()
        -- Show full note in a GameTooltip on hover
        if self.friendData and self.friendData.notes and self.friendData.notes ~= "" then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(self.friendData.notes, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)

    row:SetScript("OnLeave", function()
        GameTooltip:Hide()
        FriendsBroker:StartTooltipHideTimer()
    end)

    rowPool[index] = row
    return row
end

---------------------------------------------------------------------------
-- Tooltip display
---------------------------------------------------------------------------

function FriendsBroker:ShowTooltip(anchor)
    if not tooltipFrame then
        tooltipFrame = CreateTooltipFrame()
    end

    self:CancelTooltipHideTimer()

    -- Update data first
    self:UpdateData()

    -- Anchor
    tooltipFrame:ClearAllPoints()
    tooltipFrame:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -4)

    -- Scale
    local scale = DGF.db.profile.friends.tooltipScale or 1.0
    tooltipFrame:SetScale(scale)

    -- Apply configurable width
    local tooltipWidth = DGF.db.profile.friends.tooltipWidth or 420
    UpdateTooltipLayout(tooltipWidth)

    self:PopulateTooltip()
    tooltipFrame:Show()
end

function FriendsBroker:PopulateTooltip()
    if not tooltipFrame then return end

    local friends = self.friendsCache
    local db = DGF.db.profile.friends
    local useClassColors = db.classColorNames

    -- Header
    tooltipFrame.header:SetText(
        DGF:ColorText("Friends Online: ", 1, 0.82, 0) ..
        DGF:ColorText(tostring(self.onlineCount), 0, 1, 0) ..
        DGF:ColorText(" / " .. tostring(self.totalCount), 0.63, 0.63, 0.63)
    )

    -- Build hint text from click action config
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

    -- Hide all existing rows and group headers
    for _, row in pairs(rowPool) do
        row:Hide()
    end
    if tooltipFrame.groupHeaders then
        for _, hdr in pairs(tooltipFrame.groupHeaders) do
            hdr:Hide()
        end
    end

    -- Populate rows with online friends only
    local onlineFriends = {}
    for _, f in ipairs(friends) do
        if f.connected then
            table.insert(onlineFriends, f)
        end
    end

    local rowSpacing = db.rowSpacing or 4
    local rowStep = ROW_HEIGHT + rowSpacing
    local groupBy = db.groupBy or "none"

    -- Build groups
    local groups, groupOrder = self:BuildGroups(onlineFriends, groupBy)

    local yOffset = -(TOOLTIP_PADDING + HEADER_HEIGHT + 20) -- after header + column headers
    local rowIdx = 0

    local function RenderFriend(friend)
        rowIdx = rowIdx + 1
        local row = GetOrCreateRow(tooltipFrame, rowIdx)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", tooltipFrame, "TOPLEFT", TOOLTIP_PADDING, yOffset)
        row.friendData = friend

        -- Status prefix
        local status = ""
        if friend.afk then
            status = STATUS_STRINGS.afk
        elseif friend.dnd then
            status = STATUS_STRINGS.dnd
        end

        -- Build display name
        local displayName = friend.name
        if friend.isBNet and friend.accountName then
            displayName = displayName .. " |cff82c5ff(" .. friend.accountName .. ")|r"
        end

        -- Apply class coloring if enabled
        if useClassColors and friend.classFile then
            row.nameText:SetText(status .. DGF:ClassColorText(displayName, friend.classFile))
        else
            row.nameText:SetText(status .. displayName)
        end

        row.levelText:SetText(friend.level > 0 and tostring(friend.level) or "")
        row.zoneText:SetText(DGF:ColorText(friend.area, 0.63, 0.82, 1))

        -- Show note text (no hard truncation — FontString handles overflow via width)
        row.noteText:SetText(friend.notes or "")

        yOffset = yOffset - rowStep
    end

    if groupBy == "none" then
        for _, friend in ipairs(onlineFriends) do
            RenderFriend(friend)
        end
    else
        for _, groupName in ipairs(groupOrder) do
            local groupMembers = groups[groupName]
            if groupMembers and #groupMembers > 0 then
                -- Group header
                yOffset = yOffset - 4
                local hdr = self:GetOrCreateGroupHeader(tooltipFrame, groupName)
                hdr:ClearAllPoints()
                hdr:SetPoint("TOPLEFT", tooltipFrame, "TOPLEFT", TOOLTIP_PADDING, yOffset)
                hdr:SetText(DGF:ColorText(groupName .. " (" .. #groupMembers .. ")", 1, 0.82, 0))
                hdr:Show()
                yOffset = yOffset - 16

                -- Check collapsed state
                if not db.groupCollapsed[groupName] then
                    for _, friend in ipairs(groupMembers) do
                        RenderFriend(friend)
                    end
                end
            end
        end
    end

    -- Empty state
    if #onlineFriends == 0 then
        rowIdx = rowIdx + 1
        local row = GetOrCreateRow(tooltipFrame, rowIdx)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", tooltipFrame, "TOPLEFT", TOOLTIP_PADDING, yOffset)
        row.friendData = nil
        row.nameText:SetText("|cff888888No friends online|r")
        row.levelText:SetText("")
        row.zoneText:SetText("")
        row.noteText:SetText("")
        yOffset = yOffset - rowStep
    end

    -- Size the tooltip
    local totalHeight = math.abs(yOffset) + TOOLTIP_PADDING + 20 -- bottom padding + hint
    tooltipFrame:SetHeight(totalHeight)
end

---------------------------------------------------------------------------
-- Grouping
---------------------------------------------------------------------------

function FriendsBroker:GetOrCreateGroupHeader(parent, name)
    if not parent.groupHeaders then parent.groupHeaders = {} end
    if parent.groupHeaders[name] then return parent.groupHeaders[name] end

    local hdr = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hdr:SetJustifyH("LEFT")
    hdr:SetHeight(14)
    hdr:SetPoint("RIGHT", parent, "RIGHT", -TOOLTIP_PADDING, 0)
    parent.groupHeaders[name] = hdr
    return hdr
end

function FriendsBroker:BuildGroups(friends, groupBy)
    if groupBy == "none" then return {}, {} end

    local groups = {}
    local groupSet = {}
    local playerZone = GetRealZoneText() or ""

    for _, friend in ipairs(friends) do
        local groupNames = {}

        if groupBy == "type" then
            if friend.isBNet then
                table.insert(groupNames, "Battle.net Friends")
            else
                table.insert(groupNames, "Character Friends")
            end
        elseif groupBy == "zone" then
            if friend.area == playerZone and playerZone ~= "" then
                table.insert(groupNames, "Same Zone: " .. playerZone)
            else
                table.insert(groupNames, friend.area ~= "" and friend.area or "Unknown")
            end
        elseif groupBy == "note" then
            local tags = DGF:ParseNoteGroups(friend.notes)
            if #tags > 0 then
                for _, tag in ipairs(tags) do
                    table.insert(groupNames, tag)
                end
            else
                table.insert(groupNames, "Ungrouped")
            end
        else
            table.insert(groupNames, "Other")
        end

        for _, gn in ipairs(groupNames) do
            if not groups[gn] then
                groups[gn] = {}
                groupSet[gn] = true
            end
            table.insert(groups[gn], friend)
        end
    end

    -- Build sorted order
    local order = {}
    for name in pairs(groupSet) do
        table.insert(order, name)
    end

    if groupBy == "type" then
        -- BNet first, then character
        table.sort(order, function(a, b)
            if a == "Battle.net Friends" then return true end
            if b == "Battle.net Friends" then return false end
            return a < b
        end)
    elseif groupBy == "zone" then
        -- Same zone first
        table.sort(order, function(a, b)
            local aIsLocal = a:find("^Same Zone")
            local bIsLocal = b:find("^Same Zone")
            if aIsLocal and not bIsLocal then return true end
            if bIsLocal and not aIsLocal then return false end
            return a < b
        end)
    elseif groupBy == "note" then
        -- Ungrouped last, rest alphabetical
        table.sort(order, function(a, b)
            if a == "Ungrouped" then return false end
            if b == "Ungrouped" then return true end
            return a < b
        end)
    else
        table.sort(order)
    end

    return groups, order
end

---------------------------------------------------------------------------
-- Tooltip hide timer (persistence when moving mouse between button/tooltip)
---------------------------------------------------------------------------

FriendsBroker.hideTimer = nil

function FriendsBroker:StartTooltipHideTimer()
    self:CancelTooltipHideTimer()
    self.hideTimer = C_Timer.NewTimer(0.15, function()
        if tooltipFrame then
            tooltipFrame:Hide()
        end
        self.hideTimer = nil
    end)
end

function FriendsBroker:CancelTooltipHideTimer()
    if self.hideTimer then
        self.hideTimer:Cancel()
        self.hideTimer = nil
    end
end

---------------------------------------------------------------------------
-- Click action handling
---------------------------------------------------------------------------

function FriendsBroker:OnRowClick(row, button)
    local friend = row.friendData
    if not friend then return end

    local db = DGF.db.profile.friends
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
        self:ExecuteAction(action, friend)
    end
end

function FriendsBroker:ExecuteAction(action, friend)
    self:CancelTooltipHideTimer()

    if action == "whisper" then
        -- Hide tooltip first so it doesn't compete for focus
        if tooltipFrame then tooltipFrame:Hide() end

        if friend.isBNet then
            -- BNet whisper: use ChatFrameUtil.SendBNetTell (the modern API)
            -- ChatFrame_SendBNetTell is deprecated and may not exist
            local tellName = friend.accountName
            if not tellName or tellName == "" then
                tellName = friend.battleTag and friend.battleTag:match("^([^#]+)") or friend.name
            end
            if ChatFrameUtil and ChatFrameUtil.SendBNetTell then
                ChatFrameUtil.SendBNetTell(tellName)
            elseif ChatFrame_SendBNetTell then
                ChatFrame_SendBNetTell(tellName)
            else
                -- Last resort: manually open chat with /w
                ChatFrameUtil.OpenChat("/w " .. tellName .. " ")
            end
        else
            -- WoW character whisper: use ChatFrameUtil.SendTell (the modern API)
            local name = friend.fullName or friend.name
            if name and name ~= "" then
                if ChatFrameUtil and ChatFrameUtil.SendTell then
                    ChatFrameUtil.SendTell(name)
                elseif ChatFrame_SendTell then
                    ChatFrame_SendTell(name)
                else
                    ChatFrameUtil.OpenChat("/w " .. name .. " ")
                end
            end
        end
        return

    elseif action == "invite" then
        if friend.isBNet and friend.gameAccountID then
            BNInviteFriend(friend.gameAccountID)
        else
            local name = friend.fullName or friend.name
            if name and name ~= "" then
                C_PartyInfo.InviteUnit(name)
            end
        end

    elseif action == "who" then
        local query = friend.fullName or friend.name
        if friend.isBNet and friend.realmName and friend.realmName ~= "" and friend.name then
            query = friend.name .. "-" .. friend.realmName
        end
        C_FriendList.SendWho(query)

    elseif action == "copyname" then
        -- Insert "Name-Realm" into the active chat editbox
        local name = friend.name
        local realm = friend.realmName or ""
        if not friend.isBNet and friend.fullName and friend.fullName ~= "" then
            name = friend.fullName
        elseif realm ~= "" then
            name = name .. "-" .. realm
        end
        -- Open chat if not already open, then insert
        if not ChatFrame1EditBox:IsShown() then
            ChatFrameUtil.OpenChat("")
        end
        ChatFrame1EditBox:Insert(name)

    elseif action == "openfriends" then
        ToggleFriendsFrame()

    elseif action == "openguild" then
        ToggleGuildFrame()
    end

    -- Hide tooltip after action (except whisper which hides before and returns)
    if tooltipFrame then tooltipFrame:Hide() end
end
