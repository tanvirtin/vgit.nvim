local GitHistory = require('vgit.git.GitHistory')
local test_repo = require('tests.helpers.test_repo')
test_repo.use_driver('raw')
local async = require('tests.helpers.async')({ it = it, before_each = before_each, after_each = after_each })

local eq = assert.are.same

local function make_repo(path)
  return { get_path = function() return path end }
end

describe('GitHistory:', function()
  describe('unit', function()
    describe('constructor', function()
      it('should error when repository is nil', function()
        assert.has_error(function()
          GitHistory(nil)
        end, 'GitHistory requires a repository')
      end)
    end)

    describe('at', function()
      it('should error on nil index', function()
        local history = GitHistory(make_repo('/tmp/fake'))
        local commit, err = history:at(nil)
        assert.is_nil(commit)
        assert.is_not_nil(err)
      end)

      it('should error on zero index', function()
        local history = GitHistory(make_repo('/tmp/fake'))
        local commit, err = history:at(0)
        assert.is_nil(commit)
        assert.is_not_nil(err)
      end)

      it('should error on negative index', function()
        local history = GitHistory(make_repo('/tmp/fake'))
        local commit, err = history:at(-1)
        assert.is_nil(commit)
        assert.is_not_nil(err)
      end)
    end)

    describe('by_author', function()
      it('should error when author_name is nil', function()
        local history = GitHistory(make_repo('/tmp/fake'))
        local filtered, err = history:by_author(nil)
        assert.is_nil(filtered)
        assert.is_not_nil(err)
      end)
    end)

    describe('by_date_range', function()
      it('should error when start_timestamp is nil', function()
        local history = GitHistory(make_repo('/tmp/fake'))
        local filtered, err = history:by_date_range(nil, 1700200000)
        assert.is_nil(filtered)
        assert.is_not_nil(err)
      end)

      it('should error when end_timestamp is nil', function()
        local history = GitHistory(make_repo('/tmp/fake'))
        local filtered, err = history:by_date_range(1700000000, nil)
        assert.is_nil(filtered)
        assert.is_not_nil(err)
      end)
    end)

    describe('search', function()
      it('should error when pattern is nil', function()
        local history = GitHistory(make_repo('/tmp/fake'))
        local filtered, err = history:search(nil)
        assert.is_nil(filtered)
        assert.is_not_nil(err)
      end)
    end)

    describe('load_more', function()
      it('should error when count is nil', function()
        local history = GitHistory(make_repo('/tmp/fake'))
        local result, err = history:load_more(nil)
        assert.is_nil(result)
        assert.is_not_nil(err)
      end)

      it('should error when count is 0', function()
        local history = GitHistory(make_repo('/tmp/fake'))
        local result, err = history:load_more(0)
        assert.is_nil(result)
        assert.is_not_nil(err)
      end)

      it('should error when count is negative', function()
        local history = GitHistory(make_repo('/tmp/fake'))
        local result, err = history:load_more(-1)
        assert.is_nil(result)
        assert.is_not_nil(err)
      end)
    end)
  end)

  describe('integration', function()
    local repo
    local it = async.it
    local before_each = async.before_each
    local after_each = async.after_each

    -- We create 4 commits total:
    -- 1. Initial commit by Test User <test@example.com> with file.txt ('initial')
    -- 2. 'fix: resolve login bug' by Alice <alice@example.com> with file2.txt
    -- 3. 'feat: add dashboard' by Bob <bob@example.com> with file3.txt
    -- 4. 'chore: update deps' by Alice <alice@example.com> with file4.txt
    --
    -- git log lists them newest-first, so order is:
    --   index 1: chore: update deps (Alice)
    --   index 2: feat: add dashboard (Bob)
    --   index 3: fix: resolve login bug (Alice)
    --   index 4: Initial commit (Test User)

    before_each(function()
      local err
      repo, err = test_repo.create_repo({
        initial_commit = true,
        files = { ['file.txt'] = { 'initial' } },
      })
      assert(not err, 'Failed to create test repo: ' .. tostring(err))

      test_repo.create_commit(repo, {
        files = { ['file2.txt'] = { 'second' } },
        message = 'fix: resolve login bug',
        author = 'Alice <alice@example.com>',
      })
      test_repo.create_commit(repo, {
        files = { ['file3.txt'] = { 'third' } },
        message = 'feat: add dashboard',
        author = 'Bob <bob@example.com>',
      })
      test_repo.create_commit(repo, {
        files = { ['file4.txt'] = { 'fourth' } },
        message = 'chore: update deps',
        author = 'Alice <alice@example.com>',
      })
    end)

    after_each(function()
      if repo then test_repo.cleanup(repo) end
    end)

    describe('constructor', function()
      it('should accept opts correctly', function()
        local history = GitHistory(make_repo(repo), { count = 10, skip = 5, path = 'file.txt', from = 'main' })
        assert.is_not_nil(history)
      end)
    end)

    describe('commits', function()
      it('should fetch commits from a real repository', function()
        local history = GitHistory(make_repo(repo))
        local result, err = history:commits()
        assert.is_nil(err)
        assert.is_not_nil(result)
        eq(4, #result)
      end)

      it('should cache commits on repeated calls', function()
        local history = GitHistory(make_repo(repo))
        local result1, err1 = history:commits()
        assert.is_nil(err1)
        local result2, err2 = history:commits()
        assert.is_nil(err2)
        -- Same table reference means caching worked
        assert.is_true(rawequal(result1, result2))
      end)

      it('should return commits in newest-first order', function()
        local history = GitHistory(make_repo(repo))
        local result, err = history:commits()
        assert.is_nil(err)
        eq('chore: update deps', result[1].summary)
        eq('feat: add dashboard', result[2].summary)
        eq('fix: resolve login bug', result[3].summary)
        eq('Initial commit', result[4].summary)
      end)

      it('should return GitCommit objects with expected fields', function()
        local history = GitHistory(make_repo(repo))
        local result = history:commits()
        for _, commit in ipairs(result) do
          assert.is_not_nil(commit.hash)
          assert.is_not_nil(commit.author_name)
          assert.is_not_nil(commit.author_email)
          assert.is_not_nil(commit.timestamp)
          assert.is_not_nil(commit.summary)
        end
      end)
    end)

    describe('count', function()
      it('should return the number of commits', function()
        local history = GitHistory(make_repo(repo))
        local n, err = history:count()
        assert.is_nil(err)
        eq(4, n)
      end)
    end)

    describe('is_empty', function()
      it('should return false for a repository with commits', function()
        local history = GitHistory(make_repo(repo))
        assert.is_false(history:is_empty())
      end)
    end)

    describe('first', function()
      it('should return the most recent commit', function()
        local history = GitHistory(make_repo(repo))
        local commit, err = history:first()
        assert.is_nil(err)
        eq('chore: update deps', commit.summary)
        eq('Alice', commit.author_name)
      end)
    end)

    describe('last', function()
      it('should return the oldest commit', function()
        local history = GitHistory(make_repo(repo))
        local commit, err = history:last()
        assert.is_nil(err)
        eq('Initial commit', commit.summary)
        eq('Test User', commit.author_name)
      end)
    end)

    describe('at', function()
      it('should return the commit at a valid index', function()
        local history = GitHistory(make_repo(repo))
        local commit, err = history:at(2)
        assert.is_nil(err)
        eq('feat: add dashboard', commit.summary)
        eq('Bob', commit.author_name)
      end)

      it('should return the first commit at index 1', function()
        local history = GitHistory(make_repo(repo))
        local commit, err = history:at(1)
        assert.is_nil(err)
        eq('chore: update deps', commit.summary)
      end)

      it('should return the last commit at index 4', function()
        local history = GitHistory(make_repo(repo))
        local commit, err = history:at(4)
        assert.is_nil(err)
        eq('Initial commit', commit.summary)
      end)

      it('should error on out-of-bounds index', function()
        local history = GitHistory(make_repo(repo))
        local commit, err = history:at(100)
        assert.is_nil(commit)
        assert.is_not_nil(err)
      end)
    end)

    describe('by_author', function()
      it('should filter commits by author name', function()
        local history = GitHistory(make_repo(repo))
        local filtered, err = history:by_author('Alice')
        assert.is_nil(err)
        eq(2, #filtered)
        for _, commit in ipairs(filtered) do
          eq('Alice', commit.author_name)
        end
      end)

      it('should return single match for unique author', function()
        local history = GitHistory(make_repo(repo))
        local filtered, err = history:by_author('Bob')
        assert.is_nil(err)
        eq(1, #filtered)
        eq('Bob', filtered[1].author_name)
        eq('feat: add dashboard', filtered[1].summary)
      end)

      it('should return commits by the default test user', function()
        local history = GitHistory(make_repo(repo))
        local filtered, err = history:by_author('Test User')
        assert.is_nil(err)
        eq(1, #filtered)
        eq('Initial commit', filtered[1].summary)
      end)

      it('should return empty for unknown author', function()
        local history = GitHistory(make_repo(repo))
        local filtered, err = history:by_author('Unknown')
        assert.is_nil(err)
        eq(0, #filtered)
      end)
    end)

    describe('by_date_range', function()
      it('should filter commits within a timestamp range', function()
        local history = GitHistory(make_repo(repo))
        local commits = history:commits()
        -- Use the actual commit timestamps to define the range
        local min_ts = commits[#commits].timestamp
        local max_ts = commits[1].timestamp
        local filtered, err = history:by_date_range(min_ts, max_ts)
        assert.is_nil(err)
        eq(4, #filtered)
      end)

      it('should return empty when range has no matches', function()
        local history = GitHistory(make_repo(repo))
        -- Use a timestamp range far in the past
        local filtered, err = history:by_date_range(1000000000, 1000000001)
        assert.is_nil(err)
        eq(0, #filtered)
      end)

      it('should filter to a single commit by exact timestamp', function()
        local history = GitHistory(make_repo(repo))
        local commits = history:commits()
        -- Pick the timestamp of one specific commit
        local ts = commits[1].timestamp
        local filtered, err = history:by_date_range(ts, ts)
        assert.is_nil(err)
        assert.is_true(#filtered >= 1)
        -- All returned commits should have matching timestamp
        for _, commit in ipairs(filtered) do
          eq(ts, commit.timestamp)
        end
      end)
    end)

    describe('search', function()
      it('should filter commits by pattern match on summary', function()
        local history = GitHistory(make_repo(repo))
        local filtered, err = history:search('fix:')
        assert.is_nil(err)
        eq(1, #filtered)
        eq('fix: resolve login bug', filtered[1].summary)
      end)

      it('should find multiple commits matching a pattern', function()
        local history = GitHistory(make_repo(repo))
        -- Both 'fix:' and 'feat:' contain a colon-prefixed type
        local filtered, err = history:search('^%a+:')
        assert.is_nil(err)
        -- chore: update deps, feat: add dashboard, fix: resolve login bug
        eq(3, #filtered)
      end)

      it('should support Lua patterns', function()
        local history = GitHistory(make_repo(repo))
        local filtered, err = history:search('^feat:')
        assert.is_nil(err)
        eq(1, #filtered)
        eq('feat: add dashboard', filtered[1].summary)
      end)

      it('should return empty when pattern has no matches', function()
        local history = GitHistory(make_repo(repo))
        local filtered, err = history:search('nonexistent')
        assert.is_nil(err)
        eq(0, #filtered)
      end)

      it('should match the initial commit', function()
        local history = GitHistory(make_repo(repo))
        local filtered, err = history:search('Initial')
        assert.is_nil(err)
        eq(1, #filtered)
        eq('Initial commit', filtered[1].summary)
      end)
    end)

    describe('authors', function()
      it('should return unique authors deduplicated by email', function()
        local history = GitHistory(make_repo(repo))
        local result, err = history:authors()
        assert.is_nil(err)
        -- Alice (alice@example.com), Bob (bob@example.com), Test User (test@example.com)
        eq(3, #result)
      end)

      it('should return name and email for each author', function()
        local history = GitHistory(make_repo(repo))
        local result = history:authors()
        for _, author in ipairs(result) do
          assert.is_not_nil(author.name)
          assert.is_not_nil(author.email)
        end
      end)

      it('should contain all expected authors', function()
        local history = GitHistory(make_repo(repo))
        local result = history:authors()
        local names = {}
        for _, author in ipairs(result) do
          names[author.name] = true
        end
        assert.is_true(names['Alice'])
        assert.is_true(names['Bob'])
        assert.is_true(names['Test User'])
      end)

      it('should deduplicate Alice who has two commits', function()
        local history = GitHistory(make_repo(repo))
        local result = history:authors()
        local alice_count = 0
        for _, author in ipairs(result) do
          if author.email == 'alice@example.com' then
            alice_count = alice_count + 1
          end
        end
        eq(1, alice_count)
      end)
    end)

    describe('iter', function()
      it('should yield index and commit pairs in order', function()
        local history = GitHistory(make_repo(repo))
        local collected = {}
        for i, commit in history:iter() do
          collected[#collected + 1] = { i = i, commit = commit }
        end
        eq(4, #collected)
        eq(1, collected[1].i)
        eq('chore: update deps', collected[1].commit.summary)
        eq(4, collected[4].i)
        eq('Initial commit', collected[4].commit.summary)
      end)

      it('should iterate over all commits', function()
        local history = GitHistory(make_repo(repo))
        local count = 0
        for _ in history:iter() do
          count = count + 1
        end
        eq(4, count)
      end)
    end)

    describe('load_more', function()
      it('should load initial commits with pagination and then load more', function()
        local history = GitHistory(make_repo(repo), { count = 2 })
        local commits, err = history:commits()
        assert.is_nil(err)
        eq(2, #commits)

        local more, more_err = history:load_more(2)
        assert.is_nil(more_err)
        eq(2, #more)

        local total, count_err = history:count()
        assert.is_nil(count_err)
        eq(4, total)
      end)

      it('should correctly skip already loaded commits', function()
        local history = GitHistory(make_repo(repo), { count = 1 })
        local commits = history:commits()
        eq(1, #commits)
        local first_summary = commits[1].summary

        local more = history:load_more(1)
        eq(1, #more)
        -- The newly loaded commit should be different from the first
        assert.are_not.equal(first_summary, more[1].summary)

        local total = history:count()
        eq(2, total)
      end)

      it('should handle loading more than available', function()
        local history = GitHistory(make_repo(repo), { count = 2 })
        history:commits()

        local more, err = history:load_more(100)
        assert.is_nil(err)
        -- There are only 2 remaining commits after the initial 2
        eq(2, #more)

        local total = history:count()
        eq(4, total)
      end)

      it('should work when no commits loaded yet', function()
        local history = GitHistory(make_repo(repo))
        local result, err = history:load_more(2)
        assert.is_nil(err)
        eq(2, #result)

        -- load_more initializes the cache, so count returns what was loaded
        local total = history:count()
        eq(2, total)
      end)

      it('should append to existing cache', function()
        local history = GitHistory(make_repo(repo), { count = 1 })
        history:commits()

        history:load_more(1)
        history:load_more(1)

        local total = history:count()
        eq(3, total)
      end)
    end)

    describe('reset', function()
      it('should clear cached commits so next call re-fetches', function()
        local history = GitHistory(make_repo(repo))
        local first_result = history:commits()
        assert.is_not_nil(first_result)

        history:reset()

        local second_result = history:commits()
        assert.is_not_nil(second_result)
        -- After reset, should get a fresh table (not the same reference)
        assert.is_false(rawequal(first_result, second_result))
        -- But the content should be the same
        eq(#first_result, #second_result)
      end)

      it('should allow re-fetching after new commits are added', function()
        local history = GitHistory(make_repo(repo))
        local count_before = history:count()
        eq(4, count_before)

        -- Add a new commit
        test_repo.create_commit(repo, {
          files = { ['file5.txt'] = { 'fifth' } },
          message = 'docs: add readme',
          author = 'Charlie <charlie@example.com>',
        })

        -- Still cached at 4
        local cached_count = history:count()
        eq(4, cached_count)

        -- Reset and re-fetch
        history:reset()
        local new_count = history:count()
        eq(5, new_count)
      end)
    end)

    describe('commits with options', function()
      it('should filter to file-specific history with path option', function()
        local history = GitHistory(make_repo(repo), { path = 'file2.txt' })
        local result, err = history:commits()
        assert.is_nil(err)
        -- Only the commit that added file2.txt should appear
        eq(1, #result)
        eq('fix: resolve login bug', result[1].summary)
      end)

    end)

    describe('by_date_range edge cases', function()
      it('should return empty with inverted range', function()
        local history = GitHistory(make_repo(repo))
        local filtered, err = history:by_date_range(9999999999, 0)
        assert.is_nil(err)
        eq(0, #filtered)
      end)
    end)

    describe('caching', function()
      it('should use cached data for multiple operations', function()
        local history = GitHistory(make_repo(repo))

        -- These should all work off the same cached commits
        local count = history:count()
        eq(4, count)

        local first = history:first()
        eq('chore: update deps', first.summary)

        local last = history:last()
        eq('Initial commit', last.summary)

        local filtered = history:by_author('Alice')
        eq(2, #filtered)

        local searched = history:search('feat:')
        eq(1, #searched)
      end)
    end)
  end)
end)
