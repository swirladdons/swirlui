---@class SUI : SF
local SUI = select(2, ...)

local ADDON_TITLE = C_AddOns.GetAddOnMetadata("SwirlUI", "Title")

-- text
SUI.Title = ADDON_TITLE
SUI.Icon = "|TInterface/AddOns/SwirlUI/Media/Logo.png:16:16|t"

SUI.NameNoCore = SUI.Title:gsub(" Core", "")
SUI.HeaderNoColon = string.format("%s%s", SUI.Icon, SUI.NameNoCore)
SUI.Header = string.format("%s »", SUI.HeaderNoColon)

-- profiles
SUI.Profile = "swirl ui"
SUI.ProfileTenEightyP = "swirlui_1080p"
SUI.ProfileFourteenFortyP = "swirlui_1440p"
SUI.SettingsChanged = false

-- status
SUI.STATUS = {
    ADDON_DISABLED = "AddOn Disabled",
    NO_PROFILE = "No Profile",
    NEW_VERSION_AVAILABLE = "New Version Available",
    ACTIVE = "Active",
    READY = "Ready",
    DISABLED = "Disabled"
}

SUI.STATUS_ORDER = {
    [SUI.STATUS.ACTIVE] = 1,
    [SUI.STATUS.READY] = 2,
    [SUI.STATUS.NEW_VERSION_AVAILABLE] = 3,
    [SUI.STATUS.ADDON_DISABLED] = 4,
    [SUI.STATUS.NO_PROFILE] = 5
}

SUI.STATUS_TOOLTIPS = {
    [SUI.STATUS.ACTIVE] = "Click to reimport profile",
    [SUI.STATUS.READY] = "Click to apply profile",
    [SUI.STATUS.NO_PROFILE] = "Click to import profile",
    [SUI.STATUS.NEW_VERSION_AVAILABLE] = "Click to reimport profile (new version detected)",
    [SUI.STATUS.ADDON_DISABLED] = "Enable addon to import profile"
}