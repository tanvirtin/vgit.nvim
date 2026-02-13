local lazy = require('vgit.core.lazy')
local fs = lazy('vgit.core.fs')
local event = lazy('vgit.core.event')
local Buffer = lazy('vgit.core.Buffer')
local Window = lazy('vgit.core.Window')
local console = lazy('vgit.core.console')
local repository = lazy('vgit.git.repository')
local display_service = lazy('vgit.ui.display_service')
local scene_setting = lazy('vgit.settings.scene')

local status_command = {}

status_command.execute = event.async(function()
  event.await()

  local buffer = Buffer(0)
  local buf_name = buffer:get_name()

  local repo, repo_err = repository.current()
  if repo_err then
    console.error(repo_err)
    return
  end

  local data, err = repo:status({})

  if err then
    console.error(err)
    return
  end

  if not data or not data.entries or #data.entries == 0 then
    console.info('No changes to display')
    return
  end

  local layout_type = scene_setting:get('diff_preference') or 'unified'

  local cursor_lnum = Window(0):get_lnum()

  local current_filename = nil
  if buf_name and buf_name ~= '' then
    current_filename = fs.make_relative(repo:get_path(), buf_name)
  end

  local transformed_data = {
    type = 'status',
    entries = data.entries,
    layout_type = layout_type,
    current_filename = current_filename,
    cursor_lnum = cursor_lnum,
  }

  display_service.show_status(transformed_data)
end)

return status_command
