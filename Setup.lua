---@class SUI
local SUI = select(2, ...)

local PLAYER_CLASS = select(2, UnitClass("player"))
local PLAYER_CLASS_COLOR = RAID_CLASS_COLORS[PLAYER_CLASS]
local PLAYER_CLASS_COLOR_HEX = CreateColor(PLAYER_CLASS_COLOR.r, PLAYER_CLASS_COLOR.g, PLAYER_CLASS_COLOR.b):GenerateHexColor()

local function BugSackMinimapButton()
    if not C_AddOns.IsAddOnLoaded("BugSack") then return end
    local LDB = LibStub("LibDataBroker-1.1", true)
    if not LDB then return end

    local bugSackLDB = LDB:GetDataObjectByName("BugSack")
    if not bugSackLDB then return end

    local bugAddon = _G["BugSack"]
    if not bugAddon or not bugAddon.UpdateDisplay or not bugAddon.GetErrors then return end

    if _G["SwirlUIBugSackButton"] then return end
    local SwirlUIBugSackButton = CreateFrame("Button", "SwirlUIBugSackButton", UIParent, "BackdropTemplate")
    SwirlUIBugSackButton:SetSize(22, 22)
    SwirlUIBugSackButton:SetPoint("BOTTOMLEFT", Minimap, "BOTTOMLEFT", 2, 2)
    SwirlUIBugSackButton.Text = SwirlUIBugSackButton:CreateFontString(nil, "OVERLAY")
    SwirlUIBugSackButton.Text:SetFont(SUI.Theme.font.path, 16, "OUTLINE")
    SwirlUIBugSackButton.Text:SetPoint("CENTER", SwirlUIBugSackButton, "CENTER", 0, 0)
    SwirlUIBugSackButton.Text:SetTextColor(1, 1, 1)
    SwirlUIBugSackButton.Text:SetText("|cFF49AF4C0|r")
    SwirlUIBugSackButton:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false, tileSize = 0, edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    SwirlUIBugSackButton:SetBackdropColor(6/255, 8/255, 8/255, 0.75)
    SwirlUIBugSackButton:SetBackdropBorderColor(0, 0, 0, 1)

    SwirlUIBugSackButton:SetScript("OnClick", function(self, mouseButton)
        if bugSackLDB.OnClick then
            bugSackLDB.OnClick(self, mouseButton)
        end
    end)

    SwirlUIBugSackButton:SetScript("OnEnter", function(self)
        if bugSackLDB.OnTooltipShow then
            GameTooltip:SetOwner(self, "ANCHOR_CURSOR_RIGHT")
            SwirlUIBugSackButton:SetBackdropBorderColor(PLAYER_CLASS_COLOR.r, PLAYER_CLASS_COLOR.g, PLAYER_CLASS_COLOR.b, 1)
            bugSackLDB.OnTooltipShow(GameTooltip)
            GameTooltip:Show()
        end
    end)

    SwirlUIBugSackButton:SetScript("OnLeave", function()
        SwirlUIBugSackButton:SetBackdropBorderColor(0, 0, 0, 1)
        GameTooltip:Hide()
    end)

    hooksecurefunc(bugAddon, "UpdateDisplay", function()
        local count = #bugAddon:GetErrors(BugGrabber:GetSessionId())
        if count == 0 then
            SwirlUIBugSackButton.Text:SetText("|cFF49AF4C" .. count .. "|r")
        else
            SwirlUIBugSackButton.Text:SetText("|cFFC63F3F" .. count .. "|r")
        end
    end)
end

local function MailMinimapDataText()
    local SwirlUIMailButton = CreateFrame("Frame", "SwirlUIMailButton", UIParent)
    SwirlUIMailButton:SetPoint("TOPRIGHT", Minimap, "TOPRIGHT", -5, -2)

    SwirlUIMailButton.texture = SwirlUIMailButton:CreateTexture(nil, "OVERLAY")
    SwirlUIMailButton.texture:SetAllPoints(SwirlUIMailButton)
    SwirlUIMailButton.texture:SetTexture("Interface\\AddOns\\SwirlUI\\Media\\mail.tga")
    SwirlUIMailButton:SetSize(16, 16)

    SwirlUIMailButton:RegisterEvent("UPDATE_PENDING_MAIL")
    
    function SwirlUIMailButton:UpdateMailVisibility()
        if HasNewMail() then
            self:Show()
        else
            self:Hide()
        end
    end

    SwirlUIMailButton:SetScript("OnEvent", function(self, event)
        if event == "UPDATE_PENDING_MAIL" then
            self:UpdateMailVisibility()
        end
    end)

    SwirlUIMailButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR_RIGHT")
        GameTooltip:AddLine("Unread mail from:")
        local m1, m2, m3 = GetLatestThreeSenders()
        GameTooltip:AddLine(m1)
        GameTooltip:AddLine(m2)
        GameTooltip:AddLine(m3)
        GameTooltip:Show()
    end)

    SwirlUIMailButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    SwirlUIMailButton:UpdateMailVisibility()
