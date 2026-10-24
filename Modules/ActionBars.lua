---@class SUI : SF
local SUI = select(2, ...)

local forceShow = false
local hooked = false

-- dev toggle, session only: keeps mouseover action bars shown without touching saved settings
function SUI.ToggleMouseoverBars()
    local ns = EllesmereUI and EllesmereUI._ModuleNS and EllesmereUI._ModuleNS.EllesmereUIActionBars
    local hover = ns and ns.EAB_VTABLE and ns.EAB_VTABLE.Hover
    if not (hover and hover.RestingAlpha and ns.EAB) then return forceShow end

    if not hooked then
        hooked = true
        local RestingAlpha = hover.RestingAlpha
        -- every eui alpha writer asks this where a bar rests when not hovered
        hover.RestingAlpha = function(barKey, s)
            if forceShow then
                s = s or hover.GetSettings(barKey)
                return s and s._savedBarAlpha or 1, false
            end
            return RestingAlpha(barKey, s)
        end
    end

    forceShow = not forceShow
    ns.EAB:RefreshMouseover()
    return forceShow
end
