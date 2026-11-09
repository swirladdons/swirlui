---@class SUI : SF
local SUI = select(2, ...)

---@class SUICombatText
local CT = {}
SUI.CombatText = CT

local MESSAGE_WIDTH = 200
local MAX_FADE = 0.5

CT.MESSAGES = {
    { key = "enterCombat", label = "Enter Combat", text = "+Combat", color = { 0.7686, 0.3373, 0.3294 } },
    { key = "exitCombat", label = "Exit Combat", text = "-Combat", color = { 0.6039, 0.8431, 0.9529 } },
    { key = "lowDurability", label = "Low Durability", text = "Low Durability", color = { 0.7686, 0.3373, 0.3294 }, threshold = 15 },
    { key = "noTarget", label = "No Target", text = "No Target", color = { 1, 0.3, 0.3 }, includeDead = false },
    { key = "interrupt", label = "Interrupted", text = "Interrupted", color = { 0.45, 0.85, 1 }, duration = 3, hold = MAX_FADE },
    { key = "missedKick", label = "Missed Kick", text = "Missed Kick", color = { 1, 0.3, 0.3 }, duration = 3, hold = MAX_FADE, pulse = true },
    { key = "dispel", label = "Dispelled", text = "Dispelled", color = { 1, 0.8235, 0.3137 }, duration = 3, hold = MAX_FADE },
    { key = "purge", label = "Purged", text = "Purged", color = { 0.7843, 0.549, 1 }, duration = 3, hold = MAX_FADE },
    { key = "bloodlust", label = "Lust Ready", text = "Lust Ready", color = { 1, 0.4, 0.1 }, duration = 3, hold = MAX_FADE },
    { key = "potion", label = "Potion Ready", text = "Potion Ready", color = { 0.2, 1, 0.4 }, duration = 3, hold = MAX_FADE },
}

local BY_KEY = {}
for _, def in ipairs(CT.MESSAGES) do BY_KEY[def.key] = def end
CT.BY_KEY = BY_KEY

local function BuildDefaults()
    local defaults = {
        enabled = true,
        duration = 1,
        spacing = 0,
        fontFace = "Expressway",
        fontSize = 16,
        outline = "OUTLINE",
        x = 0,
        y = 77.94,
    }
    for _, def in ipairs(CT.MESSAGES) do
        defaults[def.key] = {
            enabled = def.enabled ~= false,
            text = def.text,
            color = def.color,
            duration = def.duration,
            threshold = def.threshold,
            includeDead = def.includeDead,
            pulse = def.pulse,
        }
    end
    return defaults
end

local function Fill(target, defaults)
    for k, v in pairs(defaults) do
        if target[k] == nil then
            target[k] = type(v) == "table" and CopyTable(v) or v
        elseif type(v) == "table" and type(target[k]) == "table" then
            Fill(target[k], v)
        end
    end
end

local cfg

---@return table|nil
function CT.Cfg()
    if cfg then return cfg end
    local settings = SwirlUIDB and SwirlUIDB.uiSettings
    if not settings then return nil end
    settings.combatText = settings.combatText or {}
    Fill(settings.combatText, BuildDefaults())
    cfg = settings.combatText
    return cfg
end

---@return table|nil
function CT.Active(key)
    local c = CT.Cfg()
    local msg = c and c.enabled and c[key]
    if msg and msg.enabled and not CT.previewing then return msg end
end

local issecretvalue = issecretvalue

-- true/false, or nil when the call throws or answers with a secret
function CT.Ask(fn, ...)
    local ok, value = pcall(fn, ...)
    if not ok or issecretvalue(value) then return nil end
    return value and true or false
end

local container, noTargetFrame
local pool = {}
local sequence = 0

local function FontPath(name)
    local lsm = LibStub and LibStub("LibSharedMedia-3.0", true)
    return lsm and lsm:Fetch("font", name, true) or SUI.Theme.font.path
end

local function StyleText(fs, c)
    local flags = c.outline ~= "NONE" and c.outline or ""
    fs:SetFont(FontPath(c.fontFace), c.fontSize, flags)
end

