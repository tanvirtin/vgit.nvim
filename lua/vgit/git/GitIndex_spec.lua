local GitIndex = require('vgit.git.GitIndex')
local git_stager = require('vgit.git.git_stager')
local git_status = require('vgit.git.git_status')
local git_hunks = require('vgit.git.git_hunks')
local git_commit = require('vgit.git.git_commit')

local eq = assert.are.same

local function make_repo(path)
  return {
    get_path = function()
      return path or '/repo'
    end,
  }
end

local function make_file(opts)
  opts = opts or {}
  return {
    is_staged = function() return opts.staged or false end,
    is_unstaged = function() return opts.unstaged or false end,
    is_unmerged = function() return opts.unmerged or false end,
  }
end

describe('GitIndex:', function()
  local orig_stager_stage
  local orig_stager_unstage
  local orig_stager_stage_hunk
  local orig_stager_unstage_hunk
  local orig_status_ls
  local orig_hunks_list
  local orig_commit_create
  local orig_commit_dry_run

  before_each(function()
    orig_stager_stage = git_stager.stage
    orig_stager_unstage = git_stager.unstage
    orig_stager_stage_hunk = git_stager.stage_hunk
    orig_stager_unstage_hunk = git_stager.unstage_hunk
    orig_status_ls = git_status.ls
    orig_hunks_list = git_hunks.list
    orig_commit_create = git_commit.create
    orig_commit_dry_run = git_commit.dry_run
  end)

  after_each(function()
    git_stager.stage = orig_stager_stage
    git_stager.unstage = orig_stager_unstage
    git_stager.stage_hunk = orig_stager_stage_hunk
    git_stager.unstage_hunk = orig_stager_unstage_hunk
    git_status.ls = orig_status_ls
    git_hunks.list = orig_hunks_list
    git_commit.create = orig_commit_create
    git_commit.dry_run = orig_commit_dry_run
  end)

  describe('constructor', function()
    it('should error when repository is nil', function()
      assert.has_error(function()
        GitIndex(nil)
      end, 'GitIndex requires a repository')
    end)

    it('should create instance with valid repository', function()
      local index = GitIndex(make_repo('/my/repo'))

      eq('/my/repo', index._repo_path)
      assert.is_nil(index._staged_files)
    end)
  end)

  describe('add', function()
    it('should delegate to git_stager.stage with repo path and filename', function()
      local called_path, called_file
      git_stager.stage = function(path, filename)
        called_path = path
        called_file = filename
        return true, nil
      end

      local index = GitIndex(make_repo('/repo'))
      local result, err = index:add('file.txt')

      eq('/repo', called_path)
      eq('file.txt', called_file)
      eq(true, result)
      assert.is_nil(err)
    end)

    it('should invalidate staged_files cache on success', function()
      git_stager.stage = function() return true, nil end
      git_status.ls = function()
        return { make_file({ staged = true }) }, nil
      end

      local index = GitIndex(make_repo())
      -- populate cache
      index:staged_files()
      assert.is_not_nil(index._staged_files)

      index:add('file.txt')
      assert.is_nil(index._staged_files)
    end)

    it('should propagate errors from git_stager.stage', function()
      git_stager.stage = function() return nil, { 'stage failed' } end

      local index = GitIndex(make_repo())
      local result, err = index:add('file.txt')

      assert.is_nil(result)
      eq({ 'stage failed' }, err)
    end)

    it('should not invalidate cache when error occurs', function()
      git_stager.stage = function() return nil, { 'error' } end

      local index = GitIndex(make_repo())
      index._staged_files = { 'cached' }

      index:add('file.txt')
      -- cache is NOT invalidated on error (the code returns early before invalidation)
      eq({ 'cached' }, index._staged_files)
    end)
  end)

  describe('add_all', function()
    it('should delegate to git_stager.stage with nil filename', function()
      local called_file = 'not_nil'
      git_stager.stage = function(_, filename)
        called_file = filename
        return true, nil
      end

      local index = GitIndex(make_repo())
      local result, err = index:add_all()

      assert.is_nil(called_file)
      eq(true, result)
      assert.is_nil(err)
    end)
  end)

  describe('remove', function()
    it('should delegate to git_stager.unstage with repo path and filename', function()
      local called_path, called_file
      git_stager.unstage = function(path, filename)
        called_path = path
        called_file = filename
        return true, nil
      end

      local index = GitIndex(make_repo('/repo'))
      local result, err = index:remove('file.txt')

      eq('/repo', called_path)
      eq('file.txt', called_file)
      eq(true, result)
      assert.is_nil(err)
    end)

    it('should invalidate staged_files cache on success', function()
      git_stager.unstage = function() return true, nil end
      git_status.ls = function()
        return { make_file({ staged = true }) }, nil
      end

      local index = GitIndex(make_repo())
      index:staged_files()
      assert.is_not_nil(index._staged_files)

      index:remove('file.txt')
      assert.is_nil(index._staged_files)
    end)

    it('should propagate errors from git_stager.unstage', function()
      git_stager.unstage = function() return nil, { 'unstage failed' } end

      local index = GitIndex(make_repo())
      local result, err = index:remove('file.txt')

      assert.is_nil(result)
      eq({ 'unstage failed' }, err)
    end)
  end)

  describe('reset', function()
    it('should delegate to git_stager.unstage with nil filename', function()
      local called_file = 'not_nil'
      git_stager.unstage = function(_, filename)
        called_file = filename
        return true, nil
      end

      local index = GitIndex(make_repo())
      local result, err = index:reset()

      assert.is_nil(called_file)
      eq(true, result)
      assert.is_nil(err)
    end)
  end)

  describe('add_hunk', function()
    it('should return error when filename is nil', function()
      local index = GitIndex(make_repo())
      local result, err = index:add_hunk(nil, { type = 'add' })

      assert.is_nil(result)
      eq({ 'filename is required' }, err)
    end)

    it('should return error when hunk is nil', function()
      local index = GitIndex(make_repo())
      local result, err = index:add_hunk('file.txt', nil)

      assert.is_nil(result)
      eq({ 'hunk is required' }, err)
    end)

    it('should delegate to git_stager.stage_hunk', function()
      local called_path, called_file, called_hunk
      git_stager.stage_hunk = function(path, filename, hunk)
        called_path = path
        called_file = filename
        called_hunk = hunk
        return true, nil
      end

      local hunk = { type = 'add', start = 1 }
      local index = GitIndex(make_repo('/repo'))
      local result, err = index:add_hunk('file.txt', hunk)

      eq('/repo', called_path)
      eq('file.txt', called_file)
      eq(hunk, called_hunk)
      eq(true, result)
      assert.is_nil(err)
    end)

    it('should invalidate cache on success', function()
      git_stager.stage_hunk = function() return true, nil end

      local index = GitIndex(make_repo())
      index._staged_files = { 'cached' }

      index:add_hunk('file.txt', { type = 'add' })
      assert.is_nil(index._staged_files)
    end)

    it('should propagate errors from git_stager.stage_hunk', function()
      git_stager.stage_hunk = function() return nil, { 'stage hunk failed' } end

      local index = GitIndex(make_repo())
      local result, err = index:add_hunk('file.txt', { type = 'add' })

      assert.is_nil(result)
      eq({ 'stage hunk failed' }, err)
    end)
  end)

  describe('remove_hunk', function()
    it('should return error when filename is nil', function()
      local index = GitIndex(make_repo())
      local result, err = index:remove_hunk(nil, { type = 'add' })

      assert.is_nil(result)
      eq({ 'filename is required' }, err)
    end)

    it('should return error when hunk is nil', function()
      local index = GitIndex(make_repo())
      local result, err = index:remove_hunk('file.txt', nil)

      assert.is_nil(result)
      eq({ 'hunk is required' }, err)
    end)

    it('should delegate to git_stager.unstage_hunk', function()
      local called_path, called_file, called_hunk
      git_stager.unstage_hunk = function(path, filename, hunk)
        called_path = path
        called_file = filename
        called_hunk = hunk
        return true, nil
      end

      local hunk = { type = 'remove', start = 5 }
      local index = GitIndex(make_repo('/repo'))
      local result, err = index:remove_hunk('file.txt', hunk)

      eq('/repo', called_path)
      eq('file.txt', called_file)
      eq(hunk, called_hunk)
      eq(true, result)
      assert.is_nil(err)
    end)

    it('should invalidate cache on success', function()
      git_stager.unstage_hunk = function() return true, nil end

      local index = GitIndex(make_repo())
      index._staged_files = { 'cached' }

      index:remove_hunk('file.txt', { type = 'remove' })
      assert.is_nil(index._staged_files)
    end)
  end)

  describe('status', function()
    it('should delegate to git_status.ls with repo path', function()
      local called_path
      git_status.ls = function(path)
        called_path = path
        return { 'file1', 'file2' }, nil
      end

      local index = GitIndex(make_repo('/repo'))
      local result, err = index:status()

      eq('/repo', called_path)
      eq({ 'file1', 'file2' }, result)
      assert.is_nil(err)
    end)
  end)

  describe('file_status', function()
    it('should return error when filename is nil', function()
      local index = GitIndex(make_repo())
      local result, err = index:file_status(nil)

      assert.is_nil(result)
      eq({ 'filename is required' }, err)
    end)

    it('should delegate to git_status.ls with repo path and filename', function()
      local called_path, called_file
      git_status.ls = function(path, filename)
        called_path = path
        called_file = filename
        return { 'file_info' }, nil
      end

      local index = GitIndex(make_repo('/repo'))
      local result, err = index:file_status('test.lua')

      eq('/repo', called_path)
      eq('test.lua', called_file)
      eq({ 'file_info' }, result)
      assert.is_nil(err)
    end)
  end)

  describe('staged_files', function()
    it('should filter files by is_staged()', function()
      local staged_file = make_file({ staged = true })
      local unstaged_file = make_file({ unstaged = true })
      local unmerged_file = make_file({ unmerged = true })
      git_status.ls = function()
        return { staged_file, unstaged_file, unmerged_file }, nil
      end

      local index = GitIndex(make_repo())
      local result, err = index:staged_files()

      assert.is_nil(err)
      eq(1, #result)
      eq(staged_file, result[1])
    end)

    it('should cache result on subsequent calls', function()
      local call_count = 0
      git_status.ls = function()
        call_count = call_count + 1
        return { make_file({ staged = true }) }, nil
      end

      local index = GitIndex(make_repo())
      index:staged_files()
      index:staged_files()
      index:staged_files()

      eq(1, call_count)
    end)

    it('should return empty table when no files are staged', function()
      git_status.ls = function()
        return { make_file({ unstaged = true }), make_file({ unmerged = true }) }, nil
      end

      local index = GitIndex(make_repo())
      local result, err = index:staged_files()

      assert.is_nil(err)
      eq(0, #result)
    end)

    it('should propagate errors from status', function()
      git_status.ls = function() return nil, { 'status error' } end

      local index = GitIndex(make_repo())
      local result, err = index:staged_files()

      assert.is_nil(result)
      eq({ 'status error' }, err)
    end)
  end)

  describe('unstaged_files', function()
    it('should filter files by is_unstaged()', function()
      local staged_file = make_file({ staged = true })
      local unstaged_file = make_file({ unstaged = true })
      local both_file = make_file({ staged = true, unstaged = true })
      git_status.ls = function()
        return { staged_file, unstaged_file, both_file }, nil
      end

      local index = GitIndex(make_repo())
      local result, err = index:unstaged_files()

      assert.is_nil(err)
      eq(2, #result)
      eq(unstaged_file, result[1])
      eq(both_file, result[2])
    end)

    it('should return empty table when no unstaged files', function()
      git_status.ls = function()
        return { make_file({ staged = true }) }, nil
      end

      local index = GitIndex(make_repo())
      local result, err = index:unstaged_files()

      assert.is_nil(err)
      eq(0, #result)
    end)

    it('should propagate errors from status', function()
      git_status.ls = function() return nil, { 'status error' } end

      local index = GitIndex(make_repo())
      local result, err = index:unstaged_files()

      assert.is_nil(result)
      eq({ 'status error' }, err)
    end)
  end)

  describe('unmerged_files', function()
    it('should filter files by is_unmerged()', function()
      local staged_file = make_file({ staged = true })
      local unmerged_file = make_file({ unmerged = true })
      git_status.ls = function()
        return { staged_file, unmerged_file }, nil
      end

      local index = GitIndex(make_repo())
      local result, err = index:unmerged_files()

      assert.is_nil(err)
      eq(1, #result)
      eq(unmerged_file, result[1])
    end)

    it('should return empty table when no unmerged files', function()
      git_status.ls = function()
        return { make_file({ staged = true }) }, nil
      end

      local index = GitIndex(make_repo())
      local result, err = index:unmerged_files()

      assert.is_nil(err)
      eq(0, #result)
    end)

    it('should propagate errors from status', function()
      git_status.ls = function() return nil, { 'status error' } end

      local index = GitIndex(make_repo())
      local result, err = index:unmerged_files()

      assert.is_nil(result)
      eq({ 'status error' }, err)
    end)
  end)

  describe('staged_hunks', function()
    it('should delegate to git_hunks.list with staged=true', function()
      local called_path, called_opts
      git_hunks.list = function(path, opts)
        called_path = path
        called_opts = opts
        return { 'hunk1' }, nil
      end

      local index = GitIndex(make_repo('/repo'))
      local result, err = index:staged_hunks('file.txt')

      eq('/repo', called_path)
      eq(true, called_opts.staged)
      eq('file.txt', called_opts.filename)
      eq({ 'hunk1' }, result)
      assert.is_nil(err)
    end)
  end)

  describe('unstaged_hunks', function()
    it('should delegate to git_hunks.list with staged=false', function()
      local called_path, called_opts
      git_hunks.list = function(path, opts)
        called_path = path
        called_opts = opts
        return { 'hunk1', 'hunk2' }, nil
      end

      local index = GitIndex(make_repo('/repo'))
      local result, err = index:unstaged_hunks('file.txt')

      eq('/repo', called_path)
      eq(false, called_opts.staged)
      eq('file.txt', called_opts.filename)
      eq({ 'hunk1', 'hunk2' }, result)
      assert.is_nil(err)
    end)
  end)

  describe('has_staged_changes', function()
    it('should return true when staged files exist', function()
      git_status.ls = function()
        return { make_file({ staged = true }) }, nil
      end

      local index = GitIndex(make_repo())
      local result, err = index:has_staged_changes()

      assert.is_nil(err)
      eq(true, result)
    end)

    it('should return false when no staged files', function()
      git_status.ls = function()
        return { make_file({ unstaged = true }) }, nil
      end

      local index = GitIndex(make_repo())
      local result, err = index:has_staged_changes()

      assert.is_nil(err)
      eq(false, result)
    end)

    it('should propagate errors', function()
      git_status.ls = function() return nil, { 'error' } end

      local index = GitIndex(make_repo())
      local result, err = index:has_staged_changes()

      assert.is_nil(result)
      eq({ 'error' }, err)
    end)
  end)

  describe('has_unstaged_changes', function()
    it('should return true when unstaged files exist', function()
      git_status.ls = function()
        return { make_file({ unstaged = true }) }, nil
      end

      local index = GitIndex(make_repo())
      local result, err = index:has_unstaged_changes()

      assert.is_nil(err)
      eq(true, result)
    end)

    it('should return false when no unstaged files', function()
      git_status.ls = function()
        return { make_file({ staged = true }) }, nil
      end

      local index = GitIndex(make_repo())
      local result, err = index:has_unstaged_changes()

      assert.is_nil(err)
      eq(false, result)
    end)

    it('should propagate errors', function()
      git_status.ls = function() return nil, { 'error' } end

      local index = GitIndex(make_repo())
      local result, err = index:has_unstaged_changes()

      assert.is_nil(result)
      eq({ 'error' }, err)
    end)
  end)

  describe('is_clean', function()
    it('should return true when no files in status', function()
      git_status.ls = function() return {}, nil end

      local index = GitIndex(make_repo())
      local result, err = index:is_clean()

      assert.is_nil(err)
      eq(true, result)
    end)

    it('should return false when files exist in status', function()
      git_status.ls = function()
        return { make_file({ unstaged = true }) }, nil
      end

      local index = GitIndex(make_repo())
      local result, err = index:is_clean()

      assert.is_nil(err)
      eq(false, result)
    end)

    it('should propagate errors', function()
      git_status.ls = function() return nil, { 'error' } end

      local index = GitIndex(make_repo())
      local result, err = index:is_clean()

      assert.is_nil(result)
      eq({ 'error' }, err)
    end)
  end)

  describe('commit', function()
    it('should return error when message is nil', function()
      local index = GitIndex(make_repo())
      local result, err = index:commit(nil)

      assert.is_nil(result)
      eq({ 'commit message is required' }, err)
    end)

    it('should return error when message is empty string', function()
      local index = GitIndex(make_repo())
      local result, err = index:commit('')

      assert.is_nil(result)
      eq({ 'commit message is required' }, err)
    end)

    it('should return error when no staged changes', function()
      git_status.ls = function()
        return { make_file({ unstaged = true }) }, nil
      end

      local index = GitIndex(make_repo())
      local result, err = index:commit('test commit')

      assert.is_nil(result)
      eq({ 'no staged changes to commit' }, err)
    end)

    it('should delegate to git_commit.create on success', function()
      local called_path, called_message
      git_status.ls = function()
        return { make_file({ staged = true }) }, nil
      end
      git_commit.create = function(path, message)
        called_path = path
        called_message = message
        return true, nil
      end

      local index = GitIndex(make_repo('/repo'))
      local result, err = index:commit('initial commit')

      eq('/repo', called_path)
      eq('initial commit', called_message)
      eq(true, result)
      assert.is_nil(err)
    end)

    it('should invalidate cache after successful commit', function()
      git_status.ls = function()
        return { make_file({ staged = true }) }, nil
      end
      git_commit.create = function() return true, nil end

      local index = GitIndex(make_repo())
      -- populate cache
      index:staged_files()
      assert.is_not_nil(index._staged_files)

      index:commit('test')
      assert.is_nil(index._staged_files)
    end)

    it('should propagate errors from has_staged_changes', function()
      git_status.ls = function() return nil, { 'status error' } end

      local index = GitIndex(make_repo())
      local result, err = index:commit('test')

      assert.is_nil(result)
      eq({ 'status error' }, err)
    end)

    it('should propagate errors from git_commit.create', function()
      git_status.ls = function()
        return { make_file({ staged = true }) }, nil
      end
      git_commit.create = function() return nil, { 'commit error' } end

      local index = GitIndex(make_repo())
      local result, err = index:commit('test')

      assert.is_nil(result)
      eq({ 'commit error' }, err)
    end)
  end)

  describe('can_commit', function()
    it('should return true when staged changes exist', function()
      git_status.ls = function()
        return { make_file({ staged = true }) }, nil
      end

      local index = GitIndex(make_repo())
      local result, err = index:can_commit()

      assert.is_nil(err)
      eq(true, result)
    end)

    it('should return false when no staged changes', function()
      git_status.ls = function() return {}, nil end

      local index = GitIndex(make_repo())
      local result, err = index:can_commit()

      assert.is_nil(err)
      eq(false, result)
    end)

    it('should propagate errors', function()
      git_status.ls = function() return nil, { 'error' } end

      local index = GitIndex(make_repo())
      local result, err = index:can_commit()

      assert.is_nil(result)
      eq({ 'error' }, err)
    end)
  end)

  describe('commit_dry_run', function()
    it('should delegate to git_commit.dry_run', function()
      local called_path
      git_commit.dry_run = function(path)
        called_path = path
        return { 'dry run output' }, nil
      end

      local index = GitIndex(make_repo('/repo'))
      local result, err = index:commit_dry_run()

      eq('/repo', called_path)
      eq({ 'dry run output' }, result)
      assert.is_nil(err)
    end)
  end)

  describe('reset_cache', function()
    it('should clear _staged_files', function()
      git_status.ls = function()
        return { make_file({ staged = true }) }, nil
      end

      local index = GitIndex(make_repo())
      index:staged_files()
      assert.is_not_nil(index._staged_files)

      index:reset_cache()
      assert.is_nil(index._staged_files)
    end)

    it('should allow staged_files to refetch after reset', function()
      local call_count = 0
      git_status.ls = function()
        call_count = call_count + 1
        return { make_file({ staged = true }) }, nil
      end

      local index = GitIndex(make_repo())
      index:staged_files()
      eq(1, call_count)

      index:reset_cache()
      index:staged_files()
      eq(2, call_count)
    end)
  end)
end)
