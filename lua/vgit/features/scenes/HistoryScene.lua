local utils = require('vgit.core.utils')
local loop = require('vgit.core.loop')
local CodeComponent = require('vgit.ui.components.CodeComponent')
local TableComponent = require('vgit.ui.components.TableComponent')
local CodeDataScene = require('vgit.ui.abstract_scenes.CodeDataScene')
local Scene = require('vgit.ui.Scene')
local dimensions = require('vgit.ui.dimensions')
local console = require('vgit.core.console')

local HistoryScene = CodeDataScene:extend()

function HistoryScene:new(...)
  return setmetatable(CodeDataScene:new(...), HistoryScene)
end

function HistoryScene:fetch(selected)
  selected = selected or 1
  local runtime_cache = self.runtime_cache
  local data = runtime_cache.data
  local buffer = runtime_cache.buffer
  local git_object = buffer.git_object
  local lines, hunks
  local err, logs
  if data then
    logs = data.logs
  else
    err, logs = git_object:logs()
  end
  if err then
    console.debug(err, debug.traceback())
    runtime_cache.err = err
    return self
  end
  local log = logs[selected]
  if not log then
    err = { 'Failed to access logs' }
    console.debug(err, debug.traceback())
    runtime_cache.err = err
    return self
  end
  local parent_hash = log.parent_hash
  local commit_hash = log.commit_hash
  err, hunks = git_object:remote_hunks(parent_hash, commit_hash)
  if err then
    console.debug(err, debug.traceback())
    runtime_cache.err = err
    return self
  end
  err, lines = git_object:lines(commit_hash)
  if err then
    console.debug(err, debug.traceback())
    runtime_cache.err = err
    return self
  end
  loop.await_fast_event()
  runtime_cache.data = {
    filename = buffer.filename,
    filetype = buffer:filetype(),
    logs = logs,
    dto = self:generate_diff(hunks, lines),
  }
  return self
end

function HistoryScene:get_unified_scene_options(options)
  local table_height = math.floor(dimensions.global_height() * 0.15)
  return {
    current = CodeComponent:new(utils.object_assign({
      config = {
        win_options = {
          cursorbind = true,
          scrollbind = true,
          cursorline = true,
        },
        window_props = {
          height = dimensions.global_height() - table_height,
          row = table_height,
        },
      },
    }, options)),
    table = TableComponent:new(utils.object_assign({
      header = { 'Revision', 'Author Name', 'Commit Hash', 'Time', 'Summary' },
      config = {
        window_props = {
          height = table_height,
          row = 0,
        },
      },
    }, options)),
  }
end

function HistoryScene:get_split_scene_options(options)
  local table_height = math.floor(dimensions.global_height() * 0.15)
  return {
    previous = CodeComponent:new(utils.object_assign({
      config = {
        win_options = {
          cursorbind = true,
          scrollbind = true,
          cursorline = true,
        },
        window_props = {
          height = dimensions.global_height() - table_height,
          width = math.floor(dimensions.global_width() / 2),
          row = table_height,
        },
      },
    }, options)),
    current = CodeComponent:new(utils.object_assign({
      config = {
        win_options = {
          cursorbind = true,
          scrollbind = true,
          cursorline = true,
        },
        window_props = {
          height = dimensions.global_height() - table_height,
          width = math.floor(dimensions.global_width() / 2),
          col = math.floor(dimensions.global_width() / 2),
          row = table_height,
        },
      },
    }, options)),
    table = TableComponent:new(utils.object_assign({
      header = { 'Revision', 'Author Name', 'Commit Hash', 'Time', 'Summary' },
      config = {
        window_props = {
          height = table_height,
          row = 0,
        },
      },
    }, options)),
  }
end

function HistoryScene:table_change()
  loop.await_fast_event()
  local selected = self.scene.components.table:get_lnum()
  self:update(selected)
end

function HistoryScene:make_table()
  self.scene.components.table
    :unlock()
    :make_rows(self.runtime_cache.data.logs, function(log)
      return {
        log.revision,
        log.author_name or '',
        log.commit_hash or '',
        (log.timestamp and os.date('%Y-%m-%d', tonumber(log.timestamp))) or '',
        log.summary or '',
      }
    end)
    :set_keymap('n', 'j', 'on_j')
    :set_keymap('n', 'J', 'on_j')
    :set_keymap('n', 'k', 'on_k')
    :set_keymap('n', 'K', 'on_k')
    :set_keymap('n', '<enter>', 'on_enter')
    :focus()
    :lock()
  return self
end

function HistoryScene:show(title, options)
  local buffer = self.git_store:current()
  if not buffer then
    console.log('Current buffer you are on has no history')
    return false
  end
  local git_object = buffer.git_object
  if git_object:tracked_filename() == '' then
    loop.await_fast_event()
    console.log('Current buffer you are on has no history')
    return false
  end
  if not git_object:is_in_remote() then
    loop.await_fast_event()
    console.log('Current buffer you are on has no history')
    return false
  end
  local runtime_cache = self.runtime_cache
  runtime_cache.title = title
  runtime_cache.options = options
  runtime_cache.buffer = buffer
  console.log('Processing buffer logs')
  self:fetch().scene = Scene:new(self:get_scene_options(options)):mount()
  if runtime_cache.err then
    console.error(runtime_cache.err)
    return false
  end
  local data = runtime_cache.data
  self
    :set_title(title, {
      filename = data.filename,
      filetype = data.filetype,
      stat = data.dto.stat,
    })
    :make_code()
    :make_table()
    :attach_to_ui()
    :set_code_cursor_on_mark(1)
  -- Must be after initial fetch
  runtime_cache.last_selected = 1
  console.clear()
  return true
end

return HistoryScene
