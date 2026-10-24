---@class SUI
local SUI = select(2, ...)
local ADDON = LibStub("AceAddon-3.0"):NewAddon("SwirlUI")

function ADDON:OnEnable()
    if not (SwirlUIDB and SwirlUIDB.uiSettings and SwirlUIDB.uiSettings.silence) then
        print(string.format("%s » %s for config", SUI.HeaderNoColon, WrapTextInColorCode("/swirlui", "ff00ff96")))
    end
    SUI:Initialize()
end