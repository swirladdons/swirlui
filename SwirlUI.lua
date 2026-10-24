---@class SUI : SF
local SUI = select(2, ...)

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    if not (SwirlUIDB and SwirlUIDB.uiSettings and SwirlUIDB.uiSettings.silence) then
        print(string.format("%s » %s for config", SUI.HeaderNoColon, WrapTextInColorCode("/swirlui", "ff00ff96")))
    end
    SUI:Initialize()
end)
