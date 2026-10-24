---@class SUI : SF
local SUI = select(2, ...)
local Serialize = LibStub:GetLibrary("AceSerializer-3.0")
local Compress = LibStub:GetLibrary("LibDeflate")

IsAddOnLoaded = C_AddOns.IsAddOnLoaded
local characterProfile = string.format("%s - %s", UnitName("player"), GetRealmName())

SUI.Utils = {}

function SUI.Utils:Print(message)
    if SwirlUIDB and SwirlUIDB.uiSettings and SwirlUIDB.uiSettings.silence then
        return
    end
    print(string.format("%s %s", SUI.Header, message))
end

function SUI.Utils:HasProfile(addon, silent)
    if not IsAddOnLoaded(addon.name) then
        return false
    end

    if not addon.database or not addon.database["profiles"] then
        if not silent then
            self:Print(string.format("No profile found for %s", SUI.WrapTextInColorCode(addon.displayName or addon.name, addon.color)))
        end
        return false
    end

    -- Check if ANY of the profile variants exist
    if addon.database["profiles"][SUI.Profile] or
       addon.database["profiles"][SUI.ProfileTenEightyP] or
       addon.database["profiles"][SUI.ProfileFourteenFortyP] then
        return true
    end

    if not silent then
        self:Print(string.format("No profile found for %s", WrapTextInColorCode(addon.displayName or addon.name, addon.color)))
    end
    return false
end

function SUI.Utils:CheckAddOnLoaded(addon)
    if not IsAddOnLoaded(addon.name) then
        self:Print(string.format("%s addon not loaded", WrapTextInColorCode(addon.name, addon.color)))
        return false
    end
    return true
end

function SUI.Utils:IsProfileApplied(addon)
    local profileKey = string.format("%s - %s", UnitName("player"), GetRealmName())
    local activeProfile = addon.database["profileKeys"] and addon.database["profileKeys"][profileKey]

    -- Check if the active profile matches ANY variant
    return activeProfile == SUI.Profile or
           activeProfile == SUI.ProfileTenEightyP or
           activeProfile == SUI.ProfileFourteenFortyP
end

function SUI.Utils:GetAddonStatus(addon)
    if not IsAddOnLoaded(addon.name) then
        return SUI.STATUS.ADDON_DISABLED, SUI.Hostile
    end

    if not self:HasProfile(addon, true) then
        return SUI.STATUS.NO_PROFILE, SUI.Hostile
    end

    if self:IsProfileVersionChanged(addon) then
        return SUI.STATUS.NEW_VERSION_AVAILABLE, SUI.Orange
    end

    if self:IsProfileApplied(addon) then
        return SUI.STATUS.ACTIVE, SUI.Friendly
    end

    return SUI.STATUS.READY, SUI.Neutral
end

function SUI.Utils:GetAddonStatusColor(addon)
    local _, color = self:GetAddonStatus(addon)
    return color
end

function SUI.Utils:GetAddonStatusText(addon)
    local status, statusColor = self:GetAddonStatus(addon)
    local addonText = WrapTextInColorCode(addon.name, addon.color)
    local statusText = WrapTextInColorCode(status, statusColor)

    return string.format("%s: %s", addonText, statusText)
end

function SUI.Utils:ApplyProfile(profile)
    if not IsAddOnLoaded(profile.name) then
        self:Print(string.format("%s addon not loaded", WrapTextInColorCode(profile.name, profile.color)))
        return false
    end

    if not profile.database or not profile.database["profiles"] or
       (not profile.database["profiles"][SUI.Profile] and not profile.database["profiles"][SUI.ProfileTenEightyP]) then
        self:Print(string.format("No profile found for %s", WrapTextInColorCode(profile.name, profile.color)))
        return false
    end

    local profileKey = string.format("%s - %s", UnitName("player"), GetRealmName())
    local activeProfile = profile.database["profileKeys"] and profile.database["profileKeys"][profileKey]

    if activeProfile == SUI.Profile or activeProfile == SUI.ProfileTenEightyP then
        self:Print(string.format("%s profile is already applied", WrapTextInColorCode(profile.name, profile.color)))
    else
        if not profile.database["profileKeys"] then
            profile.database["profileKeys"] = {}
        end
        profile.database["profileKeys"][profileKey] = SUI.Profile
        self:Print(string.format("Applied %s profile", WrapTextInColorCode(profile.name, profile.color)))
    end

    self:StoreProfileVersion(profile)
    return true
