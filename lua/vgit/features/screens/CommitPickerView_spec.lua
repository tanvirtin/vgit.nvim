local eq = assert.are.same

-- Clear lazy cache and module cache to ensure fresh mocks
package.loaded['vgit.core.lazy'] = nil
package.loaded['vgit.features.screens.CommitPickerView'] = nil
package.loaded['vgit.cli.commands.show'] = nil
package.loaded['vgit.ui.components.SearchComponent'] = nil
package.loaded['vgit.core.event'] = nil
package.loaded['vgit.git.git_log'] = nil

-- Stub modules before requiring CommitPickerView
local show_execute_args = nil
package.loaded['vgit.cli.commands.show'] = {
  execute = function(args)
    show_execute_args = args
  end,
}

package.loaded['vgit.core.event'] = {
  async = function(fn)
    return function(...)
      return fn(...)
    end
  end,
  await = function() end,
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
local mount_called = false
local close_called = false
local set_items_called_with = nil
local SearchComponentMock = setmetatable({}, {
  __call = function(_, props)
    mounted_props = props
    return {
      mounted = true,
      _loading = false,
      mount = function()
        mount_called = true
      end,
      close = function()
        close_called = true
      end,
      render = function() end,
      set_loading = function() end,
      set_items = function(_, items)
        set_items_called_with = items
      end,
    }
  end,
})
package.loaded['vgit.ui.components.SearchComponent'] = SearchComponentMock

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
  }
end

describe('CommitPickerView:', function()
  before_each(function()
    show_execute_args = nil
    mounted_props = nil
    mount_called = false
    close_called = false
    set_items_called_with = nil
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

    it('should create search component and mount it', function()
      local view = CommitPickerView()
      local result = view:create(make_data())

      assert.is_true(result)
      assert.is_true(mount_called)
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
    it('should call show_command.execute with correct hash', function()
      local view = CommitPickerView()
      view:create(make_data())

      view._destroyed = false
      view._search_component = {
        close = function()
          close_called = true
        end,
      }
      view:_on_select('abc1234567890')

      eq({ 'abc1234567890' }, show_execute_args)
    end)

    it('should handle nil value gracefully', function()
      local view = CommitPickerView()
      view:create(make_data())

      view._destroyed = false
      view._search_component = {
        close = function()
          close_called = true
        end,
      }
      view:_on_select(nil)

      assert.is_nil(show_execute_args)
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
      view._repo_path = '/tmp/repo'

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
      view._destroyed = false
      view._search_component = {
        close = function()
          close_called = true
        end,
      }

      view:destroy()
      assert.is_true(view._destroyed)
      assert.is_true(close_called)

      close_called = false
      view:destroy()
      assert.is_false(close_called)
    end)

    it('should clean up search component', function()
      local view = CommitPickerView()
      view._destroyed = false
      view._search_component = {
        close = function()
          close_called = true
        end,
      }

      view:destroy()
      assert.is_true(close_called)
      assert.is_nil(view._search_component)
    end)
  end)
end)
