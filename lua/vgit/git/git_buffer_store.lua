local lazy = require('vgit.core.lazy')

local event = lazy('vgit.core.event')
local utils = lazy('vgit.core.utils')
local Buffer = lazy('vgit.core.Buffer')
local buffers_module = lazy('vgit.core.buffers')
local console = lazy('vgit.core.console')
local git_repo = lazy('vgit.git.git_repo')
local GitBuffer = lazy('vgit.git.GitBuffer')
local assertion = lazy('vgit.core.assertion')
local repository = lazy('vgit.git.repository')
local statusline = lazy('vgit.core.statusline_state')

local buffers = {}
local events = {
  sync = {},
  attach = {},
  change = {},
  reload = {},
  detach = {},
}
local is_registered = false

local git_buffer_store = {}

git_buffer_store.register_events = event.async(function()
  if is_registered then return end
  is_registered = true

  event.on({ 'BufRead', 'BufNew' }, function()
    git_buffer_store.collect()
  end)

  event.custom_on('VGitChange', function()
    git_repo.clear_cache()
    git_buffer_store.for_each(function(buffer)
      if buffer.git_file then buffer.git_file:clear_blob_cache() end
      git_buffer_store.dispatch(buffer, 'sync')
    end)

    local repo = repository.get_cached()
    if repo then
      local refs = repo:refs()
      if refs then
        local branch = refs:current_branch()
        if branch then statusline.set_branch(branch) end
      end
    end
  end)

  event.custom_on('VGitDirChanged', function()
    repository.invalidate()
    statusline.reset()
    git_buffer_store.clear_buffers()
    for _, buffer in ipairs(buffers_module.list()) do
      if buffer:is_valid() then git_buffer_store.collect(buffer.bufnr) end
    end
  end)
end)

git_buffer_store.for_each = function(callback)
  for _, git_buffer in pairs(buffers) do
    callback(git_buffer)
  end
end

git_buffer_store.on = function(event_types, handler)
  if type(event_types) == 'string' then event_types = { event_types } end

  for i = 1, #event_types do
    local event_type = event_types[i]
    local handlers = events[event_type]
    assertion.assert(handlers, 'invalid event')

    handlers[#handlers + 1] = handler
  end

  return git_buffer_store
end

git_buffer_store.add = function(buffer)
  local bufnr = tostring(buffer.bufnr)
  buffers[bufnr] = buffer
  return git_buffer_store
end

git_buffer_store.contains = function(buffer)
  local bufnr = tostring(buffer.bufnr)
  return buffers[bufnr] ~= nil
end

git_buffer_store.remove = function(buffer)
  if not buffer then return nil end

  local bufnr = tostring(buffer.bufnr)
  buffer = buffers[bufnr]
  if not buffer then return end

  buffers[bufnr] = nil

  return buffer
end

git_buffer_store.get = function(buffer)
  local bufnr = tostring(buffer.bufnr)
  return buffers[bufnr]
end

function git_buffer_store.current(bufnr)
  if not bufnr then bufnr = vim.api.nvim_get_current_buf() end
  bufnr = tostring(bufnr)
  return buffers[bufnr]
end

git_buffer_store.size = function()
  return utils.object.size(buffers)
end

git_buffer_store.is_empty = function()
  return git_buffer_store.size() == 0
end

git_buffer_store.dispatch = function(git_buffer, event_type, ...)
  local handlers = events[event_type]
  assertion.assert(handlers, 'invalid event')

  for _, handler in pairs(handlers) do
    handler(git_buffer, event_type, ...)
  end
end

git_buffer_store.clear_buffers = function()
  buffers = {}
end

git_buffer_store.reset = function()
  buffers = {}
  events = {
    sync = {},
    attach = {},
    change = {},
    reload = {},
    detach = {},
  }
  is_registered = false
end

git_buffer_store.create_and_validate_buffer = function(bufnr)
  local git_buffer = GitBuffer(bufnr or 0)
  git_buffer:sync()

  local ok, result = pcall(git_buffer.exists, git_buffer)
  if not ok then
    git_buffer_store.remove(git_buffer)
    console.debug.error(result)
    return nil
  end
  if ok and not result then
    git_buffer_store.remove(git_buffer)
    return nil
  end

  return git_buffer
end

git_buffer_store.register_buffer = function(git_buffer)
  if git_buffer_store.contains(git_buffer) then
    local existing_git_buffer = git_buffer_store.get(git_buffer)
    return git_buffer_store.dispatch(existing_git_buffer, 'reload')
  end

  git_buffer_store.add(git_buffer)

  git_buffer
    :attach_to_changes({
      on_lines = event.async(function(_, _, _, _, p_lnum, n_lnum, byte_count)
        if p_lnum == n_lnum and byte_count == 0 then return end
        git_buffer_store.dispatch(git_buffer, 'change')
      end),

      on_reload = event.async(function()
        git_buffer_store.dispatch(git_buffer, 'reload')
      end),

      on_detach = event.async(function()
        git_buffer_store.dispatch(git_buffer, 'detach')
        git_buffer_store.remove(git_buffer)
        git_buffer:detach_from_renderer()
      end),
    })
    :attach_to_renderer()

  git_buffer_store.dispatch(git_buffer, 'attach')
end

git_buffer_store.collect = function(bufnr)
  local git_buffer = git_buffer_store.create_and_validate_buffer(bufnr)
  if not git_buffer then return end
  git_buffer_store.register_buffer(git_buffer)
end

return git_buffer_store
