---@class SUI : SF
local SUI = select(2, ...)

SUI.Utils = {}

function SUI.Utils:Print(message)
    if SwirlUIDB and SwirlUIDB.uiSettings and SwirlUIDB.uiSettings.silence then
        return
    end
    print(string.format("%s %s", SUI.Header, message))
end
