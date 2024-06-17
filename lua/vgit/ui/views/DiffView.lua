local loop = require('vgit.core.loop')
local utils = require('vgit.core.utils')
local Object = require('vgit.core.Object')
local console = require('vgit.core.console')
local dimensions = require('vgit.ui.dimensions')
local signs_setting = require('vgit.settings.signs')
local symbols_setting = require('vgit.settings.symbols')
local DiffComponent = require('vgit.ui.components.DiffComponent')

local DiffView = Object:extend()

function DiffView:get_initial_state()
  return {
    current_lines_changes = {},
    previous_lines_changes = {},
  }
end

function DiffView:constructor(scene, store, plot, config, layout_type)
  return {
    title = 'Diff',
    scene = scene,
    store = store,
    plot = plot,
    config = config or {},
    layout_type = layout_type,
    state = DiffView:get_initial_state(),
  }
end

function DiffView:define()
  if self.layout_type == 'unified' then
    self.scene:set(
      'current',
      DiffComponent({
        config = {
          elements = utils.object.assign({
            header = true,
            footer = false,
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
  end

  if self.layout_type == 'split' then
    self.scene:set(
      'previous',
      DiffComponent({
        config = {
          elements = utils.object.assign({
            header = true,
            footer = false,
          }, self.config.elements),
          win_options = {
            cursorbind = true,
            scrollbind = true,
            cursorline = true,
          },
          win_plot = dimensions.relative_win_plot(self.plot, {
            height = '100vh',
            width = '50vw',
          }),
        },
      })
    )
    self.scene:set(
      'current',
      DiffComponent({
        config = {
          elements = utils.object.assign({
            header = true,
            footer = false,
          }, self.config.elements),
          win_options = {
            cursorbind = true,
            scrollbind = true,
            cursorline = true,
          },
          win_plot = dimensions.relative_win_plot(self.plot, {
            height = '100vh',
            width = '50vw',
            col = '50vw',
            zindex = 4,
          }),
        },
      })
    )
  end

  return self
end

function DiffView:get_components()
  if self.layout_type == 'split' then return { self.scene:get('previous'), self.scene:get('current') } end

  return { self.scene:get('current') }
end

function DiffView:set_title(title)
  if not title then return self end

  self.title = title

  return self
end

function DiffView:set_keymap(configs)
  if self.layout_type == 'split' then
    utils.list.each(configs, function(config)
      self.scene:get('previous'):set_keymap(config.mode, config.key, config.handler)
    end)
  end

  utils.list.each(configs, function(config)
    self.scene:get('current'):set_keymap(config.mode, config.key, config.handler)
  end)

  return self
end

function DiffView:paint_word(component_type, line_changes, lnum)
  local lnum_change = line_changes.lnum_change

  if not lnum_change then return self end

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

      if operation == 0 or operation == -1 then offset = offset + #fragment end
    end

    component:transpose_virtual_line({
      texts = texts,
      row = lnum - 1,
    })
  end

  return self
end

function DiffView:paint_line(component_type, line_changes, lnum)
  local line_number_hl = 'GitLineNr'
  local lnum_change = line_changes.lnum_change
  local signs_usage_setting = signs_setting:get('usage')
  local scene_signs = signs_usage_setting.scene
  local main_signs = signs_usage_setting.main
  local component = self.scene:get(component_type)

  if not lnum_change then return self end

  lnum = lnum_change.lnum
  local change_type = lnum_change.type
  local sign_name = scene_signs[change_type]

  if change_type ~= 'void' then line_number_hl = main_signs[change_type] end

  if sign_name then component:sign_place(lnum, sign_name) end

  if change_type == 'void' then
    component:transpose_virtual_text({
      text = string.rep(symbols_setting:get('void'), component.window:get_width()),
      hl = line_number_hl,
      row = lnum - 1,
      col = 0,
    })
  end

  return self
end

function DiffView:apply_paint_instructions(component_type, line_changes, lnum)
  return self:paint_line(component_type, line_changes, lnum):paint_word(component_type, line_changes, lnum)
end

function DiffView:apply_brush(top, bot)
  local current_lines_changes = self.state.current_lines_changes
  local previous_lines_changes = self.state.previous_lines_changes

  for i = top, bot do
    if self.layout_type == 'split' and previous_lines_changes and previous_lines_changes[i] then
      self:apply_paint_instructions('previous', previous_lines_changes[i], i)
    end

    if current_lines_changes and current_lines_changes[i] then
      self:apply_paint_instructions('current', current_lines_changes[i], i)
    end
  end

  return self
end

function DiffView:paint()
  return self:apply_brush(1, #self.state.current_lines_changes)
end

function DiffView:reset_cursor()
  if self.layout_type == 'split' then self.scene:get('previous'):reset_cursor() end

  self.scene:get('current'):reset_cursor()

  return self
end

function DiffView:clear_title()
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

function DiffView:clear_namespace()
  if self.layout_type == 'split' then self.scene:get('previous'):clear_namespace() end

  self.scene:get('current'):clear_namespace()

  local header_component = self.scene:get('header')

  if header_component then
    header_component:clear_namespace()

    return self
  end

  return self
end

function DiffView:clear_lines()
  if self.layout_type == 'split' then self.scene:get('previous'):clear_lines():disable_cursorline() end

  self.scene:get('current'):clear_lines():disable_cursorline()

  return self
end

function DiffView:clear_notification()
  local header_component = self.scene:get('header')

  if header_component then
    header_component:clear_notification()
    return self
  end

  if self.layout_type == 'split' then self.scene:get('previous'):clear_notification() end

  self.scene:get('current'):clear_notification()

  return self
end

function DiffView:render_title()
  local filename, filename_err = self.store:get_filename()
  if filename_err then
    console.debug.error(filename_err)
    return self
  end

  local filetype, filetype_err = self.store:get_filetype()
  if filetype_err then
    console.debug.error(filetype_err)
    return self
  end

  local diff, diff_err = self.store:get_diff()
  if diff_err then
    console.debug.error(diff_err)
    return self
  end

  local options = {
    filename = filename,
    filetype = filetype,
    stat = diff.stat,
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

function DiffView:render_filetype()
  local filetype, err = self.store:get_filetype()
  if err then
    console.debug.error(err)
    return self
  end

  local current_component = self.scene:get('current')

  if current_component:get_filetype() == filetype then return self end

  if self.layout_type == 'split' then self.scene:get('previous'):set_filetype(filetype) end

  current_component:set_filetype(filetype)

  return self
end

function DiffView:render_split_current_line_numbers(diff, lnum_change_map)
  local lines = {}
  local line_count = 1
  local lines_changes = {}
  local num_lines = #diff.current_lines

  for i = 1, num_lines do
    local line
    local lnum_change = lnum_change_map[i]

    if lnum_change and lnum_change.type == 'void' then
      line = string.rep(symbols_setting:get('void'), string.len(tostring(num_lines)))
      lines[#lines + 1] = { line, 'GitLineNr' }
    elseif lnum_change and lnum_change.type == 'add' then
      line = string.format('%s ', line_count)
      lines[#lines + 1] = { line, 'GitSignsAdd' }
      line_count = line_count + 1
    elseif lnum_change and lnum_change.type == 'remove' then
      line = string.format('%s ', line_count)
      lines[#lines + 1] = { line, 'GitSignsDelete' }
      line_count = line_count + 1
    else
      line = string.format('%s ', line_count)
      lines[#lines + 1] = { line, 'GitLineNr' }
      line_count = line_count + 1
    end

    lines_changes[#lines_changes + 1] = {
      line_number = line,
      lnum_change = lnum_change,
    }
  end

  self.state.current_lines_changes = lines_changes

  self.scene:get('current'):render_line_numbers(lines)

  return self
end

function DiffView:render_split_previous_line_numbers(diff, lnum_change_map)
  local lines = {}
  local line_count = 1
  local lines_changes = {}
  local num_lines = #diff.previous_lines

  for i = 1, num_lines do
    local line
    local lnum_change = lnum_change_map[i]

    if lnum_change and lnum_change.type == 'void' then
      line = string.rep(symbols_setting:get('void'), string.len(tostring(num_lines)))
      lines[#lines + 1] = { line, 'GitLineNr' }
    elseif lnum_change and lnum_change.type == 'add' then
      line = string.format('%s ', line_count)
      lines[#lines + 1] = { line, 'GitSignsAdd' }
      line_count = line_count + 1
    elseif lnum_change and lnum_change.type == 'remove' then
      line = string.format('%s ', line_count)
      lines[#lines + 1] = { line, 'GitSignsDelete' }
      line_count = line_count + 1
    else
      line = string.format('%s ', line_count)
      lines[#lines + 1] = { line, 'GitLineNr' }
      line_count = line_count + 1
    end

    lines_changes[#lines_changes + 1] = {
      line_number = line,
      lnum_change = lnum_change,
    }
  end

  self.state.previous_lines_changes = lines_changes
  self.scene:get('previous'):render_line_numbers(lines)

  return self
end

function DiffView:render_split_line_numbers()
  local diff, err = self.store:get_diff()
  if err then
    console.debug.error(err)
    return self
  end

  local current_lnum_change_map = {}
  local previous_lnum_change_map = {}
  local num_lnum_changes = #diff.lnum_changes

  for i = 1, num_lnum_changes do
    local lnum_change = diff.lnum_changes[i]

    if lnum_change.buftype == 'current' then
      current_lnum_change_map[lnum_change.lnum] = lnum_change
    elseif lnum_change.buftype == 'previous' then
      previous_lnum_change_map[lnum_change.lnum] = lnum_change
    end
  end

  return self
    :render_split_previous_line_numbers(diff, previous_lnum_change_map)
    :render_split_current_line_numbers(diff, current_lnum_change_map)
end

function DiffView:render_unified_line_numbers()
  local diff, err = self.store:get_diff()
  if err then
    console.debug.error(err)
    return self
  end

  local lines_changes = {}
  local lines = {}
  local line_count = 1
  local lnum_change_map = {}
  local num_lines = #diff.lines
  local num_lnum_changes = #diff.lnum_changes

  for i = 1, num_lnum_changes do
    local lnum_change = diff.lnum_changes[i]
    lnum_change_map[lnum_change.lnum] = lnum_change
  end

  for i = 1, num_lines do
    local line = ''
    local lnum_change = lnum_change_map[i]

    if lnum_change and lnum_change.type == 'remove' then
      line = '  '
      lines[#lines + 1] = { line, 'GitSignsDelete' }
    elseif lnum_change and lnum_change.type == 'add' then
      line = string.format('%s ', line_count)
      lines[#lines + 1] = { line, 'GitSignsAdd' }
      line_count = line_count + 1
    else
      line = string.format('%s ', line_count)
      lines[#lines + 1] = { line, 'GitLineNr' }
      line_count = line_count + 1
    end

    lines_changes[#lines_changes + 1] = {
      line_number = line,
      lnum_change = lnum_change,
    }
  end

  self.scene:get('current'):render_line_numbers(lines)

  self.state.current_lines_changes = lines_changes

  return self
end

function DiffView:render_line_numbers()
  local layout_type = self.layout_type

  if layout_type == 'split' then
    self:render_split_line_numbers()
  elseif layout_type == 'unified' then
    self:render_unified_line_numbers()
  end

  return self
end

function DiffView:render_lines()
  local diff, diff_err = self.store:get_diff()
  if diff_err then
    console.debug.error(diff_err)
    return self
  end

  if self.layout_type == 'unified' then
    self.scene:get('current'):set_lines(diff.lines):enable_cursorline()
  else
    self.scene:get('previous'):set_lines(diff.previous_lines):enable_cursorline()
    self.scene:get('current'):set_lines(diff.current_lines):enable_cursorline()
  end

  return self
end

function DiffView:notify(msg)
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

function DiffView:get_current_mark_under_cursor()
  local diff, err = self.store:get_diff()
  if err then
    console.debug.error(err)
    return nil
  end

  local marks = diff.marks
  local lnum = self.scene:get('current'):get_lnum()

  for i = 1, #marks do
    local mark = marks[i]

    if lnum >= mark.top and lnum <= mark.bot then return mark, i end
  end
end

function DiffView:get_current_hunk_under_cursor()
  local diff, err = self.store:get_diff()
  if err then
    console.debug.error(err)
    return nil
  end

  local selected
  local marks = diff.marks
  local hunks = diff.hunks
  local lnum = self.scene:get('current'):get_lnum()

  for i = 1, #marks do
    local mark = marks[i]

    if lnum >= mark.top and lnum <= mark.bot then
      selected = i
      break
    end
  end

  if selected then return hunks[selected], selected end
end

function DiffView:set_lnum(lnum, position)
  if self.layout_type == 'split' then self.scene:get('previous'):set_lnum(lnum):position_cursor(position) end

  -- NOTE: Current must always be set after previous.
  self.scene:get('current'):set_lnum(lnum):position_cursor(position)

  return self
end

function DiffView:set_relative_lnum(lnum, position)
  local diff, err = self.store:get_diff()
  if err then return self end

  for i = 1, #diff.lnum_changes do
    local lnum_change = diff.lnum_changes[i]
    local l = lnum_change.lnum
    local type = lnum_change.type
    local buftype = lnum_change.buftype

    if buftype == 'current' and (type == 'void' or type == 'remove') and lnum >= l then lnum = lnum + 1 end
  end

  self:set_lnum(lnum, position)

  return self
end

function DiffView:select_mark(marks, mark_index, position)
  local lnum = nil
  local mark = marks[mark_index]

  if mark then lnum = mark.top end

  if not lnum then
    if marks and marks[#marks] and marks[#marks].top then
      lnum = marks[#marks].top
      mark_index = #marks
    else
      lnum = 1
      mark_index = 1
    end
  end

  self:set_lnum(lnum, position)

  return self
end

function DiffView:prev(pos)
  local diff, err = self.store:get_diff()
  if err then
    console.debug.error(err)
    return self
  end

  local marks = diff.marks
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

function DiffView:next(pos)
  local diff, err = self.store:get_diff()
  if err then
    console.debug.error(err)
    return self
  end

  local marks = diff.marks
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

function DiffView:get_relative_mark_index(lnum)
  local diff, err = self.store:get_diff()
  if err then
    console.debug.error(err)
    return 1
  end

  local marks = diff.marks
  local mark_index = 1

  for i = 1, #marks do
    local mark = marks[i]

    if lnum >= mark.top_relative and lnum <= mark.bot_relative then
      mark_index = i
      break
    end
  end

  return mark_index
end

function DiffView:navigate_to_mark(mark_index, pos)
  if not pos then pos = 'top' end

  if not mark_index then mark_index = 1 end

  local diff, err = self.store:get_diff()
  if err then
    console.debug.error(err)
    return self
  end

  local marks = diff.marks
  if #marks == 0 then
    self:notify('No changes found')

    return self
  end

  if mark_index < 1 then
    mark_index = #marks
  elseif mark_index > #marks then
    mark_index = 1
  end

  return self
    :select_mark(marks, mark_index, pos)
    :notify(string.format('%s%s/%s Changes', string.rep(' ', 1), mark_index, #marks))
end

function DiffView:render()
  local ok, msg = pcall(function()
    loop.free_textlock()
    self:clear_namespace()

    local _, err = self.store:get_diff()
    if err then
      loop.free_textlock()
      console.debug.error(err)

      self.state = DiffView:get_initial_state()

      return self:clear_title():clear_lines():clear_notification():reset_cursor()
    end

    return self:reset_cursor():render_title():render_filetype():render_lines():render_line_numbers():paint()
  end)

  if not ok then console.debug.error(msg) end
  return self
end

DiffView.render_debounced = loop.debounce_coroutine(function(self, callback)
  self:render()
  if callback then callback() end
end, 100)

function DiffView:mount()
  if self.layout_type == 'split' then self.scene:get('previous'):mount() end

  self.scene:get('current'):mount()

  return self
end

function DiffView:show()
  self.state = DiffView:get_initial_state()
  self:mount():render():navigate_to_mark(1)

  return self
end

return DiffView
