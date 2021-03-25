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
            pcall(vim.schedule_wrap(fn), select(1, ...))
        end
    end
    return wrapped_fn, timer
end

return M
