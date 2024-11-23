local loop = require('vgit.core.loop')

local event = {
  type = {
    BufRead = 'BufRead',
    BufEnter = 'BufEnter',
    BufDelete = 'BufDelete',
    WinEnter = 'WinEnter',
    BufWinEnter = 'BufWinEnter',
    BufWinLeave = 'BufWinLeave',
    ColorScheme = 'ColorScheme',
    CursorHold = 'CursorHold',
    CursorMoved = 'CursorMoved',
    InsertEnter = 'InsertEnter',
    QuitPre = 'QuitPre',
  },
  group = vim.api.nvim_create_augroup('VGitGroup', { clear = true }),
}

function event.on(event_names, callback)
  vim.api.nvim_create_autocmd(event_names, { callback = loop.coroutine(callback) })

  return event
end

function event.buffer_on(buffer, event_name, callback)
  vim.api.nvim_create_autocmd(event_name, {
    buffer = buffer.bufnr,
    callback = loop.coroutine(callback),
  })

  return event
end

function event.custom_on(event_name, callback)
  vim.api.nvim_create_autocmd('User', {
    group = event.group,
    pattern = event_name,
    callback = loop.coroutine(callback),
  })

  return event
end

function event.emit(event_name, data)
  vim.api.nvim_exec_autocmds({ 'User' }, {
    group = event.group,
    pattern = event_name,
    data = data,
  })
end

return event
