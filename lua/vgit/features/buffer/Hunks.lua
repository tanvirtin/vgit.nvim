local loop = require('vgit.core.loop')
local Window = require('vgit.core.Window')
local Object = require('vgit.core.Object')
local console = require('vgit.core.console')
local navigation = require('vgit.core.navigation')
local git_buffer_store = require('vgit.git.git_buffer_store')
local live_gutter_setting = require('vgit.settings.live_gutter')

local Hunks = Object:extend()

function Hunks:constructor()
  return {
    name = 'Buffer Hunks',
  }
end

function Hunks:is_enabled()
  return live_gutter_setting:get('enabled') == true
end

function Hunks:move_up()
  if not self:is_enabled() then return end

  local buffer = git_buffer_store.current()
  if not buffer then return end

  local hunks = buffer:get_hunks()
  if not hunks or #hunks == 0 then return end

  local window = Window(0)
  navigation.up(window, hunks)
end

function Hunks:move_down()
  if not self:is_enabled() then return end

  local buffer = git_buffer_store.current()
  if not buffer then return end

  local hunks = buffer:get_hunks()
  if not hunks or #hunks == 0 then return end

  local window = Window(0)
  navigation.down(window, hunks)
end

function Hunks:cursor_hunk()
  loop.free_textlock()
  local buffer = git_buffer_store.current()
  if not buffer then return end

  local window = Window(0)
  local lnum = window:get_lnum()

  local hunks = buffer:get_hunks()
  if not hunks then return end

  for i = 1, #hunks do
    local hunk = hunks[i]

    if lnum == 1 and hunk.top == 0 and hunk.bot == 0 then return hunk, i end
    if lnum >= hunk.top and lnum <= hunk.bot then return hunk, i end
  end
end

function Hunks:stage_all()
  loop.free_textlock()
  local buffer = git_buffer_store.current()
  if not buffer then return end

  loop.free_textlock()
  local _, err = buffer:stage()
  if err then return console.debug.error(err) end

  loop.free_textlock()
end

function Hunks:cursor_stage()
  if not self:is_enabled() then return end

  local buffer = git_buffer_store.current()
  if not buffer then return end
  if buffer:editing() then return end

  if not buffer:is_tracked() then
    local _, err = buffer:stage()
    if err then return console.debug.error(err) end
    return
  end

  local hunk = self:cursor_hunk()
  if not hunk then return end

  loop.free_textlock()
  local _, err = buffer:stage_hunk(hunk)
  if err then return console.debug.error(err) end
end

function Hunks:unstage_all()
  loop.free_textlock()
  local buffer = git_buffer_store.current()
  if not buffer then return end

  loop.free_textlock()
  local _, err = buffer:unstage()
  if err then return console.debug.error(err) end
end

function Hunks:reset_all()
  loop.free_textlock()
  local buffer = git_buffer_store.current()
  if not buffer then return end

  local hunks = buffer:get_hunks()
  if not hunks and #hunks == 0 then return end

  loop.free_textlock()
  local lines, err = buffer.git_file:lines()
  if err then return console.debug.error(err) end

  loop.free_textlock()
  buffer:set_lines(lines)
end

function Hunks:cursor_reset()
  if not self:is_enabled() then return end

  loop.free_textlock()
  local buffer = git_buffer_store.current()
  if not buffer then return end

  local window = Window(0)
  local lnum = window:get_lnum()
  local hunks = buffer:get_hunks()
  if not hunks then return end

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
      if all_removes then self:reset_all() end
    end
  end

  local selected_hunk = nil
  local selected_hunk_index = nil

  for i = 1, #hunks do
    local hunk = hunks[i]
    if
      (lnum >= hunk.top and lnum <= hunk.bot)
      or (hunk.top == 0 and hunk.bot == 0 and lnum - 1 == hunk.top and lnum - 1 == hunk.bot)
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
      if is_line_removed then replaced_lines[#replaced_lines + 1] = string.sub(line, 2, -1) end
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

      if new_lnum < 1 then new_lnum = 1 end

      window:set_lnum(new_lnum)
      table.remove(hunks, selected_hunk_index)
      vim.cmd('update')
    end
  end
end

return Hunks
