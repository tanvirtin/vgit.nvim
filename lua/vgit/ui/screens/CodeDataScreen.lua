local console = require('vgit.core.console')
local loop = require('vgit.core.loop')
local CodeScreen = require('vgit.ui.screens.CodeScreen')

local CodeDataScreen = CodeScreen:extend()

function CodeDataScreen:new(...)
  return setmetatable(CodeScreen:new(...), CodeDataScreen)
end
function CodeDataScreen:render()
  loop.await_fast_event()
  local state = self.state
  if state.err then
    console.error(state.err)
    return self
  end
  if not state.data and not state.data or not state.data.dto then
    return self
  end
  local data = state.data
  self
    :reset()
    :set_title(state.title, {
      filename = data.filename,
      filetype = data.filetype,
      stat = data.dto.stat,
    })
    :make_code()
    :paint_code_partially()
    :set_code_cursor_on_mark(1)
end

CodeDataScreen.refetch_and_render = loop.debounce(
  loop.async(function(self, lnum)
    self
      :fetch(lnum, {
        cached = true,
      })
      :render()
  end),
  50
)

function CodeDataScreen:table_move(direction)
  self:clear_state_err()
  local components = self.scene.components
  local table = components.table
  -- NOTE: Don't remove this, important for the UI flow
  loop.await_fast_event()
  local lnum = table:get_lnum()
  if direction == 'up' then
    lnum = lnum - 1
  elseif direction == 'down' then
    lnum = lnum + 1
  end
  local total_line_count = table:get_line_count()
  if lnum > total_line_count then
    lnum = 1
  elseif lnum < 1 then
    lnum = total_line_count
  end
  local state = self.state
  if state.last_lnum == lnum then
    return self
  end
  state.last_lnum = lnum
  -- NOTE: Don't remove this, important for the UI flow
  loop.await_fast_event()
  table:unlock():set_lnum(lnum):lock()
  self:refetch_and_render(lnum)
end

return CodeDataScreen
