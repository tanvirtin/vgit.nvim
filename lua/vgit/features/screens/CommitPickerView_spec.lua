local eq = assert.are.same

-- Clear lazy cache and module cache to ensure fresh mocks
package.loaded['vgit.core.lazy'] = nil
package.loaded['vgit.features.screens.CommitPickerView'] = nil
package.loaded['vgit.ui.components.SearchComponent'] = nil
package.loaded['vgit.ui.ComponentManager'] = nil
package.loaded['vgit.ui.Layout'] = nil
package.loaded['vgit.core.event'] = nil
package.loaded['vgit.git.git_log'] = nil
package.loaded['vgit.git.repository'] = nil
package.loaded['vgit.git.GitTree'] = nil
package.loaded['vgit.settings.scene'] = nil
package.loaded['vgit.ui.display_service'] = nil

-- Stub modules before requiring CommitPickerView
local display_service_show_diff_data = nil
package.loaded['vgit.ui.display_service'] = {
  show_diff = function(data)
    display_service_show_diff_data = data
  end,
  show_blame_view = function() end,
}

local mock_tree_commit = nil
local mock_tree_files = nil

local mock_repo = {
  diff = function(_, spec)
    return { hunks = {} }
  end,
  file_lines = function(_, filename, ref)
    return {}
  end,
  log_search = function(_, opts)
    return {}, nil
  end,
  tree = function(_, commit_ref)
    return {
      commit = function()
        return mock_tree_commit, nil
      end,
      files = function()
        return mock_tree_files, nil
      end,
    }
  end,
}
package.loaded['vgit.git.repository'] = {
  current = function()
    return mock_repo, nil
  end,
}
package.loaded['vgit.git.GitTree'] = setmetatable({}, {
  __call = function(_, repo, commit_ref)
    return {
      commit = function()
        return mock_tree_commit, nil
      end,
      files = function()
        return mock_tree_files, nil
      end,
    }
  end,
})

package.loaded['vgit.settings.scene'] = {
  get = function(_, key)
    return 'unified'
  end,
}

package.loaded['vgit.core.event'] = {
  async = function(fn)
    return function(...)
      return fn(...)
    end
  end,
  await = function() end,
  all = function(funcs)
    local results = {}
    for i, fn in ipairs(funcs) do
      results[i] = fn()
    end
    return results
  end,
  debounce = function(fn)
    return fn, function() end
  end,
}

