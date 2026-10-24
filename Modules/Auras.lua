---@class SUI : SF
local SUI = select(2, ...)

SUI.Auras = SUI.Auras or {}
local A = SUI.Auras

function A.CreateBorder(frame, icon)
    if frame.SwirlBorder then return end
    icon = icon or frame.Icon

    local border = CreateFrame("Frame", nil, frame)
    border:SetAllPoints(icon)
    border:SetFrameLevel(frame:GetFrameLevel() - 1)
    border.edges = {}
    frame.SwirlBorder = border

    local borders = {
        {points = {"TOPLEFT", "TOPRIGHT"}, size = "Height"},
        {points = {"BOTTOMLEFT", "BOTTOMRIGHT"}, size = "Height"},
        {points = {"TOPLEFT", "BOTTOMLEFT"}, size = "Width"},
        {points = {"TOPRIGHT", "BOTTOMRIGHT"}, size = "Width"},
    }

    for _, borderData in ipairs(borders) do
        local edge = border:CreateTexture(nil, "OVERLAY")
        edge:SetColorTexture(0, 0, 0, 1)
        edge:SetPoint(borderData.points[1], 0, 0)
        edge:SetPoint(borderData.points[2], 0, 0)
        edge["Set" .. borderData.size](edge, 1)
        table.insert(border.edges, edge)
    end
end

local function SetBorderColor(border, r, g, b)
    for _, edge in ipairs(border.edges) do
        edge:SetColorTexture(r, g, b, 1)
    end
end

-- https://wago.tools/db2/SpellDispelType
local dispelIndexes = {None = 0, Magic = 1, Curse = 2, Disease = 3, Poison = 4, Enrage = 9, Bleed = 11}
local black = {r = 0, g = 0, b = 0, a = 1}
local dispelCurve

local function GetDispelCurve()
    if dispelCurve then return dispelCurve end

    dispelCurve = C_CurveUtil.CreateColorCurve()
    dispelCurve:SetType(Enum.LuaCurveType.Step)

    for name, index in pairs(dispelIndexes) do
        local color = DebuffTypeColor[name]
        dispelCurve:AddPoint(index, color and {r = color.r, g = color.g, b = color.b, a = 1} or black)
    end

    return dispelCurve
end

local function SetDispelBorderColor(auraFrame)
    local info = auraFrame.buttonInfo
    local color = info and info.auraInstanceID and auraFrame:GetFilter() == "HARMFUL"
        and C_UnitAuras.GetAuraDispelTypeColor(auraFrame.unit, info.auraInstanceID, GetDispelCurve())

    if color then
        SetBorderColor(auraFrame.SwirlBorder, color.r, color.g, color.b)
    else
        SetBorderColor(auraFrame.SwirlBorder, black.r, black.g, black.b)
    end
end

local function FormatCompactDuration(timeLeft)
    if timeLeft >= 86400 then
        return string.format("%dd", math.floor(timeLeft / 86400 + 0.5))
    end
    if timeLeft >= 3600 then
        return string.format("%dh", math.floor(timeLeft / 3600 + 0.5))
    end
    if timeLeft >= 60 then
        return string.format("%dm", math.floor(timeLeft / 60 + 0.5))
    end
    return string.format("%d", math.floor(timeLeft + 0.5))
end

local function SkinAuras(auraFrame)
    if auraFrame.isAuraAnchor or not auraFrame.Icon then return end

    local auraSettings = SwirlUIDB.uiSettings.skinAuras
    auraFrame.Icon:SetSize(auraSettings.width or 37, auraSettings.height or 37)
    auraFrame.Icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)

    if auraFrame.DebuffBorder then
        auraFrame.DebuffBorder:Hide()
        auraFrame.DebuffBorder:SetAlpha(0)
        auraFrame.DebuffBorder:SetTexture(nil)
    elseif auraFrame.BuffBorder then
        auraFrame.BuffBorder:SetTexture(nil)
    end

    if not auraFrame.SwirlBorder then
        A.CreateBorder(auraFrame)
    end

    local width, height = auraFrame:GetSize()
    if width and height and width > 0 and height > 0 then
        auraFrame.SwirlBorder:ClearAllPoints()
        auraFrame.SwirlBorder:SetPoint("TOPLEFT", auraFrame.Icon, "TOPLEFT", -1, 1)
        auraFrame.SwirlBorder:SetPoint("BOTTOMRIGHT", auraFrame.Icon, "BOTTOMRIGHT", 1, -1)
    end

    SetDispelBorderColor(auraFrame)

    local fontSize = auraSettings.fontSize or 12

    if auraFrame.Duration then
        auraFrame.Duration:ClearAllPoints()
        auraFrame.Duration:SetPoint("CENTER", auraFrame.Icon, "CENTER", 0, 0)
        auraFrame.Duration:SetFont(SUI.Theme.font.path, fontSize, "OUTLINE")
        auraFrame.Duration:SetShadowOffset(0, 0)

        if not auraFrame._swirlDurationHooked and type(auraFrame.UpdateDuration) == "function" then
            auraFrame._swirlDurationHooked = true
            hooksecurefunc(auraFrame, "UpdateDuration", function(self, timeLeft)
                if not (SwirlUIDB.uiSettings.skinAuras and SwirlUIDB.uiSettings.skinAuras.enabled) then return end
                if type(timeLeft) ~= "number" then return end
                if issecretvalue and issecretvalue(timeLeft) then return end
                if timeLeft <= 0 then return end
                self.Duration:SetText(FormatCompactDuration(timeLeft))
            end)
        end
    end

    if auraFrame.Count then
        auraFrame.Count:ClearAllPoints()
        auraFrame.Count:SetPoint("BOTTOMRIGHT", auraFrame.Icon, "BOTTOMRIGHT", 0, 1)
        auraFrame.Count:SetFont(SUI.Theme.font.path, fontSize, "OUTLINE")
    end
end

local function SkinAuraFrames()
    local frames = {BuffFrame, DebuffFrame}
    for _, frame in pairs(frames) do
        if frame and frame.auraFrames then
            if frame.CollapseAndExpandButton then
                frame.CollapseAndExpandButton:SetAlpha(0)
                frame.CollapseAndExpandButton:SetScript("OnClick", nil)
            end

            for _, auraFrame in pairs(frame.auraFrames) do
                SkinAuras(auraFrame)
            end
        end
    end
end

local auraHooksInstalled = false
local function SetupAuraHooks()
    if auraHooksInstalled then return end
    auraHooksInstalled = true
    hooksecurefunc(EditModeManagerFrame, "EnterEditMode", function() SkinAuraFrames() end)
    hooksecurefunc(EditModeManagerFrame, "ExitEditMode", function() SkinAuraFrames() end)
    hooksecurefunc(DebuffFrame, "UpdateAuraButtons", function() SkinAuraFrames() end)
end

function A.Apply()
    if SwirlUIDB and SwirlUIDB.uiSettings and SwirlUIDB.uiSettings.skinAuras and SwirlUIDB.uiSettings.skinAuras.enabled then
        SkinAuraFrames()
        SetupAuraHooks()
    end
end
