local console = require('vgit.core.console')
local navigation = require('vgit.navigation')
local Window = require('vgit.core.Window')
local Object = require('vgit.core.Object')
local loop = require('vgit.core.loop')
local Feature = require('vgit.Feature')

local NavigationVirtualText = Object:extend()

function NavigationVirtualText:new()
  return setmetatable({
    timer_id = nil,
    epoch = 1000,
  }, NavigationVirtualText)
end

function NavigationVirtualText:clear_timer()
  if self.timer_id then
    vim.fn.timer_stop(self.timer_id)
    self.timer_id = nil
  end
end

function NavigationVirtualText:place(buffer, window, text)
  self:unplace(buffer)
  buffer:transpose_virtual_text(
    text,
    'GitComment',
    window:get_lnum() - 1,
    0,
    'right_align'
  )
  self.timer_id = vim.fn.timer_start(self.epoch, function()
    if buffer:is_valid() then
      buffer:clear_namespace()
    end
    self:clear_timer()
  end)
end

function NavigationVirtualText:unplace(buffer)
  self:clear_timer()
  if buffer:is_valid() then
    buffer:clear_namespace()
  end
end

local BufferHunks = Feature:extend()

function BufferHunks:new(git_store, versioning)
  return setmetatable({
    name = 'Buffer Hunks',
    git_store = git_store,
    versioning = versioning,
    navigation_virtual_text = NavigationVirtualText:new(),
  }, BufferHunks)
end

function BufferHunks:move_up()
  local buffer = self.git_store:current()
  if not buffer then
    return
  end
  local hunks = buffer.git_object.hunks
  if hunks and #hunks ~= 0 then
    local window = Window:new(0)
    local selected = navigation.hunk_up(window, hunks)
    self.navigation_virtual_text:place(
      buffer,
      window,
      string.format('%s/%s Changes', selected, #hunks)
    )
  end
end

function BufferHunks:move_down()
  local buffer = self.git_store:current()
  if not buffer then
    return
  end
  local hunks = buffer.git_object.hunks
  if hunks and #hunks ~= 0 then
    local window = Window:new(0)
    local selected = navigation.hunk_down(window, hunks)
    self.navigation_virtual_text:place(
      buffer,
      window,
      string.format('%s/%s Changes', selected, #hunks)
    )
  end
end

function BufferHunks:cursor_hunk()
  loop.await_fast_event()
  local buffer = self.git_store:current()
  if not buffer then
    return
  end
  local window = Window:new(0)
  local lnum = window:get_lnum()
  local hunks = buffer.git_object.hunks
  if not hunks then
    return
  end
  for i = 1, #hunks do
    local hunk = hunks[i]
    if lnum == 1 and hunk.top == 0 and hunk.bot == 0 then
      return hunk, i
    end
    if lnum >= hunk.top and lnum <= hunk.bot then
      return hunk, i
    end
  end
end

function BufferHunks:stage_all()
  loop.await_fast_event()
  local buffer = self.git_store:current()
  if not buffer then
    return
  end
  local err = buffer.git_object:stage()
  loop.await_fast_event()
  if err then
    console.debug(err, debug.traceback())
    return
  end
  vim.cmd('edit')
end

function BufferHunks:cursor_stage()
  loop.await_fast_event()
  local buffer = self.git_store:current()
  if not buffer then
    return
  end
  if buffer:editing() then
    return
  end
  local git_object = buffer.git_object
  if not git_object:is_tracked() then
    local err = git_object:stage()
    loop.await_fast_event()
    if err then
      console.debug(err, debug.traceback())
      return
    end
    vim.cmd('edit')
    return
  end
  local hunk = self:cursor_hunk()
  if not hunk then
    return
  end
  local err = git_object:stage_hunk(hunk)
  if err then
    console.debug(err, debug.traceback())
    return
  end
  vim.cmd('edit')
end

function BufferHunks:unstage_all()
  loop.await_fast_event()
  local buffer = self.git_store:current()
  if not buffer then
    return
  end
  local err = buffer.git_object:unstage()
  loop.await_fast_event()
  if err then
    console.debug(err, debug.traceback())
    return
  end
  vim.cmd('edit')
end

function BufferHunks:reset_all()
  loop.await_fast_event()
  local buffer = self.git_store:current()
  if not buffer then
    return
  end
  local hunks = buffer.git_object.hunks
  if not hunks and #hunks == 0 then
    return
  end
  local err, lines = buffer.git_object:lines()
  loop.await_fast_event()
  if err then
    return console.debug(err, debug.traceback())
  end
  buffer:set_lines(lines)
  vim.cmd('update')
end

function BufferHunks:cursor_reset()
  loop.await_fast_event()
  local buffer = self.git_store:current()
  if not buffer then
    return
  end
  local window = Window:new(0)
  local lnum = window:get_lnum()
  local hunks = buffer.git_object.hunks
  if not hunks then
    return
  end
  if lnum == 1 then
    local current_lines = buffer:get_lines()
    if #hunks > 0 and #current_lines == 1 and current_lines[1] == '' then
      local all_removes = true
      for i = 1, #hunks do
        local hunk = hunks[i]
        if hunk.type ~= 'remove' then
          all_removes = false
          break
        end
      end
      if all_removes then
        self:reset_all()
      end
    end
  end
  local selected_hunk = nil
  local selected_hunk_index = nil
  for i = 1, #hunks do
    local hunk = hunks[i]
    if
      (lnum >= hunk.top and lnum <= hunk.bot)
      or (
        hunk.top == 0
        and hunk.bot == 0
        and lnum - 1 == hunk.top
        and lnum - 1 == hunk.bot
      )
    then
      selected_hunk = hunk
      selected_hunk_index = i
      break
    end
  end
  if selected_hunk then
    local replaced_lines = {}
    for i = 1, #selected_hunk.diff do
      local line = selected_hunk.diff[i]
      local is_line_removed = vim.startswith(line, '-')
      if is_line_removed then
        replaced_lines[#replaced_lines + 1] = string.sub(line, 2, -1)
      end
    end
    local top = selected_hunk.top
    local bot = selected_hunk.bot
    if top and bot then
      if selected_hunk.type == 'remove' then
        buffer:set_lines(replaced_lines, top, bot)
      else
        buffer:set_lines(replaced_lines, top - 1, bot)
      end
      local new_lnum = top
      if new_lnum < 1 then
        new_lnum = 1
      end
      window:set_lnum(new_lnum)
      table.remove(hunks, selected_hunk_index)
      vim.cmd('update')
    end
  end
end

return BufferHunks