end

local function MinimapData()
    BugSackMinimapButton()
    MailMinimapDataText()
end

local function ApplyChatBubbleSettings()
    if SwirlUIDB and SwirlUIDB.uiSettings and SwirlUIDB.uiSettings.chatBubbles.enabled then
        ChatBubbleFont:SetFont(SUI.Theme.font.path, SwirlUIDB.uiSettings.chatBubbles.fontSize, "OUTLINE")
    end
end

local function RemoveFontShadow(region)
    if not region or not region.SetShadowOffset then return end
    region:SetShadowOffset(0, 0)
    region:SetShadowColor(0, 0, 0, 0)
end

local function RemoveChatFontShadows()
    for i = 1, NUM_CHAT_WINDOWS do
        local chat = _G["ChatFrame" .. i]
        if chat then
            RemoveFontShadow(chat)
            RemoveFontShadow(chat.editBox)
            local tab = _G["ChatFrame" .. i .. "Tab"]
            if tab then RemoveFontShadow(tab.Text) end
        end
    end
end

local chatShadowHooksInstalled = false
local function SetupChatShadowHooks()
    if chatShadowHooksInstalled then return end
    chatShadowHooksInstalled = true
    hooksecurefunc("FCF_OpenNewWindow", RemoveChatFontShadows)
    hooksecurefunc("FCF_OpenTemporaryWindow", RemoveChatFontShadows)
end

function SUI.ApplyChatFontSettings()
    if SwirlUIDB and SwirlUIDB.uiSettings and SwirlUIDB.uiSettings.chatFont.removeShadow then
        RemoveChatFontShadows()
        SetupChatShadowHooks()
    end
end

local function ApplyZoneTextSettings()
    if SwirlUIDB and SwirlUIDB.uiSettings and SwirlUIDB.uiSettings.zoneText.enabled then
        local settings = SwirlUIDB.uiSettings.zoneText
        ZoneTextString:SetFont(SUI.Theme.font.path, settings.zoneFontSize, "OUTLINE")
        SubZoneTextString:SetFont(SUI.Theme.font.path, settings.subZoneFontSize, "OUTLINE")
        PVPInfoTextString:SetFont(SUI.Theme.font.path, settings.pvpInfoFontSize, "OUTLINE")
        PVPArenaTextString:SetFont(SUI.Theme.font.path, settings.pvpArenaFontSize, "OUTLINE")
    end
end

local function ApplyUIErrorsSettings()
    if SwirlUIDB and SwirlUIDB.uiSettings and SwirlUIDB.uiSettings.uiErrors.enabled then
        UIErrorsFrame:SetFont(SUI.Theme.font.path, SwirlUIDB.uiSettings.uiErrors.fontSize, "OUTLINE")
        UIErrorsFrame:SetShadowOffset(0, 0)
        UIErrorsFrame:ClearAllPoints()
        UIErrorsFrame:SetPoint("CENTER", UIParent, "CENTER", SwirlUIDB.uiSettings.uiErrors.offsetX, SwirlUIDB.uiSettings.uiErrors.offsetY)
    end
end

local function ApplyActionStatusSettings()
    if SwirlUIDB and SwirlUIDB.uiSettings and SwirlUIDB.uiSettings.actionStatus.enabled then
        ActionStatus.Text:SetFont(SUI.Theme.font.path, SwirlUIDB.uiSettings.actionStatus.fontSize, "OUTLINE")
        ActionStatus.Text:SetShadowOffset(0, 0)
        ActionStatus.Text:ClearAllPoints()
        ActionStatus.Text:SetPoint("CENTER", UIParent, "CENTER", SwirlUIDB.uiSettings.actionStatus.offsetX, SwirlUIDB.uiSettings.actionStatus.offsetY)
    end
end

