local navigation = {}

function navigation.hunk_up(window, hunks)
  local new_lnum = nil
  local selected = nil
  local lnum = window:get_lnum()

  for i = #hunks, 1, -1 do
    local hunk = hunks[i]

    if hunk.bot < lnum then
      new_lnum = hunk.bot
      selected = i
      break
    elseif lnum > hunk.top then
      new_lnum = hunk.top
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
    local bot_hunks_lnum = hunks[#hunks].bot
    selected = #hunks

    if bot_hunks_lnum < 1 then
      bot_hunks_lnum = 1
      selected = 1
    end

    window:set_lnum(bot_hunks_lnum):call(function()
      vim.cmd('norm! zz')
    end)

    return selected
  end
end

function navigation.hunk_down(window, hunks)
  local new_lnum = nil
  local selected = nil
  local lnum = window:get_lnum()

  for i = 1, #hunks do
    local hunk = hunks[i]

    if hunk.top > lnum then
      new_lnum = hunk.top
      selected = i
      break
    elseif lnum < hunk.bot then
      new_lnum = hunk.bot
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
    local first_hunk_top_lnum = hunks[1].top
    selected = 1

    if first_hunk_top_lnum < 1 then
      first_hunk_top_lnum = 1
      selected = 1
    end

    window:set_lnum(first_hunk_top_lnum):call(function()
      vim.cmd('norm! zz')
    end)

    return selected
  end
end

return navigation
