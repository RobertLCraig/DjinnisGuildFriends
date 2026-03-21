local addonName, ns = ...
local DGF = ns.addon
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceDBOptions = LibStub("AceDBOptions-3.0")

function DGF:SetupOptions()
    local options = {
        type = "group",
        name = "Djinni's Guild & Friends",
        childGroups = "tab",
        args = {
            general = {
                type = "group",
                name = "General",
                order = 1,
                args = {
                    headerDisplay = {
                        type = "header",
                        name = "Display Settings",
                        order = 1,
                    },
                    labelFormat = {
                        type = "input",
                        name = "Panel Text Format",
                        desc = "Text shown in the LDB display panel.\n\nAvailable tokens:\n  <online> - Online friends count\n  <total> - Total friends count\n  <offline> - Offline friends count",
                        width = "full",
                        order = 2,
                        get = function() return self.db.profile.friends.labelFormat end,
                        set = function(_, val)
                            self.db.profile.friends.labelFormat = val
                            if ns.FriendsBroker then
                                ns.FriendsBroker:UpdateData()
                            end
                        end,
                    },
                    tooltipScale = {
                        type = "range",
                        name = "Tooltip Scale",
                        desc = "Scale of the friends tooltip",
                        min = 0.5, max = 2.0, step = 0.05,
                        order = 3,
                        get = function() return self.db.profile.friends.tooltipScale end,
                        set = function(_, val)
                            self.db.profile.friends.tooltipScale = val
                        end,
                    },
                    tooltipWidth = {
                        type = "range",
                        name = "Tooltip Width",
                        desc = "Width of the friends tooltip in pixels",
                        min = 300, max = 800, step = 10,
                        order = 4,
                        get = function() return self.db.profile.friends.tooltipWidth end,
                        set = function(_, val)
                            self.db.profile.friends.tooltipWidth = val
                        end,
                    },
                    rowSpacing = {
                        type = "range",
                        name = "Row Spacing",
                        desc = "Vertical spacing between friend entries in pixels",
                        min = 0, max = 16, step = 1,
                        order = 5,
                        get = function() return self.db.profile.friends.rowSpacing end,
                        set = function(_, val)
                            self.db.profile.friends.rowSpacing = val
                        end,
                    },
                    minimapIcon = {
                        type = "toggle",
                        name = "Show Minimap Icon",
                        desc = "Show or hide the minimap button",
                        order = 4,
                        get = function() return not self.db.profile.minimap.hide end,
                        set = function(_, val)
                            self.db.profile.minimap.hide = not val
                            if ns.icon then
                                if val then
                                    ns.icon:Show("DGF-Friends")
                                else
                                    ns.icon:Hide("DGF-Friends")
                                end
                            end
                        end,
                    },
                },
            },
            friends = {
                type = "group",
                name = "Friends",
                order = 2,
                args = {
                    headerFilter = {
                        type = "header",
                        name = "Display Filters",
                        order = 1,
                    },
                    showWoWFriends = {
                        type = "toggle",
                        name = "Show Character Friends",
                        desc = "Display WoW character friends in the tooltip",
                        order = 2,
                        get = function() return self.db.profile.friends.showWoWFriends end,
                        set = function(_, val)
                            self.db.profile.friends.showWoWFriends = val
                            if ns.FriendsBroker then ns.FriendsBroker:UpdateData() end
                        end,
                    },
                    showBNetFriends = {
                        type = "toggle",
                        name = "Show Battle.net Friends",
                        desc = "Display Battle.net friends playing WoW in the tooltip",
                        order = 3,
                        get = function() return self.db.profile.friends.showBNetFriends end,
                        set = function(_, val)
                            self.db.profile.friends.showBNetFriends = val
                            if ns.FriendsBroker then ns.FriendsBroker:UpdateData() end
                        end,
                    },
                    classColorNames = {
                        type = "toggle",
                        name = "Class-Colored Names",
                        desc = "Color friend names by their class color",
                        order = 4,
                        get = function() return self.db.profile.friends.classColorNames end,
                        set = function(_, val)
                            self.db.profile.friends.classColorNames = val
                            if ns.FriendsBroker then ns.FriendsBroker:UpdateData() end
                        end,
                    },
                    headerSort = {
                        type = "header",
                        name = "Sorting",
                        order = 10,
                    },
                    sortBy = {
                        type = "select",
                        name = "Sort By",
                        desc = "How to sort the friends list in the tooltip",
                        order = 11,
                        values = {
                            name   = "Name",
                            class  = "Class",
                            level  = "Level",
                            zone   = "Zone",
                            status = "Status",
                        },
                        get = function() return self.db.profile.friends.sortBy end,
                        set = function(_, val)
                            self.db.profile.friends.sortBy = val
                            if ns.FriendsBroker then ns.FriendsBroker:UpdateData() end
                        end,
                    },
                    sortAscending = {
                        type = "toggle",
                        name = "Ascending Order",
                        desc = "Sort in ascending (A-Z, low-high) or descending order",
                        order = 12,
                        get = function() return self.db.profile.friends.sortAscending end,
                        set = function(_, val)
                            self.db.profile.friends.sortAscending = val
                            if ns.FriendsBroker then ns.FriendsBroker:UpdateData() end
                        end,
                    },
                    headerClick = {
                        type = "header",
                        name = "Click Actions",
                        order = 20,
                    },
                    clickDesc = {
                        type = "description",
                        name = "Configure what happens when you click on a friend in the tooltip.",
                        order = 21,
                    },
                    leftClick = {
                        type = "select",
                        name = "Left Click",
                        order = 22,
                        values = ns.ACTION_VALUES,
                        get = function() return self.db.profile.friends.clickActions.leftClick end,
                        set = function(_, val) self.db.profile.friends.clickActions.leftClick = val end,
                    },
                    rightClick = {
                        type = "select",
                        name = "Right Click",
                        order = 23,
                        values = ns.ACTION_VALUES,
                        get = function() return self.db.profile.friends.clickActions.rightClick end,
                        set = function(_, val) self.db.profile.friends.clickActions.rightClick = val end,
                    },
                    shiftLeftClick = {
                        type = "select",
                        name = "Shift + Left Click",
                        order = 24,
                        values = ns.ACTION_VALUES,
                        get = function() return self.db.profile.friends.clickActions.shiftLeftClick end,
                        set = function(_, val) self.db.profile.friends.clickActions.shiftLeftClick = val end,
                    },
                    shiftRightClick = {
                        type = "select",
                        name = "Shift + Right Click",
                        order = 25,
                        values = ns.ACTION_VALUES,
                        get = function() return self.db.profile.friends.clickActions.shiftRightClick end,
                        set = function(_, val) self.db.profile.friends.clickActions.shiftRightClick = val end,
                    },
                    middleClick = {
                        type = "select",
                        name = "Middle Click",
                        order = 26,
                        values = ns.ACTION_VALUES,
                        get = function() return self.db.profile.friends.clickActions.middleClick end,
                        set = function(_, val) self.db.profile.friends.clickActions.middleClick = val end,
                    },
                },
            },
            profiles = AceDBOptions:GetOptionsTable(self.db),
        },
    }

    -- Set profiles tab order
    options.args.profiles.order = 99

    -- Register with AceConfig
    AceConfig:RegisterOptionsTable(addonName, options)

    -- Register with Blizzard Settings panel
    local frame, categoryID = AceConfigDialog:AddToBlizOptions(addonName, "Djinni's Guild & Friends")
    self.optionsFrame = frame
    self.optionsCategoryID = categoryID
end
