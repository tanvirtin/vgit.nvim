local fs = require('vgit.core.fs')
local event = require('vgit.core.event')
local Buffer = require('vgit.core.Buffer')
local Window = require('vgit.core.Window')
local GitFile = require('vgit.git.GitFile')
local console = require('vgit.core.console')

local hunk_command = {}

hunk_command.execute = event.async(function(args)
  args = args or {}

  local buffer = Buffer(0)
  local filename = buffer:get_name()

  if not filename or filename == '' then
    console.error('Not in a file buffer')
    return
  end

  local window = Window(0)
  local lnum = window:get_lnum()

  local scene_setting = require('vgit.settings.scene')
  local current_layout_type = scene_setting:get('diff_preference') or 'unified'

  event.await()

  local git_file = GitFile(filename)
  local current_lines = fs.read_file(filename)
  if not current_lines then
    console.error('Failed to read file')
    return
  end

  local hunks, hunks_err = git_file:live_hunks(current_lines)
  if hunks_err then
    console.error(hunks_err)
    return
  end

  local Diff = require('vgit.core.diff.Diff')
  local diff = Diff():generate(hunks, current_lines, current_layout_type)

  if not diff then
    console.error('Failed to generate diff')
    return
  end

  local target_hunk_index = nil
  if diff and diff.marks then
    for idx, mark in ipairs(diff.marks) do
      if mark.top_relative and mark.bot_relative and lnum >= mark.top_relative and lnum <= mark.bot_relative then
        target_hunk_index = idx
        break
      end
    end
  end

  local data = {
    type = 'hunk',
    file_path = filename,
    cursor_line = lnum,
    diff = diff,
    target_hunk_index = target_hunk_index,
    filename = filename,
    filetype = git_file:get_filetype(),
    layout_type = current_layout_type,
  }

  local display_service = require('vgit.ui.display_service')
  display_service.show_hunk(data)
end)

return hunk_command
