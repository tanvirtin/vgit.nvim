local PopupManager = {}
PopupManager.__index = PopupManager

local function new()
    return setmetatable({ current = {} }, PopupManager)
end

function PopupManager:get()
    return self.current
end

function PopupManager:set(popup)
    assert(type(popup) == 'table', 'type error :: expected table')
    self.current = popup
    return self
end

function PopupManager:exists()
    return not vim.tbl_isempty(self:get())
end

function PopupManager:clear()
    if self:exists() then
        self:get():unmount()
        self.current = {}
    end
    return self
end

return { new = new }
