local lazy = require('vgit.core.lazy')

local View = lazy('vgit.ui.View')
local event = lazy('vgit.core.event')
local console = lazy('vgit.core.console')
local repository = lazy('vgit.git.repository')
local scene_setting = lazy('vgit.settings.scene')
local display_service = lazy('vgit.ui.display_service')
local GitCommit = lazy('vgit.git.GitCommit')
local SearchComponent = lazy('vgit.ui.components.SearchComponent')

local CommitPickerView = View:extend()

function CommitPickerView:constructor()
  local instance = View.constructor(self)
  instance._search_component = nil
  instance._history = nil
  instance._repo = nil
  instance._repo_path = nil
  instance._search_query = ''
  instance._search_skip = 0
  instance._search_version = 0
  instance._search_cleanup = nil
  return instance
end

function CommitPickerView:_build_items(commits)
  local items = {}

  for i = 1, #commits do
    local commit = commits[i]
    local short_hash = commit:short_hash() or ''
    local summary = commit.summary or ''
    if #summary > 60 then summary = summary:sub(1, 57) .. '...' end
    local author = commit.author or ''
    local age = commit:age()
    local age_display = age and age.display or ''

    items[#items + 1] = {
      label = short_hash .. '  ' .. summary,
      description = author .. ' · ' .. age_display,
      value = commit.hash,
      search_text = short_hash .. ' ' .. summary .. ' ' .. author,
    }
  end

  return items
end

function CommitPickerView:create(data)
  if not data then return false end
  if type(data) ~= 'table' then return false end
  if not data.commits or #data.commits == 0 then return false end
  if not data.history then return false end

  self._history = data.history
  self._repo = data.repo
  self._repo_path = data.repo_path

  local debounced_search, cleanup = event.debounce(function(query)
    self:_on_search(query)
  end, 150)
  self._search_cleanup = cleanup

  local items = self:_build_items(data.commits)

  self._search_component = SearchComponent({
    items = items,
    width = '60vw',
    max_height = 15,
    page_size = 25,
    placeholder = 'No commits found',
    on_search_async = debounced_search,
    on_select = function(value)
      self:_on_select(value)
    end,
    on_load_more = function()
      return self:_on_load_more()
    end,
    on_close = function()
      self:destroy()
    end,
  })

  self:_render({
    component = self._search_component,
    mode = 'popup',
  })

  return true
end

function CommitPickerView:_on_search(query)
  self._search_query = query or ''
  self._search_skip = 0
  self._search_version = self._search_version + 1

  if self._search_query == '' then
    local commits = self._history:commits()
    if commits then
      self._search_component:set_items(self:_build_items(commits))
    else
      self._search_component:set_items({})
    end
    return
  end

  local version = self._search_version
  local sc = self._search_component

  sc:set_loading(true)

  event.async(function()
    local commits, err = self._repo:log_search({
      grep = self._search_query,
      pagination = { count = 100, skip = 0 },
    })

    vim.schedule(function()
      if not sc:is_mounted() then return end
      if self._search_version ~= version then return end

      self._search_skip = 100

      if err then
        console.debug.error(err)
        sc:set_items({})
        return
      end
      if not commits or #commits == 0 then
        sc:set_items({})
        return
      end

      sc:set_items(self:_build_items(commits))
    end)
  end)()
end

CommitPickerView._on_select = event.async(function(self, value)
  self:destroy()

  if not value then return end

  event.await()

  local repo, repo_err = repository.current()
  if repo_err then
    console.error(repo_err)
    return
  end

  local tree = repo:tree(value)

  local commit, commit_err = tree:commit()
  if commit_err then
    console.error('Failed to get commit info: ' .. tostring(commit_err))
    return
  end

  local files, files_err = tree:files()
  if files_err then
    console.error('Failed to get commit files: ' .. tostring(files_err))
    return
  end

  if not files or #files == 0 then
    console.info('No files changed in commit ' .. value)
    return
  end

  local layout_type = scene_setting:get('diff_preference') or 'unified'

  local parent_hash = commit.parent_hash or ''
  local from_ref = parent_hash ~= '' and parent_hash or GitCommit.EMPTY_TREE_HASH
  local to_ref = commit.commit_hash or commit.hash

  local funcs = {}
  for _, file in ipairs(files) do
    local filename = file.filename
    local file_old_filename = file.old_filename

    table.insert(funcs, function()
      local diff = repo:diff({
        type = 'range',
        filename = filename,
        old_filename = file_old_filename,
        from = from_ref,
        to = to_ref,
        layout_type = layout_type,
      })

      if not diff then return nil end

      local from_filename = file_old_filename or filename
      return {
        filename = filename,
        filetype = file.get_filetype and file:get_filetype() or 'text',
        diff = diff,
        status = file,
        original_lines = repo:file_lines(from_filename, from_ref) or {},
        current_lines = repo:file_lines(filename, to_ref) or {},
      }
    end)
  end

  local results = event.all(funcs)

  local entries = {}
  for i = 1, #funcs do
    if results[i] then table.insert(entries, results[i]) end
  end

  if #entries == 0 then
    console.info('No diffs available for commit ' .. value)
    return
  end

  local commit_info = {
    hash = commit.commit_hash or commit.hash,
    author = commit.author,
    author_mail = commit.author_mail,
    author_time = commit.author_time,
    message = commit.message,
  }

  local data = {
    type = 'files',
    entries = {
      {
        title = string.format('Commit: %s', (commit_info.hash or ''):sub(1, 7)),
        entries = entries,
      },
    },
    layout_type = layout_type,
    commit_info = commit_info,
  }

  display_service.show_diff(data)
end)

function CommitPickerView:_on_load_more()
  if self._search_query == '' then
    local new_commits, err = self._history:load_more(100)

    if err then
      console.debug.error(err)
      return nil
    end
    if not new_commits or #new_commits == 0 then return nil end

    return self:_build_items(new_commits)
  end

  local commits, err = self._repo:log_search({
    grep = self._search_query,
    pagination = { count = 100, skip = self._search_skip },
  })

  if err then
    console.debug.error(err)
    return nil
  end
  if not commits or #commits == 0 then return nil end

  self._search_skip = self._search_skip + #commits

  return self:_build_items(commits)
end

function CommitPickerView:destroy()
  if self:is_destroyed() then return end

  if self._search_cleanup then
    self._search_cleanup()
    self._search_cleanup = nil
  end

  View.destroy(self)
end

return CommitPickerView
