---@class SUI : SF
local SUI = select(2, ...)
local S = SUI.Skins

local function T() return SUI.Theme end

local function SkinNavButton(nav)
    if not nav or S.data(nav).skinned then return end
    S.data(nav).skinned = true

    if nav.Texture then
        local c = T().text.secondary
        nav.Texture:SetVertexColor(c.r, c.g, c.b, 1)
    end
    if nav.HighlightTexture then
        local a = T().accent
        nav.HighlightTexture:SetVertexColor(a.r, a.g, a.b, 1)
    end
end

local function SkinLootBar(button)
    local lootBar = button.LootBar
    if not lootBar or not lootBar.itemFramesPool or S.data(lootBar).skinned then return end
    S.data(lootBar).skinned = true

    hooksecurefunc(lootBar.itemFramesPool, "Acquire", function(pool)
        for item in pool:EnumerateActive() do
            if item.Icon and not S.data(item).skinned then
                S.data(item).skinned = true
                S.Icon(item, item.Icon)
            end
        end
    end)
end

local function SkinFilterButton(filterButton)
    if not filterButton or S.data(filterButton).skinned then return end
    S.data(filterButton).skinned = true

    S.StripTexture(filterButton:GetHighlightTexture())
end

local function SkinScannerButton()
    local button = _G["RARESCANNER_BUTTON"]
    if not button or S.data(button).skinned then return end
    S.data(button).skinned = true

    S.StripTexture(button:GetNormalTexture())
    S.StripTextures(button)

    for _, region in ipairs({ button:GetRegions() }) do
        if region:IsObjectType("FontString") then
            S.SetFont(region, 10)
        end
    end

    S.Backdrop(button)
    S.Hover(button)

    if button.Title then
        S.SetFont(button.Title, T().font.size.normal)
        local c = T().text.primary
        button.Title:SetTextColor(c.r, c.g, c.b, 1)
    end
    if button.Description_text then
        S.SetFont(button.Description_text, 10)
        local c = T().text.secondary
        button.Description_text:SetTextColor(c.r, c.g, c.b, 1)
    end

    S.CloseButton(button.CloseButton)

    SkinFilterButton(button.FilterEntityButton)
    SkinFilterButton(button.UnFilterEntityButton)
    SkinNavButton(button.NextButton)
    SkinNavButton(button.PreviousButton)
    SkinLootBar(button)
end

local function SkinSearchBar()
    if not WorldMapFrame then return false end

    for _, child in ipairs({ WorldMapFrame:GetChildren() }) do
        if child.EditBox and child.relativeFrame then
            if S.data(child).skinned then return true end
            S.data(child).skinned = true

            S.EditBox(child.EditBox)
            child.EditBox:ClearAllPoints()
            child.EditBox:SetAllPoints(child)
            return true
        end
    end

    return false
end

local function Skin()
    SkinScannerButton()

    if not SkinSearchBar() and WorldMapFrame then
        WorldMapFrame:HookScript("OnShow", SkinSearchBar)
    end
end

S:Register("RareScanner", "rareScanner", Skin)
