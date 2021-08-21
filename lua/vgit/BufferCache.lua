local Object = require('plenary.class')
local assert = require('vgit.assertion').assert
local Interface = require('vgit.Interface')

local BufferCache = Object:extend()

function BufferCache:new()
    return setmetatable({ buf_states = {} }, BufferCache)
end

function BufferCache:contains(buf)
    assert(type(buf) == 'number', 'type error :: expected number')
    return self.buf_states[buf] ~= nil
end

function BufferCache:add(buf)
    assert(type(buf) == 'number', 'type error :: expected number')
    self.buf_states[buf] = Interface:new({
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

function BufferCache:remove(buf)
    assert(type(buf) == 'number', 'type error :: expected number')
    local buf_state = self.buf_states[buf]
    assert(buf_state ~= nil, 'untracked buffer')
    self.buf_states[buf] = nil
end

function BufferCache:get(buf, key)
    assert(type(buf) == 'number', 'type error :: expected number')
    assert(type(key) == 'string', 'type error :: expected string')
    local buf_state = self.buf_states[buf]
    assert(buf_state ~= nil, 'untracked buffer')
    return buf_state:get(key)
end

function BufferCache:set(buf, key, value)
    assert(type(buf) == 'number', 'type error :: expected number')
    assert(type(key) == 'string', 'type error :: expected string')
    local buf_state = self.buf_states[buf]
    assert(buf_state ~= nil, 'untracked buffer')
    buf_state:set(key, value)
end

function BufferCache:for_each(fn)
    assert(type(fn) == 'function', 'type error :: expected function')
    for key, value in pairs(self.buf_states) do
        fn(key, value)
    end
end

function BufferCache:get_buf_states()
    return self.buf_states
end

function BufferCache:size()
    return #self.buf_states
end

return BufferCache
