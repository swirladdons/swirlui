---@class SUI : SF
local SUI = select(2, ...)
local CT = SUI.CombatText

local issecretvalue = issecretvalue
local Ask = CT.Ask

local INTERRUPT_SET = {}
for _, id in ipairs({
    6552, 1766, 2139, 57994, 47528, 183752, 116705, 96231, 31935, 147362, 187707, 106839,
    78675, 15487, 351338, 19647, 132409, 89766, 119914, 119910, 1276467, 115781,
}) do
    INTERRUPT_SET[id] = true
end

-- interrupts that land a moment after the cast, so the kick is judged later
local SLOW_KICK = {
    [89766] = true, [119914] = true, [132409] = true, [147362] = true, [119910] = true,
    [1276467] = true, [31935] = true,
}
-- avenger's shield also damages, so a cast without an interrupt is not a missed kick
local NOT_A_MISS = { [31935] = true }
local BLACKLIST = { [240447] = true, [240448] = true }

local KICK_WINDOW, KICK_EARLY, MISS_AFTER = 0.6, 0.05, 0.25
local ANNOUNCE_GAP = 0.4

local kickUntil, lastLanded, lastHidden, lastAnnounce = -10, -10, -10, -10
local kickTimer

local function OnPlayerCast(spellID)
    if issecretvalue(spellID) or not (spellID and INTERRUPT_SET[spellID]) then return end

    local kickAt = GetTime()
    local wait = SLOW_KICK[spellID] and KICK_WINDOW or MISS_AFTER
    kickUntil = kickAt + wait
    if NOT_A_MISS[spellID] or not CT.Active("missedKick") then return end

    if kickTimer then kickTimer:Cancel() end
    kickTimer = C_Timer.NewTimer(wait, function()
        kickTimer = nil
        if math.max(lastLanded, lastHidden) < kickAt - KICK_EARLY then
            CT.Show("missedKick")
        end
    end)
end

local function IsMine(interruptedBy)
    if interruptedBy == UnitGUID("player") then return true end
    local petGUID = UnitGUID("pet")
    return petGUID ~= nil and interruptedBy == petGUID
end

local function OnUnitInterrupted(unit, spellID, interruptedBy)
    if CT.previewing or not (CT.Cfg() and CT.Cfg().enabled) then return end

    local unitKnown = type(unit) == "string" and not issecretvalue(unit)
    if unitKnown and (unit == "player" or unit == "pet") then return end
    if unitKnown and Ask(UnitCanAttack, "player", unit) == false then return end

    if unitKnown and not issecretvalue(interruptedBy) and interruptedBy ~= nil then
        if not IsMine(interruptedBy) then return end
    else
        -- the interrupter is hidden, only a kick cast a moment ago can be ours
        lastHidden = GetTime()
        if GetTime() > kickUntil then return end
    end

    lastLanded = GetTime()
    if not unitKnown or not CT.Active("interrupt") then return end
    if GetTime() - lastAnnounce < ANNOUNCE_GAP then return end
    lastAnnounce = GetTime()

    local name, texture
    if spellID ~= nil then
        if not issecretvalue(spellID) and BLACKLIST[spellID] then return end
        -- both calls accept a secret spell id
        local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
        if ok and info then
            name, texture = info.name, info.iconID
        end
    end
    CT.ShowSpellLine("interrupt", name, texture)
end

local castEvents = CreateFrame("Frame")
castEvents:SetScript("OnEvent", function(_, event, unit, _, spellID, interruptedBy)
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        OnPlayerCast(spellID)
    elseif event == "UNIT_SPELLCAST_INTERRUPTED" or issecretvalue(interruptedBy) or interruptedBy ~= nil then
        -- a channel that simply ends raises CHANNEL_STOP without an interrupter
        OnUnitInterrupted(unit, spellID, interruptedBy)
    end
end)

-- INTERRUPTED and CHANNEL_STOP cannot be filtered to a unit, so they are only heard while needed
CT.OnApply(function(c)
    castEvents:UnregisterAllEvents()
    if not c.enabled or not (c.interrupt.enabled or c.missedKick.enabled) then return end
    castEvents:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "pet")
    castEvents:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
    castEvents:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
end)
