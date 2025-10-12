local Object = require('vgit.core.Object')

local GitPorcelain = Object:extend()

local GIT_COMMANDS = {
  diff = {
    description = 'Show changes between commits, commit and working tree, etc',
    options = {
      cached = { type = 'boolean', description = 'Show staged changes' },
      staged = { type = 'boolean', description = 'Alias for --cached' },

      name_only = { type = 'boolean', description = 'Show only names of changed files' },
      name_status = { type = 'boolean', description = 'Show names and status of changed files' },
      stat = { type = 'boolean', description = 'Show diffstat' },
      numstat = { type = 'boolean', description = 'Show numeric diffstat' },
      shortstat = { type = 'boolean', description = 'Show short diffstat' },
      summary = { type = 'boolean', description = 'Show summary' },

      unified = { type = 'number', description = 'Number of context lines', default = 3 },
      no_unified = { type = 'boolean', description = 'No context lines' },
      raw = { type = 'boolean', description = 'Raw format' },
      patch_with_raw = { type = 'boolean', description = 'Patch + raw format' },
      patch_with_stat = { type = 'boolean', description = 'Patch + stat format' },

      buffer = {
        type = 'number',
        description = 'Buffer number to diff (0 = current, defaults to current if flag present)',
        optional_value = true,
        default_when_present = 0,
      },

      split = { type = 'boolean', description = 'Split view layout' },
      unified_view = { type = 'boolean', description = 'Unified view layout' },
      lens = { type = 'boolean', description = 'Lens mode' },
      screen = { type = 'boolean', description = 'Screen mode (default)' },
    },
  },

  blame = {
    description = 'Show what revision and author last modified the current line',
    options = {
      line = { type = 'number', description = 'Line number to blame (defaults to current cursor line)' },

      C = { type = 'boolean', description = 'Find copies' },
      M = { type = 'boolean', description = 'Find moves' },

      w = { type = 'boolean', description = 'Ignore whitespace' },
      show_email = { type = 'boolean', description = 'Show email' },
      date = { type = 'string', description = 'Date format' },
      pretty = { type = 'string', description = 'Pretty format' },

      lens = { type = 'boolean', description = 'Lens mode' },
      screen = { type = 'boolean', description = 'Screen mode (default)' },
    },
  },
}

GitPorcelain._commands = GIT_COMMANDS

function GitPorcelain:get_commands()
  return self._commands
end

function GitPorcelain:get_command(command_name)
  return self._commands[command_name]
end

