---@class SUI : SF
local SUI = select(2, ...)

local VIEWER = "BuffIconCooldownViewer"
local TEXT_LEVEL_OFFSET = 30

local WEAK = { __mode = "k" }
-- per item frame: { holder, text, style, suppressed }
local overlays = setmetatable({}, WEAK)
local hookedAlpha = setmetatable({}, WEAK)
local hookedStyle = setmetatable({}, WEAK)
local hookedViewers = setmetatable({}, WEAK)

local tracked = {}
local updateQueued = false

local function Settings()
    return SwirlUIDB and SwirlUIDB.uiSettings and SwirlUIDB.uiSettings.cdmStacks
end

local function RefreshTracked(spells)
    wipe(tracked)
    for _, id in ipairs(spells) do
        tracked[id] = true
    end
end

local function IsTracked(spellID)
    return spellID ~= nil and not issecretvalue(spellID) and tracked[spellID] == true
end

local function MatchesTracked(frame)
    if not frame.GetCooldownID then return false end
    local cooldownID = frame:GetCooldownID()
    if not cooldownID or issecretvalue(cooldownID) then return false end

    local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(cooldownID)
    if not info then return false end

    if IsTracked(info.spellID) or IsTracked(info.overrideSpellID)
        or IsTracked(info.overrideTooltipSpellID) or IsTracked(info.linkedSpellID) then
        return true
    end
    if type(info.linkedSpellIDs) == "table" then
        for _, linked in ipairs(info.linkedSpellIDs) do
            if IsTracked(linked) then return true end
        end
    end
    return false
end

local function NativeText(frame)
    local container = frame.Applications
    return container and container.Applications
end

local function NativeIsEmpty(nativeText)
    local text = nativeText:GetText()
    if issecretvalue(text) then return false end
    return text == nil or text == ""
end

-- blizzard re-shows its count whenever the aura refreshes, so keep it at alpha 0 while we own the text
local function SetNativeSuppressed(overlay, nativeText, suppressed)
    overlay.suppressed = suppressed
    if suppressed and not hookedAlpha[nativeText] then
        hookedAlpha[nativeText] = true
        hooksecurefunc(nativeText, "SetAlpha", function(self, alpha)
            if overlay.suppressed and (issecretvalue(alpha) or alpha ~= 0) then
                self:SetAlpha(0)
            end
        end)
    end
    nativeText:SetAlpha(suppressed and 0 or 1)
end

local function GetOverlay(frame)
    local overlay = overlays[frame]
    if overlay then return overlay end

    local holder = CreateFrame("Frame", nil, frame)
    holder:SetAllPoints(frame)
    overlay = { holder = holder, text = holder:CreateFontString(nil, "OVERLAY") }
    overlays[frame] = overlay
    return overlay
end

-- EllesmereUI anchors the count to the icon itself, blizzard's own anchors hang off an inner frame
local function IsStyledByEllesmere()
    return C_AddOns.IsAddOnLoaded("EllesmereUICooldownManager")
end

local function SampleStyle(overlay, nativeText)
    local path, size, flags = nativeText:GetFont()
    local point, relativeTo, relativePoint, x, y = nativeText:GetPoint(1)
    if not (path and size and size > 0 and point) then return end
    if IsStyledByEllesmere() and relativeTo ~= overlay.holder:GetParent() then return end

    local r, g, b = nativeText:GetTextColor()
    -- an inactive item reports its anchor as secret, keep the last good sample
    if issecretvalue(point) or issecretvalue(relativePoint) or issecretvalue(x) or issecretvalue(y)
        or issecretvalue(r) or issecretvalue(g) or issecretvalue(b) then
        return
    end
    local text = overlay.text
    text:SetFont(path, size, flags or "")
    text:SetTextColor(r or 1, g or 1, b or 1, 1)
    text:SetAlpha(1)
    text:SetJustifyH(nativeText:GetJustifyH() or "RIGHT")
    text:ClearAllPoints()
    text:SetPoint(point, relativeTo or overlay.holder:GetParent(), relativePoint or point, x or 0, y or 0)
    overlay.styled = true
