---@class SUI : SF
local SUI = select(2, ...)
local C = SUI.Components

SUI.Imports = {}

function SUI.Imports:ImportBasicMinimap(notification)
    return SUI.Utils:Import("BasicMinimap", notification)
end

function SUI.Imports:ImportBasicMinimap1440p(notification)
    -- Find the 1440p profile by short name
    local profile1440p = nil
    for _, profile in ipairs(SUI.ImportProfiles) do
        if profile.short == "BasicMinimap1440p" then
            profile1440p = profile
            break
        end
    end
    
    if not profile1440p or not SUI.Utils:CheckAddOnLoaded(profile1440p) then
        return false
    end

    local data = SUI.Utils:Decode(profile1440p.string)
    local db = profile1440p.database

    db.profiles = db.profiles or {}
    db.profileKeys = db.profileKeys or {}

    local characterProfile = string.format("%s - %s", UnitName("player"), GetRealmName())
    local targetProfile = profile1440p.targetProfile or SUI.ProfileFourteenFortyP

    if db.profiles[targetProfile] then
        wipe(db.profiles[targetProfile])
        db.profiles[targetProfile] = data
        db.profileKeys[characterProfile] = targetProfile
    else
        db.profiles[targetProfile] = data
        db.profileKeys[characterProfile] = targetProfile
    end

    SUI.SettingsChanged = true
    local displayName = profile1440p.displayName or profile1440p.name
    if notification then
        C.ShowToast(string.format("%s\n Imported %s", SUI.NameNoCore, WrapTextInColorCode(displayName, profile1440p.color)), 2)
    else
        SUI.Utils:Print(string.format("Imported %s", WrapTextInColorCode(displayName, profile1440p.color)))
    end

    SUI.Utils:StoreProfileVersion(profile1440p)

    return db
end

function SUI.Imports:ExportBasicMinimap()
    local basicMinimap = SUI.Utils:GetImportProfile("BasicMinimap")
    if not basicMinimap then return false end
    local targetProfile = basicMinimap.targetProfile or SUI.ProfileTenEightyP
    local data = basicMinimap.database["profiles"][targetProfile]
    return SUI.Utils:Export(data, basicMinimap)
end

function SUI.Imports:ExportBasicMinimap1440p()
    -- Search for the 1440p variant by short name
    local basicMinimap1440p = nil
    for _, profile in ipairs(SUI.ImportProfiles) do
        if profile.short == "BasicMinimap1440p" then
            basicMinimap1440p = profile
            break
        end
    end
    if not basicMinimap1440p then return false end
    local data = basicMinimap1440p.database["profiles"][SUI.ProfileFourteenFortyP]
    return SUI.Utils:Export(data, basicMinimap1440p)
end
