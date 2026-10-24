---@class SUI : SF
local SUI = select(2, ...)
local C = SUI.Components

SUI.Imports = {}

function SUI.Imports:CanApplyProfiles()
    local allProfiles = SUI.Utils:GetAllProfiles()
    
    for _, profile in ipairs(allProfiles) do
        if not SUI.Utils:HasProfile(profile, true) then
            return false
        end
    end
    
    return true
end

function SUI.Imports:AreAllProfilesApplied()
    local allProfiles = SUI.Utils:GetAllProfiles()
    
    for _, profile in ipairs(allProfiles) do
        if SUI.Utils:HasProfile(profile, true) and not SUI.Utils:IsProfileApplied(profile) then
            return false
        end
    end
    
    return true
end

function SUI.Imports:ImportAll()
    local successCount = 0
    local totalCount = #SUI.ImportProfiles
    
    for _, profile in ipairs(SUI.ImportProfiles) do
        if C_AddOns.IsAddOnLoaded(profile.name) then
            local importFunction = string.format("Import%s", profile.short or profile.name)
            local success = self[importFunction] and self[importFunction](self, false)
            if success then
                successCount = successCount + 1
            else
                SUI.Utils:Print(string.format("Failed to import %s", WrapTextInColorCode(profile.name, profile.color)))
            end
        else
            SUI.Utils:Print(string.format("%s addon not loaded, skipping", WrapTextInColorCode(profile.name, profile.color)))
        end
    end

    C.ShowToast(string.format("%s\n Import complete! (%d/%d successful)", SUI.NameNoCore, successCount, totalCount), 2)

    if successCount > 0 then
        SUI.SettingsChanged = true
        SUI.Utils:Print(string.format("Please /reload to apply all changes"))
    end
end

function SUI.Imports:ApplyProfiles()
    if not self:CanApplyProfiles() then
        C.ShowToast(string.format("%s\n Not all profiles are available, check their import/enabled status", SUI.NameNoCore), 2)
        return false
    end

    local steps = {}
    local stepIndex = 0
    local allProfiles = SUI.Utils:GetAllProfiles()
    
    for _, profile in ipairs(allProfiles) do
        if not SUI.Utils:IsProfileApplied(profile) then
            stepIndex = stepIndex + 1
            table.insert(steps, function()
                SUI.Utils:ApplyProfile(profile)
            end)
        end
    end

    if (#steps > 0) then
        C.ShowToast(string.format("%s\n Applying all profiles...", SUI.NameNoCore), 2)
        for index, step in ipairs(steps) do
            C_Timer.After(index * 0.5, step)
        end
    else
        C.ShowToast(string.format("%s\n All profiles are already applied", SUI.NameNoCore), 2)
        return false
    end

    C_Timer.After((#steps + 1) * 0.5, function()
        SUI:ReloadDialog()
    end)
    
    return true
end

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

function SUI.Imports:GetAddonStatus(addonName, database)
    if not C_AddOns.IsAddOnLoaded(addonName) then
        return SUI.STATUS.DISABLED, SUI.Hostile
    elseif SUI.Utils:HasProfile(addonName, database, true) then
        return SUI.STATUS.ACTIVE, SUI.Friendly
    else
        return SUI.STATUS.READY, SUI.Neutral
    end
end

function SUI.Imports:GetProfileStatus()
    local status = {}
    local allProfiles = SUI.Utils:GetAllProfiles()
    
    for _, profile in ipairs(allProfiles) do
        local addonLoaded = C_AddOns.IsAddOnLoaded(profile.name)
        local hasDB = addonLoaded and profile.database ~= nil
        local hasProfile = SUI.Utils:HasProfile(profile, true)

        table.insert(status, {
            name = profile.name,
            color = profile.color or "FFFFFF",
            addonLoaded = addonLoaded,
            hasDB = hasDB,
            hasProfile = hasProfile
        })
    end
    
    return status
end
