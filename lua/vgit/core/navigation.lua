local live_gutter_setting = require('vgit.settings.live_gutter')

local navigation = {}

function navigation.up(window, marks)
  local new_lnum = nil
  local selected = nil
  local lnum = window:get_lnum()
  local is_edge_navigation = live_gutter_setting:get('edge_navigation')

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
    window:set_lnum(new_lnum):position_cursor('center')

    return selected
  else
    local mark = marks[#marks]
    new_lnum = is_edge_navigation and mark.bot or mark.top

    selected = #marks

    if new_lnum < 1 then
      new_lnum = 1
      selected = 1
    end

    window:set_lnum(new_lnum):position_cursor('center')
    return selected
  end
end

function navigation.down(window, marks)
  local new_lnum = nil
  local selected = nil
  local lnum = window:get_lnum()
  local is_edge_navigation = live_gutter_setting:get('edge_navigation')

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
    window:set_lnum(new_lnum):position_cursor('center')

    return selected
  else
    local first_mark = marks[1]
    new_lnum = first_mark.top
    selected = 1

    if new_lnum < 1 then
      new_lnum = 1
      selected = 1
    end

    window:set_lnum(new_lnum):position_cursor('center')

    return selected
  end
end

return navigation
