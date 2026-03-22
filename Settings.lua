local addonName, ns = ...
local DGF = ns.addon

---------------------------------------------------------------------------
-- Widget helpers
---------------------------------------------------------------------------

local dropdownCount = 0

local function AddHeader(content, y, text)
    y = y - 8
    local header = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", content, "TOPLEFT", 10, y)
    header:SetText(text)

    local line = content:CreateTexture(nil, "ARTWORK")
    line:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
    line:SetPoint("RIGHT", content, "RIGHT", -10, 0)
    line:SetHeight(1)
    line:SetColorTexture(0.5, 0.5, 0.5, 0.5)

    return y - 22
end

local function AddCheckbox(content, y, label, getter, setter, refreshList)
    local cb = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", content, "TOPLEFT", 14, y)

    local text = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    text:SetText(label)

    cb:SetChecked(getter())
    cb:SetScript("OnClick", function(self)
        setter(self:GetChecked())
    end)

    if refreshList then
        table.insert(refreshList, function() cb:SetChecked(getter()) end)
    end
    return y - 26
end

local function AddSlider(content, y, label, min, max, step, getter, setter, refreshList)
    local text = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("TOPLEFT", content, "TOPLEFT", 18, y)
    text:SetText(label)

    local slider = CreateFrame("Slider", nil, content, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -6)
    slider:SetMinMaxValues(min, max)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    slider:SetWidth(180)
    slider:SetValue(getter())
    slider.Low:SetText("")
    slider.High:SetText("")

    local function FormatVal(v)
        if step < 1 then
            return string.format("%.2f", v)
        else
            return tostring(math.floor(v + 0.5))
        end
    end

    local input = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
    input:SetPoint("LEFT", slider, "RIGHT", 8, 0)
    input:SetSize(54, 20)
    input:SetAutoFocus(false)
    input:SetText(FormatVal(getter()))

    slider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value / step + 0.5) * step
        setter(value)
        input:SetText(FormatVal(value))
    end)

    input:SetScript("OnEnterPressed", function(self)
        local val = tonumber(self:GetText())
        if val then
            val = math.max(min, math.min(max, val))
            val = math.floor(val / step + 0.5) * step
            setter(val)
            slider:SetValue(val)
            self:SetText(FormatVal(val))
        else
            self:SetText(FormatVal(getter()))
        end
        self:ClearFocus()
    end)

    input:SetScript("OnEscapePressed", function(self)
        self:SetText(FormatVal(getter()))
        self:ClearFocus()
    end)

    if refreshList then
        table.insert(refreshList, function()
            slider:SetValue(getter())
            input:SetText(FormatVal(getter()))
        end)
    end
    return y - 48
end

local function AddDropdown(content, y, label, values, getter, setter, refreshList)
    dropdownCount = dropdownCount + 1
    local ddName = "DGFDropdown" .. dropdownCount

    local text = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("TOPLEFT", content, "TOPLEFT", 18, y)
    text:SetText(label)

    local dropdown = CreateFrame("Frame", ddName, content, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", text, "BOTTOMLEFT", -16, -2)
    UIDropDownMenu_SetWidth(dropdown, 180)

    UIDropDownMenu_Initialize(dropdown, function()
        local sorted = {}
        for value, displayText in pairs(values) do
            table.insert(sorted, { value = value, text = displayText })
        end
        table.sort(sorted, function(a, b) return a.text < b.text end)

        for _, item in ipairs(sorted) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = item.text
            info.value = item.value
            info.func = function(self)
                setter(self.value)
                UIDropDownMenu_SetText(dropdown, values[getter()] or "")
            end
            info.checked = (item.value == getter())
            UIDropDownMenu_AddButton(info)
        end
    end)
    UIDropDownMenu_SetText(dropdown, values[getter()] or "")

    if refreshList then
        table.insert(refreshList, function()
            UIDropDownMenu_SetText(dropdown, values[getter()] or "")
        end)
    end
    return y - 54
end

local function AddEditBox(content, y, label, getter, setter, refreshList)
    local text = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("TOPLEFT", content, "TOPLEFT", 18, y)
    text:SetText(label)

    local editbox = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
    editbox:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 4, -4)
    editbox:SetSize(280, 20)
    editbox:SetAutoFocus(false)
    editbox:SetText(getter())
    editbox:SetScript("OnEnterPressed", function(self)
        setter(self:GetText())
        self:ClearFocus()
    end)
    editbox:SetScript("OnEscapePressed", function(self)
        self:SetText(getter())
        self:ClearFocus()
    end)

    if refreshList then
        table.insert(refreshList, function() editbox:SetText(getter()) end)
    end
    return y - 44
