local console = require('vgit.core.console')
local Window = require('vgit.core.Window')
local loop = require('vgit.core.loop')
local Feature = require('vgit.Feature')

local BufferHunks = Feature:extend()

function BufferHunks:new(git_store, navigation, marker)
  return setmetatable({
    git_store = git_store,
    navigation = navigation,
    marker = marker,
  }, BufferHunks)
end

function BufferHunks:move_up()
  loop.await_fast_event()
  local buffer = self.git_store:current()
  if not buffer then
    return
  end
  local hunks = buffer.git_object.hunks
  if hunks and #hunks ~= 0 then
    local window = Window:new(0)
    local selected = self.navigation:hunk_up(window, hunks)
    self.marker:mark_current_hunk(
      buffer,
      window,
      string.format('%s/%s Changes', selected, #hunks)
    )
  end
end

function BufferHunks:move_down()
  loop.await_fast_event()
  local buffer = self.git_store:current()
  if not buffer then
    return
  end
  local hunks = buffer.git_object.hunks
  if hunks and #hunks ~= 0 then
    local window = Window:new(0)
    local selected = self.navigation:hunk_down(window, hunks)
    self.marker:mark_current_hunk(
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
    if lnum == 1 and hunk.start == 0 and hunk.finish == 0 then
      return hunk, i
    end
    if lnum >= hunk.start and lnum <= hunk.finish then
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
      (lnum >= hunk.start and lnum <= hunk.finish)
      or (
        hunk.start == 0
        and hunk.finish == 0
        and lnum - 1 == hunk.start
        and lnum - 1 == hunk.finish
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
    local start = selected_hunk.start
    local finish = selected_hunk.finish
    if start and finish then
      if selected_hunk.type == 'remove' then
        buffer:set_lines(replaced_lines, start, finish)
      else
        buffer:set_lines(replaced_lines, start - 1, finish)
      end
      local new_lnum = start
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
