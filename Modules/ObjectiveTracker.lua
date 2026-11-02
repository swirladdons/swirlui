---@class SUI : SF
local SUI = select(2, ...)
local S = SUI.Skins

local function T() return SUI.Theme end

local FIND_GROUP_SIZE = 20
local LABEL_OFFSET_Y = 1

local function SkinBar(bar)
    if S.data(bar).skinned then return end
    S.data(bar).skinned = true

    S.StripTextures(bar, { [bar:GetStatusBarTexture()] = true }, true)
    S.CreateBackdrop(bar)
    if bar.Label then
        local path, size = bar.Label:GetFont()
        bar.Label:SetFont(path, size, "OUTLINE")
        bar.Label:SetShadowOffset(0, 0)
        bar.Label:SetShadowColor(0, 0, 0, 0)
        bar.Label:ClearAllPoints()
        bar.Label:SetPoint("CENTER", bar, "CENTER", 0, LABEL_OFFSET_Y)
    end
    S.Border(bar, bar, 0):SetFrameLevel(bar:GetFrameLevel() + 2)
end

-- the quest item button shares the icon button shape, so it is told apart by its count and cooldown
local function IsFindGroupButton(child)
    return child:IsObjectType("Button") and child.Icon
        and not (child.Count or child.HotKey or child.Cooldown)
end

local function SkinFindGroupButton(button)
    if S.data(button).skinned then return end
    S.data(button).skinned = true

    S.StripTextures(button, { [button.Icon] = true }, true)
    local backdrop = S.CreateBackdrop(button)
    backdrop:ClearAllPoints()
    backdrop:SetSize(FIND_GROUP_SIZE, FIND_GROUP_SIZE)
    backdrop:SetPoint("CENTER", button.Icon, "CENTER")
    S.Hover(button, backdrop)
end

local function SkinChildren(tracker)
    local contents = tracker.ContentsFrame
    if not contents then return end
    for _, child in ipairs({ contents:GetChildren() }) do
        local bar = child.Bar
        if bar and bar.GetStatusBarTexture then
            SkinBar(bar)
        elseif IsFindGroupButton(child) then
            SkinFindGroupButton(child)
        end
    end
end

local function Enabled()
    local db = SwirlUIDB and SwirlUIDB.uiSettings and SwirlUIDB.uiSettings.objectiveTracker
    return db and db.enabled
end

local function SkinTracker(tracker)
    if Enabled() then SkinChildren(tracker) end
end

local function Skin()
    local tracker = _G.QuestObjectiveTracker
    if not tracker or not Enabled() then return end

    SkinChildren(tracker)
    if S.data(tracker).hooked then return end
    S.data(tracker).hooked = true
    for _, method in ipairs({ "GetProgressBar", "LayoutContents" }) do
        if type(tracker[method]) == "function" then
            hooksecurefunc(tracker, method, SkinTracker)
        end
    end
end

local loader

function SUI.ApplyObjectiveTrackerSkin()
    if C_AddOns.IsAddOnLoaded("Blizzard_ObjectiveTracker") then
        Skin()
    elseif not loader then
        loader = CreateFrame("Frame")
        loader:RegisterEvent("ADDON_LOADED")
        loader:SetScript("OnEvent", function(frame, _, name)
            if name ~= "Blizzard_ObjectiveTracker" then return end
            frame:UnregisterEvent("ADDON_LOADED")
            Skin()
        end)
    end
end
