local PopupState = {}
PopupState.__index = PopupState

local function new()
    return setmetatable({ current = {} }, PopupState)
end

function PopupState:get()
    return self.current
end

function PopupState:set(popup)
    assert(type(popup) == 'table', 'type error :: expected table')
    self.current = popup
    return self
end

function PopupState:exists()
    return not vim.tbl_isempty(self:get())
end

function PopupState:clear()
    if self:exists() then
        self:get():unmount()
        self.current = {}
    end
    return self
end

return { new = new }
