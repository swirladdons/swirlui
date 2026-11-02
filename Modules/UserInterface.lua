---@class SUI : SF
local SUI = select(2, ...)
local C = SUI.Components

local function T() return SUI.Theme end

local function BuildUIScaleCard(scrollChild, y)
    local theme = T()
    local card  = C:CreateCard(scrollChild, "UI Scale")
    scrollChild:PlaceCard(card, y)

    local scaleSlider = C:CreateSlider(card, "UI Scale", 0.1, 2.0, 0.01,
        function() return tonumber(GetCVar("UIScale")) or 1 end,
        function(v) UIParent:SetScale(v); SetCVar("UIScale", v) end)
    card:AddWidget(scaleSlider)

    local presets = { 0.53, 0.63, 0.71, 1.0 }
    local btnRow  = CreateFrame("Frame", nil, card)
    btnRow:SetHeight(24)
    card:AddWidget(btnRow)

    C_Timer.After(0, function()
        local availW = btnRow:GetWidth()
        if availW <= 0 then availW = card:GetWidth() - theme.padding.med * 2 end
        local n    = #presets
        local btnW = math.floor((availW - (n - 1) * theme.padding.small) / n)
        for i, scale in ipairs(presets) do
            local b = C:CreateButton(btnRow, tostring(scale), {
                width    = btnW,
                height   = 24,
                callback = function()
                    SetCVar("UIScale", scale)
                    UIParent:SetScale(scale)
                    scaleSlider:SetVal(scale)
                    SUI.SettingsChanged = true
                end,
            })
            b:SetPoint("TOPLEFT", btnRow, "TOPLEFT", (i - 1) * (btnW + theme.padding.small), 0)
        end
    end)

    return y + card:GetHeight() + theme.padding.small
end

local function BuildChatBubblesCard(scrollChild, y)
    local theme = T()
    local card  = C:CreateCard(scrollChild, "Chat Bubbles")
    scrollChild:PlaceCard(card, y)

    card:AddHeaderToggle(SwirlUIDB.uiSettings.chatBubbles.enabled,
        function(v)
            SwirlUIDB.uiSettings.chatBubbles.enabled = v
            SUI.SettingsChanged = true
        end)

    local fsSlider = C:CreateSlider(card, "Font Size", 2, 24, 1,
        function() return SwirlUIDB.uiSettings.chatBubbles.fontSize end,
        function(v) SwirlUIDB.uiSettings.chatBubbles.fontSize = v end)
    card:AddWidget(fsSlider)

    return y + card:GetHeight() + theme.padding.small
end

local function BuildChatCard(scrollChild, y)
    local theme = T()
    local card  = C:CreateCard(scrollChild, "Chat")
    scrollChild:PlaceCard(card, y)

    local db = SwirlUIDB.uiSettings.chatFont

    local toggle = C:CreateToggle(card, "Remove Font Shadows", db.removeShadow,
        function(v)
            db.removeShadow = v
            SUI.ApplyChatFontSettings()
            SUI.SettingsChanged = true
        end)
    card:AddWidget(toggle)

    local roleIcons = SwirlUIDB.uiSettings.chatRoleIcons
    local roleToggle = C:CreateToggle(card, "Role Icons in Group Chat", roleIcons.enabled,
        function(v)
            roleIcons.enabled = v
            SUI.SettingsChanged = true
        end)
    card:AddWidget(roleToggle)

    return y + card:GetHeight() + theme.padding.small
end

local function BuildZoneTextCard(scrollChild, y)
    local theme = T()
    local card  = C:CreateCard(scrollChild, "Zone Text")
    scrollChild:PlaceCard(card, y)

    local db = SwirlUIDB.uiSettings.zoneText

    card:AddHeaderToggle(db.enabled,
        function(v) db.enabled = v; SUI.SettingsChanged = true end)

    local sliders = {
        { label = "Zone Font Size", key = "zoneFontSize" },
        { label = "Subzone Font Size", key = "subZoneFontSize" },
        { label = "PvP Info Font Size", key = "pvpInfoFontSize" },
        { label = "PvP Arena Font Size", key = "pvpArenaFontSize" },
    }

    for _, slider in ipairs(sliders) do
        local fsSlider = C:CreateSlider(card, slider.label, 8, 40, 1,
            function() return db[slider.key] end,
            function(v) db[slider.key] = v end)
        card:AddWidget(fsSlider)
    end

    return y + card:GetHeight() + theme.padding.small
end

