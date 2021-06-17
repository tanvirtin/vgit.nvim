local vim = vim

local M = {}

M.throttle_leading = function(fn, ms)
    local timer = vim.loop.new_timer()
    local running = false
    return function (...)
        if not running then
            timer:start(ms, 0, function()
                running = false
            end)
            running = true
            fn(...)
        end
    end
end

return M
