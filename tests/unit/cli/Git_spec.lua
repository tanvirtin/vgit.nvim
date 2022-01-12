local fs = require('vgit.core.fs')
local Object = require('vgit.core.Object')
local assertion = require('vgit.core.assertion')
local Git = require('vgit.cli.Git')
local a = require('plenary.async.tests')

local before_each = before_each
local after_each = after_each
local eq = assert.are.same

a.describe('Git:', function()
  local git

  local function use_invalid_directory()
    git:set_cwd('..')
  end

  -- If path is tests/mock then git will top looking from tests/mock directory for fixtures/ignoreme
  local function use_mock_repository()
    git:set_cwd('tests/mock')
  end

  before_each(function()
    git = Git:new()
    os.execute('mv tests/mock/.git_keep tests/mock/.git')
  end)

  after_each(function()
    os.execute('mv tests/mock/.git tests/mock/.git_keep')
  end)

  a.describe('config', function()
    a.it('should return the user defined config git object', function()
      local err, config = git:config()
      assert(not err)
      assertion.assert_table(config)
    end)
  end)

  a.describe('is_inside_git_dir', function()
    a.it(
      'should return true if we are currently inside a git repository',
      function()
        local result = git:is_inside_git_dir()
        assert(result)
      end
    )

    a.it('should return false if we are not inside a git repository', function()
      use_invalid_directory()
      local result = git:is_inside_git_dir()
      assert(not result)
    end)
  end)

  a.describe('is_ignored', function()
    local ignored_file = 'fixtures/ignoreme'
    local legit_file = 'fixtures/file1'

    a.it('should return true if a file is ignored', function()
      use_mock_repository()
      local result = git:is_ignored(ignored_file)
      eq(result, true)
    end)

    a.it('should return false if a file is not ignored', function()
      use_mock_repository()
      local result = git:is_ignored(legit_file)
      eq(result, false)
    end)
  end)

  a.describe('file_hunks', function()
    local filepath1 = 'fixtures/file1'
    local filepath2 = 'fixtures/file2'

    a.it('should return the hunks associated with the diff', function()
      use_mock_repository()
      local err, hunks = git:file_hunks(filepath1, filepath2)
      assert(not err)
      assert(hunks)
      eq(hunks, {
        {
          diff = { '-file1-3' },
          top = 2,
          bot = 2,
          header = '@@ -3 +2,0 @@ file1-2',
          type = 'remove',
          stat = {
            added = 0,
            removed = 1,
          },
        },
        {
          diff = { '+file1-6' },
          top = 5,
          bot = 5,
          header = '@@ -5,0 +5 @@ file1-5',
          type = 'add',
          stat = {
            added = 1,
            removed = 0,
          },
        },
      })
    end)

    a.it('should return an empty table if the files are the same', function()
      use_mock_repository()
      local err, hunks = git:file_hunks(filepath1, filepath1)
      assert(not err)
      assert(hunks)
      eq(hunks, {})
    end)
  end)

  a.describe('untracked_hunks', function()
    a.it('should return a hunk comprised of all the lines', function()
      local hunks = git:untracked_hunks({
        'a',
        'b',
        'c',
        'd',
        'e',
        'f',
      })
      assert(hunks)
      eq(hunks, {
        {
          diff = {
            '+a',
            '+b',
            '+c',
            '+d',
            '+e',
            '+f',
          },
          top = 1,
          bot = 6,
          type = 'add',
          stat = {
            added = 6,
            removed = 0,
          },
        },
      })
    end)

    a.it('should return an empty table if the lines are empty', function()
      local hunks = git:untracked_hunks({})
      assert(hunks)
      eq(hunks, {
        {
          diff = {},
          top = 1,
          bot = 0,
          header = nil,
          type = 'add',
          stat = {
            added = 0,
            removed = 0,
          },
        },
      })
    end)
  end)

  a.describe('tracked_filename', function()
    a.it(
      'should return the git tracked name for a given file in disk',
      function()
        use_mock_repository()
        local filename = 'fixtures/file1'
        local tracked_filename = git:tracked_filename(filename)
        eq(filename, tracked_filename)
      end
    )

    a.it('should return nil for a file not in git', function()
      local filename = 'lua/tinman.lua'
      local tracked_filename = git:tracked_filename(filename)
      assert(not tracked_filename)
    end)
  end)

  a.describe('show', function()
    a.it(
      'should retrieve the current lines in git for a given filename when the base is HEAD',
      function()
        use_mock_repository()
        local filename = 'fixtures/file1'
        local err, lines = git:show(filename, 'HEAD')
        assert(not err)
        assert(lines)
        eq(lines, {
          'file1-1',
          'file1-2',
          'file1-3',
          'file1-4',
          'file1-5',
        })
      end
    )
    a.it(
      'should retrieve the lines in git for a given file for a particular commit',
      function()
        use_mock_repository()
        local filename = 'fixtures/file3'
        local commit_hash = 'b3689ca8bc643725d18c231f6d8799e512443024'
        local err, lines = git:show(filename, commit_hash)
        assert(not err)
        assert(lines)
        eq(lines, {
          'file3-1',
        })
      end
    )
  end)
end)
