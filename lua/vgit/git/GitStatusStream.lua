local lazy = require('vgit.core.lazy')

local event = lazy('vgit.core.event')
local Object = lazy('vgit.core.Object')
local git_repo = lazy('vgit.git.git_repo')

local GitStatusStream = Object:extend()

GitStatusStream.MAX_RUNNING = 16
GitStatusStream.POLL_MS = 5

local function has_changes(group)
  return #group.entries > 0
end

function GitStatusStream:constructor(repos, opts)
  opts = opts or {}

  return {
    ['$_repos'] = repos,
    ['$_select_sections'] = opts.select_sections,
    _tasks = {},
    _started = 0,
    _running = 0,
  }
end

function GitStatusStream:is_done()
  return self._started == #self._repos and next(self._tasks) == nil
end

function GitStatusStream:collect()
  self:_start_more()

  local groups = {}
  for i = 1, self._started do
    local task = self._tasks[i]
    if task and task:is_done() then groups[#groups + 1] = self:_take(i) end
  end

  self:_start_more()
  return groups
end

function GitStatusStream:next()
  local groups = {}
  repeat
    vim.list_extend(groups, vim.tbl_filter(has_changes, self:collect()))
    if #groups == 0 and not self:is_done() then event.sleep(self.POLL_MS) end
  until #groups > 0 or self:is_done()
  return groups
end

function GitStatusStream:wait()
  local groups = {}
  while not self:is_done() do
    self:_start_more()
    for i = 1, self._started do
      if self._tasks[i] then groups[#groups + 1] = self:_take(i) end
    end
  end
  return groups
end

function GitStatusStream:_start_more()
  while self._running < self.MAX_RUNNING and self._started < #self._repos do
    self._started = self._started + 1
    self._running = self._running + 1
    self._tasks[self._started] = self._repos[self._started]:start_status()
  end
end

function GitStatusStream:_take(i)
  local data = self._tasks[i]:wait()
  self._tasks[i] = nil
  self._running = self._running - 1

  local repo = self._repos[i]
  local entries = data and data.entries or {}
  if self._select_sections then entries = self._select_sections(entries) end

  return { repo = repo, branch = git_repo.branch(repo:get_path()), entries = entries }
end

return GitStatusStream
