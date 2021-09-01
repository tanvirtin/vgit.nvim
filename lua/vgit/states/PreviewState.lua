local Object = require('plenary.class')

local PreviewState = Object:extend()

function PreviewState:new()
    return setmetatable({ current = {} }, PreviewState)
end

function PreviewState:get()
    return self.current
end

function PreviewState:set(popup)
    assert(type(popup) == 'table', 'type error :: expected table')
    self.current = popup
    return self
end

function PreviewState:exists()
    return not vim.tbl_isempty(self:get())
end

function PreviewState:clear()
    if self:exists() then
        self:get():unmount()
        self.current = {}
    end
    return self
end

return PreviewState
