local CodeDTO = require('vgit.core.CodeDTO')
local loop = require('vgit.core.loop')
local Scene = require('vgit.ui.Scene')
local PresentationalComponent = require(
  'vgit.ui.components.PresentationalComponent'
)
local CodeComponent = require('vgit.ui.components.CodeComponent')
local CodeScreen = require('vgit.ui.screens.CodeScreen')
local console = require('vgit.core.console')

local GutterBlameScreen = CodeScreen:extend()

function GutterBlameScreen:new(...)
  return setmetatable(CodeScreen:new(...), GutterBlameScreen)
end

function GutterBlameScreen:fetch()
  local state = self.state
  local buffer = state.buffer
  local blames_err, blames = buffer.git_object:blames()
  if blames_err then
    console.debug(blames_err, debug.traceback())
    state.err = blames_err
    return self
  end
  loop.await_fast_event()
  state.data = {
    filename = buffer.filename,
    filetype = buffer:filetype(),
    dto = CodeDTO:new({ lines = buffer:get_lines() }),
    blames = blames,
  }
  return self
end

function GutterBlameScreen:get_blame_line(blame)
  if blame.committed then
    return string.format(
      '%s %s (%s) %s',
      blame.commit_hash:sub(1, 8),
      blame.author,
      blame:age().display,
      blame.committed and blame.commit_message or 'Uncommitted changes'
    )
  end
  return 'Uncommitted changes'
end

function GutterBlameScreen:get_scene_definition()
  return {
    blames = PresentationalComponent:new({
      config = {
        elements = {
          footer = false,
        },
        win_options = {
          cursorbind = true,
          scrollbind = true,
          cursorline = true,
        },
        win_plot = {
          height = '100vh',
          width = '40vw',
        },
      },
    }),
    current = CodeComponent:new({
      config = {
        elements = {
          footer = false,
        },
        win_options = {
          cursorbind = true,
          scrollbind = true,
          cursorline = true,
        },
        win_plot = {
          height = '100vh',
          width = '60vw',
          col = '40vw',
        },
      },
    }),
  }
end

function GutterBlameScreen:make_blames()
  local lines = {}
  local blames = self.state.data.blames
  for i = 1, #blames do
    lines[#lines + 1] = self:get_blame_line(blames[i])
  end
  self.scene.components.blames:set_lines(lines)
  return self
end

function GutterBlameScreen:set_title(title, props)
  self.scene.components.blames:set_title(title, props)
  return self
end

function GutterBlameScreen:notify()
  return self
end

function GutterBlameScreen:show(title, props)
  local buffer = self.git_store:current()
  if not buffer then
    console.log('Current buffer you are on has no blames')
    return false
  end
  local git_object = buffer.git_object
  if git_object:tracked_filename() == '' then
    console.log('Current buffer you are on has no blames')
    return false
  end
  if not git_object:is_in_remote() then
    console.log('Current buffer you are on has no blames')
    return false
  end
  local state = self.state
  state.buffer = buffer
  state.title = title
  state.props = props
  if state.err then
    console.error(state.err)
    return false
  end
  console.log('Processing buffer blames')
  self:fetch()
  loop.await_fast_event()
  self.scene = Scene:new(self:get_scene_definition(props)):mount()
  local data = state.data
  self
    :set_title(title, {
      filename = data.filename,
      filetype = data.filetype,
    })
    :make_code()
    :make_blames()
    :paint_code()
  console.clear()
  return true
end

return GutterBlameScreen
