---@class SUI : SF
---@class SUI
local SUI = select(2, ...)
local C = SUI.Components

SUI.Setup(addonName)
SUI.InitTheme()

local function T() return SUI.Theme end
local SetBackdrop = C.SetBackdrop
local ApplyFont = C.ApplyFont

SUI.frames = SUI.frames or {}

local registeredTabs = {}

function SUI.AddTab(key, title, onSelect)
    table.insert(registeredTabs, { key = key, title = title, onSelect = onSelect })
end

SwirlUI_AddTab = SUI.AddTab
SwirlUI_Components = SUI.Components
SwirlUI_Theme = SUI.Theme
SwirlUI = SUI

local tabs = {
    {
        key = "General",
        title = "General",
        onSelect = function(content)
            SUI.frames.generalContent = content
            if SUI.BuildGeneralTab then SUI.BuildGeneralTab() end
        end,
    },
    {
        key = "User Interface",
        title = "User Interface",
        onSelect = function(content)
            SUI.frames.userInterfaceContent = content
            if SUI.BuildUserInterfaceTab then SUI.BuildUserInterfaceTab() end
        end,
    },
}

local function BuildHeader(win, titleText, onClose)
    local theme = T()
    local header = CreateFrame("Frame", nil, win, "BackdropTemplate")
    header:SetHeight(theme.headerHeight)
    header:SetPoint("TOPLEFT", win, "TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", win, "TOPRIGHT", 0, 0)
    SetBackdrop(header, theme.bg.med, theme.border.color)

    local hdrLine = win:CreateTexture(nil, "ARTWORK")
    hdrLine:SetHeight(1)
    hdrLine:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, 0)
    hdrLine:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, 0)
    hdrLine:SetColorTexture(1, 1, 1, 0.12)

    local titleFS = header:CreateFontString(nil, "OVERLAY")
    ApplyFont(titleFS, "large")
    titleFS:SetText(titleText or "")
    titleFS:SetPoint("LEFT", header, "LEFT", theme.padding.large, 0)
    header.titleFS = titleFS

    local closeBtn = C:CreateCloseButton(header, onClose)
    closeBtn:SetPoint("RIGHT", header, "RIGHT", -6, 0)

    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() win:StartMoving() end)
    header:SetScript("OnDragStop", function() win:StopMovingOrSizing() end)

    return header, closeBtn
end

local function BuildFooter(win, text)
    local theme = T()
    local footer = CreateFrame("Frame", nil, win, "BackdropTemplate")
    footer:SetHeight(theme.footerHeight)
    footer:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", 0, 0)
    footer:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", 0, 0)
    SetBackdrop(footer, theme.bg.med, theme.border.color)

    local footLine = win:CreateTexture(nil, "ARTWORK")
    footLine:SetHeight(1)
    footLine:SetPoint("BOTTOMLEFT", footer, "TOPLEFT", 0, 0)
    footLine:SetPoint("BOTTOMRIGHT", footer, "TOPRIGHT", 0, 0)
    footLine:SetColorTexture(1, 1, 1, 0.08)

    if text then
        local eb = CreateFrame("EditBox", nil, footer)
        eb:SetAutoFocus(false)
        eb:SetFontObject("GameFontNormal")
        ApplyFont(eb, "small")
        local color = theme.text.muted
        eb:SetTextColor(color.r, color.g, color.b, 1)
        eb:SetText(text)
        eb:SetWidth(160)
        eb:SetHeight(theme.footerHeight)
        eb:SetPoint("RIGHT", footer, "RIGHT", -theme.padding.med, 0)
        eb:SetJustifyH("RIGHT")
        eb:SetScript("OnEscapePressed", function() eb:ClearFocus() end)
        eb:SetScript("OnEditFocusGained", function() eb:HighlightText() end)
        eb:SetScript("OnEditFocusLost", function() eb:HighlightText(0, 0) end)
    end

    return footer
end

local function BuildTabArea(win, header, footer, tabs)
    local tabArea = CreateFrame("Frame", nil, win)
    tabArea:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -1)
    tabArea:SetPoint("BOTTOMRIGHT", footer, "TOPRIGHT", 0, 1)

    local _, _, ctrl = C.CreateVerticalTabs(tabArea, tabs)
    return tabArea, ctrl
end

function SUI.Show()
    if _G.SWIRLUI_MAIN_FRAME then
        _G.SWIRLUI_MAIN_FRAME:Show()
        _G.SWIRLUI_MAIN_FRAME:Raise()
        return
    end

    local theme = T()
    local WIN_W = 680
    local WIN_H = 520

    local win = CreateFrame("Frame", "SWIRLUI_MAIN_FRAME", UIParent, "BackdropTemplate")
    win:SetSize(WIN_W, WIN_H)
    win:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    win:SetFrameStrata("HIGH")
    win:SetToplevel(true)
    win:SetClampedToScreen(true)
    win:SetMovable(true)
    win:EnableMouse(true)
    SetBackdrop(win, theme.bg.dark, theme.border.color)

    local header, closeBtn = BuildHeader(win, SUI.HeaderNoColon, function()
        win:Hide()
        if SUI.SettingsChanged then
            SUI.SettingsChanged = false
            SUI:ReloadDialog()
        end
    end)

    local version = C_AddOns.GetAddOnMetadata(addonName, "Version") or ""
    if version ~= "" then
        local verFS = header:CreateFontString(nil, "OVERLAY")
        ApplyFont(verFS, "small")
        verFS:SetText("v" .. version)
        local color = theme.text.muted
        verFS:SetTextColor(color.r, color.g, color.b, 1)
        verFS:SetPoint("LEFT", header.titleFS, "RIGHT", 6, 0)
    end

    local footer = BuildFooter(win, "discord.gg/ZU5rhXtbNd")

    for _, tab in ipairs(registeredTabs) do
        table.insert(tabs, tab)
    end

    local _, ctrl = BuildTabArea(win, header, footer, tabs)

    SUI.frames.optionsFrame = win
    SUI.frames.tabController = ctrl
    SUI.frames.generalContent = ctrl.GetContent("General")
    SUI.frames.userInterfaceContent = ctrl.GetContent("User Interface")

    win:EnableKeyboard(true)
    win:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" and self:IsShown() then
            self:SetPropagateKeyboardInput(false)
            closeBtn:Click()
        else
            self:SetPropagateKeyboardInput(true)
        end
    end)

    _G["SwirlUI_Main_Frame"] = win
    table.insert(UISpecialFrames, "SwirlUI_Main_Frame")
    win:Show()
    _G.SWIRLUI_MAIN_FRAME = win
