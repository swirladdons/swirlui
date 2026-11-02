---@class SUI : SF
local SUI = select(2, ...)

local MODULE = "EllesmereUIUnitFrames"
local UNITS = { "target", "focus", "boss1", "boss2", "boss3", "boss4", "boss5", "boss6", "boss7", "boss8" }

local hooked = false
local tweaked = {}

local function Enabled()
    local settings = SwirlUIDB and SwirlUIDB.uiSettings and SwirlUIDB.uiSettings.ellesmere
    return settings and settings.powerTextAboveCastbar
end

local function ModuleNS()
    return EllesmereUI and EllesmereUI._ModuleNS and EllesmereUI._ModuleNS[MODULE]
end

local function ApplyFrame(frame, enabled)
    local power = frame.Power
    local ovr = power and power._ppTextOvr
    if not ovr then return end

    if enabled then
        local cbg = frame.Castbar and frame.Castbar:GetParent()
        if not cbg then return end
        ovr:SetFrameStrata(cbg:GetFrameStrata())
        ovr:SetFrameLevel(cbg:GetFrameLevel() + 10)
    else
        local ns = ModuleNS()
        local settings = frame.Castbar and frame.Castbar._eufSettings
        if ns and ns.UpdatePowerBorder and settings then
            ns.UpdatePowerBorder(power, settings)
        else
            ovr:SetFrameStrata(frame:GetFrameStrata())
            ovr:SetFrameLevel(frame:GetFrameLevel() + 15)
        end
    end
end

local function Apply()
    local ns = ModuleNS()
    local frames = ns and ns.frames
    if not frames then return false end

    local enabled = Enabled()

    wipe(tweaked)
    for _, unit in ipairs(UNITS) do
        local frame = frames[unit]
        if frame then
            tweaked[frame] = true
            ApplyFrame(frame, enabled)
        end
    end

    if not hooked and ns.UpdatePowerBorder then
        hooked = true
        -- eui resets strata and level here, sooo reapply
        hooksecurefunc(ns, "UpdatePowerBorder", function(power)
            if not Enabled() then return end
            local frame = power:GetParent()
            if frame and tweaked[frame] then
                ApplyFrame(frame, true)
            end
        end)
    end

    return true
end

-- ns.frames isn't ready at login, so retry
local function ApplyWhenReady(attempt)
    attempt = attempt or 1
    if Apply() or attempt > 20 then return end
    C_Timer.After(0.25, function() ApplyWhenReady(attempt + 1) end)
end

local ICON_DIR = "Interface\\AddOns\\SharedMedia_SwirlUI\\background\\bad icons\\"
local SPEC_ICON_FILES = {
    [250] = "Spell_Deathknight_BloodPresence", [251] = "Spell_Deathknight_FrostPresence", [252] = "Spell_Deathknight_UnholyPresence",
    [577] = "Ability_DemonHunter_SpecDPS", [581] = "Ability_DemonHunter_SpecTank", [1480] = "ClassIcon_DemonHunter_Void",
    [102] = "Spell_Nature_StarFall", [103] = "Ability_druid_catform", [104] = "Ability_Racial_BearForm", [105] = "SPELL_NATURE_HEALINGTOUCH",
    [1467] = "ClassIcon_Evoker_Devastation", [1468] = "ClassIcon_Evoker_Preservation", [1473] = "ClassIcon_Evoker_Augmentation",
    [253] = "ABILITY_HUNTER_BESTIALDISCIPLINE", [254] = "Ability_Hunter_FocusedAim", [255] = "Ability_Hunter_Camouflage",
    [62] = "Spell_Holy_MagicalSentry", [63] = "Spell_Fire_FireBolt02", [64] = "Spell_Frost_FrostBolt02",
    [268] = "Spell_Monk_Brewmaster_Spec", [270] = "Spell_Monk_MistWeaver_Spec", [269] = "Spell_Monk_WindWalker_Spec",
    [65] = "Spell_Holy_HolyBolt", [66] = "Ability_Paladin_ShieldoftheTemplar", [70] = "Spell_Holy_AuraOfLight",
    [256] = "Spell_Holy_PowerWordShield", [257] = "Spell_Holy_GuardianSpirit", [258] = "Spell_Shadow_ShadowWordPain",
    [259] = "Ability_Rogue_DeadlyBrew", [260] = "Ability_Rogue_Waylay", [261] = "Ability_Stealth",
    [262] = "Spell_Nature_Lightning", [263] = "Spell_Shaman_ImprovedStormstrike", [264] = "Spell_Nature_MagicImmunity",
    [265] = "Spell_Shadow_DeathCoil", [266] = "Spell_Shadow_Metamorphosis", [267] = "Spell_Shadow_RainOfFire",
    [71] = "Ability_Warrior_SavageBlow", [72] = "Ability_Warrior_InnerRage", [73] = "Ability_Warrior_DefensiveStance",
}

