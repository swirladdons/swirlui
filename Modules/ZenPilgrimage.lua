---@class SUI
local SUI = select(2, ...)

local SPELL_ID = 126892
local GCD_MAX = 1.5

local frame

local function Settings()
    return SwirlUIDB and SwirlUIDB.uiSettings and SwirlUIDB.uiSettings.zenPilgrimage
end

local function CreateIcon()
    frame = CreateFrame("Frame", nil, UIParent)
    frame:SetFrameStrata("MEDIUM")
    frame:Hide()

    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", -1, 1)
    bg:SetPoint("BOTTOMRIGHT", 1, -1)
    bg:SetColorTexture(0, 0, 0, 1)

    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture(C_Spell.GetSpellTexture(SPELL_ID))
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    frame.cd = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
    frame.cd:SetAllPoints()
    frame.cd:SetDrawEdge(false)
    frame.cd:SetHideCountdownNumbers(false)
    frame.cd:SetScript("OnCooldownDone", function() frame:Hide() end)
end

local function Update()
    local settings = Settings()
    if not settings or not settings.enabled then
        if frame then frame:Hide() end
        return
    end

    local info = C_Spell.GetSpellCooldown(SPELL_ID)
    -- unreadable in combat: leave the running swipe alone, OnCooldownDone still hides it
    if not info or issecretvalue(info.duration) or issecretvalue(info.startTime) then return end

    if info.duration > GCD_MAX then
        if not frame then CreateIcon() end
        frame:SetSize(settings.size, settings.size)
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", settings.offsetX, settings.offsetY)
        frame.cd:SetCooldown(info.startTime, info.duration)
        frame:Show()
    elseif frame then
        frame:Hide()
    end
end

function SUI.ApplyZenPilgrimage()
    Update()
end

if select(2, UnitClass("player")) == "MONK" then
    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
    watcher:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    watcher:RegisterEvent("PLAYER_REGEN_ENABLED")
    watcher:SetScript("OnEvent", Update)
end
