local console = require('vgit.core.console')
local Diff = require('vgit.Diff')
local Hunk = require('vgit.cli.models.Hunk')
local DiffScreen = require('vgit.features.screens.DiffScreen')

local StagedDiffScreen = DiffScreen:extend()

function StagedDiffScreen:new(...)
  return setmetatable(DiffScreen:new(...), StagedDiffScreen)
end

function StagedDiffScreen:fetch()
  local state = self.state
  local buffer = state.buffer
  local show_err, lines = buffer.git_object:lines()
  if show_err then
    console.debug(show_err, debug.traceback())
    state.err = show_err
    return self
  end
  local dto
  local hunks_err, hunks = buffer.git_object:staged_hunks()
  if hunks_err then
    console.debug(hunks_err, debug.traceback())
    state.err = hunks_err
    return self
  end
  if self.layout_type == 'unified' then
    dto = Diff:new(hunks):unified(lines)
  else
    dto = Diff:new(hunks):split(lines)
  end
  state.data = {
    filename = buffer.filename,
    filetype = buffer:filetype(),
    dto = dto,
    selected_hunk = self.buffer_hunks:cursor_hunk() or Hunk:new(),
  }
  return self
end

return StagedDiffScreen
