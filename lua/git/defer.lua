local vim = vim

local M = {}

M.throttle_leading = function(fn, ms)
    local timer = vim.loop.new_timer()
    local running = false

    local function wrapped_fn(...)
        if not running then
            timer:start(ms, 0, function()
                running = false
            end)
            running = true
            pcall(fn, select(1, ...))
        end
    end

    return wrapped_fn
end

return M
