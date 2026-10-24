---@class SUI : SF
local SUI = select(2, ...)

local ADDON_TITLE = C_AddOns.GetAddOnMetadata("SwirlUI", "Title")

-- text
SUI.Title = ADDON_TITLE
SUI.Icon = "|TInterface/AddOns/SwirlUI/Media/Logo.png:16:16|t"

SUI.NameNoCore = SUI.Title:gsub(" Core", "")
SUI.HeaderNoColon = string.format("%s%s", SUI.Icon, SUI.NameNoCore)
SUI.Header = string.format("%s »", SUI.HeaderNoColon)

SUI.SettingsChanged = false
