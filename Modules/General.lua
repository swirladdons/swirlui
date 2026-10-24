---@class SUI
local SUI = select(2, ...)
local C  = SUI.Components

local function T() return SUI.Theme end

local generalTab
local scrollChild, genCard

local function CreateGeneralTab()
    local theme = T()
    local parent = SUI.frames.generalContent

    generalTab = CreateFrame("Frame", "SwirlUI_GeneralTab", parent)
    generalTab:SetAllPoints(parent)
    SUI.frames.generalTab = generalTab

    scrollChild = C:CreateTabScroller(generalTab)

    local y = theme.padding.small

    genCard = C:CreateCard(scrollChild, "General Settings")
    scrollChild:PlaceCard(genCard, y)

    local silenceToggle = C:CreateToggle(genCard, string.format("Silence %s Chat Messages", SUI.NameNoCore),
        SwirlUIDB.uiSettings.silence,
        function(val)
            SwirlUIDB.uiSettings.silence = val
            SUI.SettingsChanged = true
        end)
    genCard:AddWidget(silenceToggle)

    y = y + genCard:GetHeight() + theme.padding.small

    local db = SwirlUIDB.uiSettings.autoInvite
    local inviteCard = C:CreateCard(scrollChild, "Invites")
    scrollChild:PlaceCard(inviteCard, y)

    inviteCard:AddSectionHeader("Invite Others", true)

    local inviteToggle = C:CreateToggle(inviteCard, "On whisper keyword", db.enabled,
        function(val)
            db.enabled = val
            SUI.ApplyAutoInviteSettings()
            SUI.SettingsChanged = true
        end)
    inviteCard:AddWidget(inviteToggle)

    local keywordBox = C:CreateEditBox(inviteCard, "Keywords (comma separated)", db.keywords,
        function(val)
            db.keywords = val
            SUI.AutoInvite.InvalidateKeywordCache()
            SUI.SettingsChanged = true
        end)
    inviteCard:AddWidget(keywordBox)

    local guildOnlyToggle = C:CreateToggle(inviteCard, "Guild members only", db.guildOnly,
        function(val)
            db.guildOnly = val
            SUI.ApplyAutoInviteSettings()
            SUI.SettingsChanged = true
        end)
    inviteCard:AddWidget(guildOnlyToggle)

    local convertToggle = C:CreateToggle(inviteCard, "Convert to Raid when Party is full", db.convertToRaid,
        function(val)
            db.convertToRaid = val
            SUI.SettingsChanged = true
        end)
    inviteCard:AddWidget(convertToggle)

    inviteCard:AddSectionHeader("Accept Invites")

    local acceptToggle = C:CreateToggle(inviteCard, "From Guild members", db.acceptGuildInvites,
        function(val)
            db.acceptGuildInvites = val
            SUI.ApplyAutoInviteSettings()
            SUI.SettingsChanged = true
        end)
    inviteCard:AddWidget(acceptToggle)

    local acceptBNetToggle = C:CreateToggle(inviteCard, "From Battle.net friends", db.acceptBNetInvites,
        function(val)
            db.acceptBNetInvites = val
            SUI.ApplyAutoInviteSettings()
            SUI.SettingsChanged = true
        end)
    inviteCard:AddWidget(acceptBNetToggle)

    y = y + inviteCard:GetHeight() + theme.padding.small

end

function SUI.BuildGeneralTab()
    if not generalTab then
        CreateGeneralTab()
    end
    generalTab:Show()
end
