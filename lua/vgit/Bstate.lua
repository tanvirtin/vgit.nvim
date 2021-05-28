local State = require('vgit.State')

local Bstate = {}
Bstate.__index = Bstate

local function new()
    return setmetatable({ bufs = {} }, Bstate)
end

local function translate_buf(buf)
    assert(type(buf) == 'number', 'Invalid buffer provided')
    return tostring(buf)
end

function Bstate:contains(buf)
    return self.bufs[translate_buf(buf)] ~= nil
end

function Bstate:add(buf)
    self.bufs[translate_buf(buf)] = State.new({
        filename = '',
        project_relative_filename = '',
        logs = {},
        hunks = {},
        blames = {},
        disabled = false,
        last_lnum_blamed = 1,
    })
end

function Bstate:remove(buf)
    local buf_state = self.bufs[translate_buf(buf)]
    assert(buf_state ~= nil, 'Buffer is not tracked by VGit')
    self.bufs[translate_buf(buf)] = nil
end

function Bstate:get(buf, key)
    local buf_state = self.bufs[translate_buf(buf)]
    assert(buf_state ~= nil, 'Buffer is not tracked by VGit')
    return buf_state:get(key)
end

function Bstate:set(buf, key, value)
    local buf_state = self.bufs[translate_buf(buf)]
    assert(buf_state ~= nil, 'Buffer is not tracked by VGit')
    buf_state:set(key, value)
end

function Bstate:for_each_buf(fn)
    assert(type(fn) == 'function', 'Invalid function type provided')
    for key, value in pairs(self.bufs) do
        fn(tonumber(key), value)
    end
end

return {
    new = new,
    __object = Bstate,
}
