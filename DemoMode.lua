-- DemoMode.lua - Djinni's Guild & Friends
-- Injects realistic fake data for screenshots and UI demos.
--
-- ENABLE:  Uncomment "DemoMode.lua" in DjinnisGuildFriends.toc, then /reload
-- DISABLE: Comment it out again and /reload
--
-- While active, real friend/guild/community data is replaced with demo data.
-- Use /dgf demo to toggle the fake data on/off mid-session.
---------------------------------------------------------------------------

local addonName, ns = ...
local DGF = ns.addon

---------------------------------------------------------------------------
-- Demo datasets
---------------------------------------------------------------------------

local DEMO_FRIENDS = {
    -- WoW friends
    { name="Arathos",    level=80, classFile="WARRIOR",      area="Dornogal",          connected=true,  afk=true,  dnd=false, notes="#Raid #Tank",    isBNet=false, fullName="Arathos" },
    { name="Sylvara",    level=80, classFile="PRIEST",        area="Hallowfall",        connected=true,  afk=false, dnd=false, notes="",               isBNet=false, fullName="Sylvara" },
    { name="Korvash",    level=80, classFile="DEATHKNIGHT",   area="The Ringing Deeps", connected=true,  afk=false, dnd=true,  notes="#Raid",          isBNet=false, fullName="Korvash" },
    { name="Mirela",     level=80, classFile="MAGE",          area="Azj-Kahet",         connected=true,  afk=false, dnd=false, notes="#Casual",        isBNet=false, fullName="Mirela" },
    { name="Thundrik",   level=80, classFile="SHAMAN",        area="Isle of Dorn",      connected=true,  afk=false, dnd=false, notes="#Raid #Healer",  isBNet=false, fullName="Thundrik" },
    { name="Pelindra",   level=80, classFile="DRUID",         area="Dornogal",          connected=true,  afk=false, dnd=false, notes="#Casual",        isBNet=false, fullName="Pelindra" },
    { name="Vexholm",    level=78, classFile="ROGUE",         area="The Ringing Deeps", connected=true,  afk=false, dnd=false, notes="",               isBNet=false, fullName="Vexholm" },
    -- BNet friends
    { name="Fenwick",    level=80, classFile="HUNTER",        area="Dornogal",          connected=true,  afk=false, dnd=false, notes="",               isBNet=true,  fullName="Fenwick-Kaelthas",  accountName="Fen#1482",  battleTag="Fen#1482",  realmName="Kaelthas",  gameAccountID=10001 },
    { name="Zyara",      level=80, classFile="WARLOCK",       area="The Ringing Deeps", connected=true,  afk=false, dnd=false, notes="",               isBNet=true,  fullName="Zyara-Area 52",     accountName="Zy#2204",   battleTag="Zy#2204",   realmName="Area 52",   gameAccountID=10002 },
    { name="Torvald",    level=80, classFile="PALADIN",       area="Hallowfall",        connected=true,  afk=false, dnd=false, notes="",               isBNet=true,  fullName="Torvald-Illidan",   accountName="Torv#9911", battleTag="Torv#9911", realmName="Illidan",   gameAccountID=10003 },
    { name="Duskweave",  level=80, classFile="DRUID",         area="Dornogal",          connected=true,  afk=true,  dnd=false, notes="",               isBNet=true,  fullName="Duskweave-Stormrage", accountName="Dusk#3374", battleTag="Dusk#3374", realmName="Stormrage", gameAccountID=10004 },
    { name="Nythara",    level=80, classFile="ROGUE",         area="Azj-Kahet",         connected=true,  afk=false, dnd=false, notes="",               isBNet=true,  fullName="Nythara-Proudmoore", accountName="Nyth#7623", battleTag="Nyth#7623", realmName="Proudmoore", gameAccountID=10005 },
}

local DEMO_GUILD_NAME = "Eternal Vigil"
local DEMO_GUILD_TOTAL = 178

