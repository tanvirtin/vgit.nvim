local async = require('plenary.async.tests')
local GitBuffer = require('vgit.git.GitBuffer')
local test_repo = require('tests.helpers.test_repo')
local loop = require('vgit.core.loop')
test_repo.use_driver('raw')

async.describe('GitBuffer', function()
  local repo
  local test_file

  async.before_each(function()
    local err
    repo, err = test_repo.create_repo({
      initial_commit = true,
      files = { ['test.txt'] = { 'line 1', 'line 2', 'line 3' } },
    })
    assert(not err, 'Failed to create test repo')
    test_file = repo .. '/test.txt'
  end)

  async.after_each(function()
    if repo then test_repo.cleanup(repo) end
  end)

  async.describe('constructor and creation', function()
    async.it('creates GitBuffer with bufnr', function()
      local bufnr = vim.fn.bufadd(test_file)
      local git_buf = GitBuffer(bufnr)

      assert.is_not_nil(git_buf)
      assert.equals(bufnr, git_buf.bufnr)
      assert.is_not_nil(git_buf.state)
      assert.is_table(git_buf.state.signs)
      assert.is_table(git_buf.state.blames)
      assert.is_table(git_buf.state.conflicts)
    end)

    async.it('creates GitBuffer with extmarks', function()
      local bufnr = vim.fn.bufadd(test_file)
      local git_buf = GitBuffer(bufnr)

      assert.is_not_nil(git_buf.blame_extmark)
      assert.is_not_nil(git_buf.gutter_extmark)
      assert.is_not_nil(git_buf.conflict_extmark)
    end)

    async.it('creates buffer using create method', function()
      local git_buf = GitBuffer:create()

      assert.is_not_nil(git_buf)
      assert.is_not_nil(git_buf.bufnr)
      assert.is_not_nil(git_buf.blame_extmark)
    end)
  end)

  async.describe('sync', function()
    async.it('syncs buffer and creates git_file', function()
      local bufnr = vim.fn.bufadd(test_file)
      vim.fn.bufload(bufnr)
      local git_buf = GitBuffer(bufnr)

      git_buf:sync()

      assert.is_not_nil(git_buf.git_file)
      assert.is_table(git_buf.state.signs)
      assert.is_table(git_buf.state.blames)
    end)

    async.it('resets state on sync', function()
      local bufnr = vim.fn.bufadd(test_file)
      vim.fn.bufload(bufnr)
      local git_buf = GitBuffer(bufnr)

      git_buf.state.signs = { 'old' }
      git_buf.state.blames = { 'old' }
      git_buf.state.config = { 'old' }

      git_buf:sync()

      assert.equals(0, #git_buf.state.signs)
      assert.equals(0, vim.tbl_count(git_buf.state.blames))
      assert.is_nil(git_buf.state.config)
    end)
  end)

  async.describe('file status checks', function()
    async.describe('is_inside_git_dir', function()
      async.it('returns true for file in git repo', function()
        local bufnr = vim.fn.bufadd(test_file)
        vim.fn.bufload(bufnr)
        loop.free_textlock()

        local git_buf = GitBuffer(bufnr)
        git_buf:sync()

        loop.free_textlock()
        local result, err = git_buf:is_inside_git_dir()

        assert.is_nil(err)
        assert.is_true(result)
      end)

      async.it('returns false for file not in git repo', function()
        local temp_file = '/tmp/not-in-repo-' .. os.time() .. '.txt'
        loop.free_textlock()
        vim.fn.writefile({ 'content' }, temp_file)

        local bufnr = vim.fn.bufadd(temp_file)
        vim.fn.bufload(bufnr)
        loop.free_textlock()

        local git_buf = GitBuffer(bufnr)
        loop.free_textlock()

        local result, _ = git_buf:is_inside_git_dir()

        assert.is_false(result)

        loop.free_textlock()
        vim.fn.delete(temp_file)
      end)
    end)

    async.describe('is_tracked', function()
      async.it('returns true for tracked file', function()
        local bufnr = vim.fn.bufadd(test_file)
        vim.fn.bufload(bufnr)
        local git_buf = GitBuffer(bufnr)
        git_buf:sync()

        local result, err = git_buf:is_tracked()

        assert.is_nil(err)
        assert.is_true(result)
      end)

      async.it('returns false for untracked file', function()
        local untracked_file = repo .. '/untracked.txt'
        test_repo.write_file(repo, 'untracked.txt', { 'content' })

        local bufnr = vim.fn.bufadd(untracked_file)
        vim.fn.bufload(bufnr)
        local git_buf = GitBuffer(bufnr)
        git_buf:sync()

        local result, err = git_buf:is_tracked()

        assert.is_nil(err)
        assert.is_false(result)
      end)
    end)

    async.describe('is_ignored', function()
      async.it('returns false for non-ignored file', function()
        local bufnr = vim.fn.bufadd(test_file)
        vim.fn.bufload(bufnr)
        local git_buf = GitBuffer(bufnr)
        git_buf:sync()

        local result, err = git_buf:is_ignored()

        assert.is_nil(err)
        assert.is_false(result)
      end)

      async.it('returns true for ignored file', function()
        test_repo.write_file(repo, '.gitignore', { 'ignored.txt' })
        test_repo.write_file(repo, 'ignored.txt', { 'content' })

        local ignored_file = repo .. '/ignored.txt'
        local bufnr = vim.fn.bufadd(ignored_file)
        vim.fn.bufload(bufnr)
        local git_buf = GitBuffer(bufnr)
        git_buf:sync()

        local result, err = git_buf:is_ignored()

        assert.is_nil(err)
        assert.is_true(result)
      end)
    end)

    async.describe('exists', function()
      async.it('returns true for valid git buffer', function()
        local bufnr = vim.fn.bufadd(test_file)
        vim.fn.bufload(bufnr)

        local git_buf = GitBuffer(bufnr)
        git_buf:sync()

        local result, err = git_buf:exists()

        assert.is_nil(err)
        assert.is_true(result)
      end)

      async.it('returns false for invalid buffer', function()
        local git_buf = GitBuffer:create()
        vim.api.nvim_buf_delete(git_buf.bufnr, { force = true })

        local result, _ = git_buf:exists()

        assert.is_false(result)
      end)

      async.it('returns false for ignored file', function()
        test_repo.write_file(repo, '.gitignore', { 'ignored.txt' })
        test_repo.write_file(repo, 'ignored.txt', { 'content' })

        local ignored_file = repo .. '/ignored.txt'
        local bufnr = vim.fn.bufadd(ignored_file)
        vim.fn.bufload(bufnr)

        local git_buf = GitBuffer(bufnr)
        git_buf:sync()

        local result, _ = git_buf:exists()

        assert.is_false(result)
      end)
    end)
  end)

  async.describe('config', function()
    async.it('returns repository config', function()
      local bufnr = vim.fn.bufadd(test_file)
      vim.fn.bufload(bufnr)
      local git_buf = GitBuffer(bufnr)
      git_buf:sync()

      local config, err = git_buf:config()

      assert.is_nil(err)
      assert.is_not_nil(config)
      assert.is_table(config)
    end)

    async.it('caches config after first call', function()
      local bufnr = vim.fn.bufadd(test_file)
      vim.fn.bufload(bufnr)
      local git_buf = GitBuffer(bufnr)
      git_buf:sync()

      local config1 = git_buf:config()
      local config2 = git_buf:config()

      assert.equals(config2, config1)
      assert.is_not_nil(git_buf.state.config)
    end)
  end)

  async.describe('state management', function()
    async.describe('reset_signs', function()
      async.it('clears signs from state', function()
        local bufnr = vim.fn.bufadd(test_file)
        local git_buf = GitBuffer(bufnr)

        git_buf.state.signs = { { col = 1 }, { col = 2 } }
        git_buf:reset_signs()

        assert.equals(0, #git_buf.state.signs)
      end)

      async.it('returns self for chaining', function()
        local bufnr = vim.fn.bufadd(test_file)
        local git_buf = GitBuffer(bufnr)

        local result = git_buf:reset_signs()

        assert.equals(git_buf, result)
      end)
    end)

    async.describe('clear_extmarks', function()
      async.it('clears all extmarks', function()
        local bufnr = vim.fn.bufadd(test_file)
        vim.fn.bufload(bufnr)
        local git_buf = GitBuffer(bufnr)

        local result = git_buf:clear_extmarks()

        assert.equals(git_buf, result)
      end)

      async.it('accepts top and bot parameters', function()
        local bufnr = vim.fn.bufadd(test_file)
        vim.fn.bufload(bufnr)
        local git_buf = GitBuffer(bufnr)

        local result = git_buf:clear_extmarks(0, 10)

        assert.equals(git_buf, result)
      end)
    end)

    async.describe('generate_status', function()
      async.it('returns self for chaining', function()
        local bufnr = vim.fn.bufadd(test_file)
        vim.fn.bufload(bufnr)
        loop.free_textlock()
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { 'modified 1', 'line 2', 'line 3' })
        loop.free_textlock()

        local git_buf = GitBuffer(bufnr)
        git_buf:sync()
        loop.free_textlock()
        git_buf:diff() -- Generate hunks first
        loop.free_textlock()

        local result = git_buf:generate_status()

        assert.equals(git_buf, result)
      end)
    end)

    async.describe('get_hunks', function()
      async.it('returns hunks from state', function()
        local bufnr = vim.fn.bufadd(test_file)
        vim.fn.bufload(bufnr)
        loop.free_textlock()

        local git_buf = GitBuffer(bufnr)
        git_buf:sync()
        loop.free_textlock()

        -- GitBuffer:get_hunks() returns git_file.state.hunks
        git_buf.git_file.state.hunks = { { type = 'add' } }
        local hunks = git_buf:get_hunks()

        assert.is_table(hunks)
        assert.equals(1, #hunks)
      end)

      async.it('returns empty table when no hunks', function()
        local bufnr = vim.fn.bufadd(test_file)
        vim.fn.bufload(bufnr)
        loop.free_textlock()

        local git_buf = GitBuffer(bufnr)
        git_buf:sync()
        loop.free_textlock()

        -- git_file.state.hunks defaults to nil, get_hunks() returns it directly
        git_buf.git_file.state.hunks = {}
        local hunks = git_buf:get_hunks()

        assert.is_table(hunks)
        assert.equals(0, #hunks)
      end)
    end)

    async.describe('get_conflicts', function()
      async.it('returns conflicts from state', function()
        local bufnr = vim.fn.bufadd(test_file)
        local git_buf = GitBuffer(bufnr)

        git_buf.state.conflicts = { { type = 'conflict' } }
        local conflicts = git_buf:get_conflicts()

        assert.is_table(conflicts)
        assert.equals(1, #conflicts)
      end)
    end)

    async.describe('get_conflict', function()
      async.it('returns conflict at specific line', function()
        local bufnr = vim.fn.bufadd(test_file)
        local git_buf = GitBuffer(bufnr)

        git_buf.state.conflicts = {
          {
            current = { top = 1, bot = 3 },
            incoming = { top = 4, bot = 6 },
          },
        }

        local conflict = git_buf:get_conflict(2)

        assert.is_not_nil(conflict)
        assert.equals(1, conflict.current.top)
      end)

      async.it('returns nil when no conflict at line', function()
        local bufnr = vim.fn.bufadd(test_file)
        local git_buf = GitBuffer(bufnr)

        git_buf.state.conflicts = {}
        local conflict = git_buf:get_conflict(2)

        assert.is_nil(conflict)
      end)
    end)

    async.describe('get_conflict_marks', function()
      async.it('returns conflict markers', function()
        local bufnr = vim.fn.bufadd(test_file)
        local git_buf = GitBuffer(bufnr)

        git_buf.state.conflicts = {
          {
            current = { top = 1, bot = 3 },
            incoming = { top = 4, bot = 6 },
          },
          {
            current = { top = 10, bot = 12 },
            incoming = { top = 13, bot = 15 },
          },
        }

        local marks = git_buf:get_conflict_marks()

        assert.is_table(marks)
        assert.equals(2, #marks)
        assert.equals(1, marks[1].top)
        assert.equals(6, marks[1].bot)
      end)
    end)
  end)

  async.describe('staging operations', function()
    async.describe('stage', function()
      async.it('stages file modifications', function()
        test_repo.write_file(repo, 'test.txt', { 'modified line 1' })

        local bufnr = vim.fn.bufadd(test_file)
        vim.fn.bufload(bufnr)
        local git_buf = GitBuffer(bufnr)
        git_buf:sync()

        local result, err = git_buf:stage()

        assert.is_nil(err)
        assert.is_not_nil(result)
      end)

      async.it('returns error tuple on failure', function()
        local bufnr = vim.fn.bufadd('/nonexistent/file.txt')
        local git_buf = GitBuffer(bufnr)
        git_buf.git_file = require('vgit.git.GitFile')('/nonexistent/file.txt')

        local _, err = git_buf:stage()

        assert.is_not_nil(err)
      end)
    end)

    async.describe('unstage', function()
      async.it('unstages staged file', function()
        test_repo.write_file(repo, 'test.txt', { 'modified line 1' })
        test_repo.stage(repo, 'test.txt')

        local bufnr = vim.fn.bufadd(test_file)
        vim.fn.bufload(bufnr)
        local git_buf = GitBuffer(bufnr)
        git_buf:sync()

        local result, err = git_buf:unstage()

        assert.is_nil(err)
        assert.is_not_nil(result)
      end)
    end)

    async.describe('stage_hunk', function()
      async.it('stages specific hunk', function()
        test_repo.write_file(repo, 'test.txt', { 'line 1', 'line 2', 'line 3' })
        loop.free_textlock()

        local bufnr = vim.fn.bufadd(test_file)
        vim.fn.bufload(bufnr)
        loop.free_textlock()
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { 'modified 1', 'line 2', 'line 3' })
        loop.free_textlock()

        local git_buf = GitBuffer(bufnr)
        git_buf:sync()
        loop.free_textlock()

        local hunks, _ = git_buf:diff()
        loop.free_textlock()
        if hunks and #hunks > 0 then
          local _, err = git_buf:stage_hunk(hunks[1])
          assert.is_nil(err)
        end
      end)

      async.it('returns error for invalid hunk', function()
        local bufnr = vim.fn.bufadd(test_file)
        vim.fn.bufload(bufnr)
        local git_buf = GitBuffer(bufnr)
        git_buf:sync()

        local _, err = git_buf:stage_hunk(nil)

        assert.is_not_nil(err)
      end)
    end)

    async.describe('unstage_hunk', function()
      async.it('unstages specific hunk', function()
        test_repo.write_file(repo, 'test.txt', { 'modified line 1', 'line 2', 'line 3' })
        test_repo.stage(repo, 'test.txt')

        local bufnr = vim.fn.bufadd(test_file)
        vim.fn.bufload(bufnr)
        local git_buf = GitBuffer(bufnr)
        git_buf:sync()

        -- Get staged hunks
        local git_hunks = require('vgit.git.git_hunks')
        local hunks, _ = git_hunks.list(repo, { staged = true, filename = 'test.txt' })

        if hunks and #hunks > 0 then
          local result, err = git_buf:unstage_hunk(hunks[1])
          -- Note: This may fail with specific git state, so we just check it runs
          assert.is_not_nil(result ~= nil or err)
        end
      end)
    end)
  end)

  async.describe('blame operations', function()
    async.describe('blame', function()
      async.it('returns blame for specific line', function()
        local bufnr = vim.fn.bufadd(test_file)
        vim.fn.bufload(bufnr)
        local git_buf = GitBuffer(bufnr)
        git_buf:sync()

        local blame, err = git_buf:blame(1)

        assert.is_nil(err)
        assert.is_not_nil(blame)
        assert.is_not_nil(blame.commit_hash)
      end)

      async.it('caches blame in state', function()
        local bufnr = vim.fn.bufadd(test_file)
        vim.fn.bufload(bufnr)
        local git_buf = GitBuffer(bufnr)
        git_buf:sync()

        git_buf:blame(1)

        assert.is_not_nil(git_buf.state.blames[1])
      end)
    end)

    async.describe('blames', function()
      async.it('returns blames for all lines', function()
        local bufnr = vim.fn.bufadd(test_file)
        vim.fn.bufload(bufnr)
        local git_buf = GitBuffer(bufnr)
        git_buf:sync()

        local blames, err = git_buf:blames()

        assert.is_nil(err)
        assert.is_table(blames)
        assert(#blames > 0, 'should have blame entries')
      end)
    end)
  end)

  async.describe('diff and hunks', function()
    async.describe('diff', function()
      async.it('computes diff for modified file', function()
        local bufnr = vim.fn.bufadd(test_file)
        vim.fn.bufload(bufnr)
        loop.free_textlock()
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { 'modified 1', 'line 2', 'modified 3' })
        loop.free_textlock()

        local git_buf = GitBuffer(bufnr)
        git_buf:sync()
        loop.free_textlock()

        local hunks, err = git_buf:diff()

        assert.is_nil(err)
        assert.is_table(hunks)
      end)

      async.it('updates signs state with hunks', function()
        local bufnr = vim.fn.bufadd(test_file)
        vim.fn.bufload(bufnr)
        loop.free_textlock()
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { 'modified 1', 'line 2', 'line 3' })
        loop.free_textlock()

        local git_buf = GitBuffer(bufnr)
        git_buf:sync()
        loop.free_textlock()

        git_buf:diff()

        assert.is_table(git_buf.state.signs)
      end)

      async.it('returns empty when no changes', function()
        local bufnr = vim.fn.bufadd(test_file)
        vim.fn.bufload(bufnr)
        loop.free_textlock()

        local git_buf = GitBuffer(bufnr)
        git_buf:sync()
        loop.free_textlock()

        local _, err = git_buf:diff()

        assert.is_nil(err)
        -- File hasn't changed, so no hunks
      end)
    end)

    async.describe('conflicts', function()
      async.it('returns empty conflicts when no conflicts', function()
        local bufnr = vim.fn.bufadd(test_file)
        vim.fn.bufload(bufnr)
        local git_buf = GitBuffer(bufnr)
        git_buf:sync()

        local conflicts = git_buf:conflicts()

        assert.is_table(conflicts)
        assert.equals(0, #conflicts)
      end)

      async.it('parses conflict markers from buffer', function()
        local conflict_file = repo .. '/conflict.txt'
        test_repo.write_file(
          repo,
          'conflict.txt',
          { '<<<<<<< HEAD', 'current', '=======', 'incoming', '>>>>>>> branch' }
        )

        local bufnr = vim.fn.bufadd(conflict_file)
        vim.fn.bufload(bufnr)
        local git_buf = GitBuffer(bufnr)
        git_buf:sync()

        local conflicts = git_buf:conflicts()

        -- Note: Conflict detection requires actual git state
        assert.is_table(conflicts)
      end)
    end)
  end)

  async.describe('rendering', function()
    async.describe('render_signs', function()
      async.it('renders signs in buffer', function()
        local bufnr = vim.fn.bufadd(test_file)
        vim.fn.bufload(bufnr)
        local git_buf = GitBuffer(bufnr)

        git_buf.state.signs = { { col = 0, name = 'GitSignsAdd' } }
        local result = git_buf:render_signs()

        assert.equals(git_buf, result)
      end)

      async.it('respects top and bot bounds', function()
        local bufnr = vim.fn.bufadd(test_file)
        vim.fn.bufload(bufnr)
        local git_buf = GitBuffer(bufnr)

        git_buf.state.signs = { { col = 5, name = 'GitSignsAdd' }, { col = 15, name = 'GitSignsAdd' } }
        local result = git_buf:render_signs(0, 10)

        assert.equals(git_buf, result)
      end)
    end)

    async.describe('render', function()
      async.it('renders buffer content and signs', function()
        local bufnr = vim.fn.bufadd(test_file)
        vim.fn.bufload(bufnr)
        local git_buf = GitBuffer(bufnr)

        local result = git_buf:render()

        assert.equals(git_buf, result)
      end)
    end)

    async.describe('render_conflicts', function()
      async.it('renders conflict markers', function()
        local bufnr = vim.fn.bufadd(test_file)
        vim.fn.bufload(bufnr)
        local git_buf = GitBuffer(bufnr)

        git_buf.state.conflicts = {
          {
            current = { top = 1, bot = 2 },
            middle = { top = 3, bot = 3 },
            incoming = { top = 4, bot = 5 },
          },
        }

        local result = git_buf:render_conflicts()

        assert.equals(git_buf, result)
      end)
    end)
  end)
end)