end

local function AddButton(content, y, label, onClick)
    local btn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    btn:SetPoint("TOPLEFT", content, "TOPLEFT", 18, y)
    btn:SetSize(160, 24)
    btn:SetText(label)
    btn:SetScript("OnClick", onClick)
    return y - 30
end

local function AddDescription(content, y, text)
    local desc = content:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    desc:SetPoint("TOPLEFT", content, "TOPLEFT", 18, y)
    desc:SetPoint("RIGHT", content, "RIGHT", -18, 0)
    desc:SetJustifyH("LEFT")
    desc:SetWordWrap(true)
    desc:SetText(text)
    local h = desc:GetStringHeight() or 14
    return y - h - 8
end

---------------------------------------------------------------------------
-- Panel builder
---------------------------------------------------------------------------

local function CreateScrollPanel()
    local panel = CreateFrame("Frame")

    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, -5)
    scroll:SetPoint("BOTTOMRIGHT", -24, 5)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetWidth(560)
    scroll:SetScrollChild(content)

    panel.scroll = scroll
    panel.content = content
    panel.refreshCallbacks = {}

    panel:SetScript("OnSizeChanged", function(self, w)
        content:SetWidth(math.max(w - 30, 400))
    end)

    panel:SetScript("OnShow", function(self)
        for _, cb in ipairs(self.refreshCallbacks) do
            cb()
        end
    end)

    return panel
end

---------------------------------------------------------------------------
-- General panel
---------------------------------------------------------------------------

local function BuildGeneralPanel(panel)
    local c = panel.content
    local r = panel.refreshCallbacks
    local y = -10

    y = AddHeader(c, y, "Friends Tooltip")
    y = AddEditBox(c, y, "Panel Text  (tokens: <online> <total> <offline>)",
        function() return ns.db.friends.labelFormat end,
        function(v) ns.db.friends.labelFormat = v; if ns.FriendsBroker then ns.FriendsBroker:UpdateData() end end, r)
    y = AddSlider(c, y, "Scale", 0.5, 2.0, 0.05,
        function() return ns.db.friends.tooltipScale end,
        function(v) ns.db.friends.tooltipScale = v end, r)
    y = AddSlider(c, y, "Width", 300, 800, 10,
        function() return ns.db.friends.tooltipWidth end,
        function(v) ns.db.friends.tooltipWidth = v end, r)
    y = AddSlider(c, y, "Row Spacing", 0, 16, 1,
        function() return ns.db.friends.rowSpacing end,
        function(v) ns.db.friends.rowSpacing = v end, r)
    y = AddSlider(c, y, "Max Height", 100, 1000, 10,
        function() return ns.db.friends.tooltipMaxHeight end,
        function(v) ns.db.friends.tooltipMaxHeight = v end, r)
    y = AddButton(c, y, "Copy from Guild", function()
        DGF:CopyDisplaySettings("guild", "friends")
        if ns.FriendsBroker then ns.FriendsBroker:UpdateData() end
        for _, cb in ipairs(r) do cb() end
    end)

    y = AddHeader(c, y, "Guild Tooltip")
    y = AddEditBox(c, y, "Panel Text  (tokens: <online> <total> <offline> <guildname>)",
        function() return ns.db.guild.labelFormat end,
        function(v) ns.db.guild.labelFormat = v; if ns.GuildBroker then ns.GuildBroker:UpdateData() end end, r)
    y = AddSlider(c, y, "Scale", 0.5, 2.0, 0.05,
        function() return ns.db.guild.tooltipScale end,
        function(v) ns.db.guild.tooltipScale = v end, r)
    y = AddSlider(c, y, "Width", 300, 800, 10,
        function() return ns.db.guild.tooltipWidth end,
        function(v) ns.db.guild.tooltipWidth = v end, r)
    y = AddSlider(c, y, "Row Spacing", 0, 16, 1,
        function() return ns.db.guild.rowSpacing end,
        function(v) ns.db.guild.rowSpacing = v end, r)
    y = AddSlider(c, y, "Max Height", 100, 1000, 10,
        function() return ns.db.guild.tooltipMaxHeight end,
        function(v) ns.db.guild.tooltipMaxHeight = v end, r)
    y = AddButton(c, y, "Copy from Friends", function()
        DGF:CopyDisplaySettings("friends", "guild")
        if ns.GuildBroker then ns.GuildBroker:UpdateData() end
        for _, cb in ipairs(r) do cb() end
    end)

    y = AddHeader(c, y, "Communities Tooltip")
    y = AddEditBox(c, y, "Panel Text  (tokens: <online>)",
        function() return ns.db.communities.labelFormat end,
        function(v) ns.db.communities.labelFormat = v; if ns.CommunitiesBroker then ns.CommunitiesBroker:UpdateData() end end, r)
    y = AddSlider(c, y, "Scale", 0.5, 2.0, 0.05,
        function() return ns.db.communities.tooltipScale end,
        function(v) ns.db.communities.tooltipScale = v end, r)
    y = AddSlider(c, y, "Width", 300, 800, 10,
        function() return ns.db.communities.tooltipWidth end,
        function(v) ns.db.communities.tooltipWidth = v end, r)
    y = AddSlider(c, y, "Row Spacing", 0, 16, 1,
        function() return ns.db.communities.rowSpacing end,
        function(v) ns.db.communities.rowSpacing = v end, r)
    y = AddSlider(c, y, "Max Height", 100, 1000, 10,
        function() return ns.db.communities.tooltipMaxHeight end,
        function(v) ns.db.communities.tooltipMaxHeight = v end, r)

    c:SetHeight(math.abs(y) + 20)
