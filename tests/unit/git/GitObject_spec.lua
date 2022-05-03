local fs = require('vgit.core.fs')
local Git = require('vgit.git.cli.Git')
local GitObject = require('vgit.git.GitObject')
local mock = require('luassert.mock')
local spy = require('luassert.spy')
local a = require('plenary.async.tests')

local eq = assert.are.same

a.describe('GitObject:', function()
  local filename = 'foo/bar/baz'
  local dirname = 'foo/bar'
  local untracked_hunks = {
    {
      type = 'untracked',
    },
  }
  local file_hunks = {
    {
      type = 'file',
    },
  }
  local git = {
    tracked_filename = spy.new(function()
      return filename
    end),

    is_inside_git_dir = spy.new(function()
      return true
    end),

    show = spy.new(function()
      return nil, {
        'a',
        'b',
        'c',
      }
    end),

    is_ignored = spy.new(function()
      return false
    end),

    untracked_hunks = spy.new(function()
      return untracked_hunks
    end),

    file_hunks = spy.new(function()
      return nil, file_hunks
    end),
  }
  local git_object

  before_each(function()
    Git = mock(Git, true)
    Git.returns(git)
    fs.write_file = spy.new(function() end)
    fs.remove_file = spy.new(function() end)
    fs.tmpname = spy.new(function()
      return 'temp'
    end)
    fs.dirname = mock(fs.dirname, true)
    fs.dirname.returns(dirname)
  end)

  after_each(function()
    mock.revert(fs.dirname)
    mock.revert(Git)
  end)

  describe('tracked_filename', function()
    before_each(function()
      Git = mock(Git, true)
      Git.returns(git)
      git_object = GitObject(filename)
      git.tracked_filename = spy.new(function()
        return filename
      end)
    end)

    it('returns the tracked filename from git', function()
      eq(git_object:tracked_filename(), filename)
    end)

    it('should store the result', function()
      git_object:tracked_filename()
      git_object:tracked_filename()

      assert.spy(git.tracked_filename).was.called(1)
    end)
  end)

  describe('is_inside_git_dir', function()
    before_each(function()
      Git = mock(Git, true)
      Git.returns(git)
      git_object = GitObject(filename)
    end)

    it(
      'should check if the current git object is inside a git repository',
      function()
        eq(git_object:is_inside_git_dir(), true)
      end
    )
  end)

  describe('lines', function()
    before_each(function()
      Git = mock(Git, true)
      Git.returns(git)
      git_object = GitObject(filename)
    end)

    it('should show the current lines in git related to the object', function()
      local err, lines = git_object:lines()
      assert(not err)
      eq(lines, { 'a', 'b', 'c' })
    end)
  end)

  describe('is_ignored', function()
    before_each(function()
      git_object = GitObject(filename)
    end)

    it('should check with git if the git object is ignored', function()
      eq(git_object:is_ignored(), false)
    end)
  end)

  a.describe('live_hunks', function()
    before_each(function()
      git_object = GitObject(filename)
    end)

    a.it(
      'should retrieve untracked hunks if there are no tracked filename',
      function()
        git.tracked_filename = spy.new(function()
          return ''
        end)

        local current_lines = {}
        local err, hunks = git_object:live_hunks(current_lines)

        assert(not err)
        assert.stub(git.untracked_hunks).was_called_with(git, current_lines)
        assert.stub(git.untracked_hunks).was_called(1)
        eq(hunks, untracked_hunks)
      end
    )

    a.it(
      'should not return tracked hunks if an error is encountered',
      function()
        git.tracked_filename = spy.new(function()
          return filename
        end)
        git.show = spy.new(function()
          return { 'error has occured' }, nil
        end)
        local current_lines = {}
        local err, hunks = git_object:live_hunks(current_lines)

        assert(err)
        assert(not hunks)
      end
    )
  end)
end)