local git_log_calls = {}
package.loaded['vgit.git.git_log'] = {
  list = function(repo_path, opts)
    git_log_calls[#git_log_calls + 1] = { repo_path = repo_path, opts = opts }
    return {}, nil
  end,
}

local mounted_props = nil
local close_called = false
local set_items_called_with = nil
local SearchComponentMock = setmetatable({}, {
  __call = function(_, props)
    mounted_props = props
    return {
      mounted = true,
      _mounted = true,
      _loading = false,
      close = function()
        close_called = true
      end,
      render = function() end,
      is_mounted = function(self)
        return self._mounted
      end,
      set_loading = function() end,
      set_items = function(_, items)
        set_items_called_with = items
      end,
    }
  end,
})
package.loaded['vgit.ui.components.SearchComponent'] = SearchComponentMock

local cm_render_called = false
local cm_render_config = nil
local cm_destroy_called = false
local ComponentManagerMock = setmetatable({}, {
  __call = function()
    return {
      render = function(_, config)
        cm_render_called = true
        cm_render_config = config
      end,
      destroy = function()
        cm_destroy_called = true
      end,
    }
  end,
})
package.loaded['vgit.ui.ComponentManager'] = ComponentManagerMock

package.loaded['vgit.ui.Layout'] = {
  popup = function(component, opts)
    return { mode = 'popup', component = component }
  end,
  screen = function(component, opts)
    return { mode = 'screen', component = component }
  end,
  lens = function(component, opts)
    return { mode = 'lens', component = component }
  end,
}

local CommitPickerView = require('vgit.features.screens.CommitPickerView')

local function make_commit(opts)
  opts = opts or {}
  return {
    hash = opts.hash or 'abc1234567890abcdef1234567890abcdef123456',
    author = opts.author or 'John Doe',
    summary = opts.summary or 'Fix the login bug',
    short_hash = function(self, len)
      len = len or 7
      return self.hash:sub(1, len)
    end,
    age = function()
      return { unit = 2, how_long = 'hours', display = '2 hours ago' }
    end,
  }
end

local function make_mock_repo_for_data(overrides)
  overrides = overrides or {}
  return {
    log_search = overrides.log_search or function(_, opts)
      git_log_calls[#git_log_calls + 1] = { repo_path = overrides.repo_path or '/tmp/test-repo', opts = opts }
      return {}, nil
    end,
    tree = overrides.tree or function(_, commit_ref)
      return {
        commit = function()
          return mock_tree_commit, nil
        end,
        files = function()
          return mock_tree_files, nil
        end,
      }
    end,
  }
end

local function make_data(overrides)
  overrides = overrides or {}
  return {
    commits = overrides.commits or { make_commit() },
    history = overrides.history or {
      load_more = function()
        return {}, nil
      end,
      commits = function()
        return overrides.commits or { make_commit() }
      end,
    },
    repo_path = overrides.repo_path or '/tmp/test-repo',
    repo = overrides.repo or make_mock_repo_for_data({ repo_path = overrides.repo_path }),
  }
end

describe('CommitPickerView:', function()
  before_each(function()
    display_service_show_diff_data = nil
    mock_tree_commit = nil
    mock_tree_files = nil
    mounted_props = nil
    close_called = false
    set_items_called_with = nil
    cm_render_called = false
    cm_render_config = nil
    cm_destroy_called = false
    git_log_calls = {}
  end)

  describe('constructor', function()
    it('should initialize fields correctly', function()
      local view = CommitPickerView()
      assert.is_nil(view._search_component)
      assert.is_false(view._destroyed)
      assert.is_nil(view._history)
    end)
  end)

  describe('_build_items', function()
    it('should convert commits to items with correct format', function()
      local view = CommitPickerView()
      local commits = { make_commit() }
      local items = view:_build_items(commits)

      eq(1, #items)
      eq('abc1234  Fix the login bug', items[1].label)
      eq('John Doe · 2 hours ago', items[1].description)
      eq('abc1234567890abcdef1234567890abcdef123456', items[1].value)
      eq('abc1234 Fix the login bug John Doe', items[1].search_text)
    end)

    it('should handle empty list', function()
      local view = CommitPickerView()
      local items = view:_build_items({})
      eq({}, items)
    end)

    it('should truncate long messages', function()
      local view = CommitPickerView()
      local long_message = string.rep('a', 80)
      local commits = { make_commit({ summary = long_message }) }
      local items = view:_build_items(commits)

      local expected_summary = string.rep('a', 57) .. '...'
      assert.is_true(items[1].label:find(expected_summary, 1, true) ~= nil)
    end)

    it('should handle multiple commits', function()
      local view = CommitPickerView()
      local commits = {
        make_commit({ hash = 'aaa1111000000000000000000000000000000000', summary = 'First commit', author = 'Alice' }),
        make_commit({ hash = 'bbb2222000000000000000000000000000000000', summary = 'Second commit', author = 'Bob' }),
      }
      local items = view:_build_items(commits)

      eq(2, #items)
      eq('aaa1111  First commit', items[1].label)
      eq('bbb2222  Second commit', items[2].label)
      eq('Alice · 2 hours ago', items[1].description)
      eq('Bob · 2 hours ago', items[2].description)
    end)
  end)

  describe('create', function()
    it('should return false for nil data', function()
      local view = CommitPickerView()
      assert.is_false(view:create(nil))
    end)

    it('should return false for non-table data', function()
      local view = CommitPickerView()
      assert.is_false(view:create('invalid'))
    end)

    it('should return false for missing commits', function()
      local view = CommitPickerView()
      assert.is_false(view:create({ history = {} }))
    end)

    it('should return false for empty commits', function()
      local view = CommitPickerView()
      assert.is_false(view:create({ commits = {}, history = {} }))
    end)

    it('should return false for missing history', function()
      local view = CommitPickerView()
      assert.is_false(view:create({ commits = { make_commit() } }))
    end)

    it('should create search component and render via ComponentManager', function()
      local view = CommitPickerView()
      local result = view:create(make_data())

      assert.is_true(result)
      assert.is_true(cm_render_called)
      assert.is_not_nil(cm_render_config)
      eq('popup', cm_render_config.mode)
      assert.is_not_nil(mounted_props)
      eq(1, #mounted_props.items)
      eq('60vw', mounted_props.width)
      eq(15, mounted_props.max_height)
      eq(25, mounted_props.page_size)
    end)

    it('should store repo_path', function()
      local view = CommitPickerView()
      view:create(make_data({ repo_path = '/my/repo' }))
      eq('/my/repo', view._repo_path)
    end)
  end)

  describe('_on_search', function()
    it('should restore original items when query is empty', function()
      local commits = { make_commit() }
      local view = CommitPickerView()
      view:create(make_data({ commits = commits }))

      view:_on_search('')

      assert.is_not_nil(set_items_called_with)
      eq(1, #set_items_called_with)
    end)

    it('should call git_log.list with grep when query is non-empty', function()
      local view = CommitPickerView()
      view:create(make_data({ repo_path = '/tmp/repo' }))

      view:_on_search('fix bug')

      eq(1, #git_log_calls)
      eq('/tmp/repo', git_log_calls[1].repo_path)
      eq('fix bug', git_log_calls[1].opts.grep)
      eq(100, git_log_calls[1].opts.pagination.count)
      eq(0, git_log_calls[1].opts.pagination.skip)
    end)

    it('should increment search version to cancel stale results', function()
      local view = CommitPickerView()
      view:create(make_data())

      eq(0, view._search_version)
      view:_on_search('first')
      eq(1, view._search_version)
      view:_on_search('second')
      eq(2, view._search_version)
    end)
  end)

  describe('_on_select', function()
    it('should build diff data and call display_service.show_diff', function()
      mock_tree_commit = {
        commit_hash = 'abc1234567890',
        parent_hash = 'def0000000000',
        hash = 'abc1234567890',
        author = 'John Doe',
        author_mail = 'john@example.com',
        author_time = '1234567890',
        message = 'Fix the login bug',
      }
      mock_tree_files = {
        {
          filename = 'file.lua',
          old_filename = nil,
          get_filetype = function()
            return 'lua'
          end,
        },
      }

      local view = CommitPickerView()
      view:create(make_data())

      view._destroyed = false
      view:_on_select('abc1234567890')

      assert.is_not_nil(display_service_show_diff_data)
      eq('files', display_service_show_diff_data.type)
      eq('unified', display_service_show_diff_data.layout_type)
      eq('abc1234567890', display_service_show_diff_data.commit_info.hash)
      eq(1, #display_service_show_diff_data.entries)
      eq(1, #display_service_show_diff_data.entries[1].entries)
      eq('file.lua', display_service_show_diff_data.entries[1].entries[1].filename)
    end)

    it('should handle nil value gracefully', function()
      local view = CommitPickerView()
      view:create(make_data())

      view._destroyed = false
      view:_on_select(nil)

      assert.is_nil(display_service_show_diff_data)
    end)
  end)

  describe('_on_load_more', function()
    it('should return items from history:load_more when no search query', function()
      local view = CommitPickerView()
      local new_commit = make_commit({ hash = 'def5678000000000000000000000000000000000', summary = 'New commit' })
      view._history = {
        load_more = function()
          return { new_commit }, nil
        end,
      }
      view._search_query = ''

      local items = view:_on_load_more()

      assert.is_not_nil(items)
      eq(1, #items)
      eq('def5678  New commit', items[1].label)
    end)

    it('should search git log when search query is active', function()
      local view = CommitPickerView()
      view._search_query = 'fix'
      view._search_skip = 100
      view._repo = make_mock_repo_for_data({ repo_path = '/tmp/repo' })

      view:_on_load_more()

      eq(1, #git_log_calls)
      eq('fix', git_log_calls[1].opts.grep)
      eq(100, git_log_calls[1].opts.pagination.skip)
    end)

    it('should return nil when no more commits', function()
      local view = CommitPickerView()
      view._history = {
        load_more = function()
          return {}, nil
        end,
      }
      view._search_query = ''

      local items = view:_on_load_more()
      assert.is_nil(items)
    end)

    it('should return nil on error', function()
      local view = CommitPickerView()
      view._history = {
        load_more = function()
          return nil, { 'some error' }
        end,
      }
      view._search_query = ''

      local items = view:_on_load_more()
      assert.is_nil(items)
    end)
  end)

  describe('destroy', function()
    it('should set destroyed flag', function()
      local view = CommitPickerView()
      view:create(make_data())

      view._destroyed = false
      view:destroy()
      assert.is_true(view._destroyed)
    end)

    it('should be idempotent', function()
      local view = CommitPickerView()
      view:create(make_data())

      view._destroyed = false
      view:destroy()
      assert.is_true(view._destroyed)
      assert.is_true(cm_destroy_called)

      cm_destroy_called = false
      view:destroy()
      assert.is_false(cm_destroy_called)
    end)

    it('should clean up component manager and search component', function()
      local view = CommitPickerView()
      view:create(make_data())

      view._destroyed = false
      view:destroy()
      assert.is_true(cm_destroy_called)
      assert.is_nil(view._search_component)
      assert.is_nil(view._component_manager)
    end)
  end)
end)
