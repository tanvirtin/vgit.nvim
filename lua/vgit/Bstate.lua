local assert = require('vgit.assertion').assert
local Interface = require('vgit.Interface')

local Bstate = {}
Bstate.__index = Bstate

local function new()
    return setmetatable({ buf_states = {} }, Bstate)
end

function Bstate:contains(buf)
    assert(type(buf) == 'number', 'type error :: expected number')
    return self.buf_states[buf] ~= nil
end

function Bstate:add(buf)
    assert(type(buf) == 'number', 'type error :: expected number')
    self.buf_states[buf] = Interface.new({
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

function Bstate:remove(buf)
    assert(type(buf) == 'number', 'type error :: expected number')
    local buf_state = self.buf_states[buf]
    assert(buf_state ~= nil, 'untracked buffer')
    self.buf_states[buf] = nil
end

function Bstate:get(buf, key)
    assert(type(buf) == 'number', 'type error :: expected number')
    assert(type(key) == 'string', 'type error :: expected string')
    local buf_state = self.buf_states[buf]
    assert(buf_state ~= nil, 'untracked buffer')
    return buf_state:get(key)
end

function Bstate:set(buf, key, value)
    assert(type(buf) == 'number', 'type error :: expected number')
    assert(type(key) == 'string', 'type error :: expected string')
    local buf_state = self.buf_states[buf]
    if buf_state then
        buf_state:set(key, value)
    end
end

function Bstate:for_each(fn)
    assert(type(fn) == 'function', 'type error :: expected function')
    for key, value in pairs(self.buf_states) do
        fn(key, value)
    end
end

function Bstate:get_buf_states()
    return self.buf_states
end

function Bstate:size()
    return #self.buf_states
end

return { new = new }
