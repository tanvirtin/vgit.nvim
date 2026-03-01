local lazy = require('vgit.core.lazy')

local event = lazy('vgit.core.event')
local Object = lazy('vgit.core.Object')
local git_log = lazy('vgit.git.git_log')
local console = lazy('vgit.core.console')
local show_command = lazy('vgit.cli.commands.show')
local SearchComponent = lazy('vgit.ui.components.SearchComponent')

local CommitPickerView = Object:extend()

function CommitPickerView:constructor()
  return {
    _search_component = nil,
    _destroyed = false,
    _history = nil,
    _repo_path = nil,
    _search_query = '',
    _search_skip = 0,
    _search_version = 0,
  }
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
      self._destroyed = true
      self._search_component = nil
    end,
  })

  self._search_component:mount()

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
    local commits, err = git_log.list(self._repo_path, {
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

function CommitPickerView:_on_select(value)
  self:destroy()

  if not value then return end

  show_command.execute({ value })
end

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

  local commits, err = git_log.list(self._repo_path, {
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
  if self._destroyed then return end

  self._destroyed = true

  if self._search_cleanup then
    self._search_cleanup()
    self._search_cleanup = nil
  end

  if self._search_component then
    self._search_component:close()
    self._search_component = nil
  end
end

return CommitPickerView
