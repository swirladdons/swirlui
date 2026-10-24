---@class SUI
local SUI = select(2, ...)

local frame

local function Say(message)
    print(string.format("%s %s", SUI.Header, message))
end

local function HoveredButton()
    for slot = 1, 180 do
        local btn = _G["EABButton" .. slot]
        if btn and btn.commandName and btn:IsVisible() and btn:IsMouseOver() then
            return btn
        end
    end
end

local function HoveredCommand()
    local btn = HoveredButton()
    return btn and btn.commandName
end

local function UpdateTooltip(btn)
    if not btn then
        GameTooltip:Hide()
        return
    end
    -- owned by the bind frame: an action button owner refreshes the tooltip back to its spell
    GameTooltip:SetOwner(frame, "ANCHOR_NONE")
    GameTooltip:SetPoint("BOTTOMLEFT", btn, "TOPRIGHT")
    GameTooltip_AddHighlightLine(GameTooltip, GetBindingName(btn.commandName))
    local keys = { GetBindingKey(btn.commandName) }
    if #keys > 0 then
        for _, key in ipairs(keys) do
            GameTooltip_AddInstructionLine(GameTooltip, GetBindingText(key))
        end
        GameTooltip_AddNormalLine(GameTooltip, ESCAPE_TO_UNBIND)
    else
        GameTooltip_AddErrorLine(GameTooltip, NOT_BOUND)
    end
    GameTooltip_AddNormalLine(GameTooltip, PRESS_KEY_TO_BIND)
    GameTooltip:Show()
end

-- the bind frame eats mouse motion, so the buttons never show their own hover
local function UpdateHighlight(self)
    local btn = HoveredButton()
    if btn == self.hovered then return end
    self.hovered = btn
    self.highlight:ClearAllPoints()
    if btn then
        self.highlight:SetAllPoints(btn)
    end
    self.highlight:SetShown(btn ~= nil)
    UpdateTooltip(btn)
end

local function ActionBarsNS()
    local ns = EllesmereUI and EllesmereUI._ModuleNS and EllesmereUI._ModuleNS.EllesmereUIActionBars
    return ns and ns.EAB and ns._internals and ns
end

-- the bars get no hover while the bind frame is up, so mouseover bars would stay faded out
local function RevealMouseoverBars()
    local ns = ActionBarsNS()
    if not ns or not frame:IsShown() then return end
    local I = ns._internals
    for _, info in ipairs(I.BAR_CONFIG) do
        local s = ns.EAB.db.profile.bars[info.key]
        local bar = I.barFrames[info.key]
        if bar and s and s.mouseoverEnabled then
            I.StopFade(bar, 1)
            if info.key == "MainBar" then I.SyncPagingAlpha(1) end
        end
    end
end

local function Stop()
    frame:Hide()
    GameTooltip:Hide()
    frame.hovered = nil
    frame.highlight:ClearAllPoints()
    frame.highlight:Hide()
    local ns = ActionBarsNS()
    if ns then ns.EAB:RefreshMouseover() end
    SaveBindings(GetCurrentBindingSet())
    Say("Keybind mode off, bindings saved.")
end

-- adds the key on top of whatever the slot already has, unlike eui's quick keybind
local function OnInput(input)
    local command = HoveredCommand()

    if input == "ESCAPE" then
        if not command then
            Stop()
            return
        end
        for _, key in ipairs({ GetBindingKey(command) }) do
            SetBinding(key, nil)
        end
        Say(GetBindingName(command) .. ": unbound")
        UpdateTooltip(HoveredButton())
        return
    end

    if not command or input == "LeftButton" or input == "RightButton" then return end

    input = GetConvertedKeyOrButton(input)
    if IsKeyPressIgnoredForBinding(input) then return end

    if SetBinding(CreateKeyChordStringUsingMetaKeyState(input), command) then
        Say(GetBindingName(command) .. ": " .. table.concat({ GetBindingKey(command) }, ", "))
        UpdateTooltip(HoveredButton())
    end
end

local function CreateBindFrame()
    frame = CreateFrame("Frame", nil, UIParent)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetAllPoints(UIParent)
    frame:EnableMouse(true)
    frame:EnableKeyboard(true)
    frame:EnableMouseWheel(true)
    frame:Hide()

    local dim = frame:CreateTexture(nil, "BACKGROUND")
    dim:SetAllPoints()
    dim:SetColorTexture(0, 0, 0, 0.3)

    frame.highlight = frame:CreateTexture(nil, "OVERLAY")
    frame.highlight:SetColorTexture(0.01, 0.99, 0.6, 0.35)
    frame.highlight:Hide()

    frame:SetScript("OnUpdate", UpdateHighlight)
    frame:SetScript("OnKeyDown", function(_, key) OnInput(key) end)
    frame:SetScript("OnMouseDown", function(_, button) OnInput(button) end)
    frame:SetScript("OnMouseWheel", function(_, delta)
        OnInput(delta > 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN")
    end)

    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:SetScript("OnEvent", function(self)
        if self:IsShown() then Stop() end
    end)
end

function SUI.ToggleBindMode()
    if not C_AddOns.IsAddOnLoaded("EllesmereUIActionBars") then
        Say("EllesmereUI Action Bars is not loaded.")
        return
    end
    if InCombatLockdown() then
        Say("Can't bind in combat.")
        return
    end

    if not frame then CreateBindFrame() end
    if frame:IsShown() then
        Stop()
        return
    end

    frame:Show()
    RevealMouseoverBars()
    -- again after eui's own fade-out, queued if the cursor was on a bar when the frame took over
    C_Timer.After(0.3, RevealMouseoverBars)
    Say("Keybind mode on. Hover a button and press a key to add it. Escape over a button clears it, Escape elsewhere exits.")
end
