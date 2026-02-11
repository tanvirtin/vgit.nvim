local GitWorkingTree = require('vgit.git.GitWorkingTree')

describe('GitWorkingTree', function()
  local function make_repo(path)
    return { get_path = function() return path end }
  end

  describe('constructor', function()
    it('should error when repository is nil', function()
      assert.has_error(function()
        GitWorkingTree(nil)
      end, 'GitWorkingTree requires a repository')
    end)

    it('should create with valid repository', function()
      local tree = GitWorkingTree(make_repo('/my/repo'))
      assert.is_not_nil(tree)
    end)
  end)

  describe('root', function()
    it('should return the repository root path', function()
      local tree = GitWorkingTree(make_repo('/my/repo'))
      assert.are.equal('/my/repo', tree:root())
    end)
  end)

  describe('path', function()
    it('should return root path when filename is nil', function()
      local tree = GitWorkingTree(make_repo('/my/repo'))
      assert.are.equal('/my/repo', tree:path(nil))
    end)

    it('should join root path and filename', function()
      local tree = GitWorkingTree(make_repo('/my/repo'))
      assert.are.equal('/my/repo/src/main.lua', tree:path('src/main.lua'))
    end)

    it('should handle simple filenames', function()
      local tree = GitWorkingTree(make_repo('/my/repo'))
      assert.are.equal('/my/repo/file.lua', tree:path('file.lua'))
    end)
  end)

  describe('relative_path', function()
    it('should return relative path when absolute path is under root', function()
      local tree = GitWorkingTree(make_repo('/my/repo'))
      assert.are.equal('src/main.lua', tree:relative_path('/my/repo/src/main.lua'))
    end)

    it('should return nil when absolute path is not under root', function()
      local tree = GitWorkingTree(make_repo('/my/repo'))
      assert.is_nil(tree:relative_path('/other/path/file.lua'))
    end)

    it('should return nil when absolute_path is nil', function()
      local tree = GitWorkingTree(make_repo('/my/repo'))
      assert.is_nil(tree:relative_path(nil))
    end)

    it('should handle exact root path', function()
      local tree = GitWorkingTree(make_repo('/my/repo'))
      -- /my/repo/ with nothing after stripping root + separator
      assert.are.equal('', tree:relative_path('/my/repo/'))
    end)
  end)

  describe('contains', function()
    it('should return true for absolute path under root', function()
      local tree = GitWorkingTree(make_repo('/my/repo'))
      assert.is_true(tree:contains('/my/repo/src/file.lua'))
    end)

    it('should return false for absolute path outside root', function()
      local tree = GitWorkingTree(make_repo('/my/repo'))
      assert.is_false(tree:contains('/other/repo/file.lua'))
    end)

    it('should return false when path is nil', function()
      local tree = GitWorkingTree(make_repo('/my/repo'))
      assert.is_false(tree:contains(nil))
    end)

    it('should handle relative paths by joining with root', function()
      local tree = GitWorkingTree(make_repo('/my/repo'))
      -- relative path gets joined with root, so /my/repo/src/file.lua starts with /my/repo
      assert.is_true(tree:contains('src/file.lua'))
    end)
  end)
end)
