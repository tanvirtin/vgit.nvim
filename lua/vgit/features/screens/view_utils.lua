local lazy = require('vgit.core.lazy')
local console = lazy('vgit.core.console')
local hunks_setting = lazy('vgit.settings.hunks')

local view_utils = {}

local VALID_HUNK_ALIGNMENTS = {
  center = true,
  top = true,
  bottom = true,
}
local DEFAULT_HUNK_ALIGNMENT = 'center'

function view_utils.get_key(keymap)
  if type(keymap) == 'string' then
    return keymap
  elseif type(keymap) == 'table' then
    return keymap.key
  end
  return nil
end

function view_utils.handle_git_error(err, operation_name, view_name)
  if err then
    console.debug.error(string.format('[%s] %s failed: %s', view_name, operation_name, err))
    return false
  end
  return true
end

function view_utils.get_hunk_alignment()
  local alignment = hunks_setting:get('hunk_alignment')

  if not VALID_HUNK_ALIGNMENTS[alignment] then
    console.debug.warning(string.format(
      'Invalid hunk_alignment "%s", using default "%s"',
      tostring(alignment),
      DEFAULT_HUNK_ALIGNMENT
    ))
    return DEFAULT_HUNK_ALIGNMENT
  end

  return alignment
end

return view_utils