end

---------------------------------------------------------------------------
-- Friends panel
---------------------------------------------------------------------------

local function BuildFriendsPanel(panel)
    local c = panel.content
    local r = panel.refreshCallbacks
    local y = -10

    y = AddHeader(c, y, "Display Filters")
    y = AddCheckbox(c, y, "Show Character Friends",
        function() return ns.db.friends.showWoWFriends end,
        function(v) ns.db.friends.showWoWFriends = v; if ns.FriendsBroker then ns.FriendsBroker:UpdateData() end end, r)
    y = AddCheckbox(c, y, "Show Battle.net Friends",
        function() return ns.db.friends.showBNetFriends end,
        function(v) ns.db.friends.showBNetFriends = v; if ns.FriendsBroker then ns.FriendsBroker:UpdateData() end end, r)
    y = AddCheckbox(c, y, "Class-Colored Names",
        function() return ns.db.friends.classColorNames end,
        function(v) ns.db.friends.classColorNames = v; if ns.FriendsBroker then ns.FriendsBroker:UpdateData() end end, r)

    y = AddHeader(c, y, "Grouping")
    y = AddDropdown(c, y, "Group By", ns.FRIENDS_GROUP_VALUES,
        function() return ns.db.friends.groupBy end,
        function(v) ns.db.friends.groupBy = v; if ns.FriendsBroker then ns.FriendsBroker:UpdateData() end end, r)

    y = AddHeader(c, y, "Sorting")
    y = AddDropdown(c, y, "Sort By", { name = "Name", class = "Class", level = "Level", zone = "Zone", status = "Status" },
        function() return ns.db.friends.sortBy end,
        function(v) ns.db.friends.sortBy = v; if ns.FriendsBroker then ns.FriendsBroker:UpdateData() end end, r)
    y = AddCheckbox(c, y, "Ascending Order",
        function() return ns.db.friends.sortAscending end,
        function(v) ns.db.friends.sortAscending = v; if ns.FriendsBroker then ns.FriendsBroker:UpdateData() end end, r)

    y = AddHeader(c, y, "Click Actions")
    y = AddDescription(c, y, "Configure what happens when you click on a friend in the tooltip.")
    y = AddDropdown(c, y, "Left Click", ns.ACTION_VALUES,
        function() return ns.db.friends.clickActions.leftClick end,
        function(v) ns.db.friends.clickActions.leftClick = v end, r)
    y = AddDropdown(c, y, "Right Click", ns.ACTION_VALUES,
        function() return ns.db.friends.clickActions.rightClick end,
        function(v) ns.db.friends.clickActions.rightClick = v end, r)
    y = AddDropdown(c, y, "Shift + Left Click", ns.ACTION_VALUES,
        function() return ns.db.friends.clickActions.shiftLeftClick end,
        function(v) ns.db.friends.clickActions.shiftLeftClick = v end, r)
    y = AddDropdown(c, y, "Shift + Right Click", ns.ACTION_VALUES,
        function() return ns.db.friends.clickActions.shiftRightClick end,
        function(v) ns.db.friends.clickActions.shiftRightClick = v end, r)
    y = AddDropdown(c, y, "Middle Click", ns.ACTION_VALUES,
        function() return ns.db.friends.clickActions.middleClick end,
        function(v) ns.db.friends.clickActions.middleClick = v end, r)

    c:SetHeight(math.abs(y) + 20)