local specIcons
local hookedIcons = setmetatable({}, { __mode = "k" })
local repainting = false

local function SpecIconsEnabled()
    local settings = SwirlUIDB and SwirlUIDB.uiSettings and SwirlUIDB.uiSettings.ellesmere
    return settings and settings.damageMeterSpecIcons
end

local function SpecIconPath(fileID)
    if not specIcons then
        specIcons = {}
        for specID, file in pairs(SPEC_ICON_FILES) do
            local icon = select(4, GetSpecializationInfoByID(specID))
            if icon then specIcons[icon] = ICON_DIR .. file end
        end
    end
    return type(fileID) == "number" and specIcons[fileID]
end

local function Repaint(texture, fileID)
    if repainting or not SpecIconsEnabled() then return end
    local path = SpecIconPath(fileID)
    if not path then return end
    repainting = true
    texture:SetTexture(path)
    repainting = false
end

local function HookIcon(texture)
    if not texture or hookedIcons[texture] then return end
    hookedIcons[texture] = true
    hooksecurefunc(texture, "SetTexture", Repaint)
    Repaint(texture, texture:GetTexture())
end

local function HookWindowIcons(window)
    for _, bar in ipairs(window.rowPool or {}) do HookIcon(bar.classIcon) end
    if window.stickyPlayer then HookIcon(window.stickyPlayer.classIcon) end
end

local hookedWindows = setmetatable({}, { __mode = "k" })
local meterHooked = false

local function HookWindows(ns)
    for _, window in pairs(ns._windows) do
        if not hookedWindows[window] then
            hookedWindows[window] = true
            for _, method in ipairs({ "Refresh", "UpdateSticky" }) do
                if type(window[method]) == "function" then
                    hooksecurefunc(window, method, function() HookWindowIcons(window) end)
                end
            end
        end
        HookWindowIcons(window)
    end
end

local function ApplyDamageMeterIcons(attempt)
    attempt = attempt or 1
    local ns = EllesmereUI and EllesmereUI._ModuleNS and EllesmereUI._ModuleNS.EllesmereUIDamageMeters
    if not (ns and ns._windows) then
        if attempt <= 20 then C_Timer.After(0.25, function() ApplyDamageMeterIcons(attempt + 1) end) end
        return
    end

    if not meterHooked then
        meterHooked = true
        -- windows are built one per frame at login and added later, and both paths run these
        for _, method in ipairs({ "ApplyWindowBorder", "DMAcquireWindow" }) do
            if type(ns[method]) == "function" then
                hooksecurefunc(ns, method, function()
                    C_Timer.After(0, function() HookWindows(ns) end)
                end)
            end
        end
    end
    HookWindows(ns)
end

function SUI.ApplyEllesmereSettings()
    ApplyWhenReady()
    if SpecIconsEnabled() then ApplyDamageMeterIcons() end
end

local localeHooked = false

-- eui's tooltip target line looks its label and "You" up through EllesmereUI.L on every pass
local function HookTooltipTarget()
    if localeHooked or not (EllesmereUI and EllesmereUI.L) then return end
    localeHooked = true

    local L = EllesmereUI.L
    EllesmereUI.L = function(s)
        local settings = SwirlUIDB and SwirlUIDB.uiSettings and SwirlUIDB.uiSettings.ellesmere
        if settings and settings.tooltipTargetLine and not issecretvalue(s) then
            if s == "Targeting:" then return "Target:" end
            if s == "You" then return "|cffff4400YOU|r" end
        end
        return L(s)
    end
end

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
watcher:SetScript("OnEvent", function()
    HookTooltipTarget()
    ApplyWhenReady()
end)
