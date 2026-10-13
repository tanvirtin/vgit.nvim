local lazy = require('vgit.core.lazy')

local Window = lazy('vgit.core.Window')
local fs = lazy('vgit.core.fs')
local hunks_setting = lazy('vgit.settings.hunks')
local live_gutter_setting = lazy('vgit.settings.live_gutter')

local navigation = {}

local VALID_HUNK_ALIGNMENTS = {
  center = true,
  top = true,
  bottom = true,
}

local function get_hunk_alignment()
  local alignment = hunks_setting:get('hunk_alignment')
  if not VALID_HUNK_ALIGNMENTS[alignment] then return 'top' end
  return alignment
end

local function get_hunk_alignment_offset()
  return hunks_setting:get('hunk_alignment_offset') or 0
end

local function jump_to(window, lnum)
  if lnum < 1 then lnum = 1 end
  window:set_lnum(lnum):scroll_to(get_hunk_alignment(), get_hunk_alignment_offset())
end

function navigation.up(window, marks)
  if #marks == 0 then return nil end

  local lnum = window:get_lnum()
  local is_edge_navigation = live_gutter_setting:get('edge_navigation')

  for i = #marks, 1, -1 do
    local mark = marks[i]

    if lnum > mark.bot then
      jump_to(window, mark.bot)
      return i
    elseif is_edge_navigation and lnum > mark.top then
      jump_to(window, mark.top)
      return i
    end
  end

  local mark = marks[#marks]
  jump_to(window, is_edge_navigation and mark.bot or mark.top)

  return #marks
end

function navigation.down(window, marks)
  if #marks == 0 then return nil end

  local lnum = window:get_lnum()
  local is_edge_navigation = live_gutter_setting:get('edge_navigation')

  for i = 1, #marks do
    local mark = marks[i]

    if lnum < mark.top then
      jump_to(window, mark.top)
      return i
    elseif is_edge_navigation and lnum < mark.bot then
      jump_to(window, mark.bot)
      return i
    end
  end

  jump_to(window, marks[1].top)

  return 1
end

function navigation.get_mark_index(marks, lnum)
  if not marks or #marks == 0 then return nil, 0 end

  for i, mark in ipairs(marks) do
    if lnum >= mark.top and lnum <= mark.bot then
      return i, #marks
    elseif mark.top > lnum then
      return math.max(1, i - 1), #marks
    end
  end

  return #marks, #marks
end

function navigation.get_current_lnum()
  return Window(0):get_lnum()
end

function navigation.set_current_lnum(lnum)
  Window(0):set_lnum(lnum)
end

function navigation.get_current_cursor()
  return Window(0):get_cursor()
end

function navigation.current_window()
  return Window(0)
end

function navigation.open_file(filename, lnum, scroll)
  fs.open(filename)

  if lnum then
    local window = Window(0)
    window:set_lnum(lnum)

    if scroll then window:scroll_to(scroll) end
  end
end

return navigation
