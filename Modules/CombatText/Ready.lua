---@class SUI : SF
local SUI = select(2, ...)
local CT = SUI.CombatText

local issecretvalue = issecretvalue
local issecrettable = issecrettable

-- nothing is announced for a moment after loading in, a key start or a countdown, when the
-- debuffs and cooldowns are still settling
local quietUntil = 0

local function Quiet()
    return GetTime() < quietUntil
end

local function BumpQuiet(seconds)
    quietUntil = math.max(quietUntil, GetTime() + seconds)
end

local quietEvents = CreateFrame("Frame")
quietEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
quietEvents:RegisterEvent("CHALLENGE_MODE_START")
quietEvents:RegisterEvent("CHALLENGE_MODE_RESET")
quietEvents:RegisterEvent("START_TIMER")
quietEvents:SetScript("OnEvent", function(_, event, _, seconds)
    if event == "START_TIMER" then
        BumpQuiet(math.min(tonumber(seconds) or 10, 30) + 5)
    else
        BumpQuiet(6)
    end
end)

-- the lockout aura can read as gone for a moment and come back, so it only counts as ended once its known end time has passed
local SATED_IDS = { 57723, 57724, 80354, 95809, 160455, 264689, 390435 }
local SATED_LENGTH = 600
local GRACE = 2
local SETTLE = 2

local GetPlayerAura = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID

local satedActive = false
local satedExpires, gainedAt
local settleUntil = 0
local endTimer, endTimerFor
local lastSated

local function CurrentSated()
    if lastSated then
        local aura = GetPlayerAura(SATED_IDS[lastSated])
        if aura then return aura end
    end
    for i, id in ipairs(SATED_IDS) do
        if i ~= lastSated then
            local aura = GetPlayerAura(id)
            if aura then
                lastSated = i
                return aura
            end
        end
    end
end

local function ReadExpiration(aura)
    local expires = aura.expirationTime
    if issecretvalue(expires) or type(expires) ~= "number" or expires <= 0 then return nil end
    return expires
end

local function KnownEnd()
    if satedExpires then return satedExpires end
    if gainedAt then return gainedAt + SATED_LENGTH end
end

-- a full update or a fresh login is not a bloodlust being cast
local function IsFreshGain(info, now)
    if now < settleUntil then return false end
    if info == nil or issecretvalue(info) or (issecrettable and issecrettable(info)) then return true end
    local ok, full = pcall(function() return info.isFullUpdate end)
    if not ok or issecretvalue(full) then return true end
    return not full
end

local function PayloadChurns(info)
    local function Churns()
        if issecretvalue(info) or info == nil or (issecrettable and issecrettable(info)) then return true end
        local full, added, removed = info.isFullUpdate, info.addedAuras, info.removedAuraInstanceIDs
        if issecretvalue(full) or issecretvalue(added) or issecretvalue(removed) then return true end
        return (full or added or removed) and true or false
    end
    local ok, churns = pcall(Churns)
    return not ok or churns
end

local ArmEndCheck

local function OnSatedAura(info, live, forced)
    local aura = CurrentSated()
    local now = GetTime()

    if aura then
        satedExpires = ReadExpiration(aura)
        if not satedActive then
            satedActive = true
            if live and not (gainedAt and now < gainedAt + SATED_LENGTH - GRACE) and IsFreshGain(info, now) then
                gainedAt = now
            end
        end
    elseif satedActive then
        local knownEnd = KnownEnd()
        -- gone well before its end time means the read flickered
        if not (not forced and knownEnd and now < knownEnd - GRACE) then
            satedActive, satedExpires, gainedAt = false, nil, nil
            if not Quiet() then CT.Show("bloodlust") end
        end
    end
    ArmEndCheck()
end

ArmEndCheck = function()
    local endAt = satedActive and KnownEnd()
    if not endAt then
        if endTimer then endTimer:Cancel() end
        endTimer, endTimerFor = nil, nil
        return
    end
    if endTimerFor == endAt then return end
    if endTimer then endTimer:Cancel() end
    endTimerFor = endAt
    endTimer = C_Timer.NewTimer(math.max(endAt - GetTime(), 0) + 0.1, function()
        endTimer = nil
        OnSatedAura()
    end)
