---@class SUI : SF
local SUI = select(2, ...)
local S = SUI.Skins

local function T() return SUI.Theme end

local function BlankArt(tex)
    if not tex or not tex.GetTextureObject then return end
    S.StripTexture(tex:GetTextureObject())
end

local function SkinBox(tex)
    if not tex or not tex.GetTextureObject or S.data(tex).skinned then return end
    S.data(tex).skinned = true

    BlankArt(tex)

    S.CreateBackdrop(tex, nil, 0)
end

local function Skin()
    local pinpoint = _G["WUIPinpointFrame"]
    if pinpoint and pinpoint.Foreground then
        SkinBox(pinpoint.Foreground.BackgroundTexture)
    end

    if pinpoint and pinpoint.Background then
        local contextIcon = pinpoint.Background.ContextIcon
        if contextIcon then BlankArt(contextIcon.BackgroundTexture) end
    end

    local db = _G["WaypointDB_Global"]
    local font = T().font.path
    if db and db.fontPath ~= font then
        db.fontPath = font
        SUI.Utils:Print("WaypointUI font set (applies on reload)")
    end
end

S:Register("WaypointUI", "waypointUI", Skin)
