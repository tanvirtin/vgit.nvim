local GitHistory = require('vgit.git.GitHistory')
local git_log = require('vgit.git.git_log')

describe('GitHistory', function()
  local mock_commits = {
    {
      author_name = 'Alice',
      author_email = 'alice@example.com',
      timestamp = '1700000000',
      summary = 'fix: resolve login bug',
    },
    {
      author_name = 'Bob',
      author_email = 'bob@example.com',
      timestamp = '1700100000',
      summary = 'feat: add dashboard',
    },
    {
      author_name = 'Alice',
      author_email = 'alice@example.com',
      timestamp = '1700200000',
      summary = 'chore: update deps',
    },
    {
      author_name = 'Charlie',
      author_email = 'charlie@example.com',
      timestamp = '1700300000',
      summary = 'fix: crash on startup',
    },
  }

  local original_list

  before_each(function()
    original_list = git_log.list
  end)

  after_each(function()
    git_log.list = original_list
  end)

  local function stub_commits(commits, err)
    git_log.list = function()
      if err then return nil, err end
      return commits, nil
    end
  end

  local function make_repo()
    return { get_path = function() return '/tmp/test-repo' end }
  end

  describe('constructor', function()
    it('should error when repository is nil', function()
      assert.has_error(function()
        GitHistory(nil)
      end, 'GitHistory requires a repository')
    end)

    it('should store opts correctly', function()
      stub_commits(mock_commits)
      local history = GitHistory(make_repo(), { count = 10, skip = 5, path = 'src/main.lua', from = 'main' })
      assert.is_not_nil(history)
    end)
  end)

  describe('commits', function()
    it('should fetch and cache commits', function()
      local call_count = 0
      git_log.list = function()
        call_count = call_count + 1
        return mock_commits, nil
      end

      local history = GitHistory(make_repo())
      local result1 = history:commits()
      local result2 = history:commits()

      assert.are.same(mock_commits, result1)
      assert.are.same(mock_commits, result2)
      assert.are.equal(1, call_count)
    end)

    it('should propagate errors', function()
      stub_commits(nil, { 'git error' })
      local history = GitHistory(make_repo())
      local result, err = history:commits()
      assert.is_nil(result)
      assert.is_not_nil(err)
    end)
  end)

  describe('at', function()
    it('should return commit at valid index', function()
      stub_commits(mock_commits)
      local history = GitHistory(make_repo())
      local commit, err = history:at(1)
      assert.is_nil(err)
      assert.are.equal('Alice', commit.author_name)
    end)

    it('should return last commit', function()
      stub_commits(mock_commits)
      local history = GitHistory(make_repo())
      local commit, err = history:at(4)
      assert.is_nil(err)
      assert.are.equal('Charlie', commit.author_name)
    end)

    it('should error on nil index', function()
      stub_commits(mock_commits)
      local history = GitHistory(make_repo())
      local commit, err = history:at(nil)
      assert.is_nil(commit)
      assert.is_not_nil(err)
    end)

    it('should error on zero index', function()
      stub_commits(mock_commits)
      local history = GitHistory(make_repo())
      local commit, err = history:at(0)
      assert.is_nil(commit)
      assert.is_not_nil(err)
    end)

    it('should error on negative index', function()
      stub_commits(mock_commits)
      local history = GitHistory(make_repo())
      local commit, err = history:at(-1)
      assert.is_nil(commit)
      assert.is_not_nil(err)
    end)

    it('should error on out-of-bounds index', function()
      stub_commits(mock_commits)
      local history = GitHistory(make_repo())
      local commit, err = history:at(100)
      assert.is_nil(commit)
      assert.is_not_nil(err)
    end)
  end)

  describe('first', function()
    it('should return first commit', function()
      stub_commits(mock_commits)
      local history = GitHistory(make_repo())
      local commit, err = history:first()
      assert.is_nil(err)
      assert.are.equal('Alice', commit.author_name)
      assert.are.equal('fix: resolve login bug', commit.summary)
    end)

    it('should propagate error when commits fail', function()
      stub_commits(nil, { 'error' })
      local history = GitHistory(make_repo())
      local commit, err = history:first()
      assert.is_nil(commit)
      assert.is_not_nil(err)
    end)
  end)

  describe('last', function()
    it('should return last commit', function()
      stub_commits(mock_commits)
      local history = GitHistory(make_repo())
      local commit, err = history:last()
      assert.is_nil(err)
      assert.are.equal('Charlie', commit.author_name)
    end)

    it('should propagate error', function()
      stub_commits(nil, { 'error' })
      local history = GitHistory(make_repo())
      local commit, err = history:last()
      assert.is_nil(commit)
      assert.is_not_nil(err)
    end)
  end)

  describe('count', function()
    it('should return number of commits', function()
      stub_commits(mock_commits)
      local history = GitHistory(make_repo())
      local n, err = history:count()
      assert.is_nil(err)
      assert.are.equal(4, n)
    end)

    it('should return 0 for empty commits', function()
      stub_commits({})
      local history = GitHistory(make_repo())
      local n, err = history:count()
      assert.is_nil(err)
      assert.are.equal(0, n)
    end)

    it('should propagate error', function()
      stub_commits(nil, { 'error' })
      local history = GitHistory(make_repo())
      local n, err = history:count()
      assert.is_nil(n)
      assert.is_not_nil(err)
    end)
  end)

  describe('is_empty', function()
    it('should return false for non-empty', function()
      stub_commits(mock_commits)
      local history = GitHistory(make_repo())
      assert.is_false(history:is_empty())
    end)

    it('should return true for empty commits', function()
      stub_commits({})
      local history = GitHistory(make_repo())
      assert.is_true(history:is_empty())
    end)

    it('should return true on error', function()
      stub_commits(nil, { 'error' })
      local history = GitHistory(make_repo())
      assert.is_true(history:is_empty())
    end)
  end)

  describe('by_author', function()
    it('should filter commits by author name', function()
      stub_commits(mock_commits)
      local history = GitHistory(make_repo())
      local filtered, err = history:by_author('Alice')
      assert.is_nil(err)
      assert.are.equal(2, #filtered)
      assert.are.equal('Alice', filtered[1].author_name)
      assert.are.equal('Alice', filtered[2].author_name)
    end)

    it('should return empty for unknown author', function()
      stub_commits(mock_commits)
      local history = GitHistory(make_repo())
      local filtered, err = history:by_author('Unknown')
      assert.is_nil(err)
      assert.are.equal(0, #filtered)
    end)

    it('should error when author_name is nil', function()
      stub_commits(mock_commits)
      local history = GitHistory(make_repo())
      local filtered, err = history:by_author(nil)
      assert.is_nil(filtered)
      assert.is_not_nil(err)
    end)

    it('should propagate error from commits', function()
      stub_commits(nil, { 'error' })
      local history = GitHistory(make_repo())
      local filtered, err = history:by_author('Alice')
      assert.is_nil(filtered)
      assert.is_not_nil(err)
    end)
  end)

  describe('by_date_range', function()
    it('should filter commits by timestamp range (inclusive)', function()
      stub_commits(mock_commits)
      local history = GitHistory(make_repo())
      local filtered, err = history:by_date_range(1700000000, 1700200000)
      assert.is_nil(err)
      assert.are.equal(3, #filtered)
    end)

    it('should return empty when range has no matches', function()
      stub_commits(mock_commits)
      local history = GitHistory(make_repo())
      local filtered, err = history:by_date_range(1600000000, 1600100000)
      assert.is_nil(err)
      assert.are.equal(0, #filtered)
    end)

    it('should return single match for exact timestamp', function()
      stub_commits(mock_commits)
      local history = GitHistory(make_repo())
      local filtered, err = history:by_date_range(1700100000, 1700100000)
      assert.is_nil(err)
      assert.are.equal(1, #filtered)
      assert.are.equal('Bob', filtered[1].author_name)
    end)

    it('should error when start_timestamp is nil', function()
      stub_commits(mock_commits)
      local history = GitHistory(make_repo())
      local filtered, err = history:by_date_range(nil, 1700200000)
      assert.is_nil(filtered)
      assert.is_not_nil(err)
    end)

    it('should error when end_timestamp is nil', function()
      stub_commits(mock_commits)
      local history = GitHistory(make_repo())
      local filtered, err = history:by_date_range(1700000000, nil)
      assert.is_nil(filtered)
      assert.is_not_nil(err)
    end)
  end)

  describe('search', function()
    it('should filter commits by pattern match on summary', function()
      stub_commits(mock_commits)
      local history = GitHistory(make_repo())
      local filtered, err = history:search('fix:')
      assert.is_nil(err)
      assert.are.equal(2, #filtered)
    end)

    it('should return empty when pattern has no matches', function()
      stub_commits(mock_commits)
      local history = GitHistory(make_repo())
      local filtered, err = history:search('nonexistent')
      assert.is_nil(err)
      assert.are.equal(0, #filtered)
    end)

    it('should support Lua patterns', function()
      stub_commits(mock_commits)
      local history = GitHistory(make_repo())
      local filtered, err = history:search('^feat:')
      assert.is_nil(err)
      assert.are.equal(1, #filtered)
      assert.are.equal('feat: add dashboard', filtered[1].summary)
    end)

    it('should error when pattern is nil', function()
      stub_commits(mock_commits)
      local history = GitHistory(make_repo())
      local filtered, err = history:search(nil)
      assert.is_nil(filtered)
      assert.is_not_nil(err)
    end)
  end)

  describe('authors', function()
    it('should return unique authors deduplicated by email', function()
      stub_commits(mock_commits)
      local history = GitHistory(make_repo())
      local result, err = history:authors()
      assert.is_nil(err)
      assert.are.equal(3, #result) -- Alice, Bob, Charlie (Alice appears twice but same email)
    end)

    it('should return name and email for each author', function()
      stub_commits(mock_commits)
      local history = GitHistory(make_repo())
      local result = history:authors()
      for _, author in ipairs(result) do
        assert.is_not_nil(author.name)
        assert.is_not_nil(author.email)
      end
    end)

    it('should return empty for empty commits', function()
      stub_commits({})
      local history = GitHistory(make_repo())
      local result, err = history:authors()
      assert.is_nil(err)
      assert.are.equal(0, #result)
    end)
  end)

  describe('iter', function()
    it('should yield index and commit pairs in order', function()
      stub_commits(mock_commits)
      local history = GitHistory(make_repo())
      local collected = {}
      for i, commit in history:iter() do
        collected[#collected + 1] = { i = i, commit = commit }
      end
      assert.are.equal(4, #collected)
      assert.are.equal(1, collected[1].i)
      assert.are.equal('Alice', collected[1].commit.author_name)
      assert.are.equal(4, collected[4].i)
      assert.are.equal('Charlie', collected[4].commit.author_name)
    end)

    it('should return no-op iterator on error', function()
      stub_commits(nil, { 'error' })
      local history = GitHistory(make_repo())
      local count = 0
      for _ in history:iter() do
        count = count + 1
      end
      assert.are.equal(0, count)
    end)

    it('should handle empty commits', function()
      stub_commits({})
      local history = GitHistory(make_repo())
      local count = 0
      for _ in history:iter() do
        count = count + 1
      end
      assert.are.equal(0, count)
    end)
  end)

  describe('load_more', function()
    it('should append new commits to cache', function()
      local call_count = 0
      git_log.list = function(_, opts)
        call_count = call_count + 1
        if call_count == 1 then
          return { mock_commits[1], mock_commits[2] }, nil
        else
          return { mock_commits[3], mock_commits[4] }, nil
        end
      end

      local history = GitHistory(make_repo())
      history:commits() -- initial load

      local new_commits, err = history:load_more(2)
      assert.is_nil(err)
      assert.are.equal(2, #new_commits)

      local total, _ = history:count()
      assert.are.equal(4, total)
    end)

    it('should pass correct skip based on current count', function()
      local captured_opts
      git_log.list = function(_, opts)
        captured_opts = opts
        return { mock_commits[1], mock_commits[2] }, nil
      end

      local history = GitHistory(make_repo())
      history:commits() -- loads 2 commits

      git_log.list = function(_, opts)
        captured_opts = opts
        return {}, nil
      end

      history:load_more(5)
      assert.are.equal(2, captured_opts.pagination.skip)
      assert.are.equal(5, captured_opts.pagination.count)
    end)

    it('should error when count is nil', function()
      stub_commits(mock_commits)
      local history = GitHistory(make_repo())
      local result, err = history:load_more(nil)
      assert.is_nil(result)
      assert.is_not_nil(err)
    end)

    it('should error when count is 0', function()
      stub_commits(mock_commits)
      local history = GitHistory(make_repo())
      local result, err = history:load_more(0)
      assert.is_nil(result)
      assert.is_not_nil(err)
    end)

    it('should error when count is negative', function()
      stub_commits(mock_commits)
      local history = GitHistory(make_repo())
      local result, err = history:load_more(-1)
      assert.is_nil(result)
      assert.is_not_nil(err)
    end)

    it('should work when no commits loaded yet', function()
      git_log.list = function()
        return { mock_commits[1] }, nil
      end

      local history = GitHistory(make_repo())
      local result, err = history:load_more(1)
      assert.is_nil(err)
      assert.are.equal(1, #result)

      local total, _ = history:count()
      assert.are.equal(1, total)
    end)
  end)

  describe('reset', function()
    it('should clear cached commits so next call re-fetches', function()
      local call_count = 0
      git_log.list = function()
        call_count = call_count + 1
        return mock_commits, nil
      end

      local history = GitHistory(make_repo())
      history:commits()
      assert.are.equal(1, call_count)

      history:reset()
      history:commits()
      assert.are.equal(2, call_count)
    end)
  end)
end)
