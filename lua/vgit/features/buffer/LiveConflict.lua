local utils = require('vgit.core.utils')
local loop = require('vgit.core.loop')
local Window = require('vgit.core.Window')
local Object = require('vgit.core.Object')
local git_buffer_store = require('vgit.git.git_buffer_store')

local LiveConflict = Object:extend()

function LiveConflict:constructor()
  return { name = 'Conflict' }
end

function LiveConflict:conflict_accept_current_change(buffer)
  local window = Window(0)
  local cursor = window:get_cursor()
  local conflict = buffer:get_conflict_under_hunk(cursor)
  if not conflict then return end
  local lines = buffer:get_lines()
  local current_lines = utils.list.extract(lines, conflict.current.top + 1, conflict.current.bot)
  local conflict_top = conflict.current.top
  local conflict_bot = conflict.incoming.bot
  lines = utils.list.replace(lines, conflict_top, conflict_bot, current_lines)
  buffer:set_lines(lines)
  buffer:call(function() vim.cmd('LspStart') end)
end

function LiveConflict:conflict_accept_incoming_change(buffer)
  local window = Window(0)
  local cursor = window:get_cursor()
  local conflict = buffer:get_conflict_under_hunk(cursor)
  if not conflict then return end
  local lines = buffer:get_lines()
  local incoming_lines = utils.list.extract(lines, conflict.incoming.top, conflict.incoming.bot - 1)
  local conflict_top = conflict.current.top
  local conflict_bot = conflict.incoming.bot
  lines = utils.list.replace(lines, conflict_top, conflict_bot, incoming_lines)
  buffer:set_lines(lines)
  buffer:call(function() vim.cmd('LspStart') end)
end

function LiveConflict:conflict_accept_both_changes(buffer)
  local window = Window(0)
  local cursor = window:get_cursor()
  local conflict = buffer:get_conflict_under_hunk(cursor)
  if not conflict then return end
  local lines = buffer:get_lines()
  local current_lines = utils.list.extract(lines, conflict.current.top + 1, conflict.current.bot)
  local incoming_lines = utils.list.extract(lines, conflict.incoming.top, conflict.incoming.bot - 1)
  local replacement_lines = utils.list.concat(current_lines, incoming_lines)
  local conflict_top = conflict.current.top
  local conflict_bot = conflict.incoming.bot
  lines = utils.list.replace(lines, conflict_top, conflict_bot, replacement_lines)
  buffer:set_lines(lines)
  buffer:call(function() vim.cmd('LspStart') end)
end

function LiveConflict:render(buffer)
  local has_conflict = buffer:has_conflict()
  if not has_conflict then return end

  loop.free_textlock()
  buffer:call(function() vim.cmd('LspStop') end)
  buffer:parse_conflicts()
  buffer:render_conflicts()
end

function LiveConflict:register_events()
  git_buffer_store
    .attach('attach', function(buffer)
      self:render(buffer)
    end)
    .attach('reload', function(buffer)
      self:render(buffer)
    end)
    .attach('change', function(buffer)
      self:render(buffer)
    end)
    .attach('watch', function(buffer)
      self:render(buffer)
    end)
    .attach('git_watch', function(buffers)
      for i = 1, #buffers do
        self:render(buffers[i])
      end
    end)

  return self
end

return LiveConflict
