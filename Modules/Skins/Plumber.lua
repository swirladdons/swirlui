---@class SUI : SF
local SUI = select(2, ...)
local S = SUI.Skins

local function T() return SUI.Theme end

local BUTTON_HEIGHT = 32
local BAR_HEIGHT = 40
local BAR_SIDE_INSET = 16

local function SkinButtons(selector)
    for _, button in selector.difficultyButtonPool:EnumerateActive() do
        if not S.data(button).skinned then
            S.data(button).skinned = true
            S.SetFont(button.ButtonText, T().font.size.normal)
        end
    end
end

local function SkinSelector(selector)
    if S.data(selector).skinned then return end
    S.data(selector).skinned = true

    local highlight = selector.ButtonHighlight
    S.StripTextures(selector.Bar, { [highlight] = true })
    selector.Bar:SetHeight(BAR_HEIGHT)
    local backdrop = S.CreateBackdrop(selector.Bar)
    backdrop:ClearAllPoints()
    backdrop:SetPoint("TOPLEFT", BAR_SIDE_INSET, 0)
    backdrop:SetPoint("BOTTOMRIGHT", -BAR_SIDE_INSET, 0)

    S.StripTextures(selector.ButtonBackground)
    S.Backdrop(selector.ButtonBackground, T().accentFade, T().accent)

    local a = T().accentFade
    highlight:SetColorTexture(a.r, a.g, a.b, a.a)
    highlight:SetBlendMode("BLEND")
    highlight:SetAlpha(1)
    highlight:SetHeight(BUTTON_HEIGHT)

    local hoverBorder = CreateFrame("Frame", nil, selector.Bar, "BackdropTemplate")
    hoverBorder:SetAllPoints(highlight)
    hoverBorder:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = T().border.size,
    })
    local d = T().accentDim
    hoverBorder:SetBackdropBorderColor(d.r, d.g, d.b, 1)
    hoverBorder:Hide()
    local hovered
    local function UpdateHoverBorder()
        hoverBorder:SetShown(hovered ~= nil and not hovered.selected)
    end
    hooksecurefunc(selector, "HighlightButton", function(_, button)
        hovered = button
        UpdateHoverBorder()
    end)
    hooksecurefunc(selector, "UpdateDifficulty", UpdateHoverBorder)

    S.SetFont(selector.Title, T().font.size.normal)
    S.SetFont(selector.InaccuracyAlert, T().font.size.normal)

    SkinButtons(selector)
    hooksecurefunc(selector, "ShowInstance", SkinButtons)
end

local function Skin()
    local selector = _G["PlumberInstanceDifficultySelector"]
    if not selector then return end

    if selector.Init then
        EventRegistry:RegisterCallback("Plumber.DifficultySelector.OnInit", function(_, frame)
            SkinSelector(frame)
        end, SUI)
    else
        SkinSelector(selector)
    end
end

S:Register("Plumber", "plumber", Skin)