local function BuildOffsetCard(scrollChild, y, cardTitle, dbKey)
    local theme = T()
    local card  = C:CreateCard(scrollChild, cardTitle)
    scrollChild:PlaceCard(card, y)

    local db = SwirlUIDB.uiSettings[dbKey]

    card:AddHeaderToggle(db.enabled,
        function(v) db.enabled = v; SUI.SettingsChanged = true end)

    local fsSlider = C:CreateSlider(card, "Font Size", 8, 24, 1,
        function() return db.fontSize end,
        function(v) db.fontSize = v end)
    card:AddWidget(fsSlider)

    local xSlider = C:CreateSlider(card, "X Offset", -500, 500, 1,
        function() return db.offsetX end,
        function(v) db.offsetX = v end)
    card:AddWidget(xSlider)

    local ySlider = C:CreateSlider(card, "Y Offset", -500, 500, 1,
        function() return db.offsetY end,
        function(v) db.offsetY = v end)
    card:AddWidget(ySlider)

    return y + card:GetHeight() + theme.padding.small
end

local function BuildMouseClickCard(scrollChild, y)
    local theme = T()
    local card  = C:CreateCard(scrollChild, "Mouse Click")
    scrollChild:PlaceCard(card, y)

    local function GetMC(k)
        return SwirlUIDB.uiSettings.mouseClick and SwirlUIDB.uiSettings.mouseClick[k] or false
    end
    local function SetMC(k, v)
        if not SwirlUIDB.uiSettings.mouseClick then
            SwirlUIDB.uiSettings.mouseClick = { extraActionButton = false, lfgListFrame = false }
        end
        SwirlUIDB.uiSettings.mouseClick[k] = v
        SUI.SettingsChanged = true
    end

    local extraToggle = C:CreateToggle(card, "Remove Empty Spacing around Extra Action Button",
        GetMC("extraActionButton"),
        function(v) SetMC("extraActionButton", v) end)
    card:AddWidget(extraToggle)

    local lfgToggle = C:CreateToggle(card, "Enable Click-Through in LFG",
        GetMC("lfgListFrame"),
        function(v) SetMC("lfgListFrame", v) end)
    card:AddWidget(lfgToggle)

    return y + card:GetHeight() + theme.padding.small
end

local function BuildActionBarsCard(scrollChild, y)
    local theme = T()
    local card = C:CreateCard(scrollChild, "Action Bars")
    scrollChild:PlaceCard(card, y)

    local db = SwirlUIDB.uiSettings.skinExtraButtons

    local toggle = C:CreateToggle(card, "Skin Extra Action & Zone Ability Buttons", db.enabled,
        function(v)
            db.enabled = v
            SUI.ApplyExtraButtonSkin()
            SUI.SettingsChanged = true
        end)
    card:AddWidget(toggle)

    return y + card:GetHeight() + theme.padding.small
end

local function BuildGroupFinderCard(scrollChild, y)
    local theme = T()
    local card = C:CreateCard(scrollChild, "Group Finder")
    scrollChild:PlaceCard(card, y)

    local db = SwirlUIDB.uiSettings.lfgFont

    local toggle = C:CreateToggle(card, "Skin Search Result Fonts", db.enabled,
        function(v)
            db.enabled = v
            SUI.ApplyLFGFontSkin()
            SUI.SettingsChanged = true
        end)
    card:AddWidget(toggle)

    return y + card:GetHeight() + theme.padding.small
end

local function BuildAurasCard(scrollChild, y)
    local theme = T()
    local card = C:CreateCard(scrollChild, "Skin Buffs & Debuffs")
    scrollChild:PlaceCard(card, y)

    local db = SwirlUIDB.uiSettings.skinAuras

    card:AddHeaderToggle(db.enabled,
        function(v)
            db.enabled = v
            SUI.Auras.Apply()
            SUI.SettingsChanged = true
        end)

    local widthSlider = C:CreateSlider(card, "Width", 16, 64, 1,
        function() return db.width end,
        function(v) db.width = v; SUI.Auras.Apply() end)
    card:AddWidget(widthSlider)

    local heightSlider = C:CreateSlider(card, "Height", 16, 64, 1,
        function() return db.height end,
        function(v) db.height = v; SUI.Auras.Apply() end)
    card:AddWidget(heightSlider)

    local fsSlider = C:CreateSlider(card, "Font Size", 8, 24, 1,
        function() return db.fontSize end,
        function(v) db.fontSize = v; SUI.Auras.Apply() end)
    card:AddWidget(fsSlider)

    return y + card:GetHeight() + theme.padding.small
