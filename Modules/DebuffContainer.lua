---@class SUI : SF
local SUI = select(2, ...)

SUI.Auras = SUI.Auras or {}
local A = SUI.Auras

local MAX_DEBUFFS = 16
local PER_ROW = 8
local GAP = 1

local dispelColors = {
    Magic = CreateColor(0.2, 0.6, 1, 1),
    Curse = CreateColor(0.6, 0, 1, 1),
    Disease = CreateColor(0.6, 0.4, 0, 1),
    Poison = CreateColor(0, 0.6, 0, 1),
    Enrage = CreateColor(0.8, 0, 0, 1),
    Bleed = CreateColor(0.8, 0, 0, 1),
}

local container

local function Settings()
    return SwirlUIDB.uiSettings.skinAuras
end

local function CreateEdges(parent, r, g, b)
    local edges = {}
    local sides = {
        {"TOPLEFT", "TOPRIGHT", "Height"},
        {"BOTTOMLEFT", "BOTTOMRIGHT", "Height"},
        {"TOPLEFT", "BOTTOMLEFT", "Width"},
        {"TOPRIGHT", "BOTTOMRIGHT", "Width"},
    }
    for i, side in ipairs(sides) do
        local edge = parent:CreateTexture(nil, "OVERLAY")
        edge:SetColorTexture(r, g, b, 1)
        edge:SetPoint(side[1], 0, 0)
        edge:SetPoint(side[2], 0, 0)
        edge["Set" .. side[3]](edge, 1)
        edges[i] = edge
    end
    return edges
end

local function Overlay(button, offset)
    local frame = CreateFrame("Frame", nil, button)
    frame:SetAllPoints(button)
    frame:SetFrameLevel(button:GetFrameLevel() + offset)
    frame:EnableMouse(false)
    return frame
end

-- the engine tints and shows these edges per aura, so the secret dispel type is never read
local function RegisterDispelEdges(button, edges)
    local style = Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset
    local options = {style = style, showWhenHarmful = true, showWhenHelpful = false, customDispelColorMap = dispelColors}
    for _, edge in ipairs(edges) do
        edge:Hide()
        if not pcall(button.AddDispelTypeTexture, button, edge, options) then
            pcall(button.ClearDispelTypeTextures, button)
            return
        end
    end
end

-- runs once per button, and the engine restricts what we can do to it afterwards
local function InitButton(button)
    local settings = Settings()
    local fontPath = SUI.Theme.font.path

    button:SetSize((settings.width or 37) + 2, (settings.height or 37) + 2)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 1, -1)
    icon:SetPoint("BOTTOMRIGHT", -1, 1)
    icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)

    CreateEdges(Overlay(button, 1), 0, 0, 0)
    local dispelEdges = CreateEdges(Overlay(button, 2), 1, 1, 1)

    local textFrame = Overlay(button, 3)
    local duration = textFrame:CreateFontString(nil, "OVERLAY")
    duration:SetFont(fontPath, settings.fontSize or 12, "OUTLINE")
    duration:SetShadowOffset(0, 0)
    duration:SetPoint("CENTER", icon, "CENTER", 0, 0)
    local count = textFrame:CreateFontString(nil, "OVERLAY")
    count:SetFont(fontPath, settings.fontSize or 12, "OUTLINE")
    count:SetShadowOffset(0, 0)
    count:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 0, 1)

    button:SetIcon(icon)
    pcall(button.SetDurationText, button, duration, {})
    pcall(button.SetApplicationCount, button, count, {})
    RegisterDispelEdges(button, dispelEdges)
end

-- grows left from the minimap's bottom-left corner, and up once a row is full
local function Layout()
    local settings = Settings()
    local width = (settings.width or 37) + 2
    local height = (settings.height or 37) + 2
    local direction = AnchorUtil.FlowDirection

    container:ClearAllPoints()
    container:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMLEFT", -GAP, 0)
    container:SetFlowLayoutAnchorPoint("BOTTOMRIGHT")
    container:SetFlowLayoutGrowthDirection(direction.Left, direction.Up)
    container:SetFlowLayoutMaximumLineSize(PER_ROW * (width + GAP))
    container:SetAuraGroupLayout("debuffs", {elementWidth = width, elementHeight = height, elementSpacing = GAP, lineSpacing = GAP})
end

local function Build()
    if not C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer") then
        C_AddOns.LoadAddOn("Blizzard_AuraContainer")
    end

    local created, frame = pcall(CreateFrame, "AuraContainer", "SwirlUIDebuffContainer", UIParent, "CustomAuraContainerTemplate")
    if not created then return end

    container = frame
    container:SetSize(1, 1)
    container:AddAuraGroup("debuffs", "HARMFUL", {
        maxFrameCount = MAX_DEBUFFS,
        initializeFrame = InitButton,
    })
    Layout()
    container:SetUnit("player")
    container:UpdateAllAuras()
end

local function HideBlizzardFrame()
    DebuffFrame:SetAlpha(0)
    -- invisible is not enough, its buttons would still show a second tooltip
    for _, button in pairs(DebuffFrame.auraFrames) do
        if button.EnableMouse then button:EnableMouse(false) end
    end
end

-- returns "new" when the container was just built, "existing" when it was already there
function A.EnsureDebuffContainer()
    if container then return "existing" end
    if not (Enum.CustomAuraButtonDispelTypeTextureStyle and AnchorUtil and AnchorUtil.FlowDirection) then return end

    Build()
    if not container then return end

    HideBlizzardFrame()
    hooksecurefunc(EditModeManagerFrame, "ExitEditMode", HideBlizzardFrame)
    hooksecurefunc(DebuffFrame, "UpdateAuraButtons", HideBlizzardFrame)
    return "new"
end

function A.HasDebuffContainer()
    return container ~= nil
end
