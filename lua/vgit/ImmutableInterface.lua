local assert = require('vgit.assertion').assert

local ImmutableInterface = {}
ImmutableInterface.__index = ImmutableInterface

local function readonly(tbl)
    return setmetatable({}, {
        __index = function(_, k)
            return tbl[k]
        end,
        __newindex = function()
            error('Table is readonly.')
        end,
        __metatable = {},
        __len = function()
            return #tbl
        end,
        __tostring = function()
            return tostring(tbl)
        end,
        __call = function(_, ...)
            return tbl(...)
        end,
    })
end

local function new(state)
    assert(type(state) == 'table', 'type error :: expected table')
    return setmetatable({ data = readonly(state) }, ImmutableInterface)
end

function ImmutableInterface:get(key)
    assert(type(key) == 'string', 'type error :: expected string')
    assert(self.data[key] ~= nil, string.format('key "%s" does not exist', key))
    return self.data[key]
end

return { new = new }
