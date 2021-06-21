local State = require('vgit.State')

local vim = vim

local M = {}

M.state = State.new({
    debug = false,
    debug_logs = {},
})

M.setup = function(config)
    M.state:assign(config)
end

M.error = function(msg)
    vim.api.nvim_command('echohl ErrorMsg')
    vim.api.nvim_command(string.format('echom "VGit[%s]: %s"', os.date('%H:%M:%S'), vim.fn.escape(msg, '"')))
    vim.api.nvim_command('echohl NONE')
end

M.debug = function(msg, fn)
   fn = fn or 'unknown'
   if M.state:get('debug') then
      local new_msg = ''
      if vim.tbl_islist(msg) then
         for i, m in ipairs(msg) do
            if i == 1 then
               new_msg = new_msg .. m
            else
               new_msg = new_msg .. ', ' .. m
            end
         end
      else
         new_msg = msg
      end
      table.insert(M.state:get('debug_logs'), string.format('VGit[%s][%s]: %s', os.date('%H:%M:%S'), fn, new_msg))
   end
end

return M
