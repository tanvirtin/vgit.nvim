local utils = require('vgit.core.utils')
local loop = require('vgit.core.loop')
local navigation = require('vgit.navigation')
local ListControl = require('vgit.ui.ListControl')
local CodeScreen = require('vgit.ui.screens.CodeScreen')

local CodeListScreen = CodeScreen:extend()

function CodeListScreen:new(...)
  return setmetatable(
    utils.object.assign(CodeScreen:new(...), {
      list_control = ListControl:new(),
    }),
    CodeListScreen
  )
end

function CodeListScreen:get_mark_index(marks, direction)
  local mark_index = self.state.mark_index
  if direction == 'up' then
    mark_index = mark_index - 1
  end
  if direction == 'down' then
    mark_index = mark_index + 1
  end
  if mark_index > #marks then
    mark_index = 1
  end
  if mark_index < 1 then
    mark_index = #marks
  end
  return mark_index
end

function CodeListScreen:goto_mark(marks, direction, screen_pos)
  if #marks == 0 then
    self:notify('There are no changes')
    return self
  end
  local mark_index = self:get_mark_index(marks, direction)
  local component = self.scene.components.current
  mark_index = navigation.mark_select(component, marks, mark_index, screen_pos)
  if mark_index then
    self.state.mark_index = mark_index
    self:notify(
      string.format('%s%s/%s Changes', string.rep(' ', 1), mark_index, #marks)
    )
  end
  return self
end

function CodeListScreen:navigate(direction, screen_pos)
  if not self:has_active_screen() then
    return
  end
  local dto = self:get_dto()
  if not dto then
    return self
  end
  local marks = dto.marks
  screen_pos = screen_pos or 'top'
  return self:goto_mark(marks, direction, screen_pos)
end

CodeListScreen.sync = loop.debounce(
  loop.async(function(self)
    self
      :fetch({
        cached = true,
      })
      :resync_code()
  end),
  50
)

function CodeListScreen:list_move(direction)
  self:clear_state_err()
  local components = self.scene.components
  local list = components.list
  local list_control = self.list_control
  list_control:sync(list, direction)
  if list_control:is_unchanged() then
    return self
  end
  list:unlock():set_lnum(list_control:i()):lock()
  return self:sync()
end

return CodeListScreen
