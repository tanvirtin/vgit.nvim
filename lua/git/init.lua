local git = require('git.git')
local console = require('git.console')
local sign = require('git.sign')
local flow_control = require('git.flow_control')

return {
    attach = flow_control.throttle(100, flow_control.async(function()
        sign.initialize()
        git.diff(vim.api.nvim_get_current_buf(), function(err, hunks)
            if not err then
                sign.clear_all()
                for _, hunk in ipairs(hunks) do
                    sign.place(hunk)
                end
            end
        end)
    end)()),

    setup = function()
       vim.cmd('autocmd BufRead,BufNewFile,BufWritePost * lua vim.schedule(require("git").attach)')
    end
}
