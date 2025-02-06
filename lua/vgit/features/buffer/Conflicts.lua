local utils = require('vgit.core.utils')
local Window = require('vgit.core.Window')
local Object = require('vgit.core.Object')
local navigation = require('vgit.core.navigation')
local git_buffer_store = require('vgit.git.git_buffer_store')

local Conflicts = Object:extend()

function Conflicts:constructor()
  return {
    name = 'Buffer Conflicts',
  }
end

function Conflicts:move_up()
  local buffer = git_buffer_store.current()
  if not buffer then return end

  local conflicts = buffer:get_conflicts()
  if not conflicts or #conflicts == 0 then return end

  local window = Window(0)

  local marks = buffer:get_conflict_marks()
  navigation.up(window, marks)
end

function Conflicts:move_down()
  local buffer = git_buffer_store.current()
  if not buffer then return end

  local conflicts = buffer:get_conflicts()
  if not conflicts or #conflicts == 0 then return end

  local window = Window(0)

  local marks = buffer:get_conflict_marks()
  navigation.down(window, marks)
end

function Conflicts:accept_both()
  local buffer = git_buffer_store.current()
  if not buffer then return end

  local conflicts = buffer:get_conflicts()
  if not conflicts or #conflicts == 0 then return end

  local window = Window(0)
  local cursor = window:get_cursor()
  local conflict = buffer:get_conflict(cursor[1])
  if not conflict then return end

  local lines = buffer:get_lines()
  local current_lines = utils.list.extract(lines, conflict.current.top + 1, conflict.current.bot)
  local incoming_lines = utils.list.extract(lines, conflict.incoming.top, conflict.incoming.bot - 1)
  local replacement_lines = utils.list.concat(current_lines, incoming_lines)
  local conflict_top = conflict.current.top
  local conflict_bot = conflict.incoming.bot

  lines = utils.list.replace(lines, conflict_top, conflict_bot, replacement_lines)
  buffer:set_lines(lines)
end

function Conflicts:accept_current()
  local buffer = git_buffer_store.current()
  if not buffer then return end

  local conflicts = buffer:get_conflicts()
  if not conflicts or #conflicts == 0 then return end

  local window = Window(0)
  local cursor = window:get_cursor()
  local conflict = buffer:get_conflict(cursor[1])
  if not conflict then return end

  local lines = buffer:get_lines()
  local current_lines = utils.list.extract(lines, conflict.current.top + 1, conflict.current.bot)
  local conflict_top = conflict.current.top
  local conflict_bot = conflict.incoming.bot

  lines = utils.list.replace(lines, conflict_top, conflict_bot, current_lines)
  buffer:set_lines(lines)
end

function Conflicts:accept_incoming()
  local buffer = git_buffer_store.current()
  if not buffer then return end

  local conflicts = buffer:get_conflicts()
  if not conflicts or #conflicts == 0 then return end

  local window = Window(0)
  local cursor = window:get_cursor()
  local conflict = buffer:get_conflict(cursor[1])
  if not conflict then return end

  local lines = buffer:get_lines()
  local incoming_lines = utils.list.extract(lines, conflict.incoming.top, conflict.incoming.bot - 1)
  local conflict_top = conflict.current.top
  local conflict_bot = conflict.incoming.bot

  lines = utils.list.replace(lines, conflict_top, conflict_bot, incoming_lines)
  buffer:set_lines(lines)
end

return Conflicts
