local Window = require('vgit.core.Window')
local loop = require('vgit.core.loop')
local utils = require('vgit.core.utils')
local Scene = require('vgit.ui.Scene')
local PopupComponent = require('vgit.ui.components.PopupComponent')
local CodeScene = require('vgit.ui.abstract_scenes.CodeScene')
local console = require('vgit.core.console')

local LineBlameScene = CodeScene:extend()

function LineBlameScene:new(...)
  return setmetatable(CodeScene:new(...), LineBlameScene)
end

function LineBlameScene:fetch()
  local cache = self.cache
  local buffer = cache.buffer
  loop.await_fast_event()
  local blame_err, blame = buffer.git_object:blame_line(
    Window:new(0):get_lnum()
  )
  if blame_err then
    console.debug(blame_err, debug.traceback())
    cache.err = blame_err
    return self
  end
  cache.data = blame
  return self
end

function LineBlameScene:create_uncommitted_lines(blame)
  return {
    string.format('%sLine #%s', '  ', blame.lnum),
    string.format('%s%s', '  ', 'Uncommitted changes'),
    string.format('%s%s -> %s', '  ', blame.parent_hash, blame.commit_hash),
  }
end

function LineBlameScene:create_committed_lines(blame)
  local max_line_length = 88
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
  local commit_message = blame.commit_message
  if #commit_message > max_line_length then
    commit_message = commit_message:sub(1, max_line_length) .. '...'
  end
  return {
    string.format('%sLine #%s', '  ', blame.lnum),
    string.format('  %s (%s)', blame.author, blame.author_mail),
    string.format('  %s (%s)', time_format, os.date('%c', blame.author_time)),
    string.format('%s%s', '  ', commit_message),
    string.format('%s%s -> %s', '  ', blame.parent_hash, blame.commit_hash),
  }
end

function LineBlameScene:get_scene_options(options)
  return {
    current = PopupComponent:new(utils.object_assign({
      config = {
        window_props = {
          height = 10,
          width = 50,
        },
      },
    }, options)),
  }
end

function LineBlameScene:make_lines()
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
  local blame = self.cache.data
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

function LineBlameScene:show(options)
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
  local cache = self.cache
  cache.buffer = buffer
  cache.options = options
  console.log('Processing buffer line blame')
  self:fetch()
  loop.await_fast_event()
  if cache.err then
    console.error(cache.err)
    return false
  end
  self.scene = Scene:new(self:get_scene_options(options)):mount()
  self:make_lines()
  console.clear()
  return true
end

return LineBlameScene
