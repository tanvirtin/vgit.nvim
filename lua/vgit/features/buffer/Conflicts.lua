local lazy = require('vgit.core.lazy')

local utils = lazy('vgit.core.utils')
local Object = lazy('vgit.core.Object')
local navigation = lazy('vgit.core.navigation')
local git_buffer_store = lazy('vgit.git.git_buffer_store')

local Conflicts = Object:extend()

function Conflicts:constructor()
  return {
    _name = 'Buffer Conflicts',
  }
end

function Conflicts:hunk_up()
  local buffer = git_buffer_store.current()
  if not buffer then return end

  local conflicts = buffer:get_conflicts()
  if not conflicts or #conflicts == 0 then return end

  local window = navigation.current_window()

  local marks = buffer:get_conflict_marks()
  navigation.up(window, marks)
end

function Conflicts:hunk_down()
  local buffer = git_buffer_store.current()
  if not buffer then return end

  local conflicts = buffer:get_conflicts()
  if not conflicts or #conflicts == 0 then return end

  local window = navigation.current_window()

  local marks = buffer:get_conflict_marks()
  navigation.down(window, marks)
end

local function resolve_conflict(get_replacement_lines)
  local buffer = git_buffer_store.current()
  if not buffer then return end

  local conflicts = buffer:get_conflicts()
  if not conflicts or #conflicts == 0 then return end

  local cursor = navigation.get_current_cursor()
  local conflict = buffer:get_conflict(cursor[1])
  if not conflict then return end

  local lines = buffer:get_lines()
  local replacement_lines = get_replacement_lines(lines, conflict)

  lines = utils.list.replace(lines, conflict.current.top, conflict.incoming.bot, replacement_lines)
  buffer:set_lines(lines)
end

function Conflicts:accept_both()
  resolve_conflict(function(lines, conflict)
    local current_lines = utils.list.extract(lines, conflict.current.top + 1, conflict.current.bot)
    local incoming_lines = utils.list.extract(lines, conflict.incoming.top, conflict.incoming.bot - 1)
    return utils.list.concat(current_lines, incoming_lines)
  end)
end

function Conflicts:accept_current()
  resolve_conflict(function(lines, conflict)
    return utils.list.extract(lines, conflict.current.top + 1, conflict.current.bot)
  end)
end

function Conflicts:accept_incoming()
  resolve_conflict(function(lines, conflict)
    return utils.list.extract(lines, conflict.incoming.top, conflict.incoming.bot - 1)
  end)
end

return Conflicts
