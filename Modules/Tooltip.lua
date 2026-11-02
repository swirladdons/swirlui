---@class SUI : SF
local SUI = select(2, ...)

local function Settings()
    return SwirlUIDB and SwirlUIDB.uiSettings and SwirlUIDB.uiSettings.tooltip
end

-- no closing |r: eui skips its own " [Rank]" only when the line already ends in exactly that
local function GuildText(guild, rank)
    return "|cffaaaaff" .. guild .. " [" .. rank .. "]"
end

local REACTION_COLORS = {
    hostile = CreateColorFromHexString("FFC63D3C"),
    neutral = CreateColorFromHexString("FFD8C459"),
    friendly = CreateColorFromHexString("FF47AE4A"),
    tapped = CreateColorFromHexString("FF7F7F7F"),
    pet = CreateColorFromHexString("FF5285CC"),
}

local DIFFICULTY_COLORS = {
    impossible = REACTION_COLORS.hostile,
    veryDifficult = CreateColorFromHexString("FFD98F4E"),
    difficult = REACTION_COLORS.neutral,
    standard = REACTION_COLORS.friendly,
    trivial = REACTION_COLORS.tapped,
}

local function TooltipUnit(tooltip)
    local unit
    if WorldFrame:IsMouseMotionFocus() then
        unit = "mouseover"
    else
        unit = select(2, tooltip:GetUnit())
    end
    if unit and not issecretvalue(unit) then return unit end
end

-- rebuilds the guild line whether it is blizzard's, leatrix's "Guild - Rank" or eui's "Guild [Rank]"
local function FormatGuildLine(tooltip)
    local settings = Settings()
    if tooltip ~= GameTooltip or not settings or not settings.guildRank then return end

    local unit = TooltipUnit(tooltip)
    if not unit or not UnitIsPlayer(unit) then return end

    local guild, rank = GetGuildInfo(unit)
    if not guild or not rank or issecretvalue(guild) or issecretvalue(rank) then return end

    local wanted = GuildText(guild, rank)
    for i = 2, tooltip:NumLines() do
        local line = _G["GameTooltipTextLeft" .. i]
        local text = line and line:GetText()
        if text and not issecretvalue(text) then
            if text == wanted then return end
            if text:find(guild, 1, true) then
                line:SetText(wanted)
                return
            end
        end
    end
end

-- npcs only, players keep eui's class colors
local function ReactionColor(unit)
    local isPlayer = UnitIsPlayer(unit)
    if issecretvalue(isPlayer) or isPlayer then return end

    local tapped = UnitIsTapDenied(unit)
    if not issecretvalue(tapped) and tapped then return REACTION_COLORS.tapped end

    local reaction = UnitReaction(unit, "player")
    if not reaction or issecretvalue(reaction) then return end
    if reaction <= 3 then return REACTION_COLORS.hostile end

    local controlled = UnitPlayerControlled(unit)
    if not issecretvalue(controlled) and controlled then return REACTION_COLORS.pet end
    return reaction == 4 and REACTION_COLORS.neutral or REACTION_COLORS.friendly
end

local function DifficultyColor(unit)
    local level = UnitEffectiveLevel(unit)
    local playerLevel = UnitEffectiveLevel("player")
    if issecretvalue(level) or issecretvalue(playerLevel) then return end

    local diff = level - playerLevel
    if level < 0 or diff >= 5 then return DIFFICULTY_COLORS.impossible end
    if diff >= 3 then return DIFFICULTY_COLORS.veryDifficult end
    if diff >= -2 then return DIFFICULTY_COLORS.difficult end
    if diff >= -(GetQuestGreenRange and GetQuestGreenRange() or 8) then return DIFFICULTY_COLORS.standard end
    return DIFFICULTY_COLORS.trivial
end

local function StripColorCodes(text)
    return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

-- the level line carries its own difficulty color, so it is rewritten without it
local function ColorLevelLine(tooltip, color)
    for i = 2, math.min(tooltip:NumLines(), 4) do
        local line = _G["GameTooltipTextLeft" .. i]
        local text = line and line:GetText()
        if text and not issecretvalue(text) then
            local plain = StripColorCodes(text)
            if plain:find(LEVEL, 1, true) == 1 then
                line:SetText(plain)
                line:SetTextColor(color:GetRGB())
                return
            end
        end
    end
end

-- only the level number is colored, the class name on the same line keeps its own color
local function ColorPlayerLevel(tooltip, color)
    local pattern = "^(" .. LEVEL:gsub("%p", "%%%0") .. "%s+[%d%?]+)(.*)$"
    for i = 2, math.min(tooltip:NumLines(), 4) do
        local line = _G["GameTooltipTextLeft" .. i]
        local text = line and line:GetText()
        if text and not issecretvalue(text) then
            local unwrapped = text:gsub("^|c%x%x%x%x%x%x%x%x(.-)|r", "%1", 1)
            local head, rest = unwrapped:match(pattern)
            if head then
                line:SetText(color:WrapTextInColorCode(head) .. rest)
                return
            end
        end
    end
end

local function ColorTargetLine(tooltip, unit)
    local label = EllesmereUI and EllesmereUI.L and EllesmereUI.L("Targeting:") or "Targeting:"
    local targetColor = ReactionColor(unit .. "target")
    if not targetColor then return end

    for i = 2, tooltip:NumLines() do
        local left = _G["GameTooltipTextLeft" .. i]
        local text = left and left:GetText()
        if text and not issecretvalue(text) and text == label then
            local right = _G["GameTooltipTextRight" .. i]
            if right then right:SetTextColor(targetColor:GetRGB()) end
            return
        end
    end
end

local function ApplyReactionColors(tooltip)
    local settings = Settings()
    if tooltip ~= GameTooltip or not settings or not settings.reactionColors then return end

    local unit = TooltipUnit(tooltip)
    if not unit then return end

    local color = ReactionColor(unit)
    local levelColor = DifficultyColor(unit)
    local isPlayer = UnitIsPlayer(unit)
    if color then
        GameTooltipTextLeft1:SetTextColor(color:GetRGB())
        if levelColor then ColorLevelLine(tooltip, levelColor) end
    elseif levelColor and not issecretvalue(isPlayer) and isPlayer then
        ColorPlayerLevel(tooltip, levelColor)
    end
    ColorTargetLine(tooltip, unit)
end

-- registered after login so it runs behind leatrix's own handler
local watcher = CreateFrame("Frame")
watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
watcher:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, FormatGuildLine)
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, ApplyReactionColors)
end)