end

-- restyles of the native count (font, anchor) are copied on the next frame, once the whole restyle is done
local function WatchNativeStyle(overlay, nativeText)
    if hookedStyle[nativeText] then return end
    hookedStyle[nativeText] = true

    local pending = false
    local function Resample()
        if pending then return end
        pending = true
        C_Timer.After(0, function()
            pending = false
            if overlay.suppressed then SampleStyle(overlay, nativeText) end
        end)
    end
    hooksecurefunc(nativeText, "SetFont", Resample)
    hooksecurefunc(nativeText, "SetPoint", Resample)
end

local function ReadApplications(frame)
    local instanceID, unit = frame.auraInstanceID, frame.auraDataUnit
    if not issecretvalue(instanceID) and not issecretvalue(unit) and instanceID and unit then
        local ok, data = pcall(C_UnitAuras.GetAuraDataByAuraInstanceID, unit, instanceID)
        if ok and data then
            local applications = data.applications
            if issecretvalue(applications) or applications ~= nil then return applications end
        end
    end
    local cached = frame.auraDataCached
    return cached and cached.applications
end

local function ToDisplayCount(applications)
    if issecretvalue(applications) then return applications end
    if type(applications) ~= "number" or applications < 1 then return 1 end
    return applications
end

local function IsItemActive(frame)
    if not frame:IsVisible() then return false end
    if not frame.IsActive then return true end
    local active = frame:IsActive()
    return issecretvalue(active) or active == true
end

local function ShowCount(frame)
    local nativeText = NativeText(frame)
    if not nativeText then return end

    local overlay = GetOverlay(frame)
    if not overlay.styled or NativeIsEmpty(nativeText) then
        SampleStyle(overlay, nativeText)
    end
    SetNativeSuppressed(overlay, nativeText, true)
    WatchNativeStyle(overlay, nativeText)

    if not (overlay.styled and IsItemActive(frame)) then
        overlay.holder:Hide()
        return
    end

    overlay.holder:SetFrameLevel(frame:GetFrameLevel() + TEXT_LEVEL_OFFSET)
    overlay.text:SetText(ToDisplayCount(ReadApplications(frame)))
    overlay.holder:Show()
end

local function ReleaseCount(frame)
    local overlay = overlays[frame]
    if not overlay then return end

    overlay.holder:Hide()
    if overlay.suppressed then
        local nativeText = NativeText(frame)
        if nativeText then SetNativeSuppressed(overlay, nativeText, false) end
    end
end

local function Update()
    updateQueued = false

    local settings = Settings()
    local active = settings and settings.enabled
    if active then RefreshTracked(settings.spells) end

    local viewer = _G[VIEWER]
    local frames = viewer and viewer.GetItemFrames and viewer:GetItemFrames()
    if type(frames) ~= "table" then return end

    for _, frame in ipairs(frames) do
        if active and MatchesTracked(frame) then
            ShowCount(frame)
        else
            ReleaseCount(frame)
        end
    end
end

local function QueueUpdate()
    if updateQueued then return end
    updateQueued = true
    -- blizzard's own aura handlers have to refresh the item first
    C_Timer.After(0, Update)
end

local function HookViewer()
    local viewer = _G[VIEWER]
    if not viewer or hookedViewers[viewer] or not viewer.RefreshData then return end
    hookedViewers[viewer] = true
    hooksecurefunc(viewer, "RefreshData", QueueUpdate)
end

function SUI.ApplyCooldownManagerSettings()
    if not (C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCooldownInfo) then return end
    HookViewer()
    Update()
end

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
watcher:RegisterUnitEvent("UNIT_AURA", "player")
watcher:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" then
        SUI.ApplyCooldownManagerSettings()
        return
    end
    local settings = Settings()
    if settings and settings.enabled and #settings.spells > 0 then QueueUpdate() end
end)
