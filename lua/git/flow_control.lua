local flow_control = {}

flow_control.async = function(func)
    return function(...)
        local params = { ... }
        return function(callback)
            local thread = coroutine.create(func)
            local function step(...)
                local stat, ret = coroutine.resume(thread, ...)
                assert(stat, ret)
                if coroutine.status(thread) == "dead" then
                    if callback then
                        callback(ret)
                    end
                else
                    (ret)(step)
                end
            end
            step(unpack(params))
        end
    end
end

flow_control.throttle = function(ms, fn)
    local timer = vim.loop.new_timer()
    local running = false
    return function(...)
        if not running then
            timer:start(ms, 0, function()
                running = false
                timer:stop()
            end)
            running = true
            fn(...)
        end
    end
end

return flow_control
