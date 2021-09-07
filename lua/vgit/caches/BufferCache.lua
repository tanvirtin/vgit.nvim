local Object = require('plenary.class')
local assert = require('vgit.assertion').assert
local Interface = require('vgit.Interface')

local BufferCache = Object:extend()

function BufferCache:new()
    return setmetatable({ data = {} }, BufferCache)
end

function BufferCache:contains(buf)
    assert(type(buf) == 'number', 'type error :: expected number')
    return self.data[buf] ~= nil
end

function BufferCache:add(buf)
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

function BufferCache:remove(buf)
    assert(type(buf) == 'number', 'type error :: expected number')
    local bcache = self.data[buf]
    assert(bcache ~= nil, 'untracked buffer')
    self.data[buf] = nil
end

function BufferCache:get(buf, key)
    assert(type(buf) == 'number', 'type error :: expected number')
    assert(type(key) == 'string', 'type error :: expected string')
    local bcache = self.data[buf]
    assert(bcache ~= nil, 'untracked buffer')
    return bcache:get(key)
end

function BufferCache:set(buf, key, value)
    assert(type(buf) == 'number', 'type error :: expected number')
    assert(type(key) == 'string', 'type error :: expected string')
    local bcache = self.data[buf]
    assert(bcache ~= nil, 'untracked buffer')
    bcache:set(key, value)
end

function BufferCache:for_each(fn)
    assert(type(fn) == 'function', 'type error :: expected function')
    for key, value in pairs(self.data) do
        fn(key, value)
    end
end

function BufferCache:get_data()
    return self.data
end

function BufferCache:size()
    return #self.data
end

return BufferCache
