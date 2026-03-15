local eq = assert.are.same

local function make_git_file(overrides)
  local GitFile = require('vgit.git.GitFile')
  overrides = overrides or {}

  local obj = {
    reponame = overrides.reponame or '/tmp/test-repo',
    filepath = overrides.filepath or '/tmp/test-repo/test.lua',
    filename = overrides.filename or 'test.lua',
    filetype = overrides.filetype or 'lua',
    state = overrides.state or { hunks = nil },
  }
  setmetatable(obj, { __index = GitFile })
  return obj
end

describe('GitFile:', function()
  describe('constructor fields', function()
    it('should have reponame, filename, filetype set', function()
      local file = make_git_file({
        reponame = '/repo',
        filename = 'src/main.lua',
        filetype = 'lua',
      })

      eq('/repo', file.reponame)
      eq('src/main.lua', file.filename)
      eq('lua', file.filetype)
    end)

    it('should have state with hunks nil', function()
      local file = make_git_file()

      assert.is_table(file.state)
      assert.is_nil(file.state.hunks)
    end)
  end)

  describe('get_filename', function()
    it('should return relative filename', function()
      local file = make_git_file({ filename = 'src/parser.lua' })

      eq('src/parser.lua', file:get_filename())
    end)
  end)

  describe('get_filetype', function()
    it('should return detected filetype', function()
      local file = make_git_file({ filetype = 'python' })

      eq('python', file:get_filetype())
    end)
  end)

  describe('get_hunks', function()
    it('should return nil initially', function()
      local file = make_git_file()

      assert.is_nil(file:get_hunks())
    end)

    it('should return hunks after being set', function()
      local hunks = { { stat = { added = 1, removed = 0 } } }
      local file = make_git_file({ state = { hunks = hunks } })

      eq(hunks, file:get_hunks())
    end)
  end)
end)

describe('GitFile:generate_status', function()
  local GitFile_generate_status

  before_each(function()
    -- Create a minimal object that has the generate_status method
    -- without requiring the full GitFile constructor (which needs git)
    local GitFile = require('vgit.git.GitFile')
    GitFile_generate_status = function(hunks)
      local obj = { state = { hunks = hunks } }
      setmetatable(obj, { __index = GitFile })
      return obj:generate_status()
    end
  end)

  it('should return zeros for empty hunks', function()
    local status = GitFile_generate_status({})

    eq({ added = 0, changed = 0, removed = 0 }, status)
  end)

  it('should return zeros for nil hunks', function()
    local status = GitFile_generate_status(nil)

    eq({ added = 0, changed = 0, removed = 0 }, status)
  end)

  it('should count pure additions', function()
    local hunks = {
      { stat = { added = 5, removed = 0 } },
    }
    local status = GitFile_generate_status(hunks)

    eq({ added = 5, changed = 0, removed = 0 }, status)
  end)

  it('should count pure removals', function()
    local hunks = {
      { stat = { added = 0, removed = 3 } },
    }
    local status = GitFile_generate_status(hunks)

    eq({ added = 0, changed = 0, removed = 3 }, status)
  end)

  it('should count changes as min(added, removed)', function()
    -- When added=3, removed=2: changed=min(3,2)=2, net_added=3-2=1, net_removed=0
    local hunks = {
      { stat = { added = 3, removed = 2 } },
    }
    local status = GitFile_generate_status(hunks)

    eq({ added = 1, changed = 2, removed = 0 }, status)
  end)

  it('should count changes when removed > added', function()
    -- When added=2, removed=5: changed=min(2,5)=2, net_added=0, net_removed=3
    local hunks = {
      { stat = { added = 2, removed = 5 } },
    }
    local status = GitFile_generate_status(hunks)

    eq({ added = 0, changed = 2, removed = 3 }, status)
  end)

  it('should count equal added and removed as all changed', function()
    -- When added=4, removed=4: changed=4, net_added=0, net_removed=0
    local hunks = {
      { stat = { added = 4, removed = 4 } },
    }
    local status = GitFile_generate_status(hunks)

    eq({ added = 0, changed = 4, removed = 0 }, status)
  end)

  it('should sum across multiple hunks', function()
    local hunks = {
      { stat = { added = 5, removed = 0 } }, -- +5 added
      { stat = { added = 0, removed = 3 } }, -- +3 removed
      { stat = { added = 3, removed = 2 } }, -- +1 added, +2 changed
    }
    local status = GitFile_generate_status(hunks)

    eq({ added = 6, changed = 2, removed = 3 }, status)
  end)

  it('should handle multiple change hunks', function()
    local hunks = {
      { stat = { added = 2, removed = 1 } }, -- changed=1, added=1
      { stat = { added = 1, removed = 3 } }, -- changed=1, removed=2
    }
    local status = GitFile_generate_status(hunks)

    eq({ added = 1, changed = 2, removed = 2 }, status)
  end)

  it('should handle single line add', function()
    local hunks = {
      { stat = { added = 1, removed = 0 } },
    }
    local status = GitFile_generate_status(hunks)

    eq({ added = 1, changed = 0, removed = 0 }, status)
  end)

  it('should handle single line remove', function()
    local hunks = {
      { stat = { added = 0, removed = 1 } },
    }
    local status = GitFile_generate_status(hunks)

    eq({ added = 0, changed = 0, removed = 1 }, status)
  end)

  it('should handle single line change', function()
    local hunks = {
      { stat = { added = 1, removed = 1 } },
    }
    local status = GitFile_generate_status(hunks)

    eq({ added = 0, changed = 1, removed = 0 }, status)
  end)

  it('should handle large numbers', function()
    local hunks = {
      { stat = { added = 100, removed = 50 } },
      { stat = { added = 200, removed = 300 } },
    }
    local status = GitFile_generate_status(hunks)

    -- Hunk 1: changed=50, added=50, removed=0
    -- Hunk 2: changed=200, added=0, removed=100
    eq({ added = 50, changed = 250, removed = 100 }, status)
  end)
end)