end

local function BuildEllesmereCard(scrollChild, y)
    local unitFrames = C_AddOns.IsAddOnLoaded("EllesmereUIUnitFrames")
    local blizzardSkin = C_AddOns.IsAddOnLoaded("EllesmereUIBlizzardSkin")
    if not unitFrames and not blizzardSkin then return y end

    local theme = T()
    local card = C:CreateCard(scrollChild, "EllesmereUI")
    scrollChild:PlaceCard(card, y)

    local db = SwirlUIDB.uiSettings.ellesmere

    if unitFrames then
        local toggle = C:CreateToggle(card, "Power Text Above Cast Bar (Target & Boss)",
            db.powerTextAboveCastbar,
            function(v)
                db.powerTextAboveCastbar = v
                SUI.ApplyEllesmereSettings()
                SUI.SettingsChanged = true
            end)
        card:AddWidget(toggle)
    end

    if blizzardSkin then
        local toggle = C:CreateToggle(card, "Tooltip Target Line as \"Target: YOU\"",
            db.tooltipTargetLine,
            function(v)
                db.tooltipTargetLine = v
                SUI.SettingsChanged = true
            end)
        card:AddWidget(toggle)
    end

    return y + card:GetHeight() + theme.padding.small
end

local RebuildCardTab

local function CreateSpellRow(card, spellID, onRemove)
    local theme = T()
    local row = CreateFrame("Frame", nil, card)
    row:SetHeight(24)

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("LEFT", row, "LEFT", 0, 0)
    icon:SetTexture(C_Spell.GetSpellTexture(spellID))
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local label = row:CreateFontString(nil, "OVERLAY")
    C.ApplyFont(label, "normal")
    label:SetPoint("LEFT", icon, "RIGHT", theme.padding.small, 0)
    label:SetTextColor(theme.text.primary.r, theme.text.primary.g, theme.text.primary.b, 1)
    label:SetText(string.format("%s (%d)", C_Spell.GetSpellName(spellID) or "Unknown", spellID))

    local remove = C:CreateCloseButton(row, onRemove, { size = 22 })
    remove:SetPoint("RIGHT", row, "RIGHT", 0, 0)

    return row
end

local function BuildCooldownManagerCard(scrollChild, y)
    local theme = T()
    local card = C:CreateCard(scrollChild, "Cooldown Manager Stacks")
    scrollChild:PlaceCard(card, y)

    local db = SwirlUIDB.uiSettings.cdmStacks

    local function Changed()
        SUI.ApplyCooldownManagerSettings()
        SUI.SettingsChanged = true
        RebuildCardTab("Addons")
    end

    card:AddHeaderToggle(db.enabled,
        function(v)
            db.enabled = v
            SUI.ApplyCooldownManagerSettings()
            SUI.SettingsChanged = true
        end)

    card:AddLabel("Always show the stack count, including 1, on these tracked buffs.")

    local entry
    entry = C:CreateEntryBox(card, "", function(text)
        local id = tonumber(text)
        if not id or not C_Spell.GetSpellName(id) or tContains(db.spells, id) then
            entry:SetValue("")
            return
        end
        tinsert(db.spells, id)
        Changed()
    end)
    entry:SetHeight(24)
    card:AddWidget(entry)
    card:AddLabel("Type a spell ID and press Enter.", theme.text.muted, "small")

    for index, spellID in ipairs(db.spells) do
        card:AddWidget(CreateSpellRow(card, spellID, function()
            tremove(db.spells, index)
            Changed()
        end))
    end

    return y + card:GetHeight() + theme.padding.small
end

local function BuildTooltipCard(scrollChild, y)
    local theme = T()
    local card = C:CreateCard(scrollChild, "Tooltip")
    scrollChild:PlaceCard(card, y)

    local db = SwirlUIDB.uiSettings.tooltip

    local toggle = C:CreateToggle(card, "Guild Rank as \"Guild [Rank]\"",
        db.guildRank,
        function(v)
            db.guildRank = v
            SUI.SettingsChanged = true
        end)
    card:AddWidget(toggle)

    local reactionToggle = C:CreateToggle(card, "Reaction and Difficulty Colors on NPCs",
        db.reactionColors,
        function(v)
            db.reactionColors = v
            SUI.SettingsChanged = true
        end)
    card:AddWidget(reactionToggle)

    return y + card:GetHeight() + theme.padding.small
