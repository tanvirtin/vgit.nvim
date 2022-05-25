local loop = require('vgit.core.loop')
local utils = require('vgit.core.utils')
local Window = require('vgit.core.Window')
local Object = require('vgit.core.Object')
local console = require('vgit.core.console')
local dimensions = require('vgit.ui.dimensions')
local signs_setting = require('vgit.settings.signs')
local symbols_setting = require('vgit.settings.symbols')
local CodeComponent = require('vgit.ui.components.CodeComponent')
local LineNumberElement = require('vgit.ui.elements.LineNumberElement')

local CodeView = Object:extend()

function CodeView:get_initial_state()
  return {
    is_painted = false,
    current_lines_changes = {},
    previous_lines_changes = {},
  }
end

function CodeView:constructor(scene, query, plot, config)
  return {
    title = 'Diff',
    scene = scene,
    query = query,
    plot = plot,
    layout_type = nil,
    config = config or {},
    state = CodeView:get_initial_state(),
  }
end

function CodeView:define()
  ({
    unified = function()
      self.scene:set(
        'current',
        CodeComponent({
          config = {
            elements = utils.object.assign({
              header = true,
              footer = false,
              line_number = true,
            }, self.config.elements),
            win_options = {
              cursorbind = true,
              scrollbind = true,
              cursorline = true,
            },
            win_plot = dimensions.relative_win_plot(self.plot, {
              height = '100vh',
              width = '100vw',
            }),
          },
        })
      )
    end,
    split = function()
      self.scene:set(
        'previous',
        CodeComponent({
          config = {
            elements = utils.object.assign({
              header = true,
              footer = false,
              line_number = true,
            }, self.config.elements),
            win_options = {
              cursorbind = true,
              scrollbind = true,
              cursorline = true,
            },
            win_plot = dimensions.relative_win_plot(self.plot, {
              height = '100vh',
              -- 49 and not 50 because nvim cannot have height or width be a non integer.
              -- This ensures that the other window never overflows.
              width = '49vw',
            }),
          },
        })
      )
      self.scene:set(
        'current',
        CodeComponent({
          config = {
            elements = utils.object.assign({
              header = true,
              footer = false,
              line_number = true,
            }, self.config.elements),
            win_options = {
              cursorbind = true,
              scrollbind = true,
              cursorline = true,
            },
            win_plot = dimensions.relative_win_plot(self.plot, {
              height = '100vh',
              width = '51vw',
              row = '0vh',
              col = '49vw',
            }),
          },
        })
      )
    end,
  })[self.layout_type]()

  return self
end

function CodeView:trigger_keypress(key, ...)
  self.scene:trigger_keypress(key, ...)

  return self
end

function CodeView:set_title(title)
  if not title then
    return self
  end

  self.title = title

  return self
end

function CodeView:set_keymap(configs)
  if self.layout_type == 'split' then
    utils.list.each(configs, function(config)
      self.scene
        :get('previous')
        :set_keymap(config.mode, config.key, config.vgit_key, config.handler)
    end)
  end

  utils.list.each(configs, function(config)
    self.scene
      :get('current')
      :set_keymap(config.mode, config.key, config.vgit_key, config.handler)
  end)

  return self
end

function CodeView:paint_word(component_type, line_changes, lnum)
  local lnum_change = line_changes.lnum_change

  if not lnum_change then
    return self
  end

  local texts = {}
  local change_type = lnum_change.type
  local word_diff = lnum_change.word_diff
  local component = self.scene:get(component_type)

  if word_diff then
    local offset = 0
    local num_word_diff = #word_diff

    for j = 1, num_word_diff do
      local segment = word_diff[j]
      local operation, fragment = unpack(segment)

      if operation == -1 then
        local hl = change_type == 'remove' and 'GitWordDelete' or 'GitWordAdd'
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

  return self
end

function CodeView:paint_line(component_type, line_changes, lnum)
  local line_number_hl = 'GitLineNr'
  local lnum_change = line_changes.lnum_change
  local line_number = line_changes.line_number
  local signs_usage_setting = signs_setting:get('usage')
  local scene_signs = signs_usage_setting.scene
  local main_signs = signs_usage_setting.main
  local component = self.scene:get(component_type)

  if not lnum_change then
    component:transpose_virtual_line_number(
      line_number,
      line_number_hl,
      lnum - 1
    )
    return self
  end

  lnum = lnum_change.lnum
  local change_type = lnum_change.type
  local sign_name = scene_signs[change_type]

  if change_type ~= 'void' then
    line_number_hl = main_signs[change_type]
  end

  if sign_name then
    component:sign_place_line_number(lnum, sign_name)
  end

  component:transpose_virtual_line_number(line_number, line_number_hl, lnum - 1)

  if sign_name then
    component:sign_place(lnum, sign_name)
  end

  if change_type == 'void' then
    component:transpose_virtual_text(
      string.rep(symbols_setting:get('void'), component.window:get_width()),
      line_number_hl,
      lnum - 1,
      0
    )
  end

  return self
