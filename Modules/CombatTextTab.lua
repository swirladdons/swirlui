---@class SUI : SF
local SUI = select(2, ...)
local C = SUI.Components
local CT = SUI.CombatText

local function T() return SUI.Theme end

local GAP = 12

local OUTLINES = {
    { text = "None", value = "NONE" },
    { text = "Outline", value = "OUTLINE" },
    { text = "Thick", value = "THICKOUTLINE" },
}

local function Pair(card, left, right)
    local row = CreateFrame("Frame", nil, card)
    row:SetHeight(36)

    left:SetParent(row)
    left:ClearAllPoints()
    left:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    if right then
        left:SetPoint("TOPRIGHT", row, "TOP", -GAP / 3, 0)
        right:SetParent(row)
        right:ClearAllPoints()
        right:SetPoint("TOPLEFT", row, "TOP", GAP / 3, 0)
        right:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
    else
        left:SetPoint("TOPRIGHT", row, "TOP", -GAP / 3, 0)
    end

    function row:SetEnabled(enabled)
        if left.SetEnabled then left:SetEnabled(enabled) end
        if right and right.SetEnabled then right:SetEnabled(enabled) end
    end

    card:AddWidget(row)
    return row
end

local function Slider(parent, label, min, max, step, db, key)
    return C:CreateSlider(parent, label, min, max, step,
        function() return db[key] end,
        function(v)
            db[key] = v
            CT.Apply()
        end,
        { width = 0 })
end

local function FontNames()
    local lsm = LibStub and LibStub("LibSharedMedia-3.0", true)
    return lsm and lsm:List("font") or {}
end

local function AddMessage(card, def)
    local db = CT.Cfg()[def.key]
    local dependents = {}

    local toggle = C:CreateToggle(card, def.label, db.enabled, function(v)
        db.enabled = v
        for _, dependent in ipairs(dependents) do dependent:SetEnabled(v) end
        CT.Apply()
    end)
    card:AddWidget(toggle)

    local text
    text = C:CreateEditBox(card, "Text", db.text, function(value)
        if value == "" then
            value = def.text
            text:SetValue(value)
        end
        db.text = value
        CT.Apply()
    end)
    local color = C:CreateColorPicker(card, "Color", CreateColor(db.color[1], db.color[2], db.color[3], 1), function(picked)
        db.color = { picked.r, picked.g, picked.b }
        CT.Apply()
    end)
    dependents[#dependents + 1] = Pair(card, color, text)

    local duration, threshold
    if def.duration then
        duration = C:CreateSlider(card, "Duration", 1, 10, 0.5,
            function() return db.duration end,
            function(v) db.duration = v end,
            { width = 0 })
    end
    if def.threshold then
        threshold = C:CreateSlider(card, "Threshold %", 5, 50, 1,
            function() return db.threshold end,
            function(v)
                db.threshold = v
                CT.Apply()
            end,
            { width = 0 })
    end
    if duration or threshold then
        dependents[#dependents + 1] = Pair(card, duration or threshold, duration and threshold or nil)
    end

    if def.pulse then
        local pulse = C:CreateToggle(card, "Pulse", db.pulse, function(v) db.pulse = v end)
        card:AddWidget(pulse)
        dependents[#dependents + 1] = pulse
    end

    if def.includeDead ~= nil then
        local includeDead = C:CreateToggle(card, "Also when target is dead", db.includeDead, function(v)
            db.includeDead = v
            CT.Apply()
        end)
        card:AddWidget(includeDead)
        dependents[#dependents + 1] = includeDead

        local c = CT.Cfg()
        local position = C:CreateXYPosition(card,
            function() return c.noTargetX end,
            function(v)
                c.noTargetX = v
                CT.Apply()
            end,
            function() return c.noTargetY end,
            function(v)
                c.noTargetY = v
                CT.Apply()
            end)
        card:AddWidget(position)
        dependents[#dependents + 1] = position
    end

    for _, dependent in ipairs(dependents) do dependent:SetEnabled(db.enabled) end
end

local function BuildMessageCard(scrollChild, y, title, keys)
    local theme = T()
    local card = C:CreateCard(scrollChild, title)
    scrollChild:PlaceCard(card, y)
    for i, key in ipairs(keys) do
        AddMessage(card, CT.BY_KEY[key])
        if i < #keys then card:AddSeparator() end
    end
    return card, y + card:GetHeight() + theme.padding.small
end

function SUI.BuildCombatTextCards(scrollChild, y)
    local theme = T()
    local c = CT.Cfg()
    local dependents = {}

    local card = C:CreateCard(scrollChild, "Combat Text")
    scrollChild:PlaceCard(card, y)

    card:AddHeaderToggle(c.enabled, function(v)
        c.enabled = v
        for _, dependent in ipairs(dependents) do dependent:SetEnabled(v) end
        CT.Apply()
    end)

    -- the preview covers the screen, so it only lives while this tab is open in a shown window
    local window = _G.SWIRLUI_MAIN_FRAME
    if window and not window.combatTextHooked then
        window.combatTextHooked = true
        window:HookScript("OnHide", function() CT.SetPreview(false) end)
        window:HookScript("OnShow", function() CT.SetPreview(SUI.activeTab == "Combat Text") end)
    end

    Pair(card,
        Slider(card, "Fade Duration", 0.5, 5, 0.1, c, "duration"),
        Slider(card, "Spacing", 0, 20, 1, c, "spacing"))

    local fontDropdown = C:CreateDropdown(card, "Font", FontNames(), c.fontFace, function(v)
        c.fontFace = v
        CT.Apply()
    end)
    local outlineDropdown = C:CreateDropdown(card, "Outline", OUTLINES, c.outline, function(v)
        c.outline = v
        CT.Apply()
    end)
    Pair(card, fontDropdown, outlineDropdown)

    Pair(card, Slider(card, "Font Size", 8, 72, 1, c, "fontSize"))

    card:AddWidget(C:CreateXYPosition(card,
        function() return c.x end,
        function(v)
            c.x = v
            CT.Apply()
        end,
        function() return c.y end,
        function(v)
            c.y = v
            CT.Apply()
        end))

    y = y + card:GetHeight() + theme.padding.small

    local groups = {
        { "Combat", { "enterCombat", "exitCombat", "lowDurability", "noTarget" } },
        { "Spells", { "interrupt", "missedKick", "dispel", "purge" } },
        { "Alerts", { "bloodlust", "potion" } },
    }
    for _, group in ipairs(groups) do
        local groupCard
        groupCard, y = BuildMessageCard(scrollChild, y, group[1], group[2])
        groupCard:SetEnabled(c.enabled)
        dependents[#dependents + 1] = groupCard
    end

    return y
end
