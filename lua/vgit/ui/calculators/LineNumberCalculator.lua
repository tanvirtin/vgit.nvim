local Object = require('vgit.core.Object')
local symbols_setting = require('vgit.settings.symbols')

local LineNumberCalculator = Object:extend()

function LineNumberCalculator:constructor()
  return {}
end

function LineNumberCalculator:_calculate_line_numbers(lines, lnum_change_map, line_count_start)
  local lines_result = {}
  local lines_changes = {}
  local num_lines = #lines
  local line_count = line_count_start or 1

  for i = 1, num_lines do
    local line
    local lnum_change = lnum_change_map[i]

    if lnum_change and lnum_change.type == 'void' then
      line = string.rep(symbols_setting:get('void'), string.len(tostring(num_lines)))
      lines_result[#lines_result + 1] = { line, 'GitLineNr' }
    elseif lnum_change and lnum_change.type == 'add' then
      line = string.format('%s ', line_count)
      lines_result[#lines_result + 1] = { line, 'GitSignsAdd' }
      line_count = line_count + 1
    elseif lnum_change and lnum_change.type == 'remove' then
      line = string.format('%s ', line_count)
      lines_result[#lines_result + 1] = { line, 'GitSignsDelete' }
      line_count = line_count + 1
    else
      line = string.format('%s ', line_count)
      lines_result[#lines_result + 1] = { line, 'GitLineNr' }
      line_count = line_count + 1
    end

    lines_changes[#lines_changes + 1] = {
      line_number = line,
      lnum_change = lnum_change,
    }
  end

  return lines_result, lines_changes
end

function LineNumberCalculator:calculate_unified_line_numbers(diff)
  local lines = {}
  local line_count = 1
  local lines_changes = {}
  local lnum_change_map = {}

  for i = 1, #diff.lnum_changes do
    local lnum_change = diff.lnum_changes[i]
    lnum_change_map[lnum_change.lnum] = lnum_change
  end

  for i = 1, #diff.lines do
    local lnum_change = lnum_change_map[i]
    local line

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

  return lines, lines_changes
end

function LineNumberCalculator:calculate_split_current_line_numbers(diff, lnum_change_map)
  return self:_calculate_line_numbers(diff.current_lines, lnum_change_map, 1)
end

function LineNumberCalculator:calculate_split_previous_line_numbers(diff, lnum_change_map)
  return self:_calculate_line_numbers(diff.previous_lines, lnum_change_map, 1)
end

function LineNumberCalculator:calculate_split_line_numbers(diff)
  local current_lnum_change_map = {}
  local previous_lnum_change_map = {}

  for i = 1, #diff.lnum_changes do
    local lnum_change = diff.lnum_changes[i]

    if lnum_change.buftype == 'current' then
      current_lnum_change_map[lnum_change.lnum] = lnum_change
    elseif lnum_change.buftype == 'previous' then
      previous_lnum_change_map[lnum_change.lnum] = lnum_change
    end
  end

  local previous_lines, previous_changes = self:calculate_split_previous_line_numbers(diff, previous_lnum_change_map)
  local current_lines, current_changes = self:calculate_split_current_line_numbers(diff, current_lnum_change_map)

  return {
    previous = { lines = previous_lines, changes = previous_changes },
    current = { lines = current_lines, changes = current_changes },
  }
end

return LineNumberCalculator