end

function SUI.Utils:GetImportProfile(identifier, searchBy)
    searchBy = searchBy or "name"

    for _, profile in ipairs(SUI.ImportProfiles) do
        if profile[searchBy] == identifier then
            return profile
        end
    end

    return nil
end

function SUI.Utils:GetApplyAddon(identifier, searchBy)
    searchBy = searchBy or "name"

    for _, addon in ipairs(SUI.ApplyAddons) do
        if addon[searchBy] == identifier then
            return addon
        end
    end

    return nil
end

function SUI.Utils:GetAllProfiles()
    local allProfiles = {}

    for _, profile in ipairs(SUI.ImportProfiles) do
        table.insert(allProfiles, profile)
    end

    for _, addon in ipairs(SUI.ApplyAddons) do
        table.insert(allProfiles, addon)
    end

    return allProfiles
end

function SUI.Utils:Decode(data)
    local decoded = Compress:DecodeForPrint(data)
    local decompressed = Compress:DecompressDeflate(decoded)
    local _, result = Serialize:Deserialize(decompressed)
    return result
end

function SUI.Utils:Encode(data)
    local serialized = Serialize:Serialize(data)
    local compressed = Compress:CompressDeflate(serialized)
    local encoded = Compress:EncodeForPrint(compressed)
    return encoded
end

function SUI.Utils:Export(data, addon, isNamespace)
    local encoded = self:Encode(data)

    local title = string.format("%s Exported", addon.name)
    if isNamespace then
        title = string.format("%s Namespaces Exported", addon.name)
    end

    SUI.CreateStatusDialog(title, nil, encoded)

    return true
end

function SUI.Utils:Import(addonName, notification)
    local importProfile = SUI.Utils:GetImportProfile(addonName)
    if not importProfile or not SUI.Utils:CheckAddOnLoaded(importProfile) then
        return false
    end

    local data = SUI.Utils:Decode(importProfile.string)

    local db = importProfile.database

    db.profiles = db.profiles or {}
    db.profileKeys = db.profileKeys or {}

    -- Use targetProfile if specified, otherwise default to base profile
    local targetProfile = importProfile.targetProfile or SUI.Profile

    if db.profiles[targetProfile] then
        wipe(db.profiles[targetProfile])
        db.profiles[targetProfile] = data
        db.profileKeys[characterProfile] = targetProfile
    else
        db.profiles[targetProfile] = data
        db.profileKeys[characterProfile] = targetProfile
    end

    SUI.SettingsChanged = true
    local displayName = importProfile.displayName or importProfile.name
    if notification then
        SUI.Components.ShowToast(string.format("%s\n Imported %s", SUI.NameNoCore, WrapTextInColorCode(displayName, importProfile.color)), 2)
    else
        self:Print(string.format("Imported %s", WrapTextInColorCode(displayName, importProfile.color)))
    end

    self:StoreProfileVersion(importProfile)

    return db
end

function SUI.Utils:GetStoredProfileVersion(profile)
    if not SwirlUIDB or not SwirlUIDB.profileVersions then
        return nil
    end
    return SwirlUIDB.profileVersions[profile.name]
end

function SUI.Utils:StoreProfileVersion(profile)
    if not SwirlUIDB then
        SwirlUIDB = { profileVersions = {} }
    end
    if not SwirlUIDB.profileVersions then
        SwirlUIDB.profileVersions = {}
    end

    SwirlUIDB.profileVersions[profile.name] = profile.version
end

function SUI.Utils:IsProfileVersionChanged(profile)
    if not profile.version then return end

    local storedVersion = self:GetStoredProfileVersion(profile)

    if not storedVersion then
        return true
    end

    return profile.version ~= storedVersion
end