end

local function PrimeSated()
    local aura = CurrentSated()
    satedActive = aura and true or false
    satedExpires = aura and ReadExpiration(aura) or nil
    settleUntil = GetTime() + SETTLE
    ArmEndCheck()
end

-- death, a release and a boss end remove the lockout too, but the aura event can arrive late
local RECHECK = {
    PLAYER_DEAD = true, PLAYER_ALIVE = true, PLAYER_UNGHOST = true, ENCOUNTER_END = true,
    CHALLENGE_MODE_START = true, CHALLENGE_MODE_RESET = true,
}

local satedEvents = CreateFrame("Frame")
satedEvents:SetScript("OnEvent", function(_, event, _, info)
    if CT.previewing then return end
    if event == "PLAYER_ENTERING_WORLD" then
        PrimeSated()
    elseif RECHECK[event] then
        if satedActive then C_Timer.After(1, function() OnSatedAura(nil, false, true) end) end
    else
        if satedActive and satedExpires and GetTime() < satedExpires then return end
        if (not satedActive or satedExpires) and not PayloadChurns(info) then return end
        OnSatedAura(info, true)
    end
end)

local function SyncBloodlust(on)
    satedEvents:UnregisterAllEvents()
    if not (on and GetPlayerAura) then
        if endTimer then endTimer:Cancel() end
        endTimer, endTimerFor = nil, nil
        return
    end
    satedEvents:RegisterUnitEvent("UNIT_AURA", "player")
    satedEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
    for event in pairs(RECHECK) do satedEvents:RegisterEvent(event) end
    PrimeSated()
end

local POTION_ID = 241308
local REFRESH_DELAY = 0.5

local GetItemCooldown = (C_Container and C_Container.GetItemCooldown)
    or GetItemCooldown
    or (C_Item and C_Item.GetItemCooldown)

local potionRunning = false
local potionTimer
local refreshQueued = false

local function RefreshPotion()
    refreshQueued = false
    if potionTimer then
        potionTimer:Cancel()
        potionTimer = nil
    end
    local start, duration = GetItemCooldown(POTION_ID)
    if issecretvalue(start) or issecretvalue(duration) then return end

    local remaining = (start and duration and start > 0 and duration > 0) and (start + duration - GetTime()) or 0
    if remaining > 0 then
        potionRunning = true
        potionTimer = C_Timer.NewTimer(remaining + 0.05, RefreshPotion)
        return
    end

    local wasRunning = potionRunning
    potionRunning = false
    if wasRunning and not Quiet() and not CT.previewing then CT.Show("potion") end
end

-- BAG_UPDATE_COOLDOWN fires for every item, so it is only acted on once things settle
local function QueueRefreshPotion()
    if refreshQueued then return end
    refreshQueued = true
    C_Timer.After(REFRESH_DELAY, RefreshPotion)
end

local potionEvents = CreateFrame("Frame")
potionEvents:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(0.5, RefreshPotion)
    else
        QueueRefreshPotion()
    end
end)

local function SyncPotion(on)
    potionEvents:UnregisterAllEvents()
    if not (on and GetItemCooldown) then
        if potionTimer then potionTimer:Cancel() end
        potionTimer, potionRunning = nil, false
        return
    end
    potionEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
    potionEvents:RegisterEvent("BAG_UPDATE_COOLDOWN")
    potionEvents:RegisterEvent("CHALLENGE_MODE_START")
    RefreshPotion()
end

local synced = {}

local function OnToggle(name, on, sync)
    if synced[name] == on then return end
    synced[name] = on
    sync(on)
end

CT.OnApply(function(c)
    OnToggle("bloodlust", c.enabled and c.bloodlust.enabled, SyncBloodlust)
    OnToggle("potion", c.enabled and c.potion.enabled, SyncPotion)
end)
