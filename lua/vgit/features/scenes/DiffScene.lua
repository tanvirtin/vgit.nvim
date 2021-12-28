local utils = require('vgit.core.utils')
local Scene = require('vgit.ui.Scene')
local loop = require('vgit.core.loop')
local dimensions = require('vgit.ui.dimensions')
local CodeComponent = require('vgit.ui.components.CodeComponent')
local CodeScene = require('vgit.ui.abstract_scenes.CodeScene')
local console = require('vgit.core.console')
local Hunk = require('vgit.cli.models.Hunk')

local DiffScene = CodeScene:extend()

function DiffScene:new(...)
  local this = CodeScene:new(...)
  this.cache = {
    buffer = nil,
    title = nil,
    options = nil,
    err = false,
    data = nil,
  }
  return setmetatable(this, DiffScene)
end

function DiffScene:fetch()
  local cache = self.cache
  local buffer = cache.buffer
  local hunks = buffer.git_object.hunks
  local lines = buffer:get_lines()
  if not hunks then
    -- This scenario will occur if current buffer has not computer it's live hunk yet.
    local hunks_err, calculated_hunks = buffer.git_object:live_hunks(lines)
    if hunks_err then
      console.debug(hunks_err, debug.traceback())
      cache.err = hunks_err
      return self
    end
    hunks = calculated_hunks
  end
  cache.data = {
    filename = buffer.filename,
    filetype = buffer:filetype(),
    dto = self:generate_diff(hunks, lines),
    selected_hunk = self.buffer_hunks:cursor_hunk() or Hunk:new(),
  }
  return self
end

function DiffScene:get_unified_scene_options(options)
  return {
    current = CodeComponent:new(utils.object_assign({
      config = {
        win_options = {
          cursorbind = true,
          scrollbind = true,
          cursorline = true,
        },
        window_props = {
          height = dimensions.global_height(),
          width = dimensions.global_width(),
        },
      },
    }, options)),
  }
end

function DiffScene:get_split_scene_options(options)
  return {
    previous = CodeComponent:new(utils.object_assign({
      config = {
        win_options = {
          cursorbind = true,
          scrollbind = true,
          cursorline = true,
        },
        window_props = {
          height = dimensions.global_height(),
          width = math.floor(dimensions.global_width() / 2),
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
          width = math.floor(dimensions.global_width() / 2),
          col = math.floor(dimensions.global_width() / 2),
        },
      },
    }, options)),
  }
end

function DiffScene:show(title, options)
  local buffer = self.git_store:current()
  if not buffer then
    console.log('Buffer has no hunks')
    return false
  end
  if buffer:editing() then
    console.debug(
      string.format('Buffer %s is being edited right now', buffer.bufnr)
    )
    return
  end
  local cache = self.cache
  cache.buffer = buffer
  cache.title = title
  cache.options = options
  console.log('Processing buffer diff')
  self:fetch()
  loop.await_fast_event()
  if cache.err then
    console.error(cache.err)
    return false
  end
  if #cache.data.dto.hunks == 0 then
    console.log('No hunks found')
    return false
  end
  -- selected_hunk must always be called before creating the scene.
  local _, selected_hunk = self.buffer_hunks:cursor_hunk()
  self.scene = Scene:new(self:get_scene_options(options)):mount()
  local data = cache.data
  self
    :set_title(title, {
      filename = data.filename,
      filetype = data.filetype,
      stat = data.dto.stat,
    })
    :make()
    :paint()
    :set_cursor_on_mark(selected_hunk, 'center')
  console.clear()
  return true
end

return DiffScene
