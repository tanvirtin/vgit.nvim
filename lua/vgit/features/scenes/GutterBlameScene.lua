local CodeDTO = require('vgit.core.CodeDTO')
local loop = require('vgit.core.loop')
local utils = require('vgit.core.utils')
local Scene = require('vgit.ui.Scene')
local dimensions = require('vgit.ui.dimensions')
local PresentationalComponent = require(
  'vgit.ui.components.PresentationalComponent'
)
local CodeComponent = require('vgit.ui.components.CodeComponent')
local CodeScene = require('vgit.ui.abstract_scenes.CodeScene')
local console = require('vgit.core.console')

local GutterBlameScene = CodeScene:extend()

function GutterBlameScene:new(...)
  return setmetatable(CodeScene:new(...), GutterBlameScene)
end

function GutterBlameScene:fetch()
  local runtime_cache = self.runtime_cache
  local buffer = runtime_cache.buffer
  local blames_err, blames = buffer.git_object:blames()
  if blames_err then
    console.debug(blames_err, debug.traceback())
    runtime_cache.err = blames_err
    return self
  end
  loop.await_fast_event()
  runtime_cache.data = {
    filename = buffer.filename,
    filetype = buffer:filetype(),
    dto = CodeDTO:new({ lines = buffer:get_lines() }),
    blames = blames,
  }
  return self
end

function GutterBlameScene:get_blame_line(blame)
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

function GutterBlameScene:get_scene_options(options)
  return {
    blames = PresentationalComponent:new(utils.object_assign({
      config = {
        win_options = {
          cursorbind = true,
          scrollbind = true,
          cursorline = true,
        },
        window_props = {
          height = dimensions.global_height(),
          width = math.floor(dimensions.global_width() * 0.4),
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
          height = dimensions.global_height(),
          width = math.floor(dimensions.global_width() * 0.6),
          col = math.floor(dimensions.global_width() * 0.4),
        },
      },
    }, options)),
  }
end

function GutterBlameScene:make_blames()
  local lines = {}
  local blames = self.runtime_cache.data.blames
  for i = 1, #blames do
    lines[#lines + 1] = self:get_blame_line(blames[i])
  end
  self.scene.components.blames:set_lines(lines)
  return self
end

function GutterBlameScene:set_title(title, options)
  self.scene.components.blames:set_title(title, options)
  return self
end

function GutterBlameScene:notify()
  return self
end

function GutterBlameScene:show(title, options)
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
  local runtime_cache = self.runtime_cache
  runtime_cache.buffer = buffer
  runtime_cache.title = title
  runtime_cache.options = options
  if runtime_cache.err then
    console.error(runtime_cache.err)
    return false
  end
  console.log('Processing buffer blames')
  self:fetch()
  loop.await_fast_event()
  self.scene = Scene:new(self:get_scene_options(options)):mount()
  local data = runtime_cache.data
  self
    :set_title(title, {
      filename = data.filename,
      filetype = data.filetype,
    })
    :make_code()
    :paint_code()
    :make_blames()
  console.clear()
  return true
end

return GutterBlameScene
