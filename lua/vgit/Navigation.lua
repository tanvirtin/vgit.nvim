local Object = require('vgit.core.Object')

local Navigation = Object:extend()

function Navigation:new()
  return setmetatable({}, Navigation)
end

function Navigation:mark_select(component, selected, marks, position)
  local position_window = function()
    if position == 'top' then
      vim.cmd('norm! zt')
    elseif position == 'center' then
      vim.cmd('norm! zz')
    elseif position == 'bottom' then
      vim.cmd('norm! zb')
    end
  end
  local line_count = component:get_line_count()
  local new_lnum = nil
  local mark_index = 0
  for i = #marks, 1, -1 do
    local mark = marks[i]
    if i == selected then
      new_lnum = mark.start
      mark_index = i
      break
    end
  end
  if not new_lnum or new_lnum < 1 or new_lnum > line_count then
    if marks and marks[#marks] and marks[#marks].start then
      new_lnum = marks[#marks].start
      mark_index = #marks
    else
      new_lnum = 1
      mark_index = 1
    end
  end
  if new_lnum then
    component:set_lnum(new_lnum)
    component:call(position_window)
    return mark_index
  else
    local start_hunks_lnum = marks[#marks].start
    start_hunks_lnum = start_hunks_lnum
        and (start_hunks_lnum >= 1 or new_lnum <= line_count)
        and start_hunks_lnum
      or 1
    mark_index = start_hunks_lnum
        and (start_hunks_lnum >= 1 or new_lnum <= line_count)
        and #marks
      or 1
    component:set_lnum(start_hunks_lnum)
    component:call(position_window)
    return mark_index
  end
end

function Navigation:mark_up(window, buffer, marks)
  local lnum = window:get_lnum()
  local line_count = buffer:get_line_count()
  local new_lnum = nil
  local mark_index = 0
  for i = #marks, 1, -1 do
    local mark = marks[i]
    if mark.finish < lnum then
      new_lnum = mark.finish
      mark_index = i
      break
    elseif lnum > mark.start then
      new_lnum = mark.start
      mark_index = i
      break
    end
  end
  if not new_lnum or new_lnum < 1 or new_lnum > line_count then
    if marks and marks[#marks] and marks[#marks].finish then
      new_lnum = marks[#marks].finish
      mark_index = #marks
    else
      new_lnum = 1
      mark_index = 1
    end
  end
  if new_lnum and lnum ~= new_lnum then
    window:set_lnum(new_lnum):call(function()
      vim.cmd('norm! zz')
    end)
    return mark_index
  else
    local finish_hunks_lnum = marks[#marks].finish
    finish_hunks_lnum = finish_hunks_lnum
        and (finish_hunks_lnum >= 1 or new_lnum <= line_count)
        and finish_hunks_lnum
      or 1
    mark_index = finish_hunks_lnum
        and (finish_hunks_lnum >= 1 or new_lnum <= line_count)
        and #marks
      or 1
    window:set_lnum(finish_hunks_lnum):call(function()
      vim.cmd('norm! zz')
    end)
    return mark_index
  end
end

function Navigation:mark_down(window, buffer, marks)
  local lnum = window:get_lnum()
  local line_count = buffer:get_line_count()
  local new_lnum = nil
  local selected_mark = nil
  local mark_index = 0
  for i = 1, #marks do
    local mark = marks[i]
    local compare_lnum = lnum
    if mark.start > compare_lnum then
      new_lnum = mark.start
      mark_index = i
      break
    elseif compare_lnum < mark.finish then
      new_lnum = mark.finish
      mark_index = i
      break
    elseif compare_lnum == mark.finish and compare_lnum == line_count then
      new_lnum = mark.finish
      mark_index = i
      break
    end
  end
  if not new_lnum or new_lnum < 1 or new_lnum > line_count then
    if marks and marks[1] and marks[1].start then
      new_lnum = marks[1].start
      mark_index = 1
    else
      new_lnum = 1
      mark_index = 1
    end
  end
  local compare_lnum = lnum
  if selected_mark and selected_mark.type == 'remove' then
    compare_lnum = compare_lnum + 1
  end
  if new_lnum and compare_lnum ~= new_lnum then
    window:set_lnum(new_lnum):call(function()
      vim.cmd('norm! zz')
    end)
    return mark_index
  else
    local first_hunk_start_lnum = marks[1].start
    first_hunk_start_lnum = first_hunk_start_lnum
        and (first_hunk_start_lnum >= 1 and new_lnum <= line_count)
        and first_hunk_start_lnum
      or 1
    mark_index = first_hunk_start_lnum
        and (first_hunk_start_lnum >= 1 or new_lnum <= line_count)
        and 1
      or 1
    window:set_lnum(first_hunk_start_lnum):call(function()
      vim.cmd('norm! zz')
    end)
    return mark_index
  end
end

function Navigation:hunk_up(window, hunks)
  local lnum = window:get_lnum()
  local new_lnum = nil
  local selected = nil
  for i = #hunks, 1, -1 do
    local hunk = hunks[i]
    if hunk.finish < lnum then
      new_lnum = hunk.finish
      selected = i
      break
    elseif lnum > hunk.start then
      new_lnum = hunk.start
      selected = i
      break
    end
  end
  if new_lnum and new_lnum < 1 then
    new_lnum = 1
  end
  if new_lnum and lnum ~= new_lnum then
    window:set_lnum(new_lnum):call(function()
      vim.cmd('norm! zz')
    end)
    return selected
  else
    local finish_hunks_lnum = hunks[#hunks].finish
    selected = #hunks
    if finish_hunks_lnum < 1 then
      finish_hunks_lnum = 1
      selected = 1
    end
    window:set_lnum(finish_hunks_lnum):call(function()
      vim.cmd('norm! zz')
    end)
    return selected
  end
end

function Navigation:hunk_down(window, hunks)
  local lnum = window:get_lnum()
  local new_lnum = nil
  local selected = nil
  for i = 1, #hunks do
    local hunk = hunks[i]
    if hunk.start > lnum then
      new_lnum = hunk.start
      selected = i
      break
    elseif lnum < hunk.finish then
      new_lnum = hunk.finish
      selected = i
      break
    end
  end
  if new_lnum and new_lnum < 1 then
    new_lnum = 1
  end
  if new_lnum then
    window:set_lnum(new_lnum):call(function()
      vim.cmd('norm! zz')
    end)
    return selected
  else
    local first_hunk_start_lnum = hunks[1].start
    selected = 1
    if first_hunk_start_lnum < 1 then
      first_hunk_start_lnum = 1
      selected = 1
    end
    window:set_lnum(first_hunk_start_lnum):call(function()
      vim.cmd('norm! zz')
    end)
    return selected
  end
end

return Navigation
