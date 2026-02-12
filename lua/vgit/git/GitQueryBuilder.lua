local lazy = require('vgit.core.lazy')
local Object = lazy('vgit.core.Object')
local gitcli = lazy('vgit.git.gitcli')

local GitQueryBuilder = Object:extend()

local PAGINATED_COMMANDS = {
  log = true,
  stash = true,
}

local FILE_COMMANDS = {
  log = true,
  show = true,
  status = true,
  blame = true,
}

local REF_COMMANDS = {
  show = true,
  diff = true,
  ['diff-tree'] = true,
}

local REQUIRED_PARAMS = {
  blame = { file = true },
  ['diff-tree'] = { ref = true },
}

function GitQueryBuilder:constructor(repository)
  if not repository or type(repository) ~= 'string' then
    error('GitQueryBuilder: repository path (string) is required')
  end

  if repository:match('^%s*$') then error('GitQueryBuilder: repository path cannot be empty or whitespace') end

  return {
    _repository = repository,
    _command = nil,
    _args = {},
    _has_file = false,
    _has_ref = false,
    _has_pagination = false,
  }
end

function GitQueryBuilder:_require_command()
  if not self._command then
    error('GitQueryBuilder: command method (log/show/status/diff/blame/stash) must be called first')
  end
end

function GitQueryBuilder:_prevent_duplicate_command()
  if self._command then
    error(string.format('GitQueryBuilder: cannot call multiple command methods. Already using "%s"', self._command))
  end
end

function GitQueryBuilder:_validate_pagination()
  self:_require_command()
  if not PAGINATED_COMMANDS[self._command] then
    error(string.format('GitQueryBuilder: pagination not supported for "%s" command', self._command))
  end
end

function GitQueryBuilder:_validate_file_support()
  self:_require_command()
  if not FILE_COMMANDS[self._command] then
    error(string.format('GitQueryBuilder: file filtering not supported for "%s" command', self._command))
  end
end

function GitQueryBuilder:_validate_ref_support()
  self:_require_command()
  if not REF_COMMANDS[self._command] then
    error(string.format('GitQueryBuilder: refs not supported for "%s" command', self._command))
  end
end

function GitQueryBuilder:_validate_string(value, name)
  if type(value) ~= 'string' then
    error(string.format('GitQueryBuilder: %s must be a string, got %s', name, type(value)))
  end
  if value:match('^%s*$') then error(string.format('GitQueryBuilder: %s cannot be empty or whitespace', name)) end
end

function GitQueryBuilder:_validate_number(value, name, min)
  if type(value) ~= 'number' then
    error(string.format('GitQueryBuilder: %s must be a number, got %s', name, type(value)))
  end
  if min and value < min then error(string.format('GitQueryBuilder: %s must be >= %d, got %d', name, min, value)) end
end

function GitQueryBuilder:log()
  self:_prevent_duplicate_command()
  self._command = 'log'
  self:_add_arg('--no-pager')
  self:_add_arg('log')
  self:_add_arg('--color=never')
  return self
end

function GitQueryBuilder:show(ref)
  self:_prevent_duplicate_command()
  self._command = 'show'
  self:_add_arg('show')
  if ref then
    self:_validate_string(ref, 'ref')
    self:_add_arg(ref)
    self._has_ref = true
  end
  self:_add_arg('--color=never')
  return self
end

function GitQueryBuilder:status()
  self:_prevent_duplicate_command()
  self._command = 'status'
  self:_add_arg('--no-pager')
  self:_add_arg('status')
  self:_add_arg('-u')
  self:_add_arg('-s')
  self:_add_arg('--no-renames')
  self:_add_arg('--ignore-submodules')
  return self
end

function GitQueryBuilder:diff_tree()
  self:_prevent_duplicate_command()
  self._command = 'diff-tree'
  self:_add_arg('--no-pager')
  self:_add_arg('diff-tree')
  self:_add_arg('--no-commit-id')
  self:_add_arg('--name-status')
  self:_add_arg('-r')
  return self
end

function GitQueryBuilder:blame()
  self:_prevent_duplicate_command()
  self._command = 'blame'
  self:_add_arg('blame')
  return self
end

function GitQueryBuilder:stash()
  self:_prevent_duplicate_command()
  self._command = 'stash'
  self:_add_arg('--no-pager')
  self:_add_arg('stash')
  return self
end

