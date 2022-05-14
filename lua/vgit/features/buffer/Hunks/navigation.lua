local live_gutter_setting = require('vgit.settings.live_gutter')

local navigation = {}

function navigation.hunk_up(window, hunks)
  local new_lnum = nil
  local selected = nil
  local lnum = window:get_lnum()
  local is_edge_navigation = live_gutter_setting:get('edge_navigation')

  -- We loop backwards, to find the most immediate hunk before the current lnum.
  for i = #hunks, 1, -1 do
    local hunk = hunks[i]

    -- If lnum > hunk.bot, that's hunk we must jump to.
    if lnum > hunk.bot then
      new_lnum = hunk.bot
      selected = i
      break
      -- This scenario will only occur if we are within a hunk's top and bot range.
      -- lnum <= hunk.bot is implied here.
    elseif is_edge_navigation and lnum > hunk.top then
      new_lnum = hunk.top
      selected = i
      break
    end
  end

  if new_lnum and new_lnum < 1 then
    new_lnum = 1
  end

  if new_lnum and lnum ~= new_lnum then
    window:set_lnum(new_lnum):position_cursor('center')

    return selected
  else
    local hunk = hunks[#hunks]
    new_lnum = is_edge_navigation and hunk.bot or hunk.top

    selected = #hunks

    if new_lnum < 1 then
      new_lnum = 1
      selected = 1
    end

    window:set_lnum(new_lnum):position_cursor('center')
    return selected
  end
end

function navigation.hunk_down(window, hunks)
  local new_lnum = nil
  local selected = nil
  local lnum = window:get_lnum()
  local is_edge_navigation = live_gutter_setting:get('edge_navigation')

  for i = 1, #hunks do
    local hunk = hunks[i]

    -- If our current lnum is < hunk.top, we have encounted a hunk whose top
    -- is greater than our hunk, meaning it's the hunk we should jump to.
    if lnum < hunk.top then
      new_lnum = hunk.top
      selected = i
      break
      -- This scenario will occur if we are within a hunk's top and bot range.
      -- lnum >= hunk.top is implied here.
    elseif is_edge_navigation and lnum < hunk.bot then
      new_lnum = hunk.bot
      selected = i
      break
    end
  end

  if new_lnum and new_lnum < 1 then
    new_lnum = 1
  end

  if new_lnum then
    window:set_lnum(new_lnum):position_cursor('center')

    return selected
  else
    new_lnum = hunks[1].top
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
