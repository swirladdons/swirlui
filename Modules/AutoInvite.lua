---@class SUI
local SUI = select(2, ...)

SUI.AutoInvite = SUI.AutoInvite or {}
local AI = SUI.AutoInvite

local frame
local cachedKeywords, cachedKeywordSource
local inviteCooldown = {}

local function Settings()
    return SwirlUIDB and SwirlUIDB.uiSettings and SwirlUIDB.uiSettings.autoInvite
end

local function ParseKeywords(str)
    local set = {}
    if not str then return set end
    for word in str:gmatch("[^,]+") do
        word = strtrim(word):lower()
        if word ~= "" then
            set[word] = true
        end
    end
    return set
end

local function MatchesKeyword(msg)
    if issecretvalue(msg) then return false end
    local settings = Settings()
    local source = settings and settings.keywords or ""
    if source ~= cachedKeywordSource then
        cachedKeywords = ParseKeywords(source)
        cachedKeywordSource = source
    end
    if not next(cachedKeywords) then return false end
    return cachedKeywords[strtrim(msg):lower()] or false
end

function AI.InvalidateKeywordCache()
    cachedKeywordSource = nil
end

local function IsInSameGuild(playerName)
    if not playerName then return false end
    if not playerName:find("-") then
        -- realm isn't always available yet right after login
        local realm = select(2, UnitFullName("player")) or GetNormalizedRealmName()
        if not realm then return false end
        playerName = playerName .. "-" .. realm
    end
    for i = 1, GetNumGuildMembers() do
        local name = GetGuildRosterInfo(i)
        if name == playerName then
            return true
        end
    end
    return false
end

local function ResolveBNetCharacter(bnSenderID)
    for i = 1, BNGetNumFriends() do
        local accountInfo = C_BattleNet.GetFriendAccountInfo(i)
        if accountInfo and bnSenderID == accountInfo.bnetAccountID then
            for j = 1, C_BattleNet.GetFriendNumGameAccounts(i) do
                local gameInfo = C_BattleNet.GetFriendGameAccountInfo(i, j)
                if gameInfo and gameInfo.characterName and gameInfo.realmName then
                    return gameInfo.characterName .. "-" .. gameInfo.realmName
                end
            end
            return nil
        end
    end
end

local function IsBNetFriend(playerName)
    if not playerName then return false end
    local name, realm = strsplit("-", playerName)
    for i = 1, BNGetNumFriends() do
        for j = 1, C_BattleNet.GetFriendNumGameAccounts(i) do
            local gameInfo = C_BattleNet.GetFriendGameAccountInfo(i, j)
            if gameInfo and gameInfo.characterName == name then
                if not realm or not gameInfo.realmName or gameInfo.realmName == realm then
                    return true
                end
            end
        end
    end
    return false
end

local function Invite(playerName)
    local settings = Settings()
    if settings.guildOnly and not IsInSameGuild(playerName) then return end

    local now = GetTime()
    local key = playerName:lower()
    if inviteCooldown[key] and inviteCooldown[key] > now - 10 then return end
    inviteCooldown[key] = now

    if settings.convertToRaid and not IsInRaid() and GetNumGroupMembers() == 5 and not InCombatLockdown() then
        C_PartyInfo.ConvertToRaid()
    end
    C_PartyInfo.InviteUnit(playerName)
end

local function OnEvent(_, event, ...)
    local settings = Settings()
    if not settings then return end

    if event == "CHAT_MSG_WHISPER" or event == "CHAT_MSG_BN_WHISPER" then
        if not settings.enabled then return end
        local msg, playerName = ...
        if issecretvalue(msg) or issecretvalue(playerName) then return end
        if not MatchesKeyword(msg) then return end

        if event == "CHAT_MSG_BN_WHISPER" then
            playerName = ResolveBNetCharacter(select(13, ...))
            if not playerName then return end
        end
        Invite(playerName)
    elseif event == "PARTY_INVITE_REQUEST" then
        if not (settings.acceptGuildInvites or settings.acceptBNetInvites) then return end
        local name = ...
        if issecretvalue(name) then return end
        if (settings.acceptGuildInvites and IsInSameGuild(name))
            or (settings.acceptBNetInvites and IsBNetFriend(name)) then
            AcceptGroup()
            C_Timer.After(0, function() StaticPopup_Hide("PARTY_INVITE") end)
        end
    end
end

function SUI.ApplyAutoInviteSettings()
    local settings = Settings()
    if not settings then return end

    if not frame then
        frame = CreateFrame("Frame", "SwirlUIAutoInvite")
        frame:SetScript("OnEvent", OnEvent)
    end

    if settings.enabled then
        frame:RegisterEvent("CHAT_MSG_WHISPER")
        frame:RegisterEvent("CHAT_MSG_BN_WHISPER")
    else
        frame:UnregisterEvent("CHAT_MSG_WHISPER")
        frame:UnregisterEvent("CHAT_MSG_BN_WHISPER")
    end

    if settings.acceptGuildInvites or settings.acceptBNetInvites then
        frame:RegisterEvent("PARTY_INVITE_REQUEST")
    else
        frame:UnregisterEvent("PARTY_INVITE_REQUEST")
    end

    if (settings.enabled and settings.guildOnly) or settings.acceptGuildInvites then
        C_GuildInfo.GuildRoster()
    end
end
