local console = require('vgit.core.console')
local loop = require('vgit.core.loop')
local CodeScreen = require('vgit.ui.screens.CodeScreen')

local CodeDataScreen = CodeScreen:extend()

function CodeDataScreen:new(...)
  return setmetatable(CodeScreen:new(...), CodeDataScreen)
end

CodeDataScreen.update = loop.brakecheck(loop.async(function(self, selected)
  local runtime_cache = self.runtime_cache
  runtime_cache.last_selected = selected
  self:fetch(selected)
  loop.await_fast_event()
  if runtime_cache.err then
    console.error(runtime_cache.err)
    return self
  end
  if
    not runtime_cache.data and not runtime_cache.data
    or not runtime_cache.data.dto
  then
    return
  end
  self
    :reset()
    :set_title(runtime_cache.title, {
      filename = runtime_cache.data.filename,
      filetype = runtime_cache.data.filetype,
      stat = runtime_cache.data.dto.stat,
    })
    :make_code()
    :paint_code_partially()
    :set_code_cursor_on_mark(1)
end))

function CodeDataScreen:table_move(direction)
  self:clear_runtime_cached_err()
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
  if self.runtime_cache.last_selected == selected then
    return
  end
  loop.await_fast_event()
  table:unlock():set_lnum(selected):lock()
  self:update(selected)
end

return CodeDataScreen