local DEMO_GUILD = {
    { name="Sarveth",     level=80, classFile="WARLOCK",      area="Dornogal",          rank="Guild Master", rankIndex=0, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="",               officerNote="",       fullName="Sarveth" },
    { name="Lyrandel",    level=80, classFile="DRUID",        area="Hallowfall",        rank="Officer",      rankIndex=1, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="",               officerNote="Raid RL", fullName="Lyrandel" },
    { name="Kharsus",     level=80, classFile="DEATHKNIGHT",  area="The Ringing Deeps", rank="Officer",      rankIndex=1, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="",               officerNote="Tank",   fullName="Kharsus" },
    { name="Brightmoon",  level=80, classFile="PALADIN",      area="Dornogal",          rank="Veteran",      rankIndex=2, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="For the Light!", officerNote="",       fullName="Brightmoon" },
    { name="Zephran",     level=80, classFile="MONK",         area="Azj-Kahet",         rank="Veteran",      rankIndex=2, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="",               officerNote="",       fullName="Zephran" },
    { name="Anella",      level=80, classFile="PRIEST",       area="Isle of Dorn",      rank="Veteran",      rankIndex=2, connected=true,  isMobile=false, status=1, afk=true,  dnd=false, notes="",               officerNote="Healer", fullName="Anella" },
    { name="Duskwarden",  level=80, classFile="HUNTER",       area="Dornogal",          rank="Member",       rankIndex=3, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="",               officerNote="",       fullName="Duskwarden" },
    { name="Ironforge",   level=80, classFile="WARRIOR",      area="The Ringing Deeps", rank="Member",       rankIndex=3, connected=true,  isMobile=false, status=2, afk=false, dnd=true,  notes="",               officerNote="",       fullName="Ironforge" },
    { name="Crystalsong",  level=80, classFile="MAGE",        area="Hallowfall",        rank="Member",       rankIndex=3, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="",               officerNote="",       fullName="Crystalsong" },
    { name="Wavestrider", level=80, classFile="SHAMAN",       area="Dornogal",          rank="Member",       rankIndex=3, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="",               officerNote="",       fullName="Wavestrider" },
    { name="Emberveil",   level=80, classFile="DEMONHUNTER",  area="Azj-Kahet",         rank="Recruit",      rankIndex=4, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="New member!",    officerNote="",       fullName="Emberveil" },
    { name="Thornwick",   level=80, classFile="ROGUE",        area="Isle of Dorn",      rank="Recruit",      rankIndex=4, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="",               officerNote="",       fullName="Thornwick" },
    { name="Galefrost",   level=80, classFile="EVOKER",       area="Dornogal",          rank="Recruit",      rankIndex=4, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="",               officerNote="",       fullName="Galefrost" },
    { name="Nightblossom",level=75, classFile="DRUID",        area="Hallowfall",        rank="Recruit",      rankIndex=4, connected=false, isMobile=true,  status=0, afk=false, dnd=false, notes="Leveling up",    officerNote="",       fullName="Nightblossom" },
}

local DEMO_CLUBS = {
    [1001] = {
        info = { clubId=1001, name="TWW Mythic+ Club", clubType=1 },
        members = {
            { name="Karanex",    level=80, classFile="DEATHKNIGHT",  area="The Ringing Deeps", afk=false, dnd=false, isMobile=false, isSelf=false, notes="",          fullName="Karanex",    clubId=1001, clubName="TWW Mythic+ Club" },
            { name="Solaris",    level=80, classFile="PALADIN",      area="Dornogal",          afk=false, dnd=false, isMobile=false, isSelf=false, notes="",          fullName="Solaris",    clubId=1001, clubName="TWW Mythic+ Club" },
            { name="Vexara",     level=80, classFile="WARLOCK",      area="Azj-Kahet",         afk=true,  dnd=false, isMobile=false, isSelf=false, notes="",          fullName="Vexara",     clubId=1001, clubName="TWW Mythic+ Club" },
            { name="Runethane",  level=80, classFile="MAGE",         area="Hallowfall",        afk=false, dnd=false, isMobile=false, isSelf=false, notes="M+ carry",  fullName="Runethane",  clubId=1001, clubName="TWW Mythic+ Club" },
            { name="Galebreaker",level=80, classFile="SHAMAN",       area="Isle of Dorn",      afk=false, dnd=false, isMobile=false, isSelf=false, notes="",          fullName="Galebreaker",clubId=1001, clubName="TWW Mythic+ Club" },
            { name="Thornspire", level=80, classFile="HUNTER",       area="Dornogal",          afk=false, dnd=false, isMobile=false, isSelf=false, notes="",          fullName="Thornspire", clubId=1001, clubName="TWW Mythic+ Club" },
        },
    },
    [1002] = {
        info = { clubId=1002, name="Realm Social", clubType=1 },
        members = {
            { name="Dawnseeker", level=80, classFile="PRIEST",       area="Dornogal",          afk=false, dnd=false, isMobile=false, isSelf=false, notes="",          fullName="Dawnseeker", clubId=1002, clubName="Realm Social" },
            { name="Iceveil",    level=80, classFile="MAGE",         area="The Ringing Deeps", afk=false, dnd=false, isMobile=false, isSelf=false, notes="",          fullName="Iceveil",    clubId=1002, clubName="Realm Social" },
            { name="Blazefury",  level=80, classFile="WARRIOR",      area="Dornogal",          afk=false, dnd=false, isMobile=false, isSelf=false, notes="",          fullName="Blazefury",  clubId=1002, clubName="Realm Social" },
            { name="Silksong",   level=80, classFile="ROGUE",        area="Hallowfall",        afk=false, dnd=true,  isMobile=false, isSelf=false, notes="Busy raiding", fullName="Silksong",  clubId=1002, clubName="Realm Social" },
        },
    },
}

