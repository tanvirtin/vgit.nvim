local loop = require('vgit.core.loop')
local event = require('vgit.core.event')
local utils = require('vgit.core.utils')
local console = require('vgit.core.console')
local GitBuffer = require('vgit.git.GitBuffer')
local assertion = require('vgit.core.assertion')
local git_repo = require('vgit.libgit2.git_repo')

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

git_buffer_store.register_events = loop.coroutine(function()
  if is_registered then return end
  is_registered = true

  event.on({ 'BufRead', 'BufNew' }, function()
    git_buffer_store.collect()
  end)

  loop.free_textlock()
  if not git_repo.exists() then return end
  local git_dirname = git_repo.discover(nil, { git_dirname = true })
  if not git_dirname then return end

  local handle = vim.loop.new_fs_event()
  if not handle then return end

  loop.free_textlock()
  local ok = handle:start(
    git_dirname,
    {},
    loop.debounce_coroutine(function(err, filename, event_name)
      if err then return end
      if filename and not filename:match('index%.lock$') then
        loop.free_textlock()
        event.emit('VGitSync', {
          git_dir = git_dirname,
          filename = filename,
          event_name = event_name,
        })
        event.custom_on('VGitSync', function()
          git_buffer_store.for_each(function(buffer)
            git_buffer_store.dispatch(buffer, 'sync')
          end)
        end)
      end
    end, 200)
  )

  if not ok then return handle:close() end
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
    assertion.assert(handlers, 'invalid event -- ' .. '"' .. event_type .. '"')

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

function git_buffer_store.current()
  local bufnr = vim.api.nvim_get_current_buf()
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
  assertion.assert(handlers, 'invalid event -- ' .. '"' .. event_type .. '"')

  for _, handler in pairs(handlers) do
    handler(git_buffer, event_type, ...)
  end
end

git_buffer_store.collect = function()
  local git_buffer = GitBuffer(0)
  git_buffer:sync()

  local ok, result = pcall(git_buffer.exists, git_buffer)
  if not ok then
    git_buffer_store.remove(git_buffer)
    console.debug.error(result)
    return
  end
  if ok and not result then return git_buffer_store.remove(git_buffer) end

  if git_buffer_store.contains(git_buffer) then
    local existing_git_buffer = git_buffer_store.get(git_buffer)
    return git_buffer_store.dispatch(existing_git_buffer, 'reload')
  else
    git_buffer_store.add(git_buffer)
  end

  loop.free_textlock()
  git_buffer
      :attach_to_changes({
        on_lines = loop.coroutine(function(_, _, _, _, p_lnum, n_lnum, byte_count)
          if p_lnum == n_lnum and byte_count == 0 then return end
          git_buffer_store.dispatch(git_buffer, 'change')
        end),

        on_reload = loop.coroutine(function()
          git_buffer_store.dispatch(git_buffer, 'reload')
        end),

        on_detach = loop.coroutine(function()
          git_buffer_store.dispatch(git_buffer, 'detach')
          git_buffer_store.remove(git_buffer)
          git_buffer:detach_from_renderer()
        end),
      })
      :attach_to_renderer()

  git_buffer_store.dispatch(git_buffer, 'attach')
end

return git_buffer_store
