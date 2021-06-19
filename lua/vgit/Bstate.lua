local State = require('vgit.State')

local Bstate = {}
Bstate.__index = Bstate

local function new()
    return setmetatable({ buf_states = {} }, Bstate)
end

local function translate_buf(buf)
    assert(type(buf) == 'number', 'Invalid buffer provided')
    return tostring(buf)
end

function Bstate:contains(buf)
    return self.buf_states[translate_buf(buf)] ~= nil
end

function Bstate:add(buf)
    self.buf_states[translate_buf(buf)] = State.new({
        filename = '',
        filetype = '',
        project_relative_filename = '',
        logs = {},
        hunks = {},
        blames = {},
        disabled = false,
        last_lnum_blamed = 1,
    })
end

function Bstate:remove(buf)
    local buf_state = self.buf_states[translate_buf(buf)]
    assert(buf_state ~= nil, 'Buffer is not tracked by VGit')
    self.buf_states[translate_buf(buf)] = nil
end

function Bstate:get(buf, key)
    local buf_state = self.buf_states[translate_buf(buf)]
    assert(buf_state ~= nil, 'Buffer is not tracked by VGit')
    return buf_state:get(key)
end

function Bstate:set(buf, key, value)
    local buf_state = self.buf_states[translate_buf(buf)]
    assert(buf_state ~= nil, 'Buffer is not tracked by VGit')
    buf_state:set(key, value)
end

function Bstate:for_each(fn)
    assert(type(fn) == 'function', 'Invalid function type provided')
    for key, value in pairs(self.buf_states) do
        fn(tonumber(key), value)
    end
end

function Bstate:get_buf_states()
    return self.buf_states
end

return {
    new = new,
    __object = Bstate,
}
