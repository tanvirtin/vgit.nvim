local Object = require('plenary.class')

local PreviewCache = Object:extend()

function PreviewCache:new()
    return setmetatable({ current = {} }, PreviewCache)
end

function PreviewCache:get()
    return self.current
end

function PreviewCache:set(popup)
    assert(type(popup) == 'table', 'type error :: expected table')
    self.current = popup
    return self
end

function PreviewCache:exists()
    return not vim.tbl_isempty(self:get())
end

function PreviewCache:clear()
    if self:exists() then
        self:get():unmount()
        self.current = {}
    end
    return self
end

return PreviewCache