---------------------------------------------------------------------------
-- Demo injection
---------------------------------------------------------------------------

local demoActive = false

local function InjectDemoData()
    local FB = ns.FriendsBroker
    local GB = ns.GuildBroker
    local CB = ns.CommunitiesBroker

    -- Friends
    FB.friendsCache = DEMO_FRIENDS
    FB.onlineCount = #DEMO_FRIENDS
    FB.totalCount = 24
    FB.dataobj.text = DGF:FormatLabel(ns.db.friends.labelFormat, FB.onlineCount, FB.totalCount)

    -- Guild
    GB.guildCache = DEMO_GUILD
    GB.onlineCount = #DEMO_GUILD
    GB.totalCount = DEMO_GUILD_TOTAL
    GB.guildName = DEMO_GUILD_NAME
    GB.dataobj.text = DGF:FormatLabel(ns.db.guild.labelFormat, GB.onlineCount, GB.totalCount, { guildname = DEMO_GUILD_NAME })

    -- Communities
    local communityOnline = 0
    for _, club in pairs(DEMO_CLUBS) do
        communityOnline = communityOnline + #club.members
    end
    CB.clubsCache = DEMO_CLUBS
    CB.totalOnline = communityOnline
    CB.dataobj.text = DGF:FormatLabel(ns.db.communities.labelFormat, communityOnline, communityOnline)
end

local function FreezeUpdates()
    -- Replace UpdateData with no-ops while demo is active
    ns.FriendsBroker.UpdateData = function() end
    ns.GuildBroker.UpdateData   = function() end
    ns.CommunitiesBroker.UpdateData = function() end
end

local originalFBUpdate, originalGBUpdate, originalCBUpdate

local function EnableDemo()
    originalFBUpdate = ns.FriendsBroker.UpdateData
    originalGBUpdate = ns.GuildBroker.UpdateData
    originalCBUpdate = ns.CommunitiesBroker.UpdateData
    FreezeUpdates()
    InjectDemoData()
    demoActive = true
    DGF:Print("|cff00ff00Demo mode ON|r — fake data injected. /reload or /dgf demo to toggle.")
end

local function DisableDemo()
    -- Restore original UpdateData functions
    if originalFBUpdate then ns.FriendsBroker.UpdateData   = originalFBUpdate end
    if originalGBUpdate then ns.GuildBroker.UpdateData     = originalGBUpdate end
    if originalCBUpdate then ns.CommunitiesBroker.UpdateData = originalCBUpdate end
    -- Trigger real refresh
    ns.FriendsBroker:UpdateData()
    ns.GuildBroker:UpdateData()
    ns.CommunitiesBroker:UpdateData()
    demoActive = false
    DGF:Print("|cffff4444Demo mode OFF|r — live data restored.")
end

---------------------------------------------------------------------------
-- Hook into addon load and slash command
---------------------------------------------------------------------------

local demoFrame = CreateFrame("Frame")
demoFrame:RegisterEvent("ADDON_LOADED")
demoFrame:SetScript("OnEvent", function(_, event, name)
    if name ~= addonName then return end
    -- Wait one frame so all brokers have run Init()
    C_Timer.After(0.5, function()
        EnableDemo()
    end)
end)

-- Extend /dgf to support "demo" argument
local existingSlash = SlashCmdList["DGF"]
SlashCmdList["DGF"] = function(msg)
    local arg = msg and msg:lower():match("^%s*(.-)%s*$") or ""
    if arg == "demo" then
        if demoActive then
            DisableDemo()
        else
            EnableDemo()
        end
    elseif existingSlash then
        existingSlash(msg)
    end
end
