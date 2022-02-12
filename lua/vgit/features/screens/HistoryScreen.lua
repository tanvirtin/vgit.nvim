local loop = require('vgit.core.loop')
local CodeComponent = require('vgit.ui.components.CodeComponent')
local git_buffer_store = require('vgit.git_buffer_store')
local TableComponent = require('vgit.ui.components.TableComponent')
local CodeListScreen = require('vgit.ui.screens.CodeListScreen')
local Scene = require('vgit.ui.Scene')
local console = require('vgit.core.console')

local HistoryScreen = CodeListScreen:extend()

function HistoryScreen:new(...)
  return setmetatable(CodeListScreen:new(...), HistoryScreen)
end

function HistoryScreen:fetch(opts)
  opts = opts or {}
  local state = self.state
  local data = state.data
  local buffer = state.buffer
  local git_object = buffer.git_object
  local lines, hunks
  local err, logs
  if opts.cached then
    logs = data.logs
  else
    err, logs = git_object:logs()
  end
  if err then
    console.debug(err, debug.traceback())
    state.err = err
    return self
  end
  local log = logs[self.list_control:i()]
  if not log then
    err = { 'Failed to access logs' }
    console.debug(err, debug.traceback())
    state.err = err
    return self
  end
  local parent_hash = log.parent_hash
  local commit_hash = log.commit_hash
  err, hunks = git_object:remote_hunks(parent_hash, commit_hash)
  if err then
    console.debug(err, debug.traceback())
    state.err = err
    return self
  end
  err, lines = git_object:lines(commit_hash)
  if err then
    console.debug(err, debug.traceback())
    state.err = err
    return self
  end
  loop.await_fast_event()
  state.data = {
    filename = buffer.filename,
    filetype = buffer:filetype(),
    logs = logs,
    dto = self:generate_dto(hunks, lines),
  }
  return self
end

function HistoryScreen:get_unified_scene_definition()
  return {
    current = CodeComponent:new({
      config = {
        elements = {
          header = true,
          footer = false,
        },
        win_options = {
          cursorbind = true,
          scrollbind = true,
          cursorline = true,
        },
        win_plot = {
          height = '85vh',
          row = '15vh',
        },
      },
    }),
    list = TableComponent:new({
      config = {
        elements = {
          header = true,
          footer = false,
        },
        header = {
          'Revision',
          'Author Name',
          'Commit Hash',
          'Time',
          'Summary',
        },
        win_plot = {
          height = '15vh',
        },
      },
    }),
  }
end

function HistoryScreen:get_split_scene_definition()
  return {
    previous = CodeComponent:new({
      config = {
        elements = {
          header = true,
          footer = false,
        },
        win_options = {
          cursorbind = true,
          scrollbind = true,
          cursorline = true,
        },
        win_plot = {
          height = '85vh',
          width = '50vw',
          row = '15vh',
        },
      },
    }),
    current = CodeComponent:new({
      config = {
        elements = {
          header = true,
          footer = false,
        },
        win_options = {
          cursorbind = true,
          scrollbind = true,
          cursorline = true,
        },
        win_plot = {
          height = '85vh',
          width = '50vw',
          row = '15vh',
          col = '50vw',
        },
      },
    }),
    list = TableComponent:new({
      config = {
        elements = {
          header = true,
          footer = false,
        },
        header = {
          'Revision',
          'Author Name',
          'Commit Hash',
          'Time',
          'Summary',
        },
        win_plot = {
          height = '15vh',
        },
      },
    }),
  }
end

function HistoryScreen:resync_list()
  self.scene.components.list
    :unlock()
    :make_rows(self.state.data.logs, function(log)
      return {
        log.revision,
        log.author_name or '',
        log.commit_hash or '',
        (log.timestamp and os.date('%Y-%m-%d', tonumber(log.timestamp))) or '',
        log.summary or '',
      }
    end)
    :set_keymap('n', 'j', 'keys.j', function()
      self:list_move('down')
    end)
    :set_keymap('n', 'k', 'keys.k', function()
      self:list_move('up')
    end)
    :set_keymap('n', '<enter>', 'keys.prevent_default')
    :focus()
    :lock()
  return self
end

function HistoryScreen:show(title, props)
  self:clear_state()
  self.list_control:resync()
  local buffer = git_buffer_store.current()
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
  local state = self.state
  state.title = title
  state.props = props
  state.buffer = buffer
  console.log('Processing buffer logs')
  self:fetch().scene = Scene:new(self:get_scene_definition(props)):mount()
  self:resync_list():resync_code()
  -- Must be after initial fetch
  console.clear()
  return true
end

return HistoryScreen
