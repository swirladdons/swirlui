---@class SUI : SF
local SUI = select(2, ...)
local C = SUI.Components

local function T() return SUI.Theme end

local GetSpecialization = C_SpecializationInfo and C_SpecializationInfo.GetSpecialization or GetSpecialization
local GetSpecializationInfo = C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo or GetSpecializationInfo
local GetNumSpecializations = C_SpecializationInfo and C_SpecializationInfo.GetNumSpecializations or GetNumSpecializations

-- vault cast id, from atrocityEssentials, unverified
local VAULT_SPELL_ID = 1271478
local CAST_EVENTS = {
    "UNIT_SPELLCAST_START",
    "UNIT_SPELLCAST_SUCCEEDED",
    "UNIT_SPELLCAST_INTERRUPTED",
    "UNIT_SPELLCAST_STOP",
}

local function Settings()
    return SwirlUIDB and SwirlUIDB.uiSettings and SwirlUIDB.uiSettings.greatVault
end

local function BarSettings()
    return SwirlUIDB and SwirlUIDB.uiSettings and SwirlUIDB.uiSettings.lootSpecBar
end

---@return table[] specs of the player's class as { id, name, icon }
local function Specs()
    local specs = {}
    for index = 1, GetNumSpecializations() do
        local id, name, _, icon = GetSpecializationInfo(index)
        if id then specs[#specs + 1] = { id = id, name = name, icon = icon } end
    end
    return specs
end

-- loot spec 0 is the current spec
local function LootSpec()
    local lootID = GetLootSpecialization()
    local current = GetSpecialization()
    for index, spec in ipairs(Specs()) do
        if lootID > 0 and spec.id == lootID or lootID == 0 and index == current then
            return spec
        end
    end
end

------------------------------------------------------------------------
-- Great Vault alert
------------------------------------------------------------------------
local alert, alertTimer

local function BuildMessage()
    local spec = LootSpec()
    if not spec then return end
    local class = select(2, UnitClass("player"))
    local color = RAID_CLASS_COLORS[class]
    return string.format("Opening %s as: |c%s|T%d:0|t %s|r",
        T().accent:WrapTextInColorCode("[" .. (GREAT_VAULT or "Great Vault") .. "]"),
        color and color.colorStr or "ffffffff", spec.icon, spec.name)
end

local function StyleAlert()
    local settings = Settings()
    alert:ClearAllPoints()
    alert:SetPoint("CENTER", UIParent, "CENTER", settings.x, settings.y)
    alert:SetHeight(settings.fontSize)
    alert.text:SetFont(T().font.path, settings.fontSize, "OUTLINE")
    alert.text:SetShadowOffset(0, 0)
end

local function CreateAlert()
    alert = CreateFrame("Frame", "SwirlUIGreatVaultAlert", UIParent)
    alert:SetSize(400, 30)
    alert:SetFrameStrata("HIGH")
    alert:Hide()
    alert.text = alert:CreateFontString(nil, "OVERLAY")
    alert.text:SetPoint("CENTER")
end

local function HideAlert()
    if alertTimer then alertTimer:Cancel(); alertTimer = nil end
    if alert then alert:Hide() end
end

local function ShowAlert(message, duration)
    if not alert then CreateAlert() end
    StyleAlert()
    alert.text:SetText(message)
    alert:SetWidth(alert.text:GetStringWidth() + 20)
    alert:Show()

    if alertTimer then alertTimer:Cancel(); alertTimer = nil end
    if duration then
        alertTimer = C_Timer.NewTimer(duration, HideAlert)
    end
end

function SUI.PreviewGreatVaultAlert()
    local settings = Settings()
    local message = BuildMessage()
    if not settings or not message then return end
    ShowAlert(message, settings.duration)
end

------------------------------------------------------------------------
-- Loot specialization bar
------------------------------------------------------------------------
local BAR_HEIGHT = 40
local BUTTON_HEIGHT = 32
local BUTTON_GAP = 4
local BUTTON_PADDING = 24
local TITLE_HEIGHT = 18
local BAR_GAP = 4
local PREVIEW_DURATION = 10

local bar, hideTimer
local vaultCasting = false
local buttons = {}

local function HideBar()
    if hideTimer then hideTimer:Cancel(); hideTimer = nil end
    if bar then bar:Hide() end
end

local function SchedulePreviewHide()
    if hideTimer then hideTimer:Cancel() end
    hideTimer = C_Timer.NewTimer(PREVIEW_DURATION, HideBar)
end

local function UpdateButton(button)
    local selected = button.specID == GetLootSpecialization()
    local theme = T()
    if selected then
        local a, c = theme.accentFade, theme.accent
        button:SetBackdropColor(a.r, a.g, a.b, a.a)
        button:SetBackdropBorderColor(c.r, c.g, c.b, 1)
        button.text:SetTextColor(1, 1, 1)
    else
        local b, c = theme.bg.med, theme.border.color
        button:SetBackdropColor(b.r, b.g, b.b, b.a)
        button:SetBackdropBorderColor(c.r, c.g, c.b, c.a)
        button.text:SetTextColor(theme.text.secondary.r, theme.text.secondary.g, theme.text.secondary.b)
    end
    button.selected = selected
end

local function CreateButton()
    local button = CreateFrame("Button", nil, bar.row, "SecureActionButtonTemplate, BackdropTemplate")
    -- SpellStopCasting is protected
    button:RegisterForClicks("AnyUp", "AnyDown")
    button:SetAttribute("type", "macro")
    button:SetAttribute("macrotext", "/stopcasting")
    button:SetHeight(BUTTON_HEIGHT)
    C.SetBackdrop(button)
    button.text = button:CreateFontString(nil, "OVERLAY")
    C.ApplyFont(button.text, "normal")
    button.text:SetPoint("CENTER")

    -- after the secure stop
    button:HookScript("PostClick", function(self)
        if self.specID ~= GetLootSpecialization() then SetLootSpecialization(self.specID) end
    end)
    button:SetScript("OnEnter", function(self)
        if self.selected then return end
        local d = T().accentDim
        self:SetBackdropBorderColor(d.r, d.g, d.b, 1)
    end)
    button:SetScript("OnLeave", UpdateButton)
    return button
end

local function Rebuild()
    if not bar or InCombatLockdown() then return end

    local entries = { { id = 0, label = "Current Spec" } }
    for _, spec in ipairs(Specs()) do
        entries[#entries + 1] = { id = spec.id, label = string.format("|T%d:14:14:0:0:64:64:5:59:5:59|t %s", spec.icon, spec.name) }
    end

    local x = 0
    for index, entry in ipairs(entries) do
        local button = buttons[index] or CreateButton()
        buttons[index] = button
        button.specID = entry.id
        button.text:SetText(entry.label)
        button:SetWidth(button.text:GetStringWidth() + BUTTON_PADDING)
        button:ClearAllPoints()
        button:SetPoint("LEFT", bar.row, "LEFT", x, 0)
        button:Show()
        x = x + button:GetWidth() + BUTTON_GAP
        UpdateButton(button)
    end
    for index = #entries + 1, #buttons do buttons[index]:Hide() end

    local rowWidth = x - BUTTON_GAP
    bar.row:SetSize(rowWidth, BUTTON_HEIGHT)
    bar:SetSize(rowWidth + BUTTON_GAP * 2, TITLE_HEIGHT + BAR_HEIGHT)
end

-- anchored above the alert
local function Position()
    if not alert then CreateAlert() end
    StyleAlert()
    bar:ClearAllPoints()
    bar:SetPoint("BOTTOM", alert, "TOP", 0, BAR_GAP)
end

local function CreateBar()
    bar = CreateFrame("Frame", "SwirlUILootSpecBar", UIParent)
    bar:SetFrameStrata("MEDIUM")
    bar:Hide()

    bar.title = bar:CreateFontString(nil, "OVERLAY")
    C.ApplyFont(bar.title, "normal")
    bar.title:SetPoint("TOP", bar, "TOP", 0, 0)
    bar.title:SetText("Loot Specialization")
    local accent = T().accent
    bar.title:SetTextColor(accent.r, accent.g, accent.b)

    bar.back = CreateFrame("Frame", nil, bar, "BackdropTemplate")
    bar.back:SetPoint("BOTTOMLEFT")
    bar.back:SetPoint("BOTTOMRIGHT")
    bar.back:SetHeight(BAR_HEIGHT)
    C.SetBackdrop(bar.back, SUI.Skins.bg, T().border.color)

    bar.row = CreateFrame("Frame", nil, bar.back)
    bar.row:SetPoint("CENTER", bar.back, "CENTER")

    bar:SetScript("OnShow", function(self)
        self:RegisterEvent("PLAYER_LOOT_SPEC_UPDATED")
        self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    end)
    bar:SetScript("OnHide", function(self)
        self:UnregisterEvent("PLAYER_LOOT_SPEC_UPDATED")
        self:UnregisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    end)
    bar:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_SPECIALIZATION_CHANGED" then
            Rebuild()
        else
            for _, button in ipairs(buttons) do
                if button:IsShown() then UpdateButton(button) end
            end
        end
    end)
end

local function ShowBar()
    if not bar then
        if InCombatLockdown() then return end
        CreateBar()
    end
    Position()
    Rebuild()
    bar:Show()
end

function SUI.PreviewLootSpecBar()
    if not BarSettings() then return end
    ShowBar()
    SchedulePreviewHide()
end

function SUI.ApplyLootSpecBar()
    local settings = BarSettings()
    if not settings or not bar then return end
    if not settings.enabled then
        HideBar()
        return
    end
    Position()
    if bar:IsShown() and not vaultCasting then SchedulePreviewHide() end
end

------------------------------------------------------------------------
-- Vault cast
------------------------------------------------------------------------
local watcher

local function OnCast(_, event, _, _, spellID)
    if issecretvalue(spellID) or spellID ~= VAULT_SPELL_ID then return end

    if event ~= "UNIT_SPELLCAST_START" then
        vaultCasting = false
        HideAlert()
        HideBar()
        return
    end

    vaultCasting = true
    local alertSettings, barSettings = Settings(), BarSettings()
    local message = BuildMessage()
    if alertSettings.enabled and message then
        ShowAlert(message, alertSettings.duration)
        if alertSettings.chatMessage then SUI.Utils:Print(message) end
    end
    if barSettings.enabled then
        if hideTimer then hideTimer:Cancel(); hideTimer = nil end
        ShowBar()
    end
end

function SUI.ApplyGreatVaultAlert()
    local settings, barSettings = Settings(), BarSettings()
    if not settings then return end

    if not watcher then
        watcher = CreateFrame("Frame")
        watcher:SetScript("OnEvent", OnCast)
    end

    for _, event in ipairs(CAST_EVENTS) do
        if settings.enabled or barSettings.enabled then
            watcher:RegisterUnitEvent(event, "player")
        else
            watcher:UnregisterEvent(event)
        end
    end

    if not settings.enabled then
        HideAlert()
    elseif alert then
        StyleAlert()
    end
end
