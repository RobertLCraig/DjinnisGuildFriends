-- Regression check for 12.1 secret values reaching the Communities broker.
-- CommunitiesBroker:UpdateData reads C_Club, whose reads are all
-- SecretInChatMessagingLockdown. A secret club name used to reach the tooltip,
-- which concatenates it and keys group headers by it; a secret member name
-- reached memberName:find("-") and every member sort. Card 0001.
--
-- This loads the real Core.lua and CommunitiesBroker.lua with the game stubbed.
-- A secret is modelled by what matters: type() answers "string" for it (as the
-- game's does), issecretvalue() answers true, and any comparison,
-- concatenation, length or method call on it throws.
--
--   lua docs/build/check-secret-ingest.lua          (run from the addon root)

local realtype = type
local secretmt = {}
local function boom() error("attempt to use a secret string value", 2) end
secretmt.__lt, secretmt.__le, secretmt.__concat, secretmt.__len = boom, boom, boom, boom
secretmt.__index = boom
local function secret() return setmetatable({}, secretmt) end
local function isModel(v) return realtype(v) == "table" and getmetatable(v) == secretmt end

type = function(v) if isModel(v) then return "string" end return realtype(v) end
issecretvalue = function(v) return isModel(v) end

-- Game stubs -----------------------------------------------------------------
local noop = function() end
local frameMT = { __index = function() return noop end }
CreateFrame = function() return setmetatable({}, frameMT) end
LibStub = function() return { NewDataObject = function(_, _, t) return t end } end
Enum = {
    ClubType = { BattleNet = 0, Character = 1, Guild = 2 },
    ClubMemberPresence = { Unknown = 0, Online = 1, OnlineMobile = 2, Offline = 3, Away = 4, Busy = 5 },
}
C_CreatureInfo = { GetClassInfo = function() return { classFile = "DRUID" } end }
local lockdown = false
C_ChatInfo = { InChatMessagingLockdown = function() return lockdown end }

local clubs, members = {}, {}
C_Club = {
    GetSubscribedClubs = function() return clubs end,
    GetClubMembers = function(clubId)
        local ids = {}
        for id in pairs(members[clubId] or {}) do ids[#ids + 1] = id end
        table.sort(ids)
        return ids
    end,
    GetMemberInfo = function(clubId, id) return members[clubId][id] end,
}

local ns = {}
assert(loadfile("Core.lua"))("DjinnisGuildFriends", ns)
assert(loadfile("CommunitiesBroker.lua"))("DjinnisGuildFriends", ns)
ns.db = { communities = ns.defaults.communities }
local CB = ns.CommunitiesBroker

local function online(name) return { name = name, presence = 1, level = 90, zone = "Silvermoon" } end

-- 1. The ordinary path still works: readable club, readable members, sorted.
clubs = { { clubId = "10", name = "Moonglade", clubType = 1 } }
members = { ["10"] = { online("Zed-Realm"), online("Ann") } }
CB:UpdateData()
local got = CB.clubsCache["10"]
assert(got and #got.members == 2, "a readable club must be ingested with both members")
assert(got.members[1].name == "Ann" and got.members[2].name == "Zed", "members sorted, realm stripped")

-- 2. A secret club name is skipped, and nothing throws.
clubs = {
    { clubId = "10", name = "Moonglade", clubType = 1 },
    { clubId = "20", name = secret(), clubType = 1 },
}
members = { ["10"] = { online("Ann") }, ["20"] = { online("Bob") } }
local ok, err = pcall(CB.UpdateData, CB)
assert(ok, "a secret club name must not throw -> " .. tostring(err))
assert(CB.clubsCache["20"] == nil, "a club with a secret name must not reach the tooltip cache")
assert(CB.clubsCache["10"], "the readable club must still be there")

-- 3. A secret member name, or a secret presence, is skipped.
clubs = { { clubId = "10", name = "Moonglade", clubType = 1 } }
local bad = online("x"); bad.name = secret()
local badPresence = online("Cat"); badPresence.presence = secret()
members = { ["10"] = { online("Ann"), bad, badPresence } }
ok, err = pcall(CB.UpdateData, CB)
assert(ok, "a secret member name or presence must not throw -> " .. tostring(err))
assert(#CB.clubsCache["10"].members == 1, "only the readable member is kept")

-- 4. Secret zone, note and level are replaced, never stored.
local shady = online("Dee"); shady.zone = secret(); shady.memberNote = secret(); shady.level = secret()
members = { ["10"] = { shady } }
ok, err = pcall(CB.UpdateData, CB)
assert(ok, "secret member fields must not throw -> " .. tostring(err))
local m = CB.clubsCache["10"].members[1]
assert(m.area == "" and m.notes == "" and m.level == 0, "secret fields fall back to plain values")

-- 5. In messaging lockdown nothing is read and the last roster is held.
local before = CB.clubsCache
lockdown = true
clubs = { { clubId = "30", name = secret(), clubType = 1 } }
CB:UpdateData()
assert(CB.clubsCache == before, "lockdown must hold the last known roster")

print("secret ingest: all 5 checks passed")
