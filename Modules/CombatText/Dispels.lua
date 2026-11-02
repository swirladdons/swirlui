---@class SUI : SF
local SUI = select(2, ...)
local CT = SUI.CombatText

-- reading what a dispel or purge removed is the hard part: aura lists are hidden or incomplete in
-- combat, and a cast event only says that a dispel was cast. so a cast takes a snapshot of the auras
-- on every plausible unit, and a short poll afterwards looks for the one that is gone. when no list
-- can be read the damage meter, then the dispel's own cooldown, stand in.

local issecretvalue = issecretvalue
local issecrettable = issecrettable
local Ask = CT.Ask

local DISPEL, PURGE = 1, 2
-- mass dispel does both
local SPELLS = { [32375] = 3 }
-- spells whose cooldown only starts when something was actually removed
local ON_SUCCESS = {}
for _, id in ipairs({ 527, 213634, 4987, 213644, 88423, 2782, 77130, 51886, 115450, 218164, 475, 360823, 365585 }) do
    SPELLS[id], ON_SUCCESS[id] = DISPEL, true
end
for _, id in ipairs({ 374251, 89808, 119905, 132411, 212620, 212623, 1276623 }) do SPELLS[id] = DISPEL end
for _, id in ipairs({ 370, 378773, 528, 30449, 1231112, 19801, 455641, 278326, 19505, 1276610, 2908, 455636, 5938 }) do
    SPELLS[id] = PURGE
end
-- no list could be read, and a purge that may have hit nothing is not worth guessing at
local NO_GUESS = { [5938] = true }

local FRIEND, ENEMY = "HARMFUL|RAID", "HELPFUL|DISPELLABLE"
local AIMED = { "mouseover", "target", "focus" }
local GROUP = { "player", "party1", "party2", "party3", "party4" }
local RAID, PLATES = {}, {}
for i = 1, 40 do
    RAID[i] = "raid" .. i
    PLATES[i] = "nameplate" .. i
end
local POLL, STEPS, ARMED_FOR = 0.1, 8, 2

local DM = C_DamageMeter
local DM_TYPE = Enum and Enum.DamageMeterType and Enum.DamageMeterType.Dispels
local DM_NOW = Enum and Enum.DamageMeterSessionType and Enum.DamageMeterSessionType.Current

local jobs, armed = {}, nil
local claimed, seen = {}, {}
local epoch = {}
local meterSeq = 0
local meterListsCasts = false
local watching = false

local watch = CreateFrame("Frame")
local casts = CreateFrame("Frame")

-- a unit's aura snapshot is only comparable while its epoch is unchanged, since a new target or a roster
-- change means the same token is a different unit
local function Bump(unit)
    epoch[unit] = (epoch[unit] or 0) + 1
end

watch:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_TARGET_CHANGED" then
        Bump("target")
    elseif event == "PLAYER_FOCUS_CHANGED" then
        Bump("focus")
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        Bump("mouseover")
    elseif event == "UNIT_TARGET" then
        Bump("pettarget")
    elseif event == "GROUP_ROSTER_UPDATE" then
        for _, u in ipairs(GROUP) do Bump(u) end
        for _, u in ipairs(RAID) do Bump(u) end
    elseif event == "DAMAGE_METER_COMBAT_SESSION_UPDATED" then
        if not issecretvalue(unit) and unit == DM_TYPE then meterSeq = meterSeq + 1 end
    elseif type(unit) == "string" and not issecretvalue(unit) then
        Bump(unit)
    end
end)

local function SyncWatch()
    local on = armed ~= nil or #jobs > 0
    if on == watching then return end
    watching = on
    if not on then
        watch:UnregisterAllEvents()
        return
    end
    watch:RegisterEvent("PLAYER_TARGET_CHANGED")
    watch:RegisterEvent("PLAYER_FOCUS_CHANGED")
    watch:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
    watch:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    watch:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    watch:RegisterEvent("GROUP_ROSTER_UPDATE")
    watch:RegisterUnitEvent("UNIT_TARGET", "pet")
    watch:RegisterEvent("DAMAGE_METER_COMBAT_SESSION_UPDATED")
end

local function Hidden(value)
    return type(value) ~= "table" or issecretvalue(value) or (issecrettable and issecrettable(value)) or false
end

local function ReadIDs(unit, filter)
    if not (C_UnitAuras and C_UnitAuras.GetUnitAuraInstanceIDs) then return nil end
    local ok, ids = pcall(C_UnitAuras.GetUnitAuraInstanceIDs, unit, filter)
    if not ok or Hidden(ids) then return nil end
    return ids
end