function GitPorcelain:parse_args(args)
  if not args or #args == 0 then
    return {
      command = nil,
      arguments = {},
      options = {},
      files = {},
      commits = {},
    }
  end

  local result = {
    command = args[1],
    arguments = {},
    options = {},
    files = {},
    commits = {},
  }

  local i = 2
  while i <= #args do
    local arg = args[i]

    -- Handle options
    if arg:match('^%-%-') then
      local option_name, option_value = arg:match('^%-%-([^=]+)=?(.*)$')
      local option_def = self._commands[result.command] and self._commands[result.command].options[option_name]

      if option_def then
        if option_def.type == 'boolean' then
          result.options[option_name] = true
        elseif option_def.type == 'string' or option_def.type == 'number' then
          -- Check if value is provided with = syntax
          if option_value and option_value ~= '' then
            if option_def.type == 'number' then
              result.options[option_name] = tonumber(option_value) or 0
            else
              result.options[option_name] = option_value
            end
          elseif option_def.optional_value and option_def.default_when_present ~= nil then
            -- Handle --option without value (use default)
            result.options[option_name] = option_def.default_when_present
          else
            -- Handle --option with separate value
            i = i + 1
            if i <= #args then
              if option_def.type == 'number' then
                result.options[option_name] = tonumber(args[i]) or 0
              else
                result.options[option_name] = args[i]
              end
            end
          end
        end
      end
    elseif arg:match('^%-') then
      local short_opts = arg:sub(2)
      for j = 1, #short_opts do
        local opt = short_opts:sub(j, j)
        result.options[opt] = true
      end
    elseif arg:match('^[a-f0-9]{7,40}$') or arg:match('^HEAD$') or arg:match('^[A-Za-z0-9/_-]+$') then
      result.commits[#result.commits + 1] = arg
    else
      result.files[#result.files + 1] = arg
    end

    i = i + 1
  end

  return result
end

function GitPorcelain:validate(parsed)
  if not parsed.command then return true, nil end

  local command_def = self._commands[parsed.command]
  if not command_def then return false, string.format('Unknown command: %s', parsed.command) end

  for option_name, value in pairs(parsed.options) do
    local option_def = command_def.options[option_name]
    if not option_def then return false, string.format('Unknown option: --%s', option_name) end

    if option_def.type == 'number' and type(value) ~= 'number' then
      return false, string.format('Option --%s requires a number', option_name)
    end
  end

  if parsed.command == 'diff' then
    return self:_validate_diff_options(parsed)
  elseif parsed.command == 'blame' then
    return self:_validate_blame_options(parsed)
  end

  return true, nil
end

function GitPorcelain:_validate_diff_options(parsed)
  if parsed.options.split and parsed.options.unified_view then
    return false, 'Cannot use both --split and --unified options'
  end

  if parsed.options.lens and parsed.options.screen then return false, 'Cannot use both --lens and --screen options' end

  return true, nil
end

function GitPorcelain:_validate_blame_options(parsed)
  if parsed.options.lens and parsed.options.screen then return false, 'Cannot use both --lens and --screen options' end

  if parsed.options.line then
    if type(parsed.options.line) ~= 'number' or parsed.options.line < 1 then
      return false, 'Line number must be a positive integer'
    end
  end

  return true, nil
end

function GitPorcelain:get_display_mode(parsed)
  if parsed.options.lens then return 'lens' end
  if parsed.options.screen then return 'screen' end
  return 'screen'
end

function GitPorcelain:get_layout_type(parsed)
  if parsed.options.split then return 'split' end
  if parsed.options.unified_view then return 'unified' end
end

function GitPorcelain:get_git_diff_options(parsed)
  local git_opts = {}

  if parsed.options.cached or parsed.options.staged then git_opts[#git_opts + 1] = '--cached' end

  if parsed.options.unified then git_opts[#git_opts + 1] = '--unified=' .. parsed.options.unified end

  if parsed.options.no_unified then git_opts[#git_opts + 1] = '--unified=0' end

  if parsed.options.raw then git_opts[#git_opts + 1] = '--raw' end

  if parsed.options.patch_with_raw then git_opts[#git_opts + 1] = '--patch-with-raw' end

  if parsed.options.patch_with_stat then git_opts[#git_opts + 1] = '--patch-with-stat' end

  if parsed.options.name_only then git_opts[#git_opts + 1] = '--name-only' end

  if parsed.options.name_status then git_opts[#git_opts + 1] = '--name-status' end

  if parsed.options.stat then git_opts[#git_opts + 1] = '--stat' end

  if parsed.options.numstat then git_opts[#git_opts + 1] = '--numstat' end

  if parsed.options.shortstat then git_opts[#git_opts + 1] = '--shortstat' end

  if parsed.options.summary then git_opts[#git_opts + 1] = '--summary' end

  return git_opts
end

function GitPorcelain:get_git_blame_options(parsed)
  local git_opts = {}

  if parsed.options.line then
    git_opts[#git_opts + 1] = '-L'
    git_opts[#git_opts + 1] = string.format('%d,+1', parsed.options.line)
  end

  if parsed.options.C then git_opts[#git_opts + 1] = '-C' end

  if parsed.options.M then git_opts[#git_opts + 1] = '-M' end

  if parsed.options.w then git_opts[#git_opts + 1] = '-w' end

  if parsed.options.show_email then git_opts[#git_opts + 1] = '--show-email' end

  if parsed.options.date then git_opts[#git_opts + 1] = '--date=' .. parsed.options.date end

  if parsed.options.pretty then git_opts[#git_opts + 1] = '--pretty=' .. parsed.options.pretty end

  return git_opts
end

function GitPorcelain:get_help(command_name)
  local command_def = self._commands[command_name]
  if not command_def then return nil end

  local help = {
    string.format('vgit %s - %s', command_name, command_def.description),
    '',
    'Options:',
  }

  for option_name, option_def in pairs(command_def.options) do
    local type_str = option_def.type == 'boolean' and '' or ('=' .. option_def.type:upper())
    help[#help + 1] = string.format('  --%s%s    %s', option_name, type_str, option_def.description)
  end

  return table.concat(help, '\n')
end

function GitPorcelain:get_all_help()
  local help = { 'VGit - Git porcelain interface for Neovim', '', 'Available commands:', '' }

  for command_name, command_def in pairs(self._commands) do
    help[#help + 1] = string.format('  %s    %s', command_name, command_def.description)
  end

  help[#help + 1] = ''
  help[#help + 1] = 'Use "vgit <command> --help" for detailed help on a specific command.'

  return table.concat(help, '\n')
end

return GitPorcelain