local function Arrange()
    if not container then return end
    local c = CT.Cfg()
    local active = {}
    for _, frame in ipairs(pool) do
        if frame.active then active[#active + 1] = frame end
    end
    -- No Target is a frame of its own, but it takes the top row so nothing can overlap it
    if noTargetFrame and noTargetFrame:IsShown() then active[#active + 1] = noTargetFrame end
    table.sort(active, function(a, b) return a.sequence < b.sequence end)

    local y = 0
    for _, frame in ipairs(active) do
        frame:ClearAllPoints()
        frame:SetPoint("TOP", container, "TOP", 0, -y)
        y = y + frame:GetHeight() + c.spacing
    end
    container:SetHeight(math.max(30, y - c.spacing))
end

local PULSE_SCALE, PULSE_ALPHA, PULSE_HALF = 1.2, 0.35, 0.45

local function StopPulse(frame)
    frame.holder:SetScript("OnUpdate", nil)
    frame.holder:SetScale(1)
    frame.text:SetAlpha(1)
end

local function StartPulse(frame)
    local elapsed = 0
    frame.holder:SetScript("OnUpdate", function(holder, delta)
        elapsed = elapsed + delta
        local k = (1 - math.cos(math.pi * elapsed / PULSE_HALF)) / 2
        holder:SetScale(1 + (PULSE_SCALE - 1) * k)
        frame.text:SetAlpha(1 - (1 - PULSE_ALPHA) * k)
    end)
end

local function Release(frame)
    frame.fade:Stop()
    StopPulse(frame)
    frame.active = false
    frame.persistKey = nil
    frame:Hide()
    Arrange()
end

local function EnsureContainer()
    if container then return end
    container = CreateFrame("Frame", "SwirlUICombatText", UIParent)
    container:SetSize(MESSAGE_WIDTH, 30)
    container:SetFrameStrata("HIGH")
end

local function CreateMessage()
    local frame = CreateFrame("Frame", nil, container)
    -- a single anchor, the stack height comes from the font size and never from measuring the text,
    -- which can be a secret string
    frame:SetWidth(MESSAGE_WIDTH)
    -- the text sits in its own holder so the pulse can scale it without moving the stack
    frame.holder = CreateFrame("Frame", nil, frame)
    frame.holder:SetSize(1, 1)
    frame.holder:SetPoint("CENTER")
    frame.text = frame.holder:CreateFontString(nil, "OVERLAY")
    frame.text:SetPoint("CENTER")
    frame.text:SetJustifyH("CENTER")

    frame.fade = frame:CreateAnimationGroup()
    frame.fadeAnim = frame.fade:CreateAnimation("Alpha")
    frame.fadeAnim:SetFromAlpha(1)
    frame.fadeAnim:SetToAlpha(0)
    frame.fade:SetScript("OnFinished", function() Release(frame) end)

    frame:Hide()
    pool[#pool + 1] = frame
    return frame
end

local function Acquire()
    EnsureContainer()
    for _, frame in ipairs(pool) do
        if not frame.active then return frame end
    end
    return CreateMessage()
end

local function Paint(frame, c, msg, text, opts)
    StyleText(frame.text, c)
    frame:SetHeight(math.max(c.fontSize + 6, 14))
    frame:SetAlpha(1)
    local color = msg.color
    frame.text:SetTextColor(color[1], color[2], color[3], 1)
    -- a spell line carries a secret name, SetFormattedText accepts it where string.format would throw
    if not (opts and opts.format and pcall(frame.text.SetFormattedText, frame.text, unpack(opts.format))) then
        frame.text:SetText(text)
    end
end

local function Place(frame, key)
    if not frame.active then
        sequence = sequence + 1
        frame.sequence = sequence
        frame.active = true
    end
    frame.key = key
    frame:Show()
    Arrange()
end

---@param key string message key
---@param text string|nil replaces the configured text
---@param opts table|nil { format = { fmt, ... } paints through SetFormattedText, duration = seconds }
function CT.Show(key, text, opts)
    local msg = CT.Active(key)
    if not msg then return end
    local c = CT.Cfg()
    local def = BY_KEY[key]

    local frame = Acquire()
    frame.persistKey = nil
    Paint(frame, c, msg, text or msg.text, opts)
    frame.fade:Stop()
    StopPulse(frame)
    Place(frame, key)

    local duration = (opts and opts.duration) or msg.duration or c.duration
    local hold = def.hold and math.min(def.hold, duration) or 0
    frame.fadeAnim:SetStartDelay(duration - (hold > 0 and hold or duration))
    frame.fadeAnim:SetDuration(hold > 0 and hold or duration)
    frame.fade:Play()
    if msg.pulse then StartPulse(frame) end
end

local function SpellLineFormat(msg, name, texture)
    local size = CT.Cfg().fontSize
    local format, args = "%s", { msg.text }
    if texture ~= nil then
        format = format .. " |T%d:%d:%d:0:0:64:64:5:59:5:59|t"
        args[#args + 1] = texture
        args[#args + 1] = size
        args[#args + 1] = size
    end
    if name ~= nil then
        format = format .. " [%s]"
        args[#args + 1] = name
    end
    return { format, unpack(args) }
end

function CT.ShowSpellLine(key, name, texture)
    local msg = CT.Active(key)
    if not msg then return end
    CT.Show(key, nil, { format = SpellLineFormat(msg, name, texture) })
end

function CT.ShowPersistent(key)
    local msg = CT.Active(key)
    if not msg then return end
    local c = CT.Cfg()

    local frame
    for _, candidate in ipairs(pool) do
        if candidate.active and candidate.persistKey == key then frame = candidate break end
    end
    frame = frame or Acquire()
    frame.fade:Stop()
    frame.persistKey = key
    Paint(frame, c, msg, msg.text)
    Place(frame, key)
end

function CT.HidePersistent(key)
    for _, frame in ipairs(pool) do
        if frame.active and frame.persistKey == key then Release(frame) end
    end
end

function CT.EnsureNoTarget()
    if noTargetFrame then return noTargetFrame end
    EnsureContainer()
    noTargetFrame = CreateFrame("Frame", "SwirlUINoTarget", container)
    noTargetFrame.sequence = 0
    noTargetFrame:SetWidth(MESSAGE_WIDTH)
    noTargetFrame:SetScript("OnShow", Arrange)
    noTargetFrame:SetScript("OnHide", Arrange)
    noTargetFrame.text = noTargetFrame:CreateFontString(nil, "OVERLAY")
    noTargetFrame.text:SetPoint("CENTER")
    noTargetFrame:Hide()
    return noTargetFrame
end

function CT.StyleNoTarget()
    local c = CT.Cfg()
    if not c then return end
    local frame = CT.EnsureNoTarget()
    local msg = c.noTarget
    frame:SetHeight(math.max(c.fontSize + 6, 14))
    StyleText(frame.text, c)
    frame.text:SetText(msg.text)
    frame.text:SetTextColor(msg.color[1], msg.color[2], msg.color[3], 1)
    Arrange()
end

local applyHooks = {}

function CT.OnApply(fn)
    applyHooks[#applyHooks + 1] = fn
end

local PREVIEW_SPELLS = { interrupt = 260879, dispel = 404141, purge = 384686 }

local function ShowPreview()
    local c = CT.Cfg()
    for _, def in ipairs(CT.MESSAGES) do
        local msg = c[def.key]
        if def.key ~= "noTarget" and msg.enabled then
            local frame = Acquire()
            frame.fade:Stop()
            frame.persistKey = def.key
            local text = msg.text:gsub("%%name", UnitName("player") or "Player")
            local spellID = PREVIEW_SPELLS[def.key]
            local opts = spellID and {
                format = SpellLineFormat(msg, C_Spell.GetSpellName(spellID), C_Spell.GetSpellTexture(spellID)),
            }
            Paint(frame, c, msg, text, opts)
            Place(frame, def.key)
        end
    end
end

local function ClearMessages()
    for _, frame in ipairs(pool) do
        if frame.active then Release(frame) end
    end
end

function CT.SetPreview(on)
    CT.previewing = on and true or false
    ClearMessages()
    CT.Apply()
end

function CT.Apply()
    local c = CT.Cfg()
    if not c then return end
    EnsureContainer()
    container:ClearAllPoints()
    container:SetPoint("CENTER", UIParent, "CENTER", c.x, c.y)

    if CT.previewing then
        ClearMessages()
        ShowPreview()
    else
        for _, frame in ipairs(pool) do
            StyleText(frame.text, c)
        end
    end
    Arrange()

    CT.StyleNoTarget()
    for _, fn in ipairs(applyHooks) do fn(c) end
end

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
watcher:SetScript("OnEvent", function()
    -- fonts registered by other addons are only there after login
    C_Timer.After(0.5, CT.Apply)
end)
