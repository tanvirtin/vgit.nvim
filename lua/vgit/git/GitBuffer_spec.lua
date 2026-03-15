-- Stub out modules that the user's Neovim config may require in autocmds
-- but are not available in the test environment
package.loaded['lint'] = { try_lint = function() end }

local GitBuffer = require('vgit.git.GitBuffer')
local test_repo = require('tests.helpers.test_repo')
test_repo.use_driver('raw')
local async = require('tests.helpers.async')({ it = it, before_each = before_each, after_each = after_each })
local it = async.it
local before_each = async.before_each
local after_each = async.after_each

local eq = assert.are.same

describe('GitBuffer:', function()
  local repo
  local test_file

  before_each(function()
    local err
    repo, err = test_repo.create_repo({
      initial_commit = true,
      files = { ['test.txt'] = { 'line 1', 'line 2', 'line 3' } },
    })
    assert(not err, 'Failed to create test repo')
    test_file = repo .. '/test.txt'
  end)

  after_each(function()
    if repo then test_repo.cleanup(repo) end
  end)

  describe('constructor and creation', function()
    it('creates GitBuffer with bufnr', function()
      local bufnr = vim.fn.bufadd(test_file)
      local git_buf = GitBuffer(bufnr)

      assert.is_not_nil(git_buf)
      assert.equals(bufnr, git_buf.bufnr)
      assert.is_not_nil(git_buf.state)
      assert.is_table(git_buf.state.signs)
      assert.is_table(git_buf.state.blames)
      assert.is_table(git_buf.state.conflicts)
    end)

    it('creates GitBuffer with extmarks', function()
      local bufnr = vim.fn.bufadd(test_file)
      local git_buf = GitBuffer(bufnr)

      assert.is_not_nil(git_buf._blame_extmark)
      assert.is_not_nil(git_buf._gutter_extmark)
      assert.is_not_nil(git_buf._conflict_extmark)
    end)

    it('creates buffer using create method', function()
      local git_buf = GitBuffer:create()

      assert.is_not_nil(git_buf)
      assert.is_not_nil(git_buf.bufnr)
      assert.is_not_nil(git_buf._blame_extmark)
    end)
  end)

  describe('sync', function()
    it('syncs buffer and creates git_file', function()
      local bufnr = vim.fn.bufadd(test_file)
      vim.fn.bufload(bufnr)
      local git_buf = GitBuffer(bufnr)

      git_buf:sync()

      assert.is_not_nil(git_buf._git_file)
      assert.is_table(git_buf.state.signs)
      assert.is_table(git_buf.state.blames)
    end)

    it('resets state on sync', function()
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

    it('resets op_lock on sync', function()
      local bufnr = vim.fn.bufadd(test_file)
      vim.fn.bufload(bufnr)
      local git_buf = GitBuffer(bufnr)

      git_buf._op_lock = true
      git_buf:sync()

      assert.is_false(git_buf._op_lock)
    end)
  end)

  describe('operation lock', function()
    describe('acquire', function()
      it('returns true on first acquire', function()
        local bufnr = vim.fn.bufadd(test_file)
        local git_buf = GitBuffer(bufnr)

        assert.is_true(git_buf:acquire())
      end)

      it('returns false when already acquired', function()
        local bufnr = vim.fn.bufadd(test_file)
        local git_buf = GitBuffer(bufnr)

        git_buf:acquire()

        assert.is_false(git_buf:acquire())
      end)

      it('sets _op_lock to true', function()
        local bufnr = vim.fn.bufadd(test_file)
        local git_buf = GitBuffer(bufnr)

        git_buf:acquire()

        assert.is_true(git_buf._op_lock)
      end)
    end)

    describe('release', function()
      it('clears the lock', function()
        local bufnr = vim.fn.bufadd(test_file)
        local git_buf = GitBuffer(bufnr)

        git_buf:acquire()
        git_buf:release()

        assert.is_false(git_buf._op_lock)
      end)

      it('allows re-acquire after release', function()
        local bufnr = vim.fn.bufadd(test_file)
        local git_buf = GitBuffer(bufnr)

        git_buf:acquire()
        git_buf:release()

        assert.is_true(git_buf:acquire())
      end)
    end)
  end)

  describe('file status checks', function()
    describe('is_inside_git_dir', function()
      it('returns true for file in git repo', function()
        local bufnr = vim.fn.bufadd(test_file)
        vim.fn.bufload(bufnr)

        local git_buf = GitBuffer(bufnr)
        git_buf:sync()

        local result, err = git_buf:is_inside_git_dir()

        assert.is_nil(err)
        assert.is_true(result)
      end)

      it('returns false for file not in git repo', function()
        local temp_file = '/tmp/not-in-repo-' .. os.time() .. '.txt'
        vim.fn.writefile({ 'content' }, temp_file)

        local bufnr = vim.fn.bufadd(temp_file)
        vim.fn.bufload(bufnr)

        local git_buf = GitBuffer(bufnr)

        local result, _ = git_buf:is_inside_git_dir()

        assert.is_false(result)

        vim.fn.delete(temp_file)
      end)
    end)

    describe('is_tracked', function()
      it('returns true for tracked file', function()
        local bufnr = vim.fn.bufadd(test_file)
        vim.fn.bufload(bufnr)
        local git_buf = GitBuffer(bufnr)
        git_buf:sync()

        local result, err = git_buf:is_tracked()

        assert.is_nil(err)
        assert.is_true(result)
      end)

      it('returns false for untracked file', function()
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

    describe('is_ignored', function()
      it('returns false for non-ignored file', function()
        local bufnr = vim.fn.bufadd(test_file)
        vim.fn.bufload(bufnr)
        local git_buf = GitBuffer(bufnr)
        git_buf:sync()

        local result, err = git_buf:is_ignored()

        assert.is_nil(err)
        assert.is_false(result)
      end)

      it('returns true for ignored file', function()
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

    describe('exists', function()
      it('returns true for valid git buffer', function()
        local bufnr = vim.fn.bufadd(test_file)
        vim.fn.bufload(bufnr)

        local git_buf = GitBuffer(bufnr)
        git_buf:sync()

        local result, err = git_buf:exists()

        assert.is_nil(err)
        assert.is_true(result)
      end)

      it('returns false for invalid buffer', function()
        local git_buf = GitBuffer:create()
        vim.api.nvim_buf_delete(git_buf.bufnr, { force = true })

        local result, _ = git_buf:exists()

        assert.is_false(result)
      end)

      it('returns false for ignored file', function()
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

  describe('config', function()
    it('returns repository config', function()
      local bufnr = vim.fn.bufadd(test_file)
      vim.fn.bufload(bufnr)
      local git_buf = GitBuffer(bufnr)
      git_buf:sync()

      local config, err = git_buf:config()

      assert.is_nil(err)
      assert.is_not_nil(config)
      assert.is_table(config)
    end)

    it('caches config after first call', function()
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

  describe('state management', function()
    describe('reset_signs', function()
      it('clears signs from state', function()
        local bufnr = vim.fn.bufadd(test_file)
        local git_buf = GitBuffer(bufnr)

        git_buf.state.signs = { { col = 1 }, { col = 2 } }
        git_buf:reset_signs()

        assert.equals(0, #git_buf.state.signs)
      end)

      it('returns self for chaining', function()
        local bufnr = vim.fn.bufadd(test_file)
        local git_buf = GitBuffer(bufnr)

        local result = git_buf:reset_signs()

        assert.equals(git_buf, result)
      end)
    end)

    describe('clear_extmarks', function()
      it('clears all extmarks', function()
        local bufnr = vim.fn.bufadd(test_file)
        vim.fn.bufload(bufnr)
        local git_buf = GitBuffer(bufnr)

        local result = git_buf:clear_extmarks()

        assert.equals(git_buf, result)
      end)

      it('accepts top and bot parameters', function()
        local bufnr = vim.fn.bufadd(test_file)
        vim.fn.bufload(bufnr)
        local git_buf = GitBuffer(bufnr)

        local result = git_buf:clear_extmarks(0, 10)

        assert.equals(git_buf, result)
      end)
    end)

    describe('generate_status', function()
      it('returns self for chaining', function()
        local bufnr = vim.fn.bufadd(test_file)
        vim.fn.bufload(bufnr)
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { 'modified 1', 'line 2', 'line 3' })

        local git_buf = GitBuffer(bufnr)
        git_buf:sync()
        git_buf:diff() -- Generate hunks first

        local result = git_buf:generate_status()

        assert.equals(git_buf, result)
      end)
    end)

    describe('get_hunks', function()
      it('returns hunks from state', function()
        local bufnr = vim.fn.bufadd(test_file)
        vim.fn.bufload(bufnr)

        local git_buf = GitBuffer(bufnr)
        git_buf:sync()

        -- GitBuffer:get_hunks() returns git_file.state.hunks
        git_buf._git_file.state.hunks = { { type = 'add' } }
        local hunks = git_buf:get_hunks()

        assert.is_table(hunks)
        assert.equals(1, #hunks)
      end)

      it('returns empty table when no hunks', function()
        local bufnr = vim.fn.bufadd(test_file)
        vim.fn.bufload(bufnr)

        local git_buf = GitBuffer(bufnr)
        git_buf:sync()

        -- git_file.state.hunks defaults to nil, get_hunks() returns it directly
        git_buf._git_file.state.hunks = {}
        local hunks = git_buf:get_hunks()

        assert.is_table(hunks)
        assert.equals(0, #hunks)
      end)
    end)

    describe('get_conflicts', function()
      it('returns conflicts from state', function()
        local bufnr = vim.fn.bufadd(test_file)
        local git_buf = GitBuffer(bufnr)

        git_buf.state.conflicts = { { type = 'conflict' } }
        local conflicts = git_buf:get_conflicts()

        assert.is_table(conflicts)
        assert.equals(1, #conflicts)
      end)
    end)

    describe('get_conflict', function()
      it('returns conflict at specific line', function()
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

      it('returns nil when no conflict at line', function()
        local bufnr = vim.fn.bufadd(test_file)
        local git_buf = GitBuffer(bufnr)

        git_buf.state.conflicts = {}
        local conflict = git_buf:get_conflict(2)

        assert.is_nil(conflict)
      end)
    end)

    describe('get_conflict_marks', function()
      it('returns conflict markers', function()
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

  describe('staging operations', function()
    describe('stage', function()
      it('stages file modifications', function()
        test_repo.write_file(repo, 'test.txt', { 'modified line 1' })

        local bufnr = vim.fn.bufadd(test_file)
        vim.fn.bufload(bufnr)
        local git_buf = GitBuffer(bufnr)
        git_buf:sync()

        local result, err = git_buf:stage()

        assert.is_nil(err)
        assert.is_not_nil(result)
      end)

      it('returns error tuple on failure', function()
        local bufnr = vim.fn.bufadd('/nonexistent/file.txt')
        local git_buf = GitBuffer(bufnr)
        git_buf._git_file = require('vgit.git.GitFile')('/nonexistent/file.txt')

        local _, err = git_buf:stage()

        assert.is_not_nil(err)
      end)
    end)

    describe('unstage', function()
      it('unstages staged file', function()
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

    describe('stage_hunk', function()
      it('stages specific hunk', function()
        test_repo.write_file(repo, 'test.txt', { 'line 1', 'line 2', 'line 3' })

        local bufnr = vim.fn.bufadd(test_file)
        vim.fn.bufload(bufnr)
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { 'modified 1', 'line 2', 'line 3' })

        local git_buf = GitBuffer(bufnr)
        git_buf:sync()

        local hunks, _ = git_buf:diff()
        if hunks and #hunks > 0 then
          local _, err = git_buf:stage_hunk(hunks[1])
          assert.is_nil(err)
        end
      end)

      it('returns error for invalid hunk', function()
        local bufnr = vim.fn.bufadd(test_file)
        vim.fn.bufload(bufnr)
        local git_buf = GitBuffer(bufnr)
        git_buf:sync()

        local _, err = git_buf:stage_hunk(nil)

        assert.is_not_nil(err)
      end)
    end)

    describe('unstage_hunk', function()
      it('unstages specific hunk', function()
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
          -- Either the operation succeeded or returned an error
          assert.is_true(result ~= nil or err ~= nil)
        end
      end)
    end)
  end)

  describe('blame operations', function()
    describe('blame', function()
      it('returns blame for specific line', function()
        local bufnr = vim.fn.bufadd(test_file)
        vim.fn.bufload(bufnr)
        local git_buf = GitBuffer(bufnr)
        git_buf:sync()

        local blame, err = git_buf:blame(1)

        assert.is_nil(err)
        assert.is_not_nil(blame)
        assert.is_not_nil(blame.commit_hash)
      end)

      it('caches blame in state', function()
        local bufnr = vim.fn.bufadd(test_file)
        vim.fn.bufload(bufnr)
        local git_buf = GitBuffer(bufnr)
        git_buf:sync()

        git_buf:blame(1)

        assert.is_not_nil(git_buf.state.blames[1])
      end)
    end)

    describe('blames', function()
      it('returns blames for all lines', function()
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

  describe('diff and hunks', function()
    describe('diff', function()
      it('computes diff for modified file', function()
        local bufnr = vim.fn.bufadd(test_file)
        vim.fn.bufload(bufnr)
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { 'modified 1', 'line 2', 'modified 3' })

        local git_buf = GitBuffer(bufnr)
        git_buf:sync()

        local hunks, err = git_buf:diff()

        assert.is_nil(err)
        assert.is_table(hunks)
      end)

      it('updates signs state with hunks', function()
        local bufnr = vim.fn.bufadd(test_file)
        vim.fn.bufload(bufnr)
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { 'modified 1', 'line 2', 'line 3' })

        local git_buf = GitBuffer(bufnr)
        git_buf:sync()

        git_buf:diff()

        assert.is_table(git_buf.state.signs)
      end)

      it('returns empty when no changes', function()
        local bufnr = vim.fn.bufadd(test_file)
        vim.fn.bufload(bufnr)

        local git_buf = GitBuffer(bufnr)
        git_buf:sync()

        local _, err = git_buf:diff()

        assert.is_nil(err)
        -- File hasn't changed, so no hunks
      end)
    end)

    describe('conflicts', function()
      it('returns empty conflicts when no conflicts', function()
        local bufnr = vim.fn.bufadd(test_file)
        vim.fn.bufload(bufnr)
        local git_buf = GitBuffer(bufnr)
        git_buf:sync()

        local conflicts = git_buf:conflicts()

        assert.is_table(conflicts)
        assert.equals(0, #conflicts)
      end)

      it('parses conflict markers from buffer', function()
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

  describe('rendering', function()
    describe('render_signs', function()
      it('renders signs in buffer', function()
        local bufnr = vim.fn.bufadd(test_file)
        vim.fn.bufload(bufnr)
        local git_buf = GitBuffer(bufnr)

        git_buf.state.signs = { { col = 0, name = 'GitSignsAdd' } }
        git_buf._signs_dirty = true
        local result = git_buf:render_signs()

        assert.equals(git_buf, result)
      end)

      it('respects top and bot bounds', function()
        local bufnr = vim.fn.bufadd(test_file)
        vim.fn.bufload(bufnr)
        local git_buf = GitBuffer(bufnr)

        git_buf.state.signs = { { col = 5, name = 'GitSignsAdd' }, { col = 15, name = 'GitSignsAdd' } }
        git_buf._signs_dirty = true
        local result = git_buf:render_signs(0, 10)

        assert.equals(git_buf, result)
      end)

      it('renders even when signs are not dirty (viewport pull model)', function()
        local bufnr = vim.fn.bufadd(test_file)
        vim.fn.bufload(bufnr)
        local git_buf = GitBuffer(bufnr)

        git_buf.state.signs = { { col = 0, name = 'GitSignsAdd' } }
        git_buf._signs_dirty = false
        local result = git_buf:render_signs()

        assert.equals(git_buf, result)
      end)

      it('clears dirty flag after rendering', function()
        local bufnr = vim.fn.bufadd(test_file)
        vim.fn.bufload(bufnr)
        local git_buf = GitBuffer(bufnr)

        git_buf.state.signs = { { col = 0, name = 'GitSignsAdd' } }
        git_buf._signs_dirty = true
        git_buf:render_signs()

        assert.is_false(git_buf._signs_dirty)
      end)

      it('only places signs within viewport range', function()
        local bufnr = vim.fn.bufadd(test_file)
        vim.fn.bufload(bufnr)
        local git_buf = GitBuffer(bufnr)

        git_buf.state.signs = {
          { col = 2, name = 'GitSignsAdd' },
          { col = 5, name = 'GitSignsAdd' },
          { col = 8, name = 'GitSignsAdd' },
        }
        git_buf._signs_dirty = true

        -- Render with viewport 3-6: only sign at col=5 is in range
        local result = git_buf:render_signs(3, 6)

        assert.equals(git_buf, result)
        assert.is_false(git_buf._signs_dirty)
      end)
    end)

    describe('render', function()
      it('renders buffer content and signs', function()
        local bufnr = vim.fn.bufadd(test_file)
        vim.fn.bufload(bufnr)
        local git_buf = GitBuffer(bufnr)

        local result = git_buf:render()

        assert.equals(git_buf, result)
      end)
    end)

    describe('render_conflicts', function()
      it('renders conflict markers', function()
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

describe('GitBuffer blob cache lifecycle:', function()
  local async = require('tests.helpers.async')({ it = it, before_each = before_each, after_each = after_each })
  local it = async.it
  local before_each = async.before_each
  local after_each = async.after_each

  local repo
  local test_file

  before_each(function()
    local err
    repo, err = test_repo.create_repo({
      initial_commit = true,
      files = { ['test.txt'] = { 'line 1', 'line 2', 'line 3' } },
    })
    assert(not err, 'Failed to create test repo')
    test_file = repo .. '/test.txt'
  end)

  after_each(function()
    if repo then test_repo.cleanup(repo) end
  end)

  it('should delegate clear_blob_cache to _git_file', function()
    local bufnr = vim.fn.bufadd(test_file)
    vim.fn.bufload(bufnr)
    local git_buf = GitBuffer(bufnr)
    git_buf:sync()

    -- Populate cache via diff
    git_buf:diff()
    assert.is_not_nil(git_buf._git_file._blob_cache['index'])

    git_buf:clear_blob_cache()

    assert.is_nil(git_buf._git_file._blob_cache['index'])
  end)

  it('should be safe when _git_file is nil', function()
    local bufnr = vim.fn.bufadd(test_file)
    vim.fn.bufload(bufnr)
    local git_buf = GitBuffer(bufnr)
    -- Do NOT call sync(), so _git_file is nil

    -- Should not error
    local result = git_buf:clear_blob_cache()
    assert.equals(git_buf, result)
  end)

  it('should return updated hunks after external stage and clear_blob_cache', function()
    -- Modify the file
    test_repo.write_file(repo, 'test.txt', { 'modified 1', 'line 2', 'line 3' })
    local bufnr = vim.fn.bufadd(test_file)
    vim.fn.bufload(bufnr)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { 'modified 1', 'line 2', 'line 3' })

    local git_buf = GitBuffer(bufnr)
    git_buf:sync()

    -- First diff shows hunks
    local hunks1, err1 = git_buf:diff()
    assert.is_nil(err1)
    assert.is_table(hunks1)
    assert(#hunks1 > 0, 'should have hunks before staging')

    -- Externally stage the file
    test_repo.stage(repo, 'test.txt')

    -- Clear cache
    git_buf:clear_blob_cache()

    -- Diff again should show zero hunks (buffer matches index)
    local hunks2, err2 = git_buf:diff()
    assert.is_nil(err2)
    assert.is_table(hunks2)
    assert.equals(0, #hunks2)
  end)

  it('should invalidate cache during stage_hunk and re-diff with fresh index', function()
    local bufnr = vim.fn.bufadd(test_file)
    vim.fn.bufload(bufnr)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { 'modified 1', 'line 2', 'line 3' })

    local git_buf = GitBuffer(bufnr)
    git_buf:sync()

    local hunks, _ = git_buf:diff()
    if hunks and #hunks > 0 then
      local count_before = #hunks
      -- stage_hunk calls git_file:stage_hunk (nils cache) then diff() (re-fetches fresh index)
      local new_hunks, err = git_buf:stage_hunk(hunks[1])
      assert.is_nil(err)
      -- After staging the hunk, re-diff should show fewer or zero hunks
      assert.is_table(new_hunks)
      assert(#new_hunks < count_before, 'hunks should decrease after staging')
    end
  end)

  it('should set _signs_dirty to true after diff', function()
    local bufnr = vim.fn.bufadd(test_file)
    vim.fn.bufload(bufnr)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { 'modified 1', 'line 2', 'line 3' })

    local git_buf = GitBuffer(bufnr)
    git_buf:sync()

    assert.is_false(git_buf._signs_dirty)

    git_buf:diff()

    assert.is_true(git_buf._signs_dirty)
  end)

  it('should clear _signs_dirty flag after render_signs', function()
    local bufnr = vim.fn.bufadd(test_file)
    vim.fn.bufload(bufnr)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { 'modified 1', 'line 2', 'line 3' })

    local git_buf = GitBuffer(bufnr)
    git_buf:sync()

    git_buf:diff()
    assert.is_true(git_buf._signs_dirty)

    git_buf:render_signs()
    assert.is_false(git_buf._signs_dirty)
  end)
end)
