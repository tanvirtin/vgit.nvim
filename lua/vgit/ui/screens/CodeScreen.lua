local Object = require('vgit.core.Object')
local Diff = require('vgit.Diff')
local LineNumberElement = require('vgit.ui.elements.LineNumberElement')
local symbols_setting = require('vgit.settings.symbols')
local assertion = require('vgit.core.assertion')
local signs_setting = require('vgit.settings.signs')

local CodeScreen = Object:extend()

function CodeScreen:new(buffer_hunks, navigation, git_store, git)
  return setmetatable({
    buffer_hunks = buffer_hunks,
    git_store = git_store,
    navigation = navigation,
    git = git,
    layout_type = 'unified',
    events = {},
    scene = nil,
    state = {
      mark_index = 1,
      current_lines_metadata = {},
      previous_lines_metadata = {},
    },
  }, CodeScreen)
end

function CodeScreen:trigger_keypress(key, ...)
  self.scene:trigger_keypress(key, ...)
  return self
end

function CodeScreen:generate_diff(hunks, lines)
  local diff
  if self.layout_type == 'unified' then
    diff = Diff:new(hunks):unified(lines)
  else
    diff = Diff:new(hunks):split(lines)
  end
  return diff
end

function CodeScreen:get_scene_definition()
  local scene_props = nil
  if self.layout_type == 'unified' then
    scene_props = self:get_unified_scene_definition()
  else
    scene_props = self:get_split_scene_definition()
  end
  return scene_props
end

function CodeScreen:set_filetype()
  if not self:has_active_screen() then
    return
  end
  local components = self.scene.components
  local filetype = self.state.data.filetype
  if not filetype then
    return self
  end
  local current = components.current
  if current:get_filetype() == filetype then
    return self
  end
  current:set_filetype(filetype)
  if self.layout_type == 'split' then
    components.previous:set_filetype(filetype)
  end
  return self
end

function CodeScreen:reset()
  return self:reset_cursor():clear_namespace()
end

function CodeScreen:reset_cursor()
  if not self:has_active_screen() then
    return
  end
  local components = self.scene.components
  components.current:reset_cursor()
  if self.layout_type == 'split' then
    components.previous:reset_cursor()
  end
  return self
end

function CodeScreen:set_title(title, options)
  if not self:has_active_screen() then
    return
  end
  local components = self.scene.components
  if components.header then
    components.header:set_title(title, options)
    return self
  end
  if self.layout_type == 'split' then
    components.previous:set_title(title, options)
  else
    components.current:set_title(title, options)
  end
  return self
end

function CodeScreen:notify(text)
  if not self:has_active_screen() then
    return
  end
  local components = self.scene.components
  if components.header then
    components.header:notify(text)
    return self
  end
  if self.layout_type == 'split' then
    components.previous:notify(text)
  else
    components.current:notify(text)
  end
  return self
end

