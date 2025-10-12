local fs = require('vgit.core.fs')
local loop = require('vgit.core.loop')
local Buffer = require('vgit.core.Buffer')
local GitFile = require('vgit.git.GitFile')
local console = require('vgit.core.console')
local repository = require('vgit.git.repository')

local diff_command = {}

local function normalize_file_path(filepath, repo_path)
  if not filepath or filepath == '' then return filepath end
  local absolute = vim.fn.fnamemodify(filepath, ':p')
  return fs.make_relative(repo_path, absolute)
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

  local i = 1
  while i <= #args do
    local arg = args[i]

    if arg == '--staged' or arg == '--cached' then
      opts.staged = true
    elseif arg == '--buffer' then
      -- --buffer flag (defaults to current buffer)
      opts.buffer_num = 0
    elseif arg:match('^%-%-buffer=') then
      -- --buffer=N flag
      local buf_str = arg:match('^%-%-buffer=(.+)$')
      opts.buffer_num = tonumber(buf_str) or 0
    elseif arg == '--' then
      -- Everything after -- is a file path
      opts.explicit_files = true
      for j = i + 1, #args do
        table.insert(opts.files, args[j])
      end
      break
    elseif arg:match('^%-%-') then
      -- Other flags (--word-diff, --stat, etc.)
      table.insert(opts.flags, arg)
    elseif arg:match('^%-') then
      -- Short flags (-w, -p, etc.)
      table.insert(opts.flags, arg)
    elseif arg:match('%.%.%.') then
      -- Triple-dot range: A...B means (merge-base A B)..B
      table.insert(opts.refs, arg)
    elseif arg:match('%.%.') then
      -- Double-dot range: A..B means A to B
      table.insert(opts.refs, arg)
    elseif arg:match('^HEAD') or arg:match('^@') then
      -- HEAD variations: HEAD, HEAD~1, HEAD^, @{upstream}
      table.insert(opts.refs, arg)
    elseif arg:match('^[a-f0-9]+$') and #arg >= 7 and #arg <= 40 then
      -- Looks like a commit hash (7-40 chars)
      table.insert(opts.refs, arg)
    elseif arg:match('^[a-zA-Z][a-zA-Z0-9_/-]*$') then
      -- Could be branch name OR file without extension
      -- Check for path separator to clarify
      if arg:match('/') then
        -- Has slash - could be file path or remote branch (origin/main)
        if arg:match('^origin/') or arg:match('^upstream/') then
          -- Remote branch
          table.insert(opts.refs, arg)
        else
          -- File path with directory
          table.insert(opts.files, arg)
        end
      else
        -- No slash - ambiguous (Makefile, README, main, feature)
        table.insert(opts.ambiguous, arg)
      end
    else
      -- Assume it's a file path
      table.insert(opts.files, arg)
    end

    i = i + 1
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

diff_command.execute = loop.coroutine(function(args)
  args = args or {}

  local opts = diff_command.parse_args(args)

  if opts.buffer_num ~= nil then
    local Window = require('vgit.core.Window')
    local buffer = Buffer(opts.buffer_num)
    local filename = buffer:get_name()

    if not filename or filename == '' then
      console.error('Buffer has no file associated with it')
      return
    end

    local window = Window(0)
    opts.cursor_line = window:get_lnum()

    table.insert(opts.files, filename)
    opts.buffer_num = nil -- Clear to avoid confusion downstream
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

  local base_ref, compare_ref, is_range, ref_err
  if #opts.refs > 0 then
    base_ref, compare_ref, is_range, ref_err = normalize_refs(opts.refs)
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
    console.error('Additional flags not implemented yet (e.g., --word-diff, --stat)')
    console.info('TODO: Support for git diff output flags')
    return
  end

  loop.free_textlock()

  local repo, repo_err = repository.current()
  if repo_err then
    console.error(repo_err)
    return
  end

  loop.free_textlock()

  -- Get layout preference from scene setting
  local scene_setting = require('vgit.settings.scene')
  opts.layout_type = scene_setting:get('diff_preference') or 'unified'

  local repo_path = repo:get_path()
  for i, filepath in ipairs(opts.files) do
    opts.files[i] = normalize_file_path(filepath, repo_path)
  end

  local data, err

  if opts.files and #opts.files == 1 then
    local filename = opts.files[1]
    local git_file = GitFile(filename)
    local diff

    loop.free_textlock()
    -- Check if comparing refs or working tree
    if opts.base_ref and opts.compare_ref then
      -- Ref comparison: VGit diff <file> HEAD^2..HEAD or HEAD^2 HEAD
      diff = repo:diff({
        type = 'range',
        filename = filename,
        from = opts.base_ref,
        to = opts.compare_ref,
        layout_type = opts.layout_type,
      })
    elseif opts.base_ref then
      -- Single ref: VGit diff <file> HEAD^2 (compare HEAD^2 to HEAD)
      diff = repo:diff({
        type = 'range',
        filename = filename,
        from = opts.base_ref,
        to = 'HEAD',
        layout_type = opts.layout_type,
      })
    else
      -- Working tree diff: VGit diff <file> [--staged]
      local from = opts.staged and 'HEAD' or 'index'
      local to = 'disk'
      diff = repo:diff({
        type = 'range',
        filename = filename,
        from = from,
        to = to,
        layout_type = opts.layout_type,
      })
    end

    if diff then
      data = {
        type = 'file',
        diff = diff,
        filename = filename,
        filetype = git_file:get_filetype(),
        layout_type = opts.layout_type,
      }
    end
  else
    data, err = repo:status(opts)
    if not err and data then
      data = {
        type = 'files',
        entries = data.entries,
        layout_type = opts.layout_type,
      }
    end
  end

  if err then
    console.error(err)
    return
  end

  local display_service = require('vgit.ui.display_service')
  display_service.show_diff(data)
end)

return diff_command
