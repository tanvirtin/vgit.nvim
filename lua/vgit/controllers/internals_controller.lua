local controller_store = require('vgit.stores.controller_store')
local logger = require('vgit.logger')

local M = {}

M._run_command = function(command, ...)
    if controller_store.get('disabled') then
        return
    end
    local vgit = require('vgit')
    local starts_with = command:sub(1, 1)
    if starts_with == '_' or not vgit[command] or not type(vgit[command]) == 'function' then
        logger.error(
            string.format('Invalid command %s -- checkout the actions available to you using :VGit actions', command)
        )
        return
    end
    return vgit[command](...)
end

M._command_autocompletes = function(arglead, line)
    local vgit = require('vgit')
    local parsed_line = #vim.split(line, '%s+')
    local matches = {}
    if parsed_line == 2 then
        for func, _ in pairs(vgit) do
            if not vim.startswith(func, '_') and vim.startswith(func, arglead) then
                matches[#matches + 1] = func
            end
        end
    end
    return matches
end

M.show_debug_logs = function()
    if logger.state:get('debug') then
        local debug_logs = logger.state:get('debug_logs')
        for i = 1, #debug_logs do
            local log = debug_logs[i]
            logger.error(log)
        end
    end
end

return M
