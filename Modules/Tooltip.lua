---@class SUI : SF
local SUI = select(2, ...)

local function Settings()
    return SwirlUIDB and SwirlUIDB.uiSettings and SwirlUIDB.uiSettings.tooltip
end

-- no closing |r: eui skips its own " [Rank]" only when the line already ends in exactly that
local function GuildText(guild, rank)
    return "|cffaaaaff" .. guild .. " [" .. rank .. "]"
end

-- rebuilds the guild line whether it is blizzard's, leatrix's "Guild - Rank" or eui's "Guild [Rank]"
local function FormatGuildLine(tooltip)
    local settings = Settings()
    if tooltip ~= GameTooltip or not settings or not settings.guildRank then return end

    local unit
    if WorldFrame:IsMouseMotionFocus() then
        unit = "mouseover"
    else
        unit = select(2, tooltip:GetUnit())
    end
    if not unit or issecretvalue(unit) or not UnitIsPlayer(unit) then return end

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

-- registered after login so it runs behind leatrix's own handler
local watcher = CreateFrame("Frame")
watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
watcher:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, FormatGuildLine)
end)