function ApplyMouseClickSettings()
    if SwirlUIDB and SwirlUIDB.uiSettings and SwirlUIDB.uiSettings.mouseClick then
        if SwirlUIDB.uiSettings.mouseClick.lfgListFrame then
            local frame = LFGListFrame.ApplicationViewer.UnempoweredCover
            if frame then
                frame:EnableMouse(false)
                frame:EnableMouseWheel(false)
                frame:SetToplevel(false)
            end
        end
        if SwirlUIDB.uiSettings.mouseClick.extraActionButton then
            ExtraActionBarFrame:EnableMouse(false)
            ExtraAbilityContainer:EnableMouse(false)
        end
    end
end

local function SkinLFGFont(fs)
    if not fs then return end
    local _, size = fs:GetFont()
    fs:SetFont(SUI.Theme.font.path, size or SUI.Theme.font.size.normal, "OUTLINE")
    RemoveFontShadow(fs)
end

local lfgFontHookInstalled = false
local function SetupLFGFontHooks()
    if lfgFontHookInstalled or not LFGListSearchEntry_Update then return end
    lfgFontHookInstalled = true
    hooksecurefunc("LFGListSearchEntry_Update", function(entry)
        SkinLFGFont(entry.Name)
        SkinLFGFont(entry.ActivityName)
        SkinLFGFont(entry.Playstyle)
    end)
end

local function SkinLFGApplicationViewer()
    local viewer = LFGListFrame and LFGListFrame.ApplicationViewer
    if not viewer then return end

    SkinLFGFont(viewer.EntryName)
    if viewer.DescriptionFrame then SkinLFGFont(viewer.DescriptionFrame.Text) end
    if viewer.UnempoweredCover then SkinLFGFont(viewer.UnempoweredCover.Label) end

    local headers = {
        viewer.NameColumnHeader,
        viewer.RoleColumnHeader,
        viewer.ItemLevelColumnHeader,
        LFGApplicationViewerRatingColumnHeader,
    }
    for i = 1, 4 do
        local header = headers[i]
        if header then SkinLFGFont(header.Label) end
    end
end

function SUI.ApplyLFGFontSkin()
    if SwirlUIDB and SwirlUIDB.uiSettings and SwirlUIDB.uiSettings.lfgFont and SwirlUIDB.uiSettings.lfgFont.enabled then
        SetupLFGFontHooks()
        SkinLFGApplicationViewer()
        local panel = LFGListFrame and LFGListFrame.SearchPanel
        if panel and panel:IsShown() and LFGListSearchPanel_UpdateResults then
            LFGListSearchPanel_UpdateResults(panel)
        end
    end
end

local function SkinExtraButton(button)
    local icon = button.Icon or button.icon
    if not icon then return end

    if button.IconMask then button.IconMask:Hide() end

    icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)

    local normal = button.NormalTexture or (button.GetNormalTexture and button:GetNormalTexture())
    if normal then normal:SetAlpha(0) end
    if button.style then button.style:SetAlpha(0) end

    if not button.SwirlBorder then
        SUI.Auras.CreateBorder(button, icon)
    end
    button.SwirlBorder:Show()
    button.SwirlBorder:ClearAllPoints()
    button.SwirlBorder:SetPoint("TOPLEFT", icon, "TOPLEFT", -1, 1)
    button.SwirlBorder:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, -1)
end

local function SkinExtraButtons()
    if ZoneAbilityFrame then
        if ZoneAbilityFrame.Style then ZoneAbilityFrame.Style:SetAlpha(0) end
        if ZoneAbilityFrame.SpellButtonContainer then
            for _, button in pairs({ZoneAbilityFrame.SpellButtonContainer:GetChildren()}) do
                SkinExtraButton(button)
            end
        end
    end
    if ExtraActionButton1 then
        SkinExtraButton(ExtraActionButton1)
    end
end

local extraButtonHooksInstalled = false
local function SetupExtraButtonHooks()
    if extraButtonHooksInstalled then return end
    extraButtonHooksInstalled = true
    if ZoneAbilityFrame and ZoneAbilityFrame.SpellButtonContainer and ZoneAbilityFrame.SpellButtonContainer.SetContents then
        hooksecurefunc(ZoneAbilityFrame.SpellButtonContainer, "SetContents", SkinExtraButtons)
    end
    if ExtraActionBarFrame then
        ExtraActionBarFrame:HookScript("OnShow", SkinExtraButtons)
    end
end

function SUI.ApplyExtraButtonSkin()
    if SwirlUIDB and SwirlUIDB.uiSettings and SwirlUIDB.uiSettings.skinExtraButtons and SwirlUIDB.uiSettings.skinExtraButtons.enabled then
        SkinExtraButtons()
        SetupExtraButtonHooks()
    end
