local lazy = require('vgit.core.lazy')

local event = lazy('vgit.core.event')
local console = lazy('vgit.core.console')
local repository = lazy('vgit.git.repository')
local CommitView = lazy('vgit.features.screens.CommitView')

local commit_command = {}

commit_command.execute = event.async(function()
  event.await()

  local repo, repo_err = repository.current()
  if repo_err then
    console.error(repo_err)
    return
  end

  local confirm_key = '<C-s>'
  local cancel_key = 'q'

  local lines = { '' }
  lines[#lines + 1] = '# Press ' .. confirm_key .. ' to confirm, ' .. cancel_key .. ' to cancel.'
  lines[#lines + 1] = '# Lines starting with # will be ignored.'

  local refs = repo:refs()
  if refs then
    local branch = refs:current_branch()
    if branch then
      lines[#lines + 1] = '#'
      lines[#lines + 1] = '# On branch ' .. branch
    end
  end

  local status_data, status_err = repo:status({})
  if not status_err and status_data and status_data.entries then
    for _, group in ipairs(status_data.entries) do
      if group.entries and #group.entries > 0 then
        lines[#lines + 1] = '#'
        lines[#lines + 1] = '# ' .. group.title .. ':'
        for _, entry in ipairs(group.entries) do
          if entry.status then lines[#lines + 1] = '#   ' .. entry.status.value .. ' ' .. entry.status.filename end
        end
      end
    end
  end

  local commit_view = CommitView()

  commit_view:create({
    filetype = 'gitcommit',
    confirm_key = confirm_key,
    cancel_key = cancel_key,
    on_confirm = function()
      if not commit_view:is_valid() then return end
      local commit_lines = commit_view:get_lines()

      local message_lines = {}
      for _, line in ipairs(commit_lines) do
        if not vim.startswith(line, '#') then message_lines[#message_lines + 1] = line end
      end

      commit_view:destroy()

      local message = table.concat(message_lines, '\n')
      message = message:match('^%s*(.-)%s*$') or ''

      if message == '' then
        console.info('Commit cancelled: empty message')
        return
      end

      local _, err = repo:commit(message)
      if err then
        console.error(err)
        return
      end

      console.info('Changes committed successfully')
    end,
    on_cancel = function()
      commit_view:destroy()
      console.info('Commit cancelled')
    end,
  })

  commit_view:set_lines(lines)
  commit_view:set_cursor({ 1, 0 })
  commit_view:start_insert()
end)

return commit_command
