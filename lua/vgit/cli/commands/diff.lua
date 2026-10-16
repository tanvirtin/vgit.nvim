local lazy = require('vgit.core.lazy')

local fs = lazy('vgit.core.fs')
local event = lazy('vgit.core.event')
local Window = lazy('vgit.core.Window')
local Buffer = lazy('vgit.core.Buffer')
local console = lazy('vgit.core.console')
local repository = lazy('vgit.git.repository')
local scene_setting = lazy('vgit.settings.scene')
local display_service = lazy('vgit.ui.display_service')
local normalize_file_path = require('vgit.cli.commands.normalize_file_path')
local build_file_diff_entries = require('vgit.cli.commands.build_file_diff_entries')

local diff_command = {}

local function format_ref_for_display(ref)
  if ref:match('^[a-f0-9]+$') and #ref == 40 then return ref:sub(1, 7) end
  return ref
end

function diff_command.parse_args(args)
  local opts = {
    files = {},
    refs = {},
    staged = false,
    buffer_num = nil,
    flags = {},
    ambiguous = {},
    explicit_files = false,
  }

  for i = 1, #args do
    local arg = args[i]

    if arg == '--staged' or arg == '--cached' then
      opts.staged = true
    elseif arg == '--buffer' then
      opts.buffer_num = 0
    elseif arg:match('^%-%-buffer=') then
      local buf_str = arg:match('^%-%-buffer=(.+)$')
      opts.buffer_num = tonumber(buf_str) or 0
    elseif arg == '--' then
      opts.explicit_files = true
      for j = i + 1, #args do
        table.insert(opts.files, args[j])
      end
      break
    elseif arg:match('^%-%-') then
      table.insert(opts.flags, arg)
    elseif arg:match('^%-') then
      table.insert(opts.flags, arg)
    elseif arg:match('%.%.%.') then
      table.insert(opts.refs, arg)
    elseif arg:match('%.%.') then
      table.insert(opts.refs, arg)
    elseif arg:match('^HEAD') or arg:match('^@') then
      table.insert(opts.refs, arg)
    elseif arg:match('^[a-f0-9]+$') and #arg >= 7 and #arg <= 40 then
      table.insert(opts.refs, arg)
    elseif arg:match('^[a-zA-Z][a-zA-Z0-9_/-]*$') then
      if arg:match('/') then
        if arg:match('^origin/') or arg:match('^upstream/') then
          table.insert(opts.refs, arg)
        else
          table.insert(opts.files, arg)
        end
      else
        table.insert(opts.ambiguous, arg)
      end
    else
      table.insert(opts.files, arg)
    end
  end

  return opts
end

local function normalize_refs(refs)
  if #refs == 0 then
    return nil, nil, false
  elseif #refs == 1 then
    local ref = refs[1]

    if ref:match('%.%.') then
      local base, compare = ref:match('([^.]+)%.%.%.?(.+)')
      if not base or not compare then return nil, nil, false, 'Invalid range syntax: ' .. ref end
      return base, compare, true
    end

    return ref, nil, false
  elseif #refs == 2 then
    return refs[1], refs[2], false
  else
    return nil, nil, false, 'Too many refs provided (max 2)'
  end
end

