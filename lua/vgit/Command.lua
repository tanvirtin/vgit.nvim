local console = require('vgit.core.console')
local Object = require('vgit.core.Object')

local Command = Object:extend()

function Command:new()
  return setmetatable({
    commands = {
      setup = true,
      hunk_up = true,
      hunk_down = true,
      stage_all = true,
      unstage_all = true,
      reset_all = true,
      buffer_hunk_preview = true,
      buffer_diff_preview = true,
      buffer_history_preview = true,
      buffer_blame_preview = true,
      buffer_gutter_blame_preview = true,
      buffer_diff_staged_preview = true,
      buffer_hunk_staged_preview = true,
      project_diff_preview = true,
      project_hunks_preview = true,
      project_hunks_qf = true,
      buffer_hunk_stage = true,
      buffer_hunk_reset = true,
      buffer_stage = true,
      buffer_unstage = true,
      buffer_reset = true,
      toggle_diff_preference = true,
      toggle_buffer_hunks = true,
      toggle_buffer_blames = true,
      enable_tracing = true,
      disable_tracing = true,
    },
  }, Command)
end

function Command:execute(command, ...)
  local vgit = require('vgit')
  if not self.commands[command] then
    console.error('Invalid command')
    return self
  end
  vgit[command](...)
  return self
end

function Command:list(arglead, line)
  local matches = {}
  if #vim.split(line, '%s+') == 2 then
    for command in pairs(self.commands) do
      if vim.startswith(command, arglead) then
        matches[#matches + 1] = command
      end
    end
  end
  return matches
end

return Command
