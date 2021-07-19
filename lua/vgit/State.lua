local assert = require('vgit.assertion').assert
local State = {}
State.__index = State

local vim = vim

local function new(state)
    assert(type(state) == 'nil' or type(state) == 'table', 'type error :: expected table or nil')
    if type(state) ~= 'table' then
        return setmetatable({
            initial = {},
            current = {},
        }, State)
    end
    return setmetatable({
        initial = state,
        current = state,
    }, State)
end

function State:get(key)
    assert(type(key) == 'string', 'type error :: expected string')
    assert(self.current[key] ~= nil, string.format('key "%s" does not exist', key))
    return self.current[key]
end

function State:set(key, value)
    assert(self.current[key] ~= nil, string.format('key "%s" does not exist', key))
    assert(type(self.current[key]) == type(value), string.format('type error :: expected %s', key))
    self.current[key] = value
end

function State:assign(config)
    if not config then
        return
    end
    local function assign(state_segment, config_segment)
        local state_segment_type = type(state_segment)
        local config_segment_type = type(config_segment)
        assert(state_segment_type == config_segment_type, 'invalid config')
        if config_segment_type == 'table' and not vim.tbl_islist(config_segment) then
            for key, state_value in pairs(state_segment) do
                local config_value = config_segment[key]
                if config_value ~= nil then
                    local state_value_type = type(state_value)
                    local config_value_type = type(config_value)
                    if config_value_type == 'table' and not vim.tbl_islist(config_value) then
                        assign(state_segment[key], config_segment[key])
                    else
                        assert(state_value_type == config_value_type, 'invalid config')
                        state_segment[key] = config_value
                    end
                end
            end
        end
    end
    assign(self.current, config)
    return
end

return {
    new = new,
    __object = State,
}
