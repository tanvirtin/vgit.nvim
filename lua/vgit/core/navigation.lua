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

function navigation.up(window, marks)
  if #marks == 0 then return nil end

  local new_lnum = nil
  local selected = nil
  local lnum = window:get_lnum()
  local is_edge_navigation = live_gutter_setting:get('edge_navigation')
  local alignment = get_hunk_alignment()

  -- We loop backwards, to find the most immediate mark before the current lnum.
  for i = #marks, 1, -1 do
    local mark = marks[i]
    local top = mark.top
    local bot = mark.bot

    -- If lnum > mark.bot, that's mark we must jump to.
    if lnum > bot then
      new_lnum = bot
      selected = i
      break
      -- This scenario will only occur if we are within a mark's top and bot range.
      -- lnum <= mark.bot is implied here.
    elseif is_edge_navigation and lnum > top then
      new_lnum = top
      selected = i
      break
    end
  end

  if new_lnum and new_lnum < 1 then new_lnum = 1 end

  if new_lnum and lnum ~= new_lnum then
    window:set_lnum(new_lnum):scroll_to(alignment, get_hunk_alignment_offset())

    return selected
  else
    local mark = marks[#marks]
    new_lnum = is_edge_navigation and mark.bot or mark.top

    selected = #marks

    if new_lnum < 1 then
      new_lnum = 1
      selected = 1
    end

    window:set_lnum(new_lnum):scroll_to(alignment, get_hunk_alignment_offset())
    return selected
  end
end

function navigation.down(window, marks)
  if #marks == 0 then return nil end

  local new_lnum = nil
  local selected = nil
  local lnum = window:get_lnum()
  local is_edge_navigation = live_gutter_setting:get('edge_navigation')
  local alignment = get_hunk_alignment()

  for i = 1, #marks do
    local mark = marks[i]
    local top = mark.top
    local bot = mark.bot

    -- If our current lnum is < mark.top, we have encounted a mark whose top
    -- is greater than our mark, meaning it's the mark we should jump to.
    if lnum < top then
      new_lnum = top
      selected = i
      break
      -- This scenario will occur if we are within a mark's top and bot range.
      -- lnum >= mark.top is implied here.
    elseif is_edge_navigation and lnum < bot then
      new_lnum = bot
      selected = i
      break
    end
  end

  if new_lnum and new_lnum < 1 then new_lnum = 1 end

  if new_lnum then
    window:set_lnum(new_lnum):scroll_to(alignment, get_hunk_alignment_offset())

    return selected
  else
    local first_mark = marks[1]
    new_lnum = first_mark.top
    selected = 1

    if new_lnum < 1 then
      new_lnum = 1
      selected = 1
    end

    window:set_lnum(new_lnum):scroll_to(alignment, get_hunk_alignment_offset())

    return selected
  end
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
