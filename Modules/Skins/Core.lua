---@class SUI
local SUI = select(2, ...)

SUI.Skins = SUI.Skins or {}
local S = SUI.Skins

local function T() return SUI.Theme end

S.bg = CreateColor(6 / 255, 8 / 255, 8 / 255, 0.75)

local state = setmetatable({}, { __mode = "k" })
function S.data(obj)
    local d = state[obj]
    if not d then d = {}; state[obj] = d end
    return d
end

local CLEAR_TEXTURE = 0

function S.StripTexture(tex, kill)
    if not tex then return end
    tex:SetTexture(CLEAR_TEXTURE)
    if tex.SetAtlas then tex:SetAtlas("") end
    if kill then
        tex:SetAlpha(0)
        tex:Hide()
    end
end

function S.StripTextures(frame, keep, kill)
    if not frame or not frame.GetRegions then return end
    for _, region in ipairs({ frame:GetRegions() }) do
        if region:IsObjectType("Texture") and not (keep and keep[region]) then
            S.StripTexture(region, kill)
        end
    end
end

function S.ClearButtonArt(button)
    if not button then return end
    if button.SetNormalTexture then S.StripTexture(button:GetNormalTexture()) end
    if button.SetPushedTexture then S.StripTexture(button:GetPushedTexture()) end
    if button.SetDisabledTexture then S.StripTexture(button:GetDisabledTexture()) end
    if button.SetHighlightTexture then S.StripTexture(button:GetHighlightTexture()) end
end

function S.SetFont(fs, size, outline)
    if not fs or not fs.SetFont then return end
    fs:SetFont(T().font.path, size or T().font.size.normal, outline or "OUTLINE")
    fs:SetShadowOffset(0, 0)
    fs:SetShadowColor(0, 0, 0, 0)
end

function S.Backdrop(frame, bg, border)
    if not frame then return end
    bg = bg or S.bg
    border = border or T().border.color

    if not frame.SetBackdrop then
        Mixin(frame, BackdropTemplateMixin)
        if frame.OnBackdropSizeChanged then
            frame:HookScript("OnSizeChanged", frame.OnBackdropSizeChanged)
        end
    end

    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, tileSize = 0, edgeSize = T().border.size,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    frame:SetBackdropColor(bg.r, bg.g, bg.b, bg.a)
    frame:SetBackdropBorderColor(border.r, border.g, border.b, border.a)

    if frame.Center then frame.Center:Show() end
end

function S.CreateBackdrop(frame, bg, levelOffset)
    local existing = S.data(frame).backdrop
    if existing then return existing end

    local backdrop = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    backdrop:SetAllPoints(frame)
    backdrop:SetFrameLevel(math.max(0, frame:GetFrameLevel() + (levelOffset or -1)))
    S.Backdrop(backdrop, bg)
    S.data(frame).backdrop = backdrop
    return backdrop
end

function S.Hover(frame, target)
    if not frame or S.data(frame).hover then return end
    target = target or frame
    if not target.SetBackdropBorderColor then return end
    S.data(frame).hover = true

    frame:HookScript("OnEnter", function()
        local c = T().accent
        target:SetBackdropBorderColor(c.r, c.g, c.b, 1)
    end)
    frame:HookScript("OnLeave", function()
        local c = T().border.color
        target:SetBackdropBorderColor(c.r, c.g, c.b, c.a)
    end)
end

function S.Border(owner, anchor, inset)
    inset = inset or 1
    local existing = S.data(owner).border
    if existing then
        existing:ClearAllPoints()
        existing:SetPoint("TOPLEFT", anchor, "TOPLEFT", -inset, inset)
        existing:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", inset, -inset)
        return existing
    end

    local border = CreateFrame("Frame", nil, owner, "BackdropTemplate")
    border:SetFrameLevel(math.max(0, owner:GetFrameLevel() - 1))
    border:SetPoint("TOPLEFT", anchor, "TOPLEFT", -inset, inset)
    border:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", inset, -inset)
    border:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = T().border.size,
    })
    local c = T().border.color
    border:SetBackdropBorderColor(c.r, c.g, c.b, c.a)
    S.data(owner).border = border
    return border
end

function S.Icon(owner, icon)
    if not icon then return end
    icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    S.Border(owner, icon)
end

function S.CloseButton(button, size)
    if not button or S.data(button).skinned then return end
    S.data(button).skinned = true

    S.ClearButtonArt(button)
    if size then button:SetSize(size, size) end

    local text = button:CreateFontString(nil, "OVERLAY")
    S.SetFont(text, T().font.size.normal)
    text:SetPoint("CENTER")
    text:SetText("x")
    local c = T().text.secondary
    text:SetTextColor(c.r, c.g, c.b, 1)

    button:HookScript("OnEnter", function()
        local a = T().accent
        text:SetTextColor(a.r, a.g, a.b, 1)
    end)
    button:HookScript("OnLeave", function()
        local n = T().text.secondary
        text:SetTextColor(n.r, n.g, n.b, 1)
    end)
end

function S.EditBox(box)
    if not box or S.data(box).skinned then return end
    S.data(box).skinned = true

    S.StripTextures(box)
    local backdrop = S.CreateBackdrop(box)
    S.SetFont(box, T().font.size.normal)
    local c = T().text.primary
    box:SetTextColor(c.r, c.g, c.b, 1)
    box:SetTextInsets(T().padding.small, T().padding.small, 0, 0)
    S.Hover(box, backdrop)
end

local pending = {}
local registered = {}

function S:Register(addonName, key, fn)
    registered[#registered + 1] = { addon = addonName, key = key, fn = fn }
    pending[addonName] = pending[addonName] or {}
    local list = pending[addonName]
    list[#list + 1] = { key = key, fn = fn }
end

local function Enabled(key)
    local db = SwirlUIDB and SwirlUIDB.uiSettings and SwirlUIDB.uiSettings.skins
    return db and db.enabled and db[key] ~= false
end


local function RunEntry(entry)
    if not Enabled(entry.key) then return end
    local ok, err = pcall(entry.fn)
    if not ok then
        SUI.Utils:Print(string.format("skin error [%s]: %s", entry.key, tostring(err)))
    end
end

local function RunFor(addonName)
    local list = pending[addonName]
    if not list then return end
    pending[addonName] = nil

    for _, entry in ipairs(list) do
        RunEntry(entry)
    end
end

function S:Rerun(key)
    for _, entry in ipairs(registered) do
        if entry.key == key and C_AddOns.IsAddOnLoaded(entry.addon) then
            RunEntry(entry)
        end
    end
end

local dispatcher
function S:Run()
    for _, entry in ipairs(registered) do
        if C_AddOns.IsAddOnLoaded(entry.addon) then
            pending[entry.addon] = nil
            RunEntry(entry)
        end
    end

    if next(pending) and not dispatcher then
        dispatcher = CreateFrame("Frame")
        dispatcher:RegisterEvent("ADDON_LOADED")
        dispatcher:SetScript("OnEvent", function(frame, _, name)
            RunFor(name)
            if not next(pending) then
                frame:UnregisterEvent("ADDON_LOADED")
            end
        end)
    end
end
