local Scene = require('vgit.ui.Scene')
local loop = require('vgit.core.loop')
local CodeComponent = require('vgit.ui.components.CodeComponent')
local CodeScreen = require('vgit.ui.screens.CodeScreen')
local git_buffer_store = require('vgit.git_buffer_store')
local console = require('vgit.core.console')

local DiffScreen = CodeScreen:extend()

function DiffScreen:new(...)
  local this = CodeScreen:new(...)
  this.state = {
    buffer = nil,
    title = nil,
    err = false,
    data = nil,
  }
  return setmetatable(this, DiffScreen)
end

function DiffScreen:fetch()
  local state = self.state
  local buffer = state.buffer
  local hunks = buffer.git_object.hunks
  local lines = buffer:get_lines()
  if not hunks then
    -- This scenario will occur if current buffer has not computer it's live hunk yet.
    local hunks_err, calculated_hunks = buffer.git_object:live_hunks(lines)
    if hunks_err then
      console.debug(hunks_err, debug.traceback())
      state.err = hunks_err
      return self
    end
    hunks = calculated_hunks
  end
  state.data = {
    filename = buffer.filename,
    filetype = buffer:filetype(),
    dto = self:generate_diff(hunks, lines),
  }
  return self
end

function DiffScreen:get_unified_scene_definition()
  return {
    current = CodeComponent:new({
      config = {
        win_options = {
          cursorbind = true,
          scrollbind = true,
          cursorline = true,
        },
        win_plot = {
          height = '100vh',
          width = '100vw',
        },
      },
    }),
  }
end

function DiffScreen:get_split_scene_definition()
  return {
    previous = CodeComponent:new({
      config = {
        win_options = {
          cursorbind = true,
          scrollbind = true,
          cursorline = true,
        },
        win_plot = {
          height = '100vh',
          width = '50vw',
        },
      },
    }),
    current = CodeComponent:new({
      config = {
        win_options = {
          cursorbind = true,
          scrollbind = true,
          cursorline = true,
        },
        win_plot = {
          height = '100vh',
          width = '50vw',
          col = '50vw',
        },
      },
    }),
  }
end

function DiffScreen:navigate(direction)
  CodeScreen.navigate(self, direction)
  return self
end

function DiffScreen:show(title)
  self:clear_state()
  local buffer = git_buffer_store:current()
  if not buffer then
    console.log('Current buffer you are on has no hunks')
    return false
  end
  if buffer:editing() then
    console.debug(
      string.format('Buffer %s is being edited right now', buffer.bufnr)
    )
    return
  end
  local state = self.state
  state.buffer = buffer
  state.title = title
  console.log('Processing buffer diff')
  self:fetch()
  loop.await_fast_event()
  if state.err then
    console.error(state.err)
    return false
  end
  if #state.data.dto.hunks == 0 then
    console.log('No hunks found')
    return false
  end
  local _, initial_mark_index = self.buffer_hunks:cursor_hunk()
  self.scene = Scene:new(self:get_scene_definition()):mount()
  self:resync_code(initial_mark_index, 'center')
  console.clear()
  return true
end

return DiffScreen
