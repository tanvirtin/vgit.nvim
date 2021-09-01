local Object = require('plenary.class')
local assert = require('vgit.assertion').assert
local Interface = require('vgit.Interface')

local BufferState = Object:extend()

function BufferState:new()
    return setmetatable({ data = {} }, BufferState)
end

function BufferState:contains(buf)
    assert(type(buf) == 'number', 'type error :: expected number')
    return self.data[buf] ~= nil
end

function BufferState:add(buf)
    assert(type(buf) == 'number', 'type error :: expected number')
    self.data[buf] = Interface:new({
        filename = '',
        filetype = '',
        tracked_filename = '',
        tracked_remote_filename = '',
        logs = {},
        hunks = {},
        blames = {},
        disabled = false,
        last_lnum_blamed = 1,
        temp_lines = {},
        untracked = false,
    })
end

function BufferState:remove(buf)
    assert(type(buf) == 'number', 'type error :: expected number')
    local bstate = self.data[buf]
    assert(bstate ~= nil, 'untracked buffer')
    self.data[buf] = nil
end

function BufferState:get(buf, key)
    assert(type(buf) == 'number', 'type error :: expected number')
    assert(type(key) == 'string', 'type error :: expected string')
    local bstate = self.data[buf]
    assert(bstate ~= nil, 'untracked buffer')
    return bstate:get(key)
end

function BufferState:set(buf, key, value)
    assert(type(buf) == 'number', 'type error :: expected number')
    assert(type(key) == 'string', 'type error :: expected string')
    local bstate = self.data[buf]
    assert(bstate ~= nil, 'untracked buffer')
    bstate:set(key, value)
end

function BufferState:for_each(fn)
    assert(type(fn) == 'function', 'type error :: expected function')
    for key, value in pairs(self.data) do
        fn(key, value)
    end
end

function BufferState:get_data()
    return self.data
end

function BufferState:size()
    return #self.data
end

return BufferState
