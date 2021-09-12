local Interface = require('vgit.Interface')

local M = {}

M.state = Interface:new({
    config = {},
    disabled = false,
    hunks_enabled = true,
    blames_enabled = true,
    diff_strategy = 'index',
    diff_preference = 'vertical',
    predict_hunk_signs = true,
    action_delay_ms = 300,
    predict_hunk_throttle_ms = 300,
    predict_hunk_max_lines = 50000,
    blame_line_throttle_ms = 150,
    show_untracked_file_signs = true,
})

M.setup = function(config)
    config = config or {}
    M.state:assign(config.controller)
end

M.get = function(key)
    return M.state:get(key)
end

M.set = function(key, value)
    return M.state:set(key, value)
end

return M
