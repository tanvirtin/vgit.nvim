local console = require('vgit.core.console')
local Object = require('vgit.core.Object')
local Set = require('vgit.core.Set')

local Command = Object:extend()

function Command:constructor()
  return {
    deprecated = {},
    commands = Set({
      'setup',
      'hunk_up',
      'hunk_down',

      'checkout',

      'buffer_hunk_preview',
      'buffer_diff_preview',
      'buffer_history_preview',
      'buffer_blame_preview',
      'buffer_gutter_blame_preview',
      'buffer_diff_staged_preview',
      'buffer_hunk_staged_preview',
      'buffer_hunk_stage',
      'buffer_hunk_reset',
      'buffer_stage',
      'buffer_unstage',
      'buffer_reset',

      'project_hunks_qf',
      'project_reset_all',
      'project_stage_all',
      'project_unstage_all',
      'project_logs_preview',
      'project_stash_preview',
      'project_diff_preview',
      'project_hunks_preview',
      'project_debug_preview',
      'project_commits_preview',
      'project_hunks_staged_preview',

      'toggle_tracing',
      'toggle_diff_preference',
      'toggle_live_gutter',
      'toggle_live_blame',
      'toggle_authorship_code_lens',

      'h',
      'help',
    }),
  }
end

function Command:palette()
  local vgit = require('vgit')

  vim.ui.select(self.commands:to_list(), {
    prompt = 'VGit Commands:',
    format_item = function(item) return item end,
  }, function(command)
    if command then
      vgit[command]()
    end
  end)
end

function Command:execute(command, ...)
  local vgit = require('vgit')

  if command == nil then
    self:palette()
    return
  end

  if not self.commands:has(command) and not self.deprecated[command] then
    local err = 'Invalid command'
    console.debug.error(err).error(err)
    return self
  end

  if self.deprecated[command] then
    console.warn(
      string.format(
        'The command %s is deprecated and will be removed in the future, please use \'%s\' instead.',
        command,
        self.deprecated[command]
      )
    )
  end

  vgit[command](...)

  return self
end

function Command:list(arglead, line)
  local matches = {}

  if #vim.split(line, '%s+') == 2 then
    self.commands:for_each(function(command)
      if vim.startswith(command, arglead) then
        matches[#matches + 1] = command
      end
    end)
  end

  return matches
end

return Command