end

---------------------------------------------------------------------------
-- Guild panel
---------------------------------------------------------------------------

local function BuildGuildPanel(panel)
    local c = panel.content
    local r = panel.refreshCallbacks
    local y = -10

    y = AddHeader(c, y, "Display Options")
    y = AddCheckbox(c, y, "Class-Colored Names",
        function() return ns.db.guild.classColorNames end,
        function(v) ns.db.guild.classColorNames = v; if ns.GuildBroker then ns.GuildBroker:UpdateData() end end, r)

    y = AddHeader(c, y, "Grouping")
    y = AddDropdown(c, y, "Group By", ns.GUILD_GROUP_VALUES,
        function() return ns.db.guild.groupBy end,
        function(v) ns.db.guild.groupBy = v; if ns.GuildBroker then ns.GuildBroker:UpdateData() end end, r)

    y = AddHeader(c, y, "Sorting")
    y = AddDropdown(c, y, "Sort By", { name = "Name", class = "Class", level = "Level", zone = "Zone", rank = "Rank", status = "Status" },
        function() return ns.db.guild.sortBy end,
        function(v) ns.db.guild.sortBy = v; if ns.GuildBroker then ns.GuildBroker:UpdateData() end end, r)
    y = AddCheckbox(c, y, "Ascending Order",
        function() return ns.db.guild.sortAscending end,
        function(v) ns.db.guild.sortAscending = v; if ns.GuildBroker then ns.GuildBroker:UpdateData() end end, r)

    y = AddHeader(c, y, "Click Actions")
    y = AddDescription(c, y, "Configure what happens when you click on a guild member in the tooltip.")
    y = AddDropdown(c, y, "Left Click", ns.ACTION_VALUES,
        function() return ns.db.guild.clickActions.leftClick end,
        function(v) ns.db.guild.clickActions.leftClick = v end, r)
    y = AddDropdown(c, y, "Right Click", ns.ACTION_VALUES,
        function() return ns.db.guild.clickActions.rightClick end,
        function(v) ns.db.guild.clickActions.rightClick = v end, r)
    y = AddDropdown(c, y, "Shift + Left Click", ns.ACTION_VALUES,
        function() return ns.db.guild.clickActions.shiftLeftClick end,
        function(v) ns.db.guild.clickActions.shiftLeftClick = v end, r)
    y = AddDropdown(c, y, "Shift + Right Click", ns.ACTION_VALUES,
        function() return ns.db.guild.clickActions.shiftRightClick end,
        function(v) ns.db.guild.clickActions.shiftRightClick = v end, r)
    y = AddDropdown(c, y, "Middle Click", ns.ACTION_VALUES,
        function() return ns.db.guild.clickActions.middleClick end,
        function(v) ns.db.guild.clickActions.middleClick = v end, r)

    c:SetHeight(math.abs(y) + 20)
end

---------------------------------------------------------------------------
-- Communities panel
---------------------------------------------------------------------------