end

function SUI.BuildZenPilgrimageCard(scrollChild, y)
    if select(2, UnitClass("player")) ~= "MONK" then return y end

    local theme = T()
    local card = C:CreateCard(scrollChild, "Zen Pilgrimage Cooldown")
    scrollChild:PlaceCard(card, y)

    local db = SwirlUIDB.uiSettings.zenPilgrimage

    card:AddHeaderToggle(db.enabled,
        function(v)
            db.enabled = v
            SUI.ApplyZenPilgrimage()
            SUI.SettingsChanged = true
        end)

    local sliders = {
        { key = "size", label = "Size", min = 16, max = 128 },
        { key = "offsetX", label = "X Offset", min = -1000, max = 1000 },
        { key = "offsetY", label = "Y Offset", min = -600, max = 600 },
    }
    for _, slider in ipairs(sliders) do
        local widget = C:CreateSlider(card, slider.label, slider.min, slider.max, 1,
            function() return db[slider.key] end,
            function(v)
                db[slider.key] = v
                SUI.ApplyZenPilgrimage()
            end)
        card:AddWidget(widget)
    end

    return y + card:GetHeight() + theme.padding.small
end

local function BuildAddonSkinsCard(scrollChild, y)
    local theme = T()
    local card = C:CreateCard(scrollChild, "Addon Skins")
    scrollChild:PlaceCard(card, y)

    local db = SwirlUIDB.uiSettings.skins

    card:AddHeaderToggle(db.enabled,
        function(v)
            db.enabled = v
            SUI.Skins:Run()
            SUI.SettingsChanged = true
        end)

    local skins = {
        { key = "rareScanner", label = "RareScanner" },
        { key = "waypointUI", label = "WaypointUI (Experimental)" },
        { key = "opie", label = "OPie Ring Buttons" },
        { key = "plumber", label = "Plumber Difficulty Selector" },
    }

    for _, skin in ipairs(skins) do
        local skinToggle = C:CreateToggle(card, skin.label, db[skin.key],
            function(v)
                db[skin.key] = v
                if v then SUI.Skins:Rerun(skin.key) end
                SUI.SettingsChanged = true
            end)
        card:AddWidget(skinToggle)
    end

    return y + card:GetHeight() + theme.padding.small
end

local function OffsetCard(title, dbKey)
    return function(scrollChild, y) return BuildOffsetCard(scrollChild, y, title, dbKey) end
end

local CARD_TABS = {
    ["User Interface"] = {
        BuildUIScaleCard,
        BuildChatBubblesCard,
        BuildChatCard,
        BuildZoneTextCard,
        OffsetCard("UI Errors", "uiErrors"),
        OffsetCard("Action Status", "actionStatus"),
        BuildMouseClickCard,
        BuildGroupFinderCard,
        BuildTooltipCard,
    },
    ["Combat Text"] = {
        function(scrollChild, y) return SUI.BuildCombatTextCards(scrollChild, y) end,
    },
    ["Action Bars & Auras"] = {
        BuildActionBarsCard,
        BuildAurasCard,
    },
    ["Addons"] = {
        BuildEllesmereCard,
        BuildCooldownManagerCard,
        BuildAddonSkinsCard,
    },
}

local cardTabs = {}

local function CreateCardTab(key, parent)
    local theme = T()
    local tab = CreateFrame("Frame", nil, parent)
    tab:SetAllPoints(parent)
    tab.scrollChild = C:CreateTabScroller(tab)
    tab.parent = parent
    cardTabs[key] = tab

    local y = theme.padding.small
    for _, build in ipairs(CARD_TABS[key]) do
        y = build(tab.scrollChild, y)
    end
    tab.scrollChild:Commit(y)
    return tab
end

RebuildCardTab = function(key)
    local old = cardTabs[key]
    local scroll = old.scrollChild.scrollFrame:GetVerticalScroll()
    old:Hide()
    old:SetParent(nil)

    local tab = CreateCardTab(key, old.parent)
    tab:Show()
    -- the scroll child is sized a frame or two after the build
    C_Timer.After(0, function()
        C_Timer.After(0, function()
            tab.scrollChild.scrollFrame:SetVerticalScroll(scroll)
        end)
    end)
end

function SUI.BuildCardTab(key, content)
    local tab = cardTabs[key] or CreateCardTab(key, content)
    tab:Show()
    SUI.CombatText.SetPreview(key == "Combat Text")
end
