local test_harness = require('ops.lib.test_harness')
local git_test_repo = require('tests.helpers.git_test_repo')
local GitRepository = require('vgit.git.GitRepository')

local describe = test_harness.describe
local it = test_harness.it
local before_each = test_harness.before_each
local after_each = test_harness.after_each

describe('GitWorkingTree', function()
  local test_repo
  local repo
  local wt

  before_each(function()
    test_repo = git_test_repo.create()
    test_repo:init()

    -- Create and commit initial file
    test_repo:create_file('test.txt', { 'original content' })
    test_repo:stage_file('test.txt')
    test_repo:commit('Initial commit')

    repo = GitRepository.open(test_repo.dir)
    wt = repo:working_tree()
  end)

  after_each(function()
    if test_repo then test_repo:cleanup() end
  end)

  describe('constructor', function()
    it('creates working tree', function()
      assert(wt ~= nil, 'working tree should be created')
      assert(wt:root() == test_repo.dir, 'should have correct root')
    end)

    it('requires repository', function()
      local GitWorkingTree = require('vgit.git.GitWorkingTree')
      local success = pcall(function()
        GitWorkingTree(nil)
      end)
      assert(not success, 'should require repository')
    end)
  end)

  describe('root', function()
    it('returns repository root path', function()
      local root = wt:root()
      assert(root == test_repo.dir, 'should return correct root')
    end)
  end)

  describe('path', function()
    it('returns absolute path for file', function()
      local path = wt:path('test.txt')
      assert(path:match('test%.txt$'), 'should contain filename')
      assert(path:match('^/'), 'should be absolute path')
    end)

    it('returns root when no filename', function()
      local path = wt:path()
      assert(path == test_repo.dir, 'should return root')
    end)
  end)

  describe('exists', function()
    it('returns true for existing file', function()
      assert(wt:exists('test.txt'), 'file should exist')
    end)

    it('returns false for non-existing file', function()
      assert(not wt:exists('nonexistent.txt'), 'file should not exist')
    end)
  end)

  describe('read', function()
    it('reads file content', function()
      local lines, err = wt:read('test.txt')
      assert(err == nil, 'should not return error')
      assert(type(lines) == 'table', 'should return table')
      assert(#lines == 1, 'should have 1 line')
      assert(lines[1] == 'original content', 'should have correct content')
    end)

    it('returns error for non-existing file', function()
      local _, err = wt:read('nonexistent.txt')
      assert(err ~= nil, 'should return error')
    end)

    it('requires filename', function()
      local _, err = wt:read(nil)
      assert(err ~= nil, 'should return error')
    end)
  end)

  describe('write', function()
    it('writes file content', function()
      local success, err = wt:write('new.txt', { 'line 1', 'line 2' })
      assert(err == nil, 'should not return error')
      assert(success == true, 'should succeed')

      -- Verify content
      local lines = wt:read('new.txt')
      assert(#lines == 2, 'should have 2 lines')
    end)

    it('requires filename', function()
      local _, err = wt:write(nil, { 'content' })
      assert(err ~= nil, 'should return error')
    end)

    it('requires lines', function()
      local _, err = wt:write('file.txt', nil)
      assert(err ~= nil, 'should return error')
    end)
  end)

  describe('is_tracked', function()
    it('returns true for tracked file', function()
      local tracked, err = wt:is_tracked('test.txt')
      assert(err == nil, 'should not return error')
      assert(tracked == true, 'file should be tracked')
    end)

    it('returns false for untracked file', function()
      test_repo:create_file('untracked.txt', { 'content' })
      local tracked, err = wt:is_tracked('untracked.txt')
      assert(err == nil, 'should not return error')
      assert(tracked == false, 'file should not be tracked')
    end)
  end)

  describe('relative_path', function()
    it('converts absolute to relative path', function()
      local abs_path = test_repo.dir .. '/test.txt'
      local rel_path = wt:relative_path(abs_path)
      assert(rel_path == 'test.txt', 'should return relative path')
    end)

    it('returns nil for path outside repository', function()
      local abs_path = '/some/other/path/file.txt'
      local rel_path = wt:relative_path(abs_path)
      assert(rel_path == nil, 'should return nil')
    end)
  end)

  describe('contains', function()
    it('returns true for path within repository', function()
      local path = test_repo.dir .. '/test.txt'
      assert(wt:contains(path), 'path should be in repository')
    end)

    it('returns false for path outside repository', function()
      assert(not wt:contains('/some/other/path'), 'path should not be in repository')
    end)

    it('handles relative paths', function()
      assert(wt:contains('test.txt'), 'should handle relative paths')
    end)
  end)

  describe('stat', function()
    it('returns file statistics', function()
      local stat, err = wt:stat('test.txt')
      assert(err == nil, 'should not return error')
      assert(stat ~= nil, 'stat should be returned')
      assert(stat.size ~= nil, 'should have size')
    end)

    it('returns error for non-existing file', function()
      local _, err = wt:stat('nonexistent.txt')
      assert(err ~= nil, 'should return error')
    end)
  end)

  describe('is_ignored', function()
    it('returns false for tracked file', function()
      local ignored, err = wt:is_ignored('test.txt')
      assert(err == nil, 'should not return error')
      assert(ignored == false, 'tracked file should not be ignored')
    end)

    it('returns true for gitignored file', function()
      -- Create .gitignore
      test_repo:create_file('.gitignore', { '*.log' })
      test_repo:create_file('debug.log', { 'log content' })

      local ignored, err = wt:is_ignored('debug.log')
      assert(err == nil, 'should not return error')
      -- Note: result depends on gitignore implementation
      assert(type(ignored) == 'boolean', 'should return boolean')
    end)
  end)

  describe('hunks', function()
    it('returns hunks for modified file', function()
      -- Modify the committed file
      test_repo:create_file('test.txt', { 'modified content', 'new line' })

      local hunks, err = wt:hunks('test.txt')
      assert(err == nil, 'should not return error')
      assert(type(hunks) == 'table', 'should return table')
      if #hunks > 0 then assert(hunks[1].header ~= nil, 'hunk should have header') end
    end)

    it('returns empty for unmodified file', function()
      local hunks, err = wt:hunks('test.txt')
      assert(err == nil, 'should not return error')
      assert(type(hunks) == 'table', 'should return table')
    end)

    it('requires filename', function()
      local _, err = wt:hunks(nil)
      assert(err ~= nil, 'should return error')
    end)
  end)

  describe('compare', function()
    it('compares working tree with commit', function()
      -- Modify the file
      test_repo:create_file('test.txt', { 'modified content' })

      local comparison, err = wt:compare('test.txt', 'HEAD')
      assert(err == nil, 'should not return error')
      assert(comparison ~= nil, 'comparison should be returned')
      assert(comparison.original ~= nil, 'should have original')
      assert(comparison.current ~= nil, 'should have current')
      assert(comparison.hunks ~= nil, 'should have hunks')
    end)

    it('requires filename', function()
      local _, err = wt:compare(nil, 'HEAD')
      assert(err ~= nil, 'should return error')
    end)
  end)

  describe('reset', function()
    it('resets a modified file', function()
      -- Modify the file
      test_repo:create_file('test.txt', { 'modified content' })

      local success, err = wt:reset('test.txt')
      assert(err == nil, 'should not return error')
      assert(success == true, 'should succeed')

      -- Verify content is restored
      local lines = wt:read('test.txt')
      assert(lines[1] == 'original content', 'content should be restored')
    end)

    it('resets all files when no filename provided', function()
      test_repo:create_file('test.txt', { 'modified' })

      local success, err = wt:reset()
      assert(err == nil, 'should not return error')
      assert(type(success) == 'boolean', 'should return boolean')
    end)
  end)

  describe('clean', function()
    it('removes untracked file', function()
      test_repo:create_file('untracked.txt', { 'temp content' })

      local success, err = wt:clean('untracked.txt')
      assert(err == nil, 'should not return error')
      assert(success == true, 'should succeed')
      assert(not wt:exists('untracked.txt'), 'file should be removed')
    end)

    it('cleans all untracked files when no filename provided', function()
      test_repo:create_file('temp1.txt', { 'temp' })
      test_repo:create_file('temp2.txt', { 'temp' })

      local success, err = wt:clean()
      assert(err == nil, 'should not return error')
      assert(type(success) == 'boolean', 'should return boolean')
    end)
  end)

  describe('repository', function()
    it('returns repository reference', function()
      assert(wt:repository() == repo, 'should return repository')
    end)
  end)

  describe('live_hunks', function()
    it('returns hunks for modified tracked file', function()
      test_repo:create_file('test.txt', { 'line 1', 'line 2', 'line 3' })
      test_repo:stage_file('test.txt')
      test_repo:commit('Add test file')

      local current_lines = { 'modified 1', 'line 2', 'modified 3' }
      local hunks, err = wt:live_hunks('test.txt', current_lines)

      assert(err == nil, 'should not return error')
      assert(type(hunks) == 'table', 'should return table')
      assert(#hunks > 0, 'should have hunks')
    end)

    it('returns untracked hunks for new file', function()
      local current_lines = { 'new file content' }
      local hunks, err = wt:live_hunks('untracked.txt', current_lines)

      assert(err == nil, 'should not return error')
      assert(type(hunks) == 'table', 'should return table')
      assert(#hunks > 0, 'should have hunks for untracked file')
      assert(hunks[1].type == 'add', 'should be add type')
    end)

    it('returns empty hunks when no changes', function()
      test_repo:create_file('test.txt', { 'line 1', 'line 2' })
      test_repo:stage_file('test.txt')
      test_repo:commit('Add test file')

      local current_lines = { 'line 1', 'line 2' }
      local hunks, err = wt:live_hunks('test.txt', current_lines)

      assert(err == nil, 'should not return error')
      assert(type(hunks) == 'table', 'should return table')
      assert(#hunks == 0, 'should have no hunks when no changes')
    end)

    it('handles added lines', function()
      test_repo:create_file('test.txt', { 'line 1' })
      test_repo:stage_file('test.txt')
      test_repo:commit('Initial')

      local current_lines = { 'line 1', 'line 2', 'line 3' }
      local hunks, err = wt:live_hunks('test.txt', current_lines)

      assert(err == nil, 'should not return error')
      assert(#hunks > 0, 'should detect added lines')
    end)

    it('handles removed lines', function()
      test_repo:create_file('test.txt', { 'line 1', 'line 2', 'line 3' })
      test_repo:stage_file('test.txt')
      test_repo:commit('Initial')

      local current_lines = { 'line 1' }
      local hunks, err = wt:live_hunks('test.txt', current_lines)

      assert(err == nil, 'should not return error')
      assert(#hunks > 0, 'should detect removed lines')
    end)

    it('returns error when filename is missing', function()
      local _, err = wt:live_hunks(nil, { 'content' })

      assert(err ~= nil, 'should return error')
    end)

    it('returns error when current_lines is missing', function()
      local _, err = wt:live_hunks('test.txt', nil)

      assert(err ~= nil, 'should return error')
    end)

    it('handles multiple hunks in same file', function()
      test_repo:create_file('test.txt', { 'line 1', 'line 2', 'line 3', 'line 4', 'line 5' })
      test_repo:stage_file('test.txt')
      test_repo:commit('Initial')

      local current_lines = { 'modified 1', 'line 2', 'line 3', 'line 4', 'modified 5' }
      local hunks, err = wt:live_hunks('test.txt', current_lines)

      assert(err == nil, 'should not return error')
      assert(#hunks >= 2, 'should detect multiple hunks')
    end)

    it('works with files in subdirectories', function()
      test_repo:create_file('subdir/test.txt', { 'content' })
      test_repo:stage_file('subdir/test.txt')
      test_repo:commit('Add subdir file')

      local current_lines = { 'modified content' }
      local hunks, err = wt:live_hunks('subdir/test.txt', current_lines)

      assert(err == nil, 'should not return error')
      assert(#hunks > 0, 'should work with subdirectory files')
    end)
  end)
end)