local function BuildCommunitiesPanel(panel)
    local c = panel.content
    local r = panel.refreshCallbacks
    local y = -10

    y = AddHeader(c, y, "Enabled Communities")
    y = AddDescription(c, y, "Uncheck a community to hide it from the tooltip. New communities are shown by default.")

    -- Dynamic community checkboxes — rebuilt on each OnShow
    local dynamicStart = y
    local dynamicWidgets = {}

    local function RebuildClubList()
        -- Remove old dynamic widgets
        for _, widget in ipairs(dynamicWidgets) do
            widget:Hide()
            widget:SetParent(nil)
        end
        wipe(dynamicWidgets)

        local dy = dynamicStart
        local clubs = C_Club.GetSubscribedClubs() or {}

        local communityClubs = {}
        for _, clubInfo in ipairs(clubs) do
            if clubInfo.clubType == Enum.ClubType.Character or clubInfo.clubType == Enum.ClubType.BattleNet then
                table.insert(communityClubs, clubInfo)
            end
        end
        table.sort(communityClubs, function(a, b) return a.name < b.name end)

        if #communityClubs == 0 then
            local noClubs = c:CreateFontString(nil, "OVERLAY", "GameFontDisable")
            noClubs:SetPoint("TOPLEFT", c, "TOPLEFT", 18, dy)
            noClubs:SetText("No communities found.")
            table.insert(dynamicWidgets, noClubs)
            dy = dy - 20
        else
            for _, clubInfo in ipairs(communityClubs) do
                local cb = CreateFrame("CheckButton", nil, c, "UICheckButtonTemplate")
                cb:SetPoint("TOPLEFT", c, "TOPLEFT", 14, dy)

                local text = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                text:SetPoint("LEFT", cb, "RIGHT", 2, 0)
                text:SetText(clubInfo.name)

                local clubId = clubInfo.clubId
                cb:SetChecked(not ns.db.communities.disabledClubs[clubId])
                cb:SetScript("OnClick", function(self)
                    if self:GetChecked() then
                        ns.db.communities.disabledClubs[clubId] = nil
                    else
                        ns.db.communities.disabledClubs[clubId] = true
                    end
                    if ns.CommunitiesBroker then ns.CommunitiesBroker:UpdateData() end
                end)

                table.insert(dynamicWidgets, cb)
                table.insert(dynamicWidgets, text)
                dy = dy - 26
            end
        end

        -- Continue with static controls after dynamic list
        return dy
    end

    -- Build once now (will be rebuilt on show)
    y = RebuildClubList()

    -- Store rebuild function for OnShow
    local staticY = y -- snapshot after initial build
    panel:HookScript("OnShow", function()
        RebuildClubList()
    end)

    y = AddHeader(c, y, "Display Options")
    y = AddCheckbox(c, y, "Class-Colored Names",
        function() return ns.db.communities.classColorNames end,
        function(v) ns.db.communities.classColorNames = v; if ns.CommunitiesBroker then ns.CommunitiesBroker:UpdateData() end end, r)

    y = AddHeader(c, y, "Sorting")
    y = AddDropdown(c, y, "Sort By", { name = "Name", class = "Class", level = "Level", zone = "Zone" },
        function() return ns.db.communities.sortBy end,
        function(v) ns.db.communities.sortBy = v; if ns.CommunitiesBroker then ns.CommunitiesBroker:UpdateData() end end, r)
    y = AddCheckbox(c, y, "Ascending Order",
        function() return ns.db.communities.sortAscending end,
        function(v) ns.db.communities.sortAscending = v; if ns.CommunitiesBroker then ns.CommunitiesBroker:UpdateData() end end, r)

    y = AddHeader(c, y, "Click Actions")
    y = AddDescription(c, y, "Configure what happens when you click on a community member in the tooltip.")
    y = AddDropdown(c, y, "Left Click", ns.ACTION_VALUES,
        function() return ns.db.communities.clickActions.leftClick end,
        function(v) ns.db.communities.clickActions.leftClick = v end, r)
    y = AddDropdown(c, y, "Right Click", ns.ACTION_VALUES,
        function() return ns.db.communities.clickActions.rightClick end,
        function(v) ns.db.communities.clickActions.rightClick = v end, r)
    y = AddDropdown(c, y, "Shift + Left Click", ns.ACTION_VALUES,
        function() return ns.db.communities.clickActions.shiftLeftClick end,
        function(v) ns.db.communities.clickActions.shiftLeftClick = v end, r)
    y = AddDropdown(c, y, "Shift + Right Click", ns.ACTION_VALUES,
        function() return ns.db.communities.clickActions.shiftRightClick end,
        function(v) ns.db.communities.clickActions.shiftRightClick = v end, r)
    y = AddDropdown(c, y, "Middle Click", ns.ACTION_VALUES,
        function() return ns.db.communities.clickActions.middleClick end,
        function(v) ns.db.communities.clickActions.middleClick = v end, r)

    c:SetHeight(math.abs(y) + 20)
end

---------------------------------------------------------------------------
-- Registration
---------------------------------------------------------------------------

function DGF:SetupOptions()
    local generalPanel = CreateScrollPanel()
    BuildGeneralPanel(generalPanel)

    local friendsPanel = CreateScrollPanel()
    BuildFriendsPanel(friendsPanel)

    local guildPanel = CreateScrollPanel()
    BuildGuildPanel(guildPanel)

    local commPanel = CreateScrollPanel()
    BuildCommunitiesPanel(commPanel)

    -- Register with Blizzard Settings
    local mainCategory = Settings.RegisterCanvasLayoutCategory(generalPanel, "Djinni's Guild & Friends")
    Settings.RegisterCanvasLayoutSubcategory(mainCategory, friendsPanel, "Friends")
    Settings.RegisterCanvasLayoutSubcategory(mainCategory, guildPanel, "Guild")
    Settings.RegisterCanvasLayoutSubcategory(mainCategory, commPanel, "Communities")
    Settings.RegisterAddOnCategory(mainCategory)

    self.settingsCategoryID = mainCategory:GetID()
end