function GitQueryBuilder:pretty(format_string)
  self:_require_command()
  self:_validate_string(format_string, 'format_string')
  self:_add_arg('--pretty=format:' .. format_string)
  return self
end

function GitQueryBuilder:paginate(count, offset)
  self:_validate_pagination()
  if self._has_pagination then error('GitQueryBuilder: limit/skip/paginate already called') end

  self:_validate_number(count, 'count', 1)
  if offset and offset > 0 then self:_validate_number(offset, 'offset', 0) end

  if count then
    self:_add_arg('-n')
    self:_add_arg(tostring(count))
  end

  if offset and offset > 0 then self:_add_arg(string.format('--skip=%d', offset)) end

  self._has_pagination = true
  return self
end

function GitQueryBuilder:file(filename)
  self:_validate_file_support()
  if self._has_file then error('GitQueryBuilder: file already called') end

  if filename then
    self:_validate_string(filename, 'filename')
    self:_add_arg('--')
    self:_add_arg(filename)
    self._has_file = true
  end
  return self
end

function GitQueryBuilder:refs(...)
  self:_validate_ref_support()

  local refs = { ... }
  if #refs == 0 then error('GitQueryBuilder: refs() requires at least one ref') end

  for i, ref in ipairs(refs) do
    if ref then
      self:_validate_string(ref, string.format('ref[%d]', i))
      self:_add_arg(ref)
      self._has_ref = true
    end
  end

  return self
end

function GitQueryBuilder:no_patch()
  self:_require_command()
  if self._command ~= 'show' then error('GitQueryBuilder: no_patch() only supported for show command') end
  self:_add_arg('--no-patch')

  return self
end

function GitQueryBuilder:subcommand(subcmd)
  self:_require_command()
  if self._command ~= 'stash' then error('GitQueryBuilder: subcommand() only supported for stash command') end

  if subcmd then
    self:_validate_string(subcmd, 'subcommand')
    local valid_stash_subcommands = {
      list = true,
      show = true,
      drop = true,
      pop = true,
      apply = true,
      branch = true,
      clear = true,
      create = true,
      store = true,
    }

    if not valid_stash_subcommands[subcmd] then
      error(string.format('GitQueryBuilder: invalid stash subcommand "%s"', subcmd))
    end

    self:_add_arg(subcmd)
  end

  return self
end

function GitQueryBuilder:option(key, value)
  self:_require_command()
  self:_validate_string(key, 'option key')

  if value then
    if type(value) ~= 'string' and type(value) ~= 'number' then
      error(string.format('GitQueryBuilder: option value must be string or number, got %s', type(value)))
    end
    self:_add_arg(string.format('--%s=%s', key, value))
  else
    self:_add_arg('--' .. key)
  end

  return self
end

function GitQueryBuilder:raw_arg(arg)
  if not self._command then self._command = 'raw' end
  if arg then
    self:_validate_string(arg, 'raw_arg')
    self:_add_arg(arg)
  end

  return self
end

function GitQueryBuilder:raw_args(...)
  if not self._command then self._command = 'raw' end

  local args = { ... }
  if #args == 0 then error('GitQueryBuilder: raw_args() requires at least one argument') end

  for i, arg in ipairs(args) do
    if arg then
      if type(arg) ~= 'string' and type(arg) ~= 'number' then
        error(string.format('GitQueryBuilder: raw_arg[%d] must be string or number, got %s', i, type(arg)))
      end
      self:_add_arg(tostring(arg))
    end
  end

  return self
end

function GitQueryBuilder:to_args()
  local args = { '-C', self._repository }
  for _, arg in ipairs(self._args) do
    args[#args + 1] = arg
  end

  return args
end

function GitQueryBuilder:to_command()
  local args = self:to_args()
  return 'git ' .. table.concat(args, ' ')
end

function GitQueryBuilder:execute(opts)
  self:_validate_query()
  local args = self:to_args()
  return gitcli.run(args, opts)
end

function GitQueryBuilder:_validate_query()
  if self._command == 'raw' then return end

  local required = REQUIRED_PARAMS[self._command]
  if required then
    if required.file and not self._has_file then
      error(string.format('GitQueryBuilder: %s command requires a file to be specified', self._command))
    end
    if required.ref and not self._has_ref then
      error(string.format('GitQueryBuilder: %s command requires refs to be specified', self._command))
    end
  end
end

function GitQueryBuilder:_add_arg(arg)
  if arg ~= nil then self._args[#self._args + 1] = arg end
end

return GitQueryBuilder
