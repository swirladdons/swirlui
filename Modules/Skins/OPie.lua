---@class SUI : SF
local SUI = select(2, ...)
local S = SUI.Skins

local function T() return SUI.Theme end

local cdFont = CreateFont("SwirlUIOPieCooldownFont")

local Indicator = {}

local function UpdateEdge(self)
    if self.highlighted then
        local c = T().accent
        self.border:SetBackdropBorderColor(c.r, c.g, c.b, 1)
    elseif self.glowing then
        local c = T().accentDim
        self.border:SetBackdropBorderColor(c.r, c.g, c.b, 1)
    else
        self.border:SetBackdropBorderColor(self.edgeR, self.edgeG, self.edgeB, 1)
    end
end

local function AdjustIconAspect(self, aspect)
    if self.iconAspect == aspect then return end
    self.iconAspect = aspect
    local w, h = self.iconbg:GetSize()
    self.icon:SetSize(aspect < 1 and h * aspect or w, aspect > 1 and w / aspect or h)
end

function Indicator:SetIcon(texture, aspect)
    self.icon:SetTexture(texture)
    self.icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    AdjustIconAspect(self, aspect)
end

function Indicator:SetIconAtlas(atlas, aspect)
    self.icon:SetAtlas(atlas)
    AdjustIconAspect(self, aspect)
end

function Indicator:SetIconTexCoord(a, b, c, d, e, f, g, h)
    if not (a and b and c and d) then return end
    if e and f and g and h then
        self.icon:SetTexCoord(a, b, c, d, e, f, g, h)
    else
        self.icon:SetTexCoord(a, b, c, d)
    end
end

function Indicator:SetIconVertexColor(r, g, b)
    self.icon:SetVertexColor(r, g, b)
end

function Indicator:SetDominantColor(r, g, b)
    r, g, b = r or 1, g or 1, b or 0.6
    self.edgeR, self.edgeG, self.edgeB = r * 0.8, g * 0.8, b * 0.8
    UpdateEdge(self)
end

function Indicator:SetUsable(usable, _usableCharge, _cd, nomana, norange)
    local state = usable and 0 or (norange and 1 or (nomana and 2 or 3))
    if self.ustate == state then return end
    self.ustate = state

    self.veil:SetAlpha(usable and 0 or 0.4)

    if not usable and (nomana or norange) then
        local c = norange and T().error or T().accent
        self.stateBar:SetColorTexture(c.r, c.g, c.b, 1)
        self.stateBar:Show()
    else
        self.stateBar:Hide()
    end
end

function Indicator:SetOverlayIcon(tex, w, h, ...)
    local oi = self.overIcon
    if not tex then return oi:Hide() end
    oi:SetTexture(tex)
    oi:SetSize(w, h)
    if ... then
        oi:SetTexCoord(...)
    else
        oi:SetTexCoord(0, 1, 0, 1)
    end
    oi:Show()
end

function Indicator:SetOverlayIconVertexColor(...)
    self.overIcon:SetVertexColor(...)
end

function Indicator:SetCount(count)
    self.count:SetText(count or "")
end

function Indicator:SetBinding(binding)
    self.key:SetText(binding and GetBindingText(binding, 1) or "")
end

function Indicator:SetCooldown(remain, duration, usable)
    if duration and remain and duration > 0 and remain > 0 then
        self.cd:SetDrawEdge(usable and true or false)
        self.cd:SetDrawSwipe(not usable)
        self.cd:SetCooldown(GetTime() + remain - duration, duration)
        self.cd:Show()
    else
        self.cd:Hide()
    end
end

function Indicator:SetCooldownDuration(duration, isRecharge)
    if not duration then
        self.cd:Hide()
        return
    end
    self.cd:SetDrawEdge(isRecharge and true or false)
    self.cd:SetDrawSwipe(not isRecharge)
    self.cd:SetCooldownFromDurationObject(duration)
    self.cd:Show()
end

function Indicator:SetHighlighted(highlight)
    self.highlighted = highlight
    UpdateEdge(self)
end

function Indicator:SetOuterGlow(shown)
    self.glowing = shown
    UpdateEdge(self)
end

function Indicator:SetActive(active)
    self.activeTint:SetShown(active)
end

function Indicator:SetEquipState(isInContainer, isInInventory)
    local shown = isInContainer or isInInventory
    self.equipBar:SetShown(shown)
    if shown then
        local c = isInInventory and T().success or T().warning
        self.equipBar:SetColorTexture(c.r, c.g, c.b, 1)
    end
end

function Indicator:SetShortLabel(text)
    self.label:SetText(text)
end

function Indicator:SetQualityOverlay(_qual, atlas)
    if atlas then self.qualityMark:SetAtlas(atlas) end
    self.qualityMark:SetShown(atlas ~= nil)
end

