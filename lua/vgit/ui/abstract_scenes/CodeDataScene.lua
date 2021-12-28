local console = require('vgit.core.console')
local loop = require('vgit.core.loop')
local CodeScene = require('vgit.ui.abstract_scenes.CodeScene')

local CodeDataScene = CodeScene:extend()

function CodeDataScene:new(...)
  return setmetatable(CodeScene:new(...), CodeDataScene)
end

CodeDataScene.update = loop.brakecheck(loop.async(function(self, selected)
  local cache = self.cache
  cache.last_selected = selected
  self:fetch(selected)
  loop.await_fast_event()
  if cache.err then
    console.error(cache.err)
    return self
  end
  self:reset():set_title(cache.title, {
    filename = cache.data.filename,
    filetype = cache.data.filetype,
    stat = cache.data.dto.stat,
  })
  self:make():paint():set_cursor_on_mark(1)
end))

function CodeDataScene:table_move(direction)
  self:clear_cached_err()
  local components = self.scene.components
  local table = components.table
  loop.await_fast_event()
  local selected = table:get_lnum()
  if direction == 'up' then
    selected = selected - 1
  elseif direction == 'down' then
    selected = selected + 1
  end
  local total_line_count = table:get_line_count()
  if selected > total_line_count then
    selected = 1
  elseif selected < 1 then
    selected = total_line_count
  end
  if self.cache.last_selected == selected then
    return
  end
  loop.await_fast_event()
  table:unlock():set_lnum(selected):lock()
  self:update(selected)
end

return CodeDataScene
