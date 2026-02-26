local lazy = require('vgit.core.lazy')

local async = lazy('vgit.core.async')
local git_repo = lazy('vgit.libgit2.git_repo')
local utils_math = lazy('vgit.core.utils.math')

local _is_registered = false
local _augroup_created = false
local _dir_watcher_registered = false
local _handle = nil

local function ensure_augroup()
  if _augroup_created then return end
  _augroup_created = true
  vim.api.nvim_create_augroup('VGitGroup', { clear = false })
end

local function safe_async_void(func)
  local call_site_trace = debug.traceback('async function defined at:', 2)

  return function(...)
    local args = { ... }
    local argc = select('#', ...)

    local function error_handler(err)
      local error_trace = debug.traceback('', 2)
      local msg = string.format(
        '[VGit] Async Error: %s\n\n--- Error Location ---\n%s\n--- Call Site ---\n%s',
        tostring(err),
        error_trace,
        call_site_trace
      )
      vim.schedule(function()
        vim.api.nvim_err_writeln(msg)
      end)
      return err
    end

    local function protected_func()
      xpcall(function()
        func(unpack(args, 1, argc))
      end, error_handler)
    end

    async.void(protected_func)()
  end
end

local event = {
  group = 'VGitGroup',
  async = safe_async_void,
  promisify = async.wrap,
  await = async.wrap(vim.schedule, 1),
}

function event.all(funcs, opts)
  opts = opts or {}
  if not opts.max_concurrent then opts.max_concurrent = 20 end
  return async.all(funcs, opts)
end

function event.on(event_names, callback)
  ensure_augroup()
  vim.api.nvim_create_autocmd(event_names, {
    group = event.group,
    callback = event.async(callback),
  })

  return event
end

function event.buffer_on(buffer, event_name, callback)
  ensure_augroup()
  local group = event_name
  if type(event_name) == 'table' then group = '::' .. table.concat(event_name, '::') end
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
  local uuid = utils_math.uuid()
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
  local timer = nil

  local function close_timer()
    if timer and not timer:is_closing() then timer:close() end
    timer = nil
  end

  local debounced = function(...)
    args = { ... }
    argc = select('#', ...)

    if not cooldown then
      cooldown = true
      fn(...)
      close_timer()
      timer = vim.loop.new_timer()
      timer:start(ms, 0, function()
        close_timer()
        cooldown = false
      end)
      return
    end

    close_timer()
    timer = vim.loop.new_timer()
    timer:start(ms, 0, function()
      close_timer()
      cooldown = false
      vim.schedule(function()
        fn(unpack(args, 1, argc))
      end)
    end)
  end

  local cleanup = function()
    close_timer()
    cooldown = false
  end

  return debounced, cleanup
end

function event.debounce_async(fn, ms)
  return event.debounce(event.async(fn), ms)
end

local function _start_watcher()
  if _handle then
    pcall(function()
      _handle:stop()
    end)
    pcall(function()
      _handle:close()
    end)
    _handle = nil
  end

  if not git_repo.exists() then return end

  local git_dirname = git_repo.discover(nil, { git_dirname = true })
  if not git_dirname then return end

  local handle = vim.loop.new_fs_event()
  if not handle then return end

  local ok = handle:start(git_dirname, {}, function(err, filename, ev_name)
    if err then return end
    if not filename then return end
    if filename:match('index%.lock$') then return end

    vim.schedule(function()
      event.emit('VGitChange', {
        git_dir = git_dirname,
        filename = filename,
        event_name = ev_name,
      })
    end)
  end)

  if not ok then
    handle:close()
    return
  end

  _handle = handle
end

function event.register_module()
  if _is_registered then return end
  _is_registered = true

  _start_watcher()

  event.on({ 'VimLeavePre' }, function()
    if _handle then
      pcall(function()
        _handle:stop()
      end)
      pcall(function()
        _handle:close()
      end)
      _handle = nil
    end
  end)

  if not _dir_watcher_registered then
    _dir_watcher_registered = true
    event.on({ 'DirChanged' }, function(args)
      if args.match ~= 'global' then return end
      git_repo.clear_cache()
      _start_watcher()
      event.emit('VGitDirChanged', {})
    end)
  end
end

function event.reset()
  if _handle then
    pcall(function()
      _handle:stop()
    end)
    pcall(function()
      _handle:close()
    end)
    _handle = nil
  end
  _is_registered = false
  _augroup_created = false
  _dir_watcher_registered = false
end

return event
