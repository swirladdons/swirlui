---@class SUI : SF
local SUI = select(2, ...)
local CT = SUI.CombatText

local issecretvalue = issecretvalue

local EQUIP_SLOTS = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17 }

local inCombat = UnitAffectingCombat("player") and true or false

local durabilityPending = false

local function CheckDurability()
    durabilityPending = false
    if CT.previewing then return end

    local msg = CT.Active("lowDurability")
    if not msg or inCombat then
        CT.HidePersistent("lowDurability")
        return
    end

    local threshold = msg.threshold / 100
    for _, slot in ipairs(EQUIP_SLOTS) do
        local current, maximum = GetInventoryItemDurability(slot)
        if current and maximum and maximum > 0 and current / maximum < threshold then
            CT.ShowPersistent("lowDurability")
            return
        end
    end
    CT.HidePersistent("lowDurability")
end

-- UPDATE_INVENTORY_DURABILITY arrives in bursts
local function QueueDurabilityCheck()
    if durabilityPending then return end
    durabilityPending = true
    C_Timer.After(0.5, CheckDurability)
end

local function UpdateNoTarget()
    local frame = CT.EnsureNoTarget()
    local c = CT.Cfg()
    local msg = c and c.noTarget

    if CT.previewing then
        frame:SetAlpha(1)
        frame:SetShown(c.enabled and msg.enabled)
        return
    end
    if not (c and c.enabled and msg.enabled and inCombat) then
        frame:Hide()
        return
    end

    local meDead = UnitIsDeadOrGhost("player")
    if not issecretvalue(meDead) and meDead then
        frame:Hide()
        return
    end

    if not UnitExists("target") then
        frame:SetAlpha(1)
        frame:Show()
        return
    end
    if not msg.includeDead then
        frame:Hide()
        return
    end

    local dead = UnitIsDeadOrGhost("target")
    if issecretvalue(dead) then
        if frame.SetAlphaFromBoolean then
            frame:SetAlphaFromBoolean(dead, 1, 0)
            frame:Show()
        else
            frame:Hide()
        end
        return
    end
    frame:SetAlpha(1)
    frame:SetShown(dead and true or false)
end

local function OnCombatEnter()
    inCombat = true
    CT.HidePersistent("lowDurability")
    UpdateNoTarget()
    CT.Show("enterCombat")
end

local function OnCombatLeave()
    inCombat = false
    UpdateNoTarget()
    CT.Show("exitCombat")
    QueueDurabilityCheck()
end

local targetEvents = CreateFrame("Frame")
targetEvents:SetScript("OnEvent", UpdateNoTarget)

local function SyncTargetWatch(c)
    targetEvents:UnregisterAllEvents()
    if c.enabled and c.noTarget.enabled then
        targetEvents:RegisterEvent("PLAYER_TARGET_CHANGED")
        if c.noTarget.includeDead then targetEvents:RegisterUnitEvent("UNIT_HEALTH", "target") end
    end
end

CT.OnApply(function(c)
    SyncTargetWatch(c)
    UpdateNoTarget()
    CheckDurability()
end)

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("PLAYER_DEAD")
events:RegisterEvent("UPDATE_INVENTORY_DURABILITY")
events:SetScript("OnEvent", function(_, event)
    if CT.previewing and event ~= "PLAYER_ENTERING_WORLD" then return end
    if event == "PLAYER_REGEN_DISABLED" then
        OnCombatEnter()
    elseif event == "PLAYER_REGEN_ENABLED" then
        OnCombatLeave()
    elseif event == "PLAYER_DEAD" then
        UpdateNoTarget()
    elseif event == "UPDATE_INVENTORY_DURABILITY" then
        QueueDurabilityCheck()
    else
        inCombat = UnitAffectingCombat("player") and true or false
        UpdateNoTarget()
        QueueDurabilityCheck()
    end
end)