diff_command.execute = event.async(function(args)
  args = args or {}

  local opts = diff_command.parse_args(args)

  if opts.buffer_num ~= nil then
    local buffer = Buffer(opts.buffer_num)
    local filename = buffer:get_name()

    if not filename or filename == '' then
      console.error('Buffer has no file associated with it')
      return
    end

    local window = Window(0)
    opts.cursor_line = window:get_lnum()

    table.insert(opts.files, filename)
    opts.buffer_num = nil
  end

  if opts.ambiguous and #opts.ambiguous > 0 then
    for _, arg in ipairs(opts.ambiguous) do
      local file_exists = vim.fn.filereadable(arg) == 1

      if file_exists then
        table.insert(opts.files, arg)
      else
        table.insert(opts.refs, arg)
      end
    end
    opts.ambiguous = nil
  end

  local base_ref, compare_ref, _, ref_err
  if #opts.refs > 0 then
    base_ref, compare_ref, _, ref_err = normalize_refs(opts.refs)
    if ref_err then
      console.error(ref_err)
      return
    end
  end

  if opts.staged and base_ref then
    console.error('Cannot combine --staged with ref comparison')
    console.info('Use either "--staged" or provide refs, not both')
    return
  end

  if base_ref then
    opts.base_ref = base_ref
    opts.compare_ref = compare_ref
  end

  if #opts.flags > 0 then
    console.info('Flag options not yet supported')
    return
  end

  event.await()

  local repo, repo_err = repository.current()
  if repo_err then
    console.error(repo_err)
    return
  end

  opts.layout_type = scene_setting:get('diff_preference') or 'unified'

  local repo_path = repo:get_path()
  for i, filepath in ipairs(opts.files) do
    opts.files[i] = normalize_file_path(filepath, repo_path)
  end

  local data, err

  if opts.files and #opts.files == 1 then
    local filename = opts.files[1]
    local diff
    local old_filename = nil

    if opts.base_ref and opts.compare_ref then
      diff = repo:diff({
        type = 'range',
        filename = filename,
        from = opts.base_ref,
        to = opts.compare_ref,
        layout_type = opts.layout_type,
      })
    elseif opts.base_ref then
      diff = repo:diff({
        type = 'range',
        filename = filename,
        from = opts.base_ref,
        to = 'HEAD',
        layout_type = opts.layout_type,
      })
    else
      local from, to
      if opts.staged then
        from = 'HEAD'
        to = 'index'
        local file_status = repo:file_status(filename)
        if file_status and file_status.old_filename then old_filename = file_status.old_filename end
      else
        from = 'index'
        to = 'disk'
      end
      diff = repo:diff({
        type = 'range',
        filename = filename,
        old_filename = old_filename,
        from = from,
        to = to,
        layout_type = opts.layout_type,
      })
    end

    if diff then
      local is_live = not opts.base_ref

      data = {
        type = 'file',
        diff = diff,
        filename = filename,
        old_filename = old_filename,
        filetype = fs.detect_filetype(filename),
        layout_type = opts.layout_type,
        is_staged = opts.staged,
        is_live = is_live,
      }
    end
  elseif opts.base_ref then
    local from_ref = opts.base_ref
    local to_ref = opts.compare_ref or 'HEAD'

    local files, files_err = repo:diff_tree({
      commit_hash = to_ref,
      parent_hash = from_ref,
    })

    if files_err then
      console.error('Failed to get files between refs: ' .. (files_err[1] or tostring(files_err)))
      return
    end

    if not files or #files == 0 then
      console.info('No files changed between ' .. from_ref .. ' and ' .. to_ref)
      return
    end

    local entries = build_file_diff_entries(repo, files, from_ref, to_ref, opts.layout_type)

    if #entries == 0 then
      console.info('No diffs available between ' .. from_ref .. ' and ' .. to_ref)
      return
    end

    data = {
      type = 'files',
      entries = {
        {
          title = string.format('Changes: %s..%s', format_ref_for_display(from_ref), format_ref_for_display(to_ref)),
          entries = entries,
        },
      },
      layout_type = opts.layout_type,
    }
  else
    data, err = repo:status(opts)
    if not err and data then
      local filtered_entries = {}
      for _, entry in ipairs(data.entries) do
        if opts.staged then
          if entry.title == 'Staged Changes' then table.insert(filtered_entries, entry) end
        else
          if entry.title == 'Changes' or entry.title == 'Merge Changes' then table.insert(filtered_entries, entry) end
        end
      end

      if #filtered_entries == 0 then
        display_service.show_diff({
          type = 'empty',
          message = opts.staged and 'No staged changes' or 'No unstaged changes',
        })
        return
      end

      data = {
        type = 'files',
        entries = filtered_entries,
        layout_type = opts.layout_type,
      }
    end
  end

  if err then
    console.error(err)
    return
  end

  if not data then
    console.info('No changes')
    return
  end

  display_service.show_diff(data)
end)

return diff_command