end

function CodeView:apply_paint_instructions(component_type, line_changes, lnum)
  return self
    :paint_line(component_type, line_changes, lnum)
    :paint_word(component_type, line_changes, lnum)
end

function CodeView:apply_brush(top, bot)
  local current_lines_changes = self.state.current_lines_changes
  local previous_lines_changes = self.state.previous_lines_changes

  for i = top, bot do
    if
      self.layout_type == 'split'
      and previous_lines_changes
      and previous_lines_changes[i]
    then
      self:apply_paint_instructions('previous', previous_lines_changes[i], i)
    end

    if current_lines_changes and current_lines_changes[i] then
      self:apply_paint_instructions('current', current_lines_changes[i], i)
    end
  end

  return self
end

function CodeView:paint_partially()
  self.scene:get('current'):attach_to_renderer(function(top, bot)
    self:apply_brush(top, bot)
  end)

  return self
end

function CodeView:paint_full()
  return self:apply_brush(1, #self.state.current_lines_changes)
end

function CodeView:reset_cursor()
  if self.layout_type == 'split' then
    self.scene:get('previous'):reset_cursor()
  end

  self.scene:get('current'):reset_cursor()

  return self
end

function CodeView:clear_title()
  local header_component = self.scene:get('header')

  if header_component then
    header_component:clear_title()
    return self
  end

  if self.layout_type == 'split' then
    self.scene:get('previous'):clear_title()
  else
    self.scene:get('current'):clear_title()
  end

  return self
end

function CodeView:clear_namespace()
  if self.layout_type == 'split' then
    self.scene:get('previous'):clear_namespace()
  end

  self.scene:get('current'):clear_namespace()

  local header_component = self.scene:get('header')

  if header_component then
    header_component:clear_namespace()

    return self
  end

  return self
end

function CodeView:clear_lines()
  if self.layout_type == 'split' then
    self.scene:get('previous'):clear_lines():disable_cursorline()
  end

  self.scene:get('current'):clear_lines():disable_cursorline()

  return self
end

function CodeView:clear_notification()
  local header_component = self.scene:get('header')

  if header_component then
    header_component:clear_notification()
    return self
  end

  if self.layout_type == 'split' then
    self.scene:get('previous'):clear_notification()
  end

  self.scene:get('current'):clear_notification()

  return self
end

function CodeView:make_title()
  local filename_err, filename = self.query:get_filename()

  if filename_err then
    console.debug.error(filename_err)
    return self
  end

  local filetype_err, filetype = self.query:get_filetype()

  if filetype_err then
    console.debug.error(filetype_err)
    return self
  end

  local diff_dto_err, diff_dto = self.query:get_diff_dto()

  if diff_dto_err then
    console.debug.error(diff_dto_err)
    return self
  end

  local options = {
    filename = filename,
    filetype = filetype,
    stat = diff_dto.stat,
  }

  local title = self.title
  local header_component = self.scene:get('header')

  if header_component then
    header_component:set_title(title, options)
    return self
  end

  if self.layout_type == 'split' then
    self.scene:get('previous'):set_title(title, options)
  else
    self.scene:get('current'):set_title(title, options)
  end

  return self
end

function CodeView:make_filetype()
  local err, filetype = self.query:get_filetype()

  if err then
    console.debug.error(err)
    return self
  end

  local current_component = self.scene:get('current')

  if current_component:get_filetype() == filetype then
    return self
  end

  if self.layout_type == 'split' then
    self.scene:get('previous'):set_filetype(filetype)
  end

  current_component:set_filetype(filetype)

  return self
end

function CodeView:make_split_current_line_numbers(
  diff_dto,
  current_lnum_change_map
)
  local current_lines_changes = {}
  local current_lines = {}
  local current_line_count = 1
  local num_current_lines = #diff_dto.current_lines

  for i = 1, num_current_lines do
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
      current_lines[#current_lines + 1] = line
    else
      line = string.format('%s ', current_line_count)
      current_lines[#current_lines + 1] = line
      current_line_count = current_line_count + 1
    end

    current_lines_changes[#current_lines_changes + 1] = {
      lnum_change = lnum_change,
      line_number = line,
    }
  end

  self.state.current_lines_changes = current_lines_changes

  self.scene:get('current'):make_line_numbers(current_lines)

  return self
end

function CodeView:make_split_previous_line_numbers(
  diff_dto,
  previous_lnum_change_map
)
  local previous_lines = {}
  local previous_lines_changes = {}
  local previous_lines_count = 1
  local num_previous_lines = #diff_dto.previous_lines

  for i = 1, num_previous_lines do
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
      previous_lines[#previous_lines + 1] = line
    else
      line = string.format('%s ', previous_lines_count)
      previous_lines[#previous_lines + 1] = line
      previous_lines_count = previous_lines_count + 1
    end

    previous_lines_changes[#previous_lines_changes + 1] = {
      lnum_change = lnum_change,
      line_number = line,
    }
  end

  self.state.previous_lines_changes = previous_lines_changes
  self.scene:get('previous'):make_line_numbers(previous_lines)

  return self
end

function CodeView:make_split_line_numbers()
  local err, diff_dto = self.query:get_diff_dto()

  if err then
    console.debug.error(err)
    return self
  end

  local current_lnum_change_map = {}
  local previous_lnum_change_map = {}
  local num_lnum_changes = #diff_dto.lnum_changes

  for i = 1, num_lnum_changes do
    local lnum_change = diff_dto.lnum_changes[i]

    if lnum_change.buftype == 'current' then
      current_lnum_change_map[lnum_change.lnum] = lnum_change
    elseif lnum_change.buftype == 'previous' then
      previous_lnum_change_map[lnum_change.lnum] = lnum_change
    end
  end

  return self
    :make_split_current_line_numbers(diff_dto, current_lnum_change_map)
    :make_split_previous_line_numbers(diff_dto, previous_lnum_change_map)
end

function CodeView:make_unified_line_numbers()
  local err, diff_dto = self.query:get_diff_dto()

  if err then
    console.debug.error(err)
    return self
  end

  local lines_changes = {}
  local lines = {}
  local line_count = 1
  local lnum_change_map = {}
  local num_lnum_changes = #diff_dto.lnum_changes
  local num_lines = #diff_dto.lines

  for i = 1, num_lnum_changes do
    local lnum_change = diff_dto.lnum_changes[i]
    lnum_change_map[lnum_change.lnum] = lnum_change
  end

  for i = 1, num_lines do
    local line = ''
    local lnum_change = lnum_change_map[i]

    if lnum_change and lnum_change.type == 'remove' then
      lines[#lines + 1] = line
    else
      line = string.format('%s ', line_count)
      lines[#lines + 1] = line
      line_count = line_count + 1
    end

    lines_changes[#lines_changes + 1] = {
      lnum_change = lnum_change,
      line_number = line,
    }
  end

  self.scene:get('current'):make_line_numbers(lines)

  self.state.current_lines_changes = lines_changes

  return self
end

function CodeView:make_line_numbers()
  local layout_type = self.layout_type

  if layout_type == 'split' then
    self:make_split_line_numbers()
  elseif layout_type == 'unified' then
    self:make_unified_line_numbers()
  end

  return self
end

function CodeView:make_lines()
  local diff_dto_err, diff_dto = self.query:get_diff_dto()
  if diff_dto_err then
    console.debug.error(diff_dto_err)
    return self
  end

  if self.layout_type == 'unified' then
    self.scene:get('current'):set_lines(diff_dto.lines):enable_cursorline()
  else
    self.scene
      :get('previous')
      :set_lines(diff_dto.previous_lines)
      :enable_cursorline()
    self.scene
      :get('current')
      :set_lines(diff_dto.current_lines)
      :enable_cursorline()
  end

  return self
end

function CodeView:paint()
  if not self.state.is_painted then
    self.state.is_painted = true

    return self:paint_full()
  end

  return self:paint_partially()
end

function CodeView:notify(msg)
  local layout_type = self.layout_type
  local header_component = self.scene:get('header')

  if header_component then
    header_component:notify(msg)
    return self
  end

  if layout_type == 'split' then
    self.scene:get('previous'):notify(msg)
  elseif layout_type == 'unified' then
    self.scene:get('current'):notify(msg)
  end

  return self
end

function CodeView:get_current_mark_under_cursor()
  local err, diff_dto = self.query:get_diff_dto()

  if err then
    console.debug.error(err)
    return nil
  end

  local marks = diff_dto.marks
  local lnum = self.scene:get('current'):get_lnum()

  for i = 1, #marks do
    local mark = marks[i]

    if lnum >= mark.top and lnum <= mark.bot then
      return mark, i
    end
  end

  return nil, nil
end

function CodeView:get_current_hunk_under_cursor()
  local err, diff_dto = self.query:get_diff_dto()

  if err then
    console.debug.error(err)
    return nil
  end

  local selected
  local marks = diff_dto.marks
  local hunks = diff_dto.hunks
  local lnum = self.scene:get('current'):get_lnum()

  for i = 1, #marks do
    local mark = marks[i]

    if lnum >= mark.top and lnum <= mark.bot then
      selected = i
      break
    end
  end

  if selected then
    return hunks[selected], selected
  end

  return nil, nil
end

function CodeView:select_mark(marks, mark_index, position)
  local lnum = nil
  local mark = marks[mark_index]

  if mark then
    lnum = mark.top
  end

  if not lnum then
    if marks and marks[#marks] and marks[#marks].top then
      lnum = marks[#marks].top
      mark_index = #marks
    else
      lnum = 1
      mark_index = 1
    end
  end

  if self.layout_type == 'split' then
    self.scene:get('previous'):set_lnum(lnum):position_cursor(position)
  end

  -- NOTE: Current must always be set after previous.
  self.scene:get('current'):set_lnum(lnum):position_cursor(position)

  return self
end

function CodeView:prev(pos)
  local err, diff_dto = self.query:get_diff_dto()

  if err then
    console.debug.error(err)
    return self
  end

  local marks = diff_dto.marks
  local lnum = self.scene:get('current'):get_lnum()
  local mark_index = #marks

  for i = #marks, 1, -1 do
    local mark = marks[i]

    if lnum >= mark.top and lnum <= mark.bot then
      mark_index = i - 1
      break
    elseif mark.top < lnum then
      mark_index = i
      break
    end
  end

  return self:navigate_to_mark(mark_index, pos)
end

function CodeView:next(pos)
  local err, diff_dto = self.query:get_diff_dto()

  if err then
    console.debug.error(err)
    return self
  end

  local marks = diff_dto.marks
  local lnum = self.scene:get('current'):get_lnum()
  local mark_index = 1
  local num_marks = #marks

  for i = 1, num_marks do
    local mark = marks[i]

    if lnum >= mark.top and lnum <= mark.bot then
      mark_index = i + 1
      break
    elseif mark.top > lnum then
      mark_index = i
      break
    end
  end

  return self:navigate_to_mark(mark_index, pos)
end

function CodeView:get_relative_mark_index(parent_lnum)
  local err, diff_dto = self.query:get_diff_dto()

  if err then
    console.debug.error(err)
    return 1
  end

  local marks = diff_dto.marks
  local mark_index = 1

  for i = 1, #marks do
    local mark = marks[i]

    if
      parent_lnum >= mark.top_relative and parent_lnum <= mark.bot_relative
    then
      mark_index = i
      break
    end
  end

  return mark_index
end

function CodeView:navigate_to_mark(mark_index, pos)
  if not pos then
    pos = 'top'
  end

  if not mark_index then
    mark_index = 1
  end

  local err, diff_dto = self.query:get_diff_dto()

  if err then
    console.debug.error(err)
    return self
  end

  local marks = diff_dto.marks
  if #marks == 0 then
    self:notify('No changes found')

    return self
  end

  if mark_index < 1 then
    mark_index = #marks
  elseif mark_index > #marks then
    mark_index = 1
  end

  return self:select_mark(marks, mark_index, pos):notify(
    string.format('%s%s/%s Changes', string.rep(' ', 1), mark_index, #marks)
  )
end

function CodeView:render()
  -- NOTE: important to clear the namespace first.
  loop.await_fast_event(5)
  self:clear_namespace()
  loop.await_fast_event(5)

  local err, _ = self.query:get_diff_dto()

  if err then
    console.debug.error(err)

    self.state = CodeView:get_initial_state()

    return self:clear_title():clear_lines():clear_notification():reset_cursor()
  end

  -- NOTE: It is super important to reset the cursor or else
  -- you will randomly see line numbers not aligning with the current view.
  return self
    :reset_cursor()
    :make_title()
    :make_filetype()
    :make_lines()
    :make_line_numbers()
    :paint()
end

CodeView.render_debounced = loop.debounced_async(function(self, callback)
  self:render()
  if callback then
    callback()
  end
end, 100)

function CodeView:mount_scene(mount_opts)
  if self.layout_type == 'split' then
    self.scene:get('previous'):mount(mount_opts)
  end

  self.scene:get('current'):mount(mount_opts)

  return self
end

function CodeView:show(layout_type, pos, mount_opts)
  mount_opts = mount_opts or {}
  self.layout_type = layout_type
  self.state = CodeView:get_initial_state()

  local mark_index = 1
  local is_relative_to_parent = mount_opts.winline ~= nil

  if is_relative_to_parent then
    mark_index = self:get_relative_mark_index(Window(0):get_lnum())
  end

  self
    :define()
    :mount_scene(mount_opts)
    :render()
    :navigate_to_mark(mark_index, pos)

  return self
end

return CodeView