local function Wanted(unit, hostile)
    if Ask(UnitExists, unit) == false then return false end
    if hostile then return Ask(UnitCanAttack, "player", unit) ~= false end
    return Ask(UnitCanAssist, "player", unit) ~= false
end

local function IsAimedAt(unit, aim)
    if not aim then return false end
    local ok, name, realm = pcall(UnitName, unit)
    if not ok or type(name) ~= "string" or issecretvalue(name) then return false end
    if name == aim then return true end
    return type(realm) == "string" and not issecretvalue(realm) and realm ~= "" and name .. "-" .. realm == aim or false
end

local function Snap(job, unit, hostile)
    local snap = job.units[unit]
    if snap and snap.hostile ~= hostile then return end
    if not Wanted(unit, hostile) then return end
    local ids = ReadIDs(unit, hostile and ENEMY or FRIEND)
    if not ids then return end

    job.readable = true
    if not snap then
        snap = { hostile = hostile, auras = {} }
        job.units[unit] = snap
        job.order[#job.order + 1] = unit
    elseif snap.epoch ~= epoch[unit] then
        wipe(snap.auras)
    end
    snap.epoch, snap.hidden = epoch[unit], 0
    snap.aimed = IsAimedAt(unit, job.aim)

    for _, id in ipairs(ids) do
        if type(id) ~= "number" or issecretvalue(id) then
            snap.hidden = snap.hidden + 1
        elseif not snap.auras[id] then
            local ok, data = pcall(C_UnitAuras.GetAuraDataByAuraInstanceID, unit, id)
            snap.auras[id] = (ok and not Hidden(data)) and { name = data.name, icon = data.icon } or {}
        end
    end
end

local function AurasHidden()
    local secrets = C_Secrets
    if not (secrets and secrets.ShouldAurasBeSecret) then return false end
    local ok, hidden = pcall(secrets.ShouldAurasBeSecret)
    return ok and hidden == true
end

local function SnapAll(job)
    if AurasHidden() then return end
    if job.friendly then
        for _, unit in ipairs(AIMED) do Snap(job, unit, false) end
        for _, unit in ipairs(IsInRaid() and RAID or GROUP) do Snap(job, unit, false) end
    end
    if job.hostile then
        for _, unit in ipairs(AIMED) do Snap(job, unit, true) end
        Snap(job, "pettarget", true)
        for _, unit in ipairs(PLATES) do Snap(job, unit, true) end
    end
end

local function FindGone(unit, snap)
    if snap.epoch ~= epoch[unit] or Ask(UnitExists, unit) == false or Ask(UnitIsDeadOrGhost, unit) == true then
        return nil
    end
    local ids = ReadIDs(unit, snap.hostile and ENEMY or FRIEND)
    if not ids then return nil end

    wipe(seen)
    local hidden = 0
    for _, id in ipairs(ids) do
        if type(id) ~= "number" or issecretvalue(id) then
            hidden = hidden + 1
        else
            seen[id] = true
        end
    end
    -- more hidden auras than before means the list is not comparable
    if hidden > snap.hidden then return nil end

    for id, info in pairs(snap.auras) do
        if not seen[id] and not claimed[id] then return id, info end
    end
end

local function Find(job)
    for pass = 1, 2 do
        for _, unit in ipairs(job.order) do
            local snap = job.units[unit]
            if snap.aimed == (pass == 1) then
                local id, info = FindGone(unit, snap)
                if id then return unit, snap, id, info end
            end
        end
    end
end

local function OwnCooldownRunning(id)
    if not (C_Spell and C_Spell.GetSpellCooldown) then return nil end
    local ok, cooldown = pcall(C_Spell.GetSpellCooldown, id)
    if not ok or Hidden(cooldown) then return nil end
    local active, onGCD = cooldown.isActive, cooldown.isOnGCD
    if issecretvalue(active) or issecretvalue(onGCD) then return nil end
    return (active and not onGCD) and true or false
end

local function MeterList(unit)
    if not (DM and DM.GetCombatSessionSourceFromType and DM_TYPE and DM_NOW) then return nil end
    local guid = UnitGUID(unit)
    if type(guid) ~= "string" then return nil end
    local ok, data = pcall(DM.GetCombatSessionSourceFromType, DM_NOW, DM_TYPE, guid)
    if not ok or Hidden(data) then return nil end
    local list = data.combatSpells
    if Hidden(list) then return nil end
    return list
end

-- the removed aura when the meter names exactly one, false when it names several, nil when unusable
local function FromMeter(job)
    if meterListsCasts or meterSeq == job.meterSeq then return nil end

    local list = MeterList(job.who)
    if job.who == "pet" and (not list or #list == 0) then list = MeterList("player") end
    if not list then return nil end
    if #list > 1 then return false end

    local entry = list[1]
    if Hidden(entry) then return nil end
    local id = entry.spellID
    if type(id) ~= "number" then return nil end
    if not issecretvalue(id) and SPELLS[id] then
        -- it lists the dispel spell itself, not what it removed
        meterListsCasts = true
        return nil
    end

    local info = {}
    local okName, name = pcall(C_Spell.GetSpellName, id)
    if okName then info.name = name end
    local okIcon, icon = pcall(C_Spell.GetSpellTexture, id)
    if okIcon then info.icon = icon end
    return info
end

local function Announce(hostile, info)
    CT.ShowSpellLine(hostile and "purge" or "dispel", info and info.name, info and info.icon)
end

local function Done(job)
    if job.ticker then
        job.ticker:Cancel()
        job.ticker = nil
    end
    for i = #jobs, 1, -1 do
        if jobs[i] == job then table.remove(jobs, i) end
    end
    if #jobs == 0 then wipe(claimed) end
    SyncWatch()
end

local function Step(job)
    job.steps = job.steps + 1

    local unit, snap, id, info = Find(job)
    if unit then
        claimed[id] = true
        Done(job)
        Announce(snap.hostile, info)
        return
    end

    if not job.readable or job.steps >= STEPS then
        local meter = FromMeter(job)
        if meter then
            Done(job)
            Announce(not job.friendly, meter)
            return
        elseif meter == false then
            Done(job)
            Announce(not job.friendly)
            return
        end
    end
    if job.steps < STEPS then return end

    Done(job)
    if job.friendly and ON_SUCCESS[job.id] and job.cooldownBefore == false and OwnCooldownRunning(job.id) == true then
        Announce(false)
    elseif not job.readable and not NO_GUESS[job.id] then
        Announce(not job.friendly)
    end
end

local function Begin(id, friendly, hostile, aim, who)
    return {
        id = id, friendly = friendly, hostile = hostile, aim = aim, who = who,
        meterSeq = meterSeq, steps = 0, units = {}, order = {}, sentAt = GetTime(),
    }
end

local function Sides(spellID)
    if type(spellID) ~= "number" or issecretvalue(spellID) then return nil end
    local kind = SPELLS[spellID]
    if not kind then return nil end
    local friendly = kind ~= PURGE and CT.Active("dispel") ~= nil
    local hostile = kind ~= DISPEL and CT.Active("purge") ~= nil
    if friendly or hostile then return friendly, hostile end
end

-- snapshot on send, before the aura goes
local function OnSent(spellID, aim)
    local friendly, hostile = Sides(spellID)
    if not (friendly or hostile) then return end
    if type(aim) ~= "string" or issecretvalue(aim) or aim == "" then aim = nil end

    local job = Begin(spellID, friendly, hostile, aim, "player")
    if ON_SUCCESS[spellID] then job.cooldownBefore = OwnCooldownRunning(spellID) end
    armed = job
    SnapAll(job)
    SyncWatch()
    C_Timer.After(ARMED_FOR, function()
        if armed == job then
            armed = nil
            SyncWatch()
        end
    end)
end

local function OnSucceeded(spellID, unit)
    local friendly, hostile = Sides(spellID)
    if not (friendly or hostile) then return end

    local job = armed
    if job and job.id == spellID and GetTime() - job.sentAt < ARMED_FOR then
        armed = nil
    else
        job = Begin(spellID, friendly, hostile, nil, unit == "pet" and "pet" or "player")
    end
    SnapAll(job)
    jobs[#jobs + 1] = job
    job.ticker = C_Timer.NewTicker(POLL, function() Step(job) end, STEPS)
    SyncWatch()
end

local function Reset()
    for i = #jobs, 1, -1 do
        if jobs[i].ticker then jobs[i].ticker:Cancel() end
        jobs[i] = nil
    end
    armed = nil
    wipe(claimed)
    SyncWatch()
end

-- SENT carries (unit, target, castGUID, spellID), SUCCEEDED carries (unit, castGUID, spellID)
casts:SetScript("OnEvent", function(_, event, unit, arg2, arg3, arg4)
    if CT.previewing then return end
    if event == "UNIT_SPELLCAST_SENT" then
        OnSent(arg4, arg2)
    else
        OnSucceeded(arg3, unit)
    end
end)

CT.OnApply(function(c)
    casts:UnregisterAllEvents()
    if c.enabled and (c.dispel.enabled or c.purge.enabled) then
        casts:RegisterUnitEvent("UNIT_SPELLCAST_SENT", "player")
        casts:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "pet")
    else
        Reset()
    end
end)
