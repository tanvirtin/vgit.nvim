local Window = require('vgit.core.Window')
local loop = require('vgit.core.loop')
local utils = require('vgit.core.utils')
local Scene = require('vgit.ui.Scene')
local PopupComponent = require('vgit.ui.components.PopupComponent')
local CodeScreen = require('vgit.ui.screens.CodeScreen')
local console = require('vgit.core.console')

local LineBlameScreen = CodeScreen:extend()

function LineBlameScreen:new(...)
  return setmetatable(CodeScreen:new(...), LineBlameScreen)
end

function LineBlameScreen:fetch()
  local state = self.state
  local buffer = state.buffer
  loop.await_fast_event()
  local blame_err, blame = buffer.git_object:blame_line(
    Window:new(0):get_lnum()
  )
  if blame_err then
    console.debug(blame_err, debug.traceback())
    state.err = blame_err
    return self
  end
  state.data = blame
  return self
end

function LineBlameScreen:create_uncommitted_lines(blame)
  return {
    string.format('%sLine #%s', '  ', blame.lnum),
    string.format('%s%s', '  ', 'Uncommitted changes'),
    string.format('%s%s -> %s', '  ', blame.parent_hash, blame.commit_hash),
  }
end

function LineBlameScreen:create_committed_lines(blame)
  local max_line_length = 88
  local commit_message = blame.commit_message
  if #commit_message > max_line_length then
    commit_message = commit_message:sub(1, max_line_length) .. '...'
  end
  return {
    string.format('%sLine #%s', '  ', blame.lnum),
    string.format('  %s (%s)', blame.author, blame.author_mail),
    string.format(
      '  %s (%s)',
      blame:age().display,
      os.date('%c', blame.author_time)
    ),
    string.format('%s%s', '  ', commit_message),
    string.format('%s%s -> %s', '  ', blame.parent_hash, blame.commit_hash),
  }
end

function LineBlameScreen:get_scene_definition()
  return {
    current = PopupComponent:new({
      config = {
        win_plot = {
          height = 10,
          width = 50,
        },
      },
    }),
  }
end

function LineBlameScreen:make_lines()
  local get_width = function(lines)
    local max_line_width = 50
    for i = 1, #lines do
      local line = lines[i]
      if #line > max_line_width then
        max_line_width = #line + 1
      end
    end
    return max_line_width
  end
  local component = self.scene.components.current
  local blame = self.state.data
  if not blame.committed then
    local uncommitted_lines = self:create_uncommitted_lines(blame)
    component
      :set_lines(uncommitted_lines)
      :set_height(#uncommitted_lines)
      :set_width(get_width(uncommitted_lines))
    return self
  end
  local committed_lines = self:create_committed_lines(blame)
  component
    :set_lines(committed_lines)
    :set_height(#committed_lines)
    :set_width(get_width(committed_lines))
end

function LineBlameScreen:show(props)
  local buffer = self.git_store:current()
  if not buffer then
    return false
  end
  local git_object = buffer.git_object
  if git_object:tracked_filename() == '' then
    return false
  end
  if not git_object:is_in_remote() then
    return false
  end
  local state = self.state
  state.buffer = buffer
  state.props = props
  console.log('Processing buffer line blame')
  self:fetch()
  loop.await_fast_event()
  if state.err then
    console.error(state.err)
    return false
  end
  self.scene = Scene:new(self:get_scene_definition(props)):mount()
  self:make_lines()
  console.clear()
  return true
end

return LineBlameScreen
