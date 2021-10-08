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
  local cache = self.cache
  local buffer = cache.buffer
  local blames_err, blames = buffer.git_object:blames()
  if blames_err then
    console.debug(blames_err, debug.traceback())
    cache.err = blames_err
    return self
  end
  loop.await_fast_event()
  cache.data = {
    filename = buffer.filename,
    filetype = buffer:filetype(),
    dto = CodeDTO:new({ lines = buffer:get_lines() }),
    blames = blames,
  }
  return self
end

function GutterBlameScene:get_blame_line(blame)
  local time = os.difftime(os.time(), blame.author_time) / (24 * 60 * 60)
  local time_format = string.format('%s days ago', utils.round(time))
  local time_divisions = {
    { 24, 'hours' },
    { 60, 'minutes' },
    { 60, 'seconds' },
  }
  local division_counter = 1
  while time < 1 and division_counter ~= #time_divisions do
    local division = time_divisions[division_counter]
    time = time * division[1]
    time_format = string.format('%s %s ago', utils.round(time), division[2])
    division_counter = division_counter + 1
  end
  if blame.committed then
    return string.format(
      '%s (%s) • %s',
      blame.author,
      time_format,
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
  local blames = self.cache.data.blames
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
    console.log('Buffer has no blames')
    return false
  end
  local git_object = buffer.git_object
  if git_object:tracked_filename() == '' then
    console.log('Buffer has no blames')
    return false
  end
  if not git_object:is_in_remote() then
    console.log('Buffer has no blames')
    return false
  end
  local cache = self.cache
  cache.buffer = buffer
  cache.title = title
  cache.options = options
  if cache.err then
    console.error(cache.err)
    return false
  end
  console.log('Processing buffer blames')
  self:fetch()
  loop.await_fast_event()
  self.scene = Scene:new(self:get_scene_options(options)):mount()
  local data = cache.data
  self
    :set_title(title, {
      filename = data.filename,
      filetype = data.filetype,
    })
    :make()
    :make_blames()
    :paint()
  console.clear()
  return true
end

return GutterBlameScene