end

local function ApplyUISettings()
    ApplyChatBubbleSettings()
    SUI.ApplyChatFontSettings()
    ApplyZoneTextSettings()
    ApplyUIErrorsSettings()
    ApplyActionStatusSettings()
    ApplyMouseClickSettings()
    SUI.Auras.Apply()
    SUI.ApplyExtraButtonSkin()
    SUI.ApplyLFGFontSkin()
    SUI.ApplyAutoInviteSettings()
    SUI.ApplyEllesmereSettings()
    SUI.Skins:Run()
end

local function CheckProfileVersionUpdates()
    if SwirlUIDB and SwirlUIDB.uiSettings and SwirlUIDB.uiSettings.silence then return end
    for _, profile in ipairs(SUI.ImportProfiles) do
        if (profile.string or profile.data) and IsAddOnLoaded(profile.name) then
            local currentVersion = profile.version
            local storedVersion = SwirlUIDB.profileVersions[profile.name]
            
            if storedVersion and storedVersion ~= currentVersion then
                local addonColor = WrapTextInColorCode(profile.name, profile.color)
                local versionColor = WrapTextInColorCode(currentVersion, SUI.Friendly)
                SUI.Utils:Print(string.format("Update available for %s to v%s", addonColor, versionColor))
            end
        end
    end
end

local function CheckProfilesReady()
    if SwirlUIDB and SwirlUIDB.uiSettings and SwirlUIDB.uiSettings.silence then return end
    local readyProfiles = {}

    for _, profile in ipairs(SUI.Utils:GetAllProfiles()) do
        local status = SUI.Utils:GetAddonStatus(profile)
        if status == SUI.STATUS.READY then
            table.insert(readyProfiles, profile)
        end
    end

    if #readyProfiles > 0 then
        local readyCount = #readyProfiles
        local readyColor = WrapTextInColorCode(string(readyCount), SUI.Theme.warning)
        SUI.Utils:Print(string.format("Profiles ready: %s", readyColor))
    end
end

local function SetupDB()
    if not SwirlUIDB then
        SwirlUIDB = {
            profileVersions = {},
            uiSettings = {},
        }
    end

    if not SwirlUIDB.profileVersions then
        SwirlUIDB.profileVersions = {}
    end

    local defaultUiSettings = {
        silence = false,
        chatBubbles = { enabled = true, fontSize = 8 },
        chatFont = { removeShadow = true },
        chatRoleIcons = { enabled = true },
        zoneText = { enabled = true, zoneFontSize = 25, subZoneFontSize = 24, pvpInfoFontSize = 22, pvpArenaFontSize = 22 },
        uiErrors = { enabled = true, fontSize = 12, offsetX = 0, offsetY = 200 },
        actionStatus = { enabled = true, fontSize = 12, offsetX = 0, offsetY = 200 },
        mouseClick = { extraActionButton = true, lfgListFrame = true },
        skinAuras = { enabled = true, width = 37, height = 37, fontSize = 12 },
        skinExtraButtons = { enabled = true },
        lfgFont = { enabled = true },
        skins = { enabled = true, rareScanner = true, waypointUI = false, opie = true, plumber = true },
        ellesmere = { powerTextAboveCastbar = true, tooltipTargetLine = true },
        tooltip = { guildRank = true },
        zenPilgrimage = { enabled = true, size = 48, offsetX = 0, offsetY = 150 },
        autoInvite = { enabled = true, keywords = "inv", guildOnly = true, convertToRaid = true, acceptGuildInvites = false, acceptBNetInvites = false },
    }

    if not SwirlUIDB.uiSettings then
        SwirlUIDB.uiSettings = {}
    end

    for key, defaultValue in pairs(defaultUiSettings) do
        if SwirlUIDB.uiSettings[key] == nil then
            SwirlUIDB.uiSettings[key] = defaultValue
        elseif type(defaultValue) == "table" and type(SwirlUIDB.uiSettings[key]) == "table" then
            for subKey, subDefault in pairs(defaultValue) do
                if SwirlUIDB.uiSettings[key][subKey] == nil then
                    SwirlUIDB.uiSettings[key][subKey] = subDefault
                end
            end
        elseif type(defaultValue) ~= type(SwirlUIDB.uiSettings[key]) then
            SwirlUIDB.uiSettings[key] = defaultValue
        end
    end
end

function SUI:Initialize()
    SetupDB()

    ApplyUISettings()
    MinimapData()

    CheckProfileVersionUpdates()
    CheckProfilesReady()
end