local function CreateIndicator(name, parent, size, _nested)
    local f = CreateFrame("Frame", name, parent)
    f:SetSize(size, size)
    Mixin(f, Indicator)
    f.iconAspect = 1
    f.ustate = -1

    local bc = T().border.color
    f.edgeR, f.edgeG, f.edgeB = bc.r, bc.g, bc.b

    local art = CreateFrame("Frame", nil, f)
    art:SetAllPoints()
    art:SetFrameLevel(f:GetFrameLevel() + 1)

    f.iconbg = art:CreateTexture(nil, "BACKGROUND")
    f.iconbg:SetPoint("TOPLEFT", 1, -1)
    f.iconbg:SetPoint("BOTTOMRIGHT", -1, 1)
    f.iconbg:SetColorTexture(0, 0, 0, 1)

    f.icon = art:CreateTexture(nil, "ARTWORK")
    f.icon:SetPoint("CENTER")
    f.icon:SetSize(size - 2, size - 2)
    f.icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)

    f.border = S.Border(f, f.iconbg, 1)

    f.activeTint = art:CreateTexture(nil, "ARTWORK", nil, 1)
    f.activeTint:SetAllPoints(f.iconbg)
    local a = T().accentFade
    f.activeTint:SetColorTexture(a.r, a.g, a.b, a.a)
    f.activeTint:Hide()

    f.veil = art:CreateTexture(nil, "ARTWORK", nil, 2)
    f.veil:SetAllPoints(f.iconbg)
    f.veil:SetColorTexture(0, 0, 0, 1)
    f.veil:SetAlpha(0)

    f.stateBar = art:CreateTexture(nil, "OVERLAY")
    f.stateBar:SetPoint("BOTTOMLEFT", f.iconbg, "BOTTOMLEFT", 0, 0)
    f.stateBar:SetPoint("BOTTOMRIGHT", f.iconbg, "BOTTOMRIGHT", 0, 0)
    f.stateBar:SetHeight(2)
    f.stateBar:Hide()

    f.equipBar = art:CreateTexture(nil, "OVERLAY")
    f.equipBar:SetPoint("TOPLEFT", f.iconbg, "TOPLEFT", 0, 0)
    f.equipBar:SetPoint("TOPRIGHT", f.iconbg, "TOPRIGHT", 0, 0)
    f.equipBar:SetHeight(2)
    f.equipBar:Hide()

    f.overIcon = art:CreateTexture(nil, "OVERLAY")
    f.overIcon:SetPoint("BOTTOMLEFT", f.iconbg, "BOTTOMLEFT", 2, 2)
    f.overIcon:Hide()

    f.qualityMark = art:CreateTexture(nil, "OVERLAY")
    f.qualityMark:SetPoint("TOPRIGHT", f.iconbg, "TOPRIGHT", -2, -2)
    f.qualityMark:SetSize(14, 14)
    f.qualityMark:Hide()

    f.cd = CreateFrame("Cooldown", nil, art, "CooldownFrameTemplate")
    f.cd:ClearAllPoints()
    f.cd:SetPoint("CENTER")
    f.cd:SetSize(size - 2, size - 2)
    f.cd:SetSwipeColor(0, 0, 0, 0.8)
    f.cd:SetDrawBling(false)
    if f.cd.SetCountdownFont then f.cd:SetCountdownFont(cdFont:GetName()) end

    local text = CreateFrame("Frame", nil, f)
    text:SetAllPoints()
    text:SetFrameLevel(art:GetFrameLevel() + 5)

    local fontSize = math.max(8, math.floor(size * 0.22))

    f.key = text:CreateFontString(nil, "OVERLAY")
    S.SetFont(f.key, fontSize)
    f.key:SetJustifyH("LEFT")
    f.key:SetPoint("TOPLEFT", f.iconbg, "TOPLEFT", 2, -2)
    local muted = T().text.muted
    f.key:SetTextColor(muted.r, muted.g, muted.b, 1)

    f.count = text:CreateFontString(nil, "OVERLAY")
    S.SetFont(f.count, 14)
    f.count:SetJustifyH("RIGHT")
    f.count:SetPoint("BOTTOMRIGHT", f.iconbg, "BOTTOMRIGHT", -2, 2)

    f.label = text:CreateFontString(nil, "OVERLAY")
    S.SetFont(f.label, fontSize)
    f.label:SetJustifyH("CENTER")
    f.label:SetMaxLines(1)
    f.label:SetPoint("BOTTOM", f.iconbg, "BOTTOM", 0, 4)
    f.label:SetPoint("LEFT", f.iconbg, "LEFT", 2, 0)
    f.label:SetPoint("RIGHT", f.count, "LEFT", -2, 0)

    UpdateEdge(f)
    return f
end

local registered = false
local function Skin()
    local opie = _G["OPie"]
    if registered or not (opie and opie.UI) then return end
    registered = true

    cdFont:SetFont(T().font.path, T().font.size.large, "OUTLINE")

    opie.UI:RegisterIndicatorConstructor("swirlui", {
        name = "swirlui",
        apiLevel = 4,
        CreateIndicator = CreateIndicator,
        supportsCooldownNumbers = false,
        supportsShortLabels = true,
    })
end

S:Register("OPie", "opie", Skin)