-- Integration tests using real git repos
-- Stub out modules that the user's Neovim config may require in autocmds
package.loaded['lint'] = package.loaded['lint'] or { try_lint = function() end }

local test_repo = require('tests.helpers.test_repo')
test_repo.use_driver('raw')

describe('GitFile (integration):', function()
  local async = require('tests.helpers.async')({ it = it, before_each = before_each, after_each = after_each })
  local it = async.it
  local before_each = async.before_each
  local after_each = async.after_each

  local GitFile = require('vgit.git.GitFile')
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

  describe('blob cache', function()
    it('should populate cache on first call to _cached_blob_lines', function()
      local git_file = GitFile(test_file)

      assert.is_table(git_file._blob_cache)
      assert.is_nil(git_file._blob_cache['index'])

      local lines, err = git_file:_cached_blob_lines('index')

      assert.is_nil(err)
      assert.is_table(lines)
      assert.is_not_nil(git_file._blob_cache['index'])
    end)

    it('should return cached reference on second call', function()
      local git_file = GitFile(test_file)

      local lines1, err1 = git_file:_cached_blob_lines('index')
      assert.is_nil(err1)

      local lines2, err2 = git_file:_cached_blob_lines('index')
      assert.is_nil(err2)

      -- Same reference (not a new table)
      assert.equals(lines1, lines2)
    end)

    it('should empty cache on clear_blob_cache', function()
      local git_file = GitFile(test_file)

      git_file:_cached_blob_lines('index')
      assert.is_not_nil(git_file._blob_cache['index'])

      git_file:clear_blob_cache()

      assert.is_table(git_file._blob_cache)
      assert.is_nil(git_file._blob_cache['index'])
    end)

    it('should re-fetch fresh lines after clear_blob_cache', function()
      local git_file = GitFile(test_file)

      local lines1, _ = git_file:_cached_blob_lines('index')
      local ref1 = git_file._blob_cache['index']

      git_file:clear_blob_cache()

      local lines2, err2 = git_file:_cached_blob_lines('index')
      assert.is_nil(err2)
      assert.is_table(lines2)
      -- New reference after re-fetch
      assert.is_not.equals(ref1, git_file._blob_cache['index'])
    end)
  end)

  describe('stage and unstage', function()
    it('should stage file without error', function()
      test_repo.write_file(repo, 'test.txt', { 'modified line 1', 'line 2', 'line 3' })
      local git_file = GitFile(test_file)

      local _, err = git_file:stage()

      assert.is_nil(err)
    end)

    it('should set blob_cache index to nil after stage', function()
      local git_file = GitFile(test_file)

      -- Populate cache
      git_file:_cached_blob_lines('index')
      assert.is_not_nil(git_file._blob_cache['index'])

      test_repo.write_file(repo, 'test.txt', { 'modified line 1', 'line 2', 'line 3' })
      git_file:stage()

      assert.is_nil(git_file._blob_cache['index'])
    end)

    it('should unstage file without error', function()
      test_repo.write_file(repo, 'test.txt', { 'modified line 1', 'line 2', 'line 3' })
      test_repo.stage(repo, 'test.txt')
      local git_file = GitFile(test_file)

      local _, err = git_file:unstage()

      assert.is_nil(err)
    end)

    it('should set blob_cache index to nil after unstage', function()
      test_repo.write_file(repo, 'test.txt', { 'modified line 1', 'line 2', 'line 3' })
      test_repo.stage(repo, 'test.txt')
      local git_file = GitFile(test_file)

      git_file:_cached_blob_lines('index')
      assert.is_not_nil(git_file._blob_cache['index'])

      git_file:unstage()

      assert.is_nil(git_file._blob_cache['index'])
    end)

    it('should stage hunk and set blob_cache index to nil', function()
      local git_file = GitFile(test_file)

      -- Create a modification and get hunks
      local bufnr = vim.fn.bufadd(test_file)
      vim.fn.bufload(bufnr)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { 'modified 1', 'line 2', 'line 3' })
      local current_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

      local hunks, hunks_err = git_file:live_hunks(current_lines)
      assert.is_nil(hunks_err)

      if hunks and #hunks > 0 then
        -- Cache should be populated from live_hunks
        assert.is_not_nil(git_file._blob_cache['index'])

        local _, err = git_file:stage_hunk(hunks[1])
        assert.is_nil(err)
        assert.is_nil(git_file._blob_cache['index'])
      end
    end)

    it('should unstage hunk and set blob_cache index to nil', function()
      -- First stage a modification
      test_repo.write_file(repo, 'test.txt', { 'modified 1', 'line 2', 'line 3' })
      test_repo.stage(repo, 'test.txt')

      local git_file = GitFile(test_file)

      -- Get staged hunks via git_hunks
      local git_hunks = require('vgit.git.git_hunks')
      local hunks, _ = git_hunks.list(repo, { staged = true, filename = 'test.txt' })

      if hunks and #hunks > 0 then
        -- Populate cache
        git_file:_cached_blob_lines('index')
        assert.is_not_nil(git_file._blob_cache['index'])

        local _, err = git_file:unstage_hunk(hunks[1])
        assert.is_nil(err)
        assert.is_nil(git_file._blob_cache['index'])
      end
    end)
  end)

  describe('live_hunks', function()
    it('should return non-empty hunks for modified file', function()
      local git_file = GitFile(test_file)
      local current_lines = { 'modified 1', 'line 2', 'line 3' }

      local hunks, err = git_file:live_hunks(current_lines)

      assert.is_nil(err)
      assert.is_table(hunks)
      assert(#hunks > 0, 'should have hunks for modified file')
    end)

    it('should return empty hunks for unmodified file', function()
      local git_file = GitFile(test_file)
      local current_lines = { 'line 1', 'line 2', 'line 3' }

      local hunks, err = git_file:live_hunks(current_lines)

      assert.is_nil(err)
      assert.is_table(hunks)
      assert.equals(0, #hunks)
    end)

    it('should return add-type hunks for untracked file', function()
      local new_file = repo .. '/new_file.txt'
      test_repo.write_file(repo, 'new_file.txt', { 'new content' })
      local git_file = GitFile(new_file)
      local current_lines = { 'new content' }

      local hunks, err = git_file:live_hunks(current_lines)

      assert.is_nil(err)
      assert.is_table(hunks)
      assert(#hunks > 0, 'should have hunks for untracked file')
      assert.equals('add', hunks[1].type)
    end)

    it('should use cached blob on second call', function()
      local git_file = GitFile(test_file)
      local current_lines = { 'modified 1', 'line 2', 'line 3' }

      git_file:live_hunks(current_lines)
      -- After first call, cache should be populated
      assert.is_not_nil(git_file._blob_cache['index'])

      local hunks2, err2 = git_file:live_hunks(current_lines)
      assert.is_nil(err2)
      assert.is_table(hunks2)
    end)

    it('should succeed after clear_blob_cache', function()
      local git_file = GitFile(test_file)
      local current_lines = { 'modified 1', 'line 2', 'line 3' }

      git_file:live_hunks(current_lines)
      git_file:clear_blob_cache()
      assert.is_nil(git_file._blob_cache['index'])

      local hunks, err = git_file:live_hunks(current_lines)

      assert.is_nil(err)
      assert.is_table(hunks)
      assert(#hunks > 0, 'should still have hunks after cache clear')
    end)
  end)

  describe('blame', function()
    it('should return blame with commit_hash for committed file', function()
      local git_file = GitFile(test_file)

      local blame, err = git_file:blame(1)

      assert.is_nil(err)
      assert.is_not_nil(blame)
      assert.is_not_nil(blame.commit_hash)
    end)

    it('should return array with entries for each line via blames()', function()
      local git_file = GitFile(test_file)

      local blames, err = git_file:blames()

      assert.is_nil(err)
      assert.is_table(blames)
      assert(#blames > 0, 'should have blame entries')
    end)
  end)

  describe('file status checks', function()
    it('should return true for is_tracked on committed file', function()
      local git_file = GitFile(test_file)

      local result, err = git_file:is_tracked()

      assert.is_nil(err)
      assert.is_true(result)
    end)

    it('should return false for is_tracked on new untracked file', function()
      local new_file = repo .. '/untracked.txt'
      test_repo.write_file(repo, 'untracked.txt', { 'content' })
      local git_file = GitFile(new_file)

      local result, err = git_file:is_tracked()

      assert.is_nil(err)
      assert.is_false(result)
    end)

    it('should return true for is_ignored on file matching .gitignore', function()
      test_repo.write_file(repo, '.gitignore', { 'ignored.txt' })
      test_repo.write_file(repo, 'ignored.txt', { 'content' })
      local ignored_file = repo .. '/ignored.txt'
      local git_file = GitFile(ignored_file)

      local result, err = git_file:is_ignored()

      assert.is_nil(err)
      assert.is_true(result)
    end)

    it('should return false for is_ignored on normal tracked file', function()
      local git_file = GitFile(test_file)

      local result, err = git_file:is_ignored()

      assert.is_nil(err)
      assert.is_false(result)
    end)
  end)
end)
