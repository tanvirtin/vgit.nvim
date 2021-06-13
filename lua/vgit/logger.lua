local State = require('vgit.State')

local vim = vim

local M = {}

M.state = State.new({
    debug = false,
    logs = {},
})

M.setup = function(config)
    M.state:assign(config)
end

M.error = function(msg)
    vim.cmd('echohl ErrorMsg')
    vim.cmd(string.format('echom "VGit[%s]: %s"', os.date('%H:%M:%S'), vim.fn.escape(msg, '"')))
    vim.cmd('echohl NONE')
end

M.debug = function(msg, fn)
   fn = fn or 'unknown'
   if M.state:get('debug') then
      local new_msg = ''
      if vim.tbl_islist(msg) then
         for _, m in ipairs(msg) do
            new_msg = new_msg .. m
         end
      else
         new_msg = msg
      end
      table.insert(M.state:get('logs'), string.format('VGit[%s][%s]: %s', os.date('%H:%M:%S'), fn, new_msg))
   end
end

return M
