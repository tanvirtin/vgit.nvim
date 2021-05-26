local State = {}
State.__index = State

local function new(state)
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
    if self.current[key] ~= nil then
        return self.current[key]
    else
        error(debug.traceback('Key does not exist'))
    end
end

function State:set(key, value)
    if self.current[key] ~= nil then
        if type(self.current[key]) == type(value) then
            self.current[key] = value
        else
            error(debug.traceback('Invalid data type'))
        end
    else
        error(debug.traceback('Key does not exist'))
    end
end

function State:assign(config)
    if not config then
        return
    end
    local function assign(state_segment, config_segment)
        local state_segment_type = type(state_segment)
        local config_segment_type = type(config_segment)
        assert(state_segment_type == config_segment_type, 'invalid config')
        if config_segment_type == 'table' then
            for key, state_value in pairs(state_segment) do
                local config_value = config_segment[key]
                if config_value ~= nil then
                    local state_value_type = type(state_value)
                    local config_value_type = type(config_value)
                    if config_value_type == 'table' then
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
