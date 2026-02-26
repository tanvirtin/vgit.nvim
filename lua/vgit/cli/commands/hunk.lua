local lazy = require('vgit.core.lazy')

local fs = lazy('vgit.core.fs')
local event = lazy('vgit.core.event')
local Buffer = lazy('vgit.core.Buffer')
local Window = lazy('vgit.core.Window')
local GitFile = lazy('vgit.git.GitFile')
local Diff = lazy('vgit.core.diff.Diff')
local console = lazy('vgit.core.console')
local scene_setting = lazy('vgit.settings.scene')
local display_service = lazy('vgit.ui.display_service')

local hunk_command = {}

function hunk_command.find_target_hunk_index(diff, lnum)
  if not diff or not diff.marks then return nil end

  for idx, mark in ipairs(diff.marks) do
    if mark.top_relative and mark.bot_relative and lnum >= mark.top_relative and lnum <= mark.bot_relative then
      return idx
    end
  end

  return nil
end

function hunk_command.compute_hunk_diff(filename, current_lines, layout_type)
  local git_file = GitFile(filename)
  local hunks, hunks_err = git_file:live_hunks(current_lines)
  if hunks_err then return nil, nil, hunks_err end

  local diff = Diff():generate(hunks, current_lines, layout_type)
  if not diff then return nil, nil, 'Failed to generate diff' end

  return diff, git_file, nil
end

hunk_command.execute = event.async(function(args)
  args = args or {}

  local buffer = args.buffer or Buffer(0)
  local filename = buffer:get_name()

  if not filename or filename == '' then
    console.error('Not in a file buffer')
    return
  end

  local window = args.window or Window(0)
  local lnum = window:get_lnum()

  local current_layout_type = scene_setting:get('diff_preference') or 'unified'

  event.await()

  local current_lines = fs.read_file(filename)
  if not current_lines then
    console.error('Failed to read file')
    return
  end

  local diff, git_file, err = hunk_command.compute_hunk_diff(filename, current_lines, current_layout_type)
  if err then
    console.error(err)
    return
  end

  local target_hunk_index = hunk_command.find_target_hunk_index(diff, lnum)

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

  display_service.show_hunk(data)
end)

return hunk_command
