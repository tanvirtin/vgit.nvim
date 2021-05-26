local State = require('vgit.State')

local Bstate = {}
Bstate.__index = Bstate

local function new()
    return setmetatable({
        bufs = {},
    }, Bstate)
end

local function translate_buf(buf)
    if type(buf) == 'number' then
        return tostring(buf)
    else
        error(debug.traceback('Invalid buffer provided'))
    end
end

function Bstate:contains(buf)
    return self.bufs[translate_buf(buf)] ~= nil
end

function Bstate:add(buf)
    self.bufs[translate_buf(buf)] = State.new({
        logs = {},
        hunks = {},
        blames = {},
        last_lnum = 1,
        disabled = false,
        blame_is_shown = false,
    })
end

function Bstate:remove(buf)
    local buf_state = self.bufs[translate_buf(buf)]
    if buf_state ~= nil then
        self.bufs[translate_buf(buf)] = nil
    else
        error(debug.traceback('Buffer is not tracked by VGit'))
    end
end

function Bstate:get(buf, key)
    local buf_state = self.bufs[translate_buf(buf)]
    if buf_state ~= nil then
        return buf_state:get(key)
    else
        error(debug.traceback('Buffer is not tracked by VGit'))
    end
end

function Bstate:set(buf, key, value)
    local buf_state = self.bufs[translate_buf(buf)]
    if buf_state ~= nil then
        buf_state:set(key, value)
    else
        error(debug.traceback('Buffer is not tracked by VGit'))
    end
end

function Bstate:for_each_buf(fn)
    if type(fn) == 'function' then
        for key, value in pairs(self.bufs) do
            fn(tonumber(key), value)
        end
    else
        error(debug.traceback('Invalid function type provided'))
    end
end

function Bstate:clear()
    self.bufs = {}
end

return {
    new = new,
    __object = Bstate,
}