function CodeScreen:navigate(direction)
  local data = self.state.data
  if not data then
    return self
  end
  if self.state.err then
    return self
  end
  local dto = data.dto
  if not dto then
    return self
  end
  local marks = dto.marks
  local mark_index = nil
  if not self:has_active_screen() then
    return
  end
  local scene = self.scene
  local components = scene.components
  if #marks == 0 then
    self:notify('There are no changes')
    return self
  end
  local focused_component_name = scene:get_focused_component_name()
  local component = components.current
  local window = component.window
  local buffer = component.buffer
  if focused_component_name == 'table' then
    local selected = self.state.mark_index
    if direction == 'up' then
      selected = selected - 1
    end
    if direction == 'down' then
      selected = selected + 1
    end
    if selected > #marks then
      selected = 1
    end
    if selected < 1 then
      selected = #marks
    end
    mark_index = self.navigation:mark_select(component, selected, marks, 'top')
  else
    if direction == 'up' then
      mark_index = self.navigation:mark_up(window, buffer, marks)
    end
    if direction == 'down' then
      mark_index = self.navigation:mark_down(window, buffer, marks)
    end
  end
  if mark_index then
    self.state.mark_index = mark_index
    self:notify(
      string.format('%s%s/%s Changes', string.rep(' ', 1), mark_index, #marks)
    )
    return self
  end
  return self
end

function CodeScreen:has_active_screen()
  return self.scene ~= nil
end

function CodeScreen:set_cursor(cursor)
  local components = self.scene.components
  components.current:set_cursor(cursor)
  if self.layout_type == 'split' then
    components.previous:set_cursor(cursor)
  end
  return self
end

function CodeScreen:set_code_cursor_on_mark(selected, position)
  if not position then
    position = 'top'
  end
  local data = self.state.data
  if not data then
    return self
  end
  if self.state.err then
    return self
  end
  if not data.dto then
    return self
  end
  local marks = data.dto.marks
  if #marks == 0 then
    self:notify('There are no changes')
    return self
  end
  local scene = self.scene
  if not scene then
    return
  end
  local components = scene.components
  if not selected or selected > #marks then
    selected = 1
  end
  if self.layout_type == 'split' then
    self.navigation:mark_select(components.previous, selected, marks, position)
  end
  local mark_index = self.navigation:mark_select(
    components.current,
    selected,
    marks,
    position
  )
  if mark_index then
    self.state.mark_index = selected
    self:notify(
      string.format('%s%s/%s Changes', string.rep(' ', 1), mark_index, #marks)
    )
    return self
  end
  return self
end

function CodeScreen:make_code()
  return self:make_lines():make_line_numbers():set_filetype()
end

function CodeScreen:make_lines()
  local components = self.scene.components
  local dto = self.state.data.dto
  if self.layout_type == 'unified' then
    components.current:set_lines(dto.lines)
  else
    components.previous:set_lines(dto.previous_lines)
    components.current:set_lines(dto.current_lines)
  end
  return self
end

function CodeScreen:make_line_numbers()
  local dto = self.state.data.dto
  if not dto then
    return self
  end
  local components = self.scene.components
  local layout_type = self.layout_type or 'unified'
  local line_metadata = {}
  local lines = {}
  local line_count = 1
  if layout_type == 'unified' then
    local component = components.current
    local lnum_change_map = {}
    for i = 1, #dto.lnum_changes do
      local lnum_change = dto.lnum_changes[i]
      lnum_change_map[lnum_change.lnum] = lnum_change
    end
    for i = 1, #dto.lines do
      local line
      local lnum_change = lnum_change_map[i]
      if lnum_change and lnum_change.type == 'remove' then
        line = ''
        lines[#lines + 1] = line
      else
        line = string.format('%s ', line_count)
        lines[#lines + 1] = line
        line_count = line_count + 1
      end
      line_metadata[#line_metadata + 1] = {
        lnum_change = lnum_change,
        line_number = line,
      }
    end
    self.state.current_lines_metadata = line_metadata
    component:make_line_numbers(lines)
  elseif layout_type == 'split' then
    local previous_component = components.previous
    local current_component = components.current
    local current_lnum_change_map = {}
    local previous_lnum_change_map = {}
    for i = 1, #dto.lnum_changes do
      local lnum_change = dto.lnum_changes[i]
      if lnum_change.buftype == 'current' then
        current_lnum_change_map[lnum_change.lnum] = lnum_change
      elseif lnum_change.buftype == 'previous' then
        previous_lnum_change_map[lnum_change.lnum] = lnum_change
      end
    end
    for i = 1, #dto.current_lines do
      local line
      local lnum_change = current_lnum_change_map[i]
      if
        lnum_change
        and (lnum_change.type == 'remove' or lnum_change.type == 'void')
      then
        line = string.rep(
          symbols_setting:get('void'),
          LineNumberElement:get_width()
        )
        lines[#lines + 1] = line
      else
        line = string.format('%s ', line_count)
        lines[#lines + 1] = line
        line_count = line_count + 1
      end
      line_metadata[#line_metadata + 1] = {
        lnum_change = lnum_change,
        line_number = line,
      }
    end
    self.state.current_lines_metadata = line_metadata
    current_component:make_line_numbers(lines)
    line_metadata = {}
    lines = {}
    line_count = 1
    for i = 1, #dto.previous_lines do
      local line
      local lnum_change = previous_lnum_change_map[i]
      if
        lnum_change
        and (lnum_change.type == 'add' or lnum_change.type == 'void')
      then
        line = string.rep(
          symbols_setting:get('void'),
          LineNumberElement:get_width()
        )
        lines[#lines + 1] = line
      else
        line = string.format('%s ', line_count)
        lines[#lines + 1] = line
        line_count = line_count + 1
      end
      line_metadata[#line_metadata + 1] = {
        lnum_change = lnum_change,
        line_number = line,
      }
    end
    self.state.previous_lines_metadata = line_metadata
    previous_component:make_line_numbers(lines)
  end
  return self
end

function CodeScreen:apply_paint_instructions(lnum, metadata, component_type)
  local lnum_change = metadata.lnum_change
  local line_number = metadata.line_number
  local line_number_hl = 'GitLineNr'
  local signs_usage_setting = signs_setting:get('usage')
  local scene_signs = signs_usage_setting.scene
  local main_signs = signs_usage_setting.main
  local component = self.scene.components[component_type]
  if lnum_change then
    component = self.scene.components[lnum_change.buftype]
    local type = lnum_change.type
    local word_diff = lnum_change.word_diff
    local sign_name = scene_signs[type]
    lnum = lnum_change.lnum
    if lnum_change.type ~= 'void' then
      line_number_hl = main_signs[type]
    end
    if sign_name then
      component:sign_place_line_number(lnum, sign_name)
    end
    component:transpose_virtual_line_number(
      line_number,
      line_number_hl,
      lnum - 1
    )
    if sign_name then
      component:sign_place(lnum, sign_name)
    end
    if type == 'void' then
      component:transpose_virtual_text(
        string.rep(symbols_setting:get('void'), component.window:get_width()),
        line_number_hl,
        lnum - 1,
        0
      )
    end
    -- Highlighting the word diff text here.
    local texts = {}
    if word_diff then
      local offset = 0
      for j = 1, #word_diff do
        local segment = word_diff[j]
        local operation, fragment = unpack(segment)
        if operation == -1 then
          local hl = type == 'remove' and 'GitWordDelete' or 'GitWordAdd'
          texts[#texts + 1] = { fragment, hl }
        elseif operation == 0 then
          texts[#texts + 1] = {
            fragment,
            nil,
          }
        end
        if operation == 0 or operation == -1 then
          offset = offset + #fragment
        end
      end
      component:transpose_virtual_line(texts, lnum - 1)
    end
  else
    component:transpose_virtual_line_number(
      line_number,
      line_number_hl,
      lnum - 1
    )
  end
end

function CodeScreen:apply_brush(top, bot)
  local current_lines_metadata = self.state.current_lines_metadata
  local previous_lines_metadata = self.state.previous_lines_metadata
  for i = top, bot do
    if current_lines_metadata and current_lines_metadata[i] then
      self:apply_paint_instructions(i, current_lines_metadata[i], 'current')
    end
    if self.layout_type == 'split' then
      if previous_lines_metadata and previous_lines_metadata[i] then
        self:apply_paint_instructions(i, previous_lines_metadata[i], 'previous')
      end
    end
  end
  return self
end

-- Applies brush to only a given range in a document.
function CodeScreen:paint_code_partially()
  -- Attaching it to just current will always be enough.
  self.scene.components.current:attach_to_renderer(function(top, bot)
    self:apply_brush(top, bot)
  end)
  return self
end

-- Applies brush to the entire document.
function CodeScreen:paint_code()
  return self:apply_brush(1, #self.state.current_lines_metadata)
end

function CodeScreen:show()
  assertion.assert('Not yet implemented', debug.traceback())
end

function CodeScreen:detach_from_renderer()
  -- TODO: This is a super important step to avoid memory leak.
  -- Should be a better way to handle this
  local components = self.scene.components
  components.current:detach_from_renderer()
  if self.layout_type == 'split' then
    components.previous:detach_from_renderer()
  end
  return self
end

function CodeScreen:hide()
  if self.scene then
    self:detach_from_renderer()
    self.scene:unmount()
  end
  self.scene = nil
  return self
end

function CodeScreen:clear_namespace()
  local components = self.scene.components
  components.current:clear_namespace()
  if self.layout_type == 'split' then
    components.previous:clear_namespace()
  end
  return self
end

function CodeScreen:clear_state_err()
  self.state.err = nil
  return self
end

function CodeScreen:clear_state_data()
  self.state.data = nil
  return self
end

function CodeScreen:clear_state()
  self.state = {}
  return self
end

function CodeScreen:destroy()
  self:hide()
  self:clear_state()
  return self
end

function CodeScreen:keep_focused()
  if self.scene then
    self.scene:keep_focused()
  end
  return self
end

function CodeScreen:get_unified_scene_definition()
  assertion.assert('Not yet implemented', debug.traceback())
end

function CodeScreen:get_split_scene_definition()
  assertion.assert('Not yet implemented', debug.traceback())
end

return CodeScreen
