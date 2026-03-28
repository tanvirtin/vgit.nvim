local lazy = require('vgit.core.lazy')

local Object = lazy('vgit.core.Object')

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

      lens = { type = 'boolean', description = 'Lens mode' },
      screen = { type = 'boolean', description = 'Screen mode (default)' },
    },
  },
}

GitPorcelain._commands = GIT_COMMANDS

function GitPorcelain:get_command(command_name)
  return self._commands[command_name]
end

return GitPorcelain
