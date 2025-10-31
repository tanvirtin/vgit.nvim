local utils = require('vgit.core.utils')
local async = require('plenary.async.async')

vim.api.nvim_create_augroup('VGitGroup', { clear = false })

local _is_registered = false

local event = {
  group = 'VGitGroup',
  async = async.void,
  promisify = async.wrap,
  await = async.wrap(vim.schedule, 1),
}

function event.on(event_names, callback)
  vim.api.nvim_create_autocmd(event_names, { callback = event.async(callback) })

  return event
end

function event.buffer_on(buffer, event_name, callback)
  local group = event_name
  if type(event_name) == 'table' then
    group = utils.list.reduce(event_name, '', function(acc, e)
      acc = acc .. '::' .. e
      return acc
    end)
  end
  group = event.group .. '::' .. group .. '::' .. buffer.bufnr
  vim.api.nvim_create_augroup(group, { clear = true })
  vim.api.nvim_create_autocmd(event_name, {
    group = group,
    buffer = buffer.bufnr,
    callback = event.async(callback),
  })

  return event
end

function event.custom_on(event_name, callback)
  local uuid = require('vgit.core.utils.math').uuid()
  local group_name = event.group .. '::custom::' .. event_name .. '::' .. uuid

  vim.api.nvim_create_augroup(group_name, { clear = true })
  vim.api.nvim_create_autocmd('User', {
    group = group_name,
    pattern = event_name,
    callback = event.async(callback),
  })

  local cleaned_up = false
  return function()
    if cleaned_up then return end
    cleaned_up = true
    vim.api.nvim_del_augroup_by_name(group_name)
  end
end

function event.emit(event_name, data)
  vim.api.nvim_exec_autocmds({ 'User' }, {
    pattern = event_name,
    data = data,
  })
end

function event.debounce(fn, ms)
  local args, argc
  local cooldown = false
  local timer = vim.loop.new_timer()

  local debounced = function(...)
    args = { ... }
    argc = select('#', ...)

    if not cooldown then
      cooldown = true
      fn(...)
      timer:stop()
      timer:start(ms, 0, function()
        cooldown = false
      end)
      return
    end

    timer:stop()
    timer:start(ms, 0, function()
      cooldown = false
      vim.schedule(function()
        fn(unpack(args, 1, argc))
      end)
    end)
  end

  local cleanup = function()
    if timer and not timer:is_closing() then
      timer:stop()
      timer:close()
    end
  end

  return debounced, cleanup
end

function event.debounce_async(fn, ms)
  return event.debounce(event.async(fn), ms)
end

function event.register_module()
  if _is_registered then return end

  local git_repo = require('vgit.libgit2.git_repo')
  if not git_repo.exists() then return end

  local git_dirname = git_repo.discover(nil, { git_dirname = true })
  if not git_dirname then return end

  local handle = vim.loop.new_fs_event()
  if not handle then return end

  local ok = handle:start(
    git_dirname,
    {},
    event.async(function(err, filename, event_name)
      if err then return end
      if not filename then return end
      if filename:match('index%.lock$') then return end

      event.await()
      event.emit('VGitChange', {
        git_dir = git_dirname,
        filename = filename,
        event_name = event_name,
      })
    end)
  )
  if not ok then return handle:close() end

  _is_registered = true

  event.on({ 'VimLeavePre' }, function ()
    handle:stop()
    handle:close()
  end)
end

return event