end

function SUI.ShowExport()
    if _G.SWIRLUI_EXPORT_FRAME then
        _G.SWIRLUI_EXPORT_FRAME:Show()
        return
    end

    local theme = T()
    local btnH = 24
    local spacing = 5
    local n = #SUI.ImportProfiles
    local WIN_W = 320
    local WIN_H = n * (btnH + spacing) + 60

    local win = CreateFrame("Frame", "SWIRLUI_EXPORT_FRAME", UIParent, "BackdropTemplate")
    win:SetSize(WIN_W, WIN_H)
    win:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    win:SetFrameStrata("DIALOG")
    win:SetToplevel(true)
    win:SetMovable(true)
    win:EnableMouse(true)
    SetBackdrop(win, theme.bg.dark, theme.border.color)

    BuildHeader(win, SUI.NameNoCore .. " Export", function() win:Hide() end)

    local yOff = -(theme.headerHeight + spacing)
    for _, profile in ipairs(SUI.ImportProfiles) do
        local lbl = string.format("Export %s", WrapTextInColorCode(profile.name, profile.color))
        local btn = C:CreateButton(win, lbl, {
            width = WIN_W - theme.padding.med * 2,
            height = btnH,
            callback = function()
                local fn = string.format("Export%s", profile.short or profile.name)
                if SUI.Imports[fn] then SUI.Imports[fn](SUI.Imports) end
            end,
        })
        btn:SetPoint("TOPLEFT", win, "TOPLEFT", theme.padding.med, yOff)
        yOff = yOff - (btnH + spacing)
    end

    win:Show()
    _G["SwirlUI_Export_Frame"] = win
    table.insert(UISpecialFrames, "SwirlUI_Export_Frame")
    _G.SWIRLUI_EXPORT_FRAME = win
end

function SUI:ReloadDialog()
    SUI.Components.ShowConfirm("Reload the UI to apply changes?", function()
        C_UI.Reload()
    end)
end

function SUI.CreateStatusDialog(title, content, editBoxContent)
    local theme = T()
    local WIN_W = 400
    local WIN_H = 25 + (content and 30 or 0) + (editBoxContent and 40 or 0) + 34

    local win = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    win:SetSize(WIN_W, WIN_H)
    win:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    win:SetFrameStrata("DIALOG")
    win:SetMovable(false)
    SetBackdrop(win, theme.bg.dark, theme.border.color)

    local header = BuildHeader(win, title or "", function() win:Hide() end)
    header.titleFS:SetPoint("CENTER", header, "CENTER", 0, 0)

    local yOff = -(theme.headerHeight + theme.padding.med)

    if content then
        local fs = win:CreateFontString(nil, "OVERLAY")
        ApplyFont(fs, "normal")
        fs:SetText(content)
        local color = theme.text.primary
        fs:SetTextColor(color.r, color.g, color.b, 1)
        fs:SetPoint("TOPLEFT", win, "TOPLEFT", theme.padding.med, yOff)
        yOff = yOff - 30
    end

    if editBoxContent then
        local editBox = CreateFrame("EditBox", nil, win, "InputBoxTemplate")
        editBox:SetSize(WIN_W - theme.padding.med * 2, 22)
        editBox:SetPoint("TOPLEFT", win, "TOPLEFT", theme.padding.med, yOff)
        editBox:SetAutoFocus(false)
        editBox:SetText(editBoxContent)
        editBox:SetCursorPosition(0)
        editBox:HighlightText()
        editBox:SetFocus()
    end

    local okBtn = C:CreateButton(win, "OK", {
        width = 80,
        height = 24,
        callback = function() win:Hide() end,
    })
    okBtn:SetPoint("BOTTOM", win, "BOTTOM", 0, theme.padding.med)

    win:Show()
    return win
end

SLASH_SWIRLUI1 = "/swirlui"
SLASH_SWIRLUI2 = "/sui"
SLASH_SWIRLUI3 = "/swirl"
SlashCmdList["SWIRLUI"] = function(msg)
    if msg == "export" then
        SUI.ShowExport()
    elseif msg == "bind" then
        SUI.ToggleBindMode()
    elseif msg == "bars" then
        local shown = SUI.ToggleMouseoverBars()
        print(string.format("%s Mouseover bars %s.", SUI.Header, shown and "forced visible" or "back to normal"))
    elseif msg == "toast" then
        SUI.Components.ShowToast("SwirlUI\nTest toast message", 3)
    elseif msg == "confirm" then
        SUI.Components.ShowConfirm("Test confirm dialog?", function()
            print("SwirlUI: confirmed")
        end, function()
            print("SwirlUI: cancelled")
        end)
    else
        SUI.Show()
    end
end
