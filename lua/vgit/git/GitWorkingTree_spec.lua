local GitWorkingTree = require('vgit.git.GitWorkingTree')

local eq = assert.are.same

describe('GitWorkingTree:', function()
  local function make_repo(path)
    return {
      get_path = function()
        return path
      end,
    }
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

    it('should strip trailing slashes from root path', function()
      local tree = GitWorkingTree(make_repo('/my/repo/'))
      assert.are.equal('/my/repo', tree:root())
    end)

    it('should strip multiple trailing slashes from root path', function()
      local tree = GitWorkingTree(make_repo('/my/repo///'))
      assert.are.equal('/my/repo', tree:root())
    end)

    it('should preserve root path / as-is', function()
      local tree = GitWorkingTree(make_repo('/'))
      assert.are.equal('/', tree:root())
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

    it('should not produce double slashes when repo path has trailing slash', function()
      local tree = GitWorkingTree(make_repo('/my/repo/'))
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

    it('should work when repo path has trailing slash', function()
      local tree = GitWorkingTree(make_repo('/my/repo/'))
      assert.are.equal('src/main.lua', tree:relative_path('/my/repo/src/main.lua'))
    end)

    it('should not match partial directory prefixes', function()
      local tree = GitWorkingTree(make_repo('/my/repo'))
      assert.is_nil(tree:relative_path('/my/repo-extra/file.lua'))
    end)
  end)

  describe('exists', function()
    it('should return true for existing file', function()
      local tmpdir = vim.fn.tempname()
      vim.fn.mkdir(tmpdir, 'p')
      local filepath = tmpdir .. '/test.txt'
      vim.fn.writefile({ 'hello' }, filepath)

      local tree = GitWorkingTree(make_repo(tmpdir))
      assert.is_true(tree:exists('test.txt'))

      vim.fn.delete(tmpdir, 'rf')
    end)

    it('should return false for non-existent file', function()
      local tmpdir = vim.fn.tempname()
      vim.fn.mkdir(tmpdir, 'p')

      local tree = GitWorkingTree(make_repo(tmpdir))
      assert.is_false(tree:exists('nonexistent.txt'))

      vim.fn.delete(tmpdir, 'rf')
    end)

    it('should return false when filename is nil', function()
      local tree = GitWorkingTree(make_repo('/my/repo'))
      assert.is_false(tree:exists(nil))
    end)
  end)

  describe('read', function()
    it('should return file contents as lines', function()
      local tmpdir = vim.fn.tempname()
      vim.fn.mkdir(tmpdir, 'p')
      local filepath = tmpdir .. '/test.txt'
      vim.fn.writefile({ 'line1', 'line2', 'line3' }, filepath)

      local tree = GitWorkingTree(make_repo(tmpdir))
      local lines, err = tree:read('test.txt')

      assert.is_nil(err)
      assert.is_table(lines)

      vim.fn.delete(tmpdir, 'rf')
    end)

    it('should return error for non-existent file', function()
      local tmpdir = vim.fn.tempname()
      vim.fn.mkdir(tmpdir, 'p')

      local tree = GitWorkingTree(make_repo(tmpdir))
      local lines, err = tree:read('nonexistent.txt')

      assert.is_nil(lines)
      assert.is_not_nil(err)

      vim.fn.delete(tmpdir, 'rf')
    end)

    it('should return error when filename is nil', function()
      local tree = GitWorkingTree(make_repo('/my/repo'))
      local lines, err = tree:read(nil)

      assert.is_nil(lines)
      assert.is_not_nil(err)
    end)
  end)

  describe('stat', function()
    it('should return file stat information', function()
      local tmpdir = vim.fn.tempname()
      vim.fn.mkdir(tmpdir, 'p')
      local filepath = tmpdir .. '/test.txt'
      vim.fn.writefile({ 'hello' }, filepath)

      local tree = GitWorkingTree(make_repo(tmpdir))
      local stat, err = tree:stat('test.txt')

      assert.is_nil(err)
      assert.is_not_nil(stat)
      assert.is_number(stat.size)

      vim.fn.delete(tmpdir, 'rf')
    end)

    it('should return error for non-existent file', function()
      local tmpdir = vim.fn.tempname()
      vim.fn.mkdir(tmpdir, 'p')

      local tree = GitWorkingTree(make_repo(tmpdir))
      local stat, err = tree:stat('nonexistent.txt')

      assert.is_nil(stat)
      assert.is_not_nil(err)

      vim.fn.delete(tmpdir, 'rf')
    end)

    it('should return error when filename is nil', function()
      local tree = GitWorkingTree(make_repo('/my/repo'))
      local stat, err = tree:stat(nil)

      assert.is_nil(stat)
      assert.is_not_nil(err)
    end)
  end)

  describe('write', function()
    it('should write file contents', function()
      local tmpdir = vim.fn.tempname()
      vim.fn.mkdir(tmpdir, 'p')

      local tree = GitWorkingTree(make_repo(tmpdir))
      local result, err = tree:write('new.txt', { 'written' })

      assert.is_nil(err)
      assert.is_true(result)
      assert.is_true(tree:exists('new.txt'))

      vim.fn.delete(tmpdir, 'rf')
    end)

    it('should return error when filename is nil', function()
      local tree = GitWorkingTree(make_repo('/my/repo'))
      local result, err = tree:write(nil, { 'content' })

      assert.is_nil(result)
      assert.is_not_nil(err)
    end)

    it('should return error when lines is nil', function()
      local tree = GitWorkingTree(make_repo('/my/repo'))
      local result, err = tree:write('file.txt', nil)

      assert.is_nil(result)
      assert.is_not_nil(err)
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

    it('should not match partial directory prefixes', function()
      local tree = GitWorkingTree(make_repo('/my/repo'))
      assert.is_false(tree:contains('/my/repo-extra/file.lua'))
    end)

    it('should work when repo path has trailing slash', function()
      local tree = GitWorkingTree(make_repo('/my/repo/'))
      assert.is_true(tree:contains('/my/repo/src/file.lua'))
    end)
  end)
end)
