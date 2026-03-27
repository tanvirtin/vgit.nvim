local GitBlob = require('vgit.git.GitBlob')
local test_repo = require('tests.helpers.test_repo')
test_repo.use_driver('raw')
local async = require('tests.helpers.async')({ it = it, before_each = before_each, after_each = after_each })

local eq = assert.are.same

describe('GitBlob:', function()
  -- Unit tests (no repo needed)
  describe('constructor', function()
    it('should error when repo is nil', function()
      assert.has_error(function()
        GitBlob(nil, 'file.lua')
      end, 'GitBlob: repo_path is required')
    end)

    it('should error when filename is nil', function()
      assert.has_error(function()
        GitBlob('/my/repo', nil)
      end, 'GitBlob: filename is required')
    end)

    it('should error when filename is empty string', function()
      assert.has_error(function()
        GitBlob('/my/repo', '')
      end, 'GitBlob: filename is required')
    end)

    it('should accept string repo path', function()
      local blob = GitBlob('/my/repo', 'file.lua')
      assert.is_not_nil(blob)
    end)

    it('should accept repo object with get_path', function()
      local repo = {
        get_path = function()
          return '/my/repo'
        end,
      }
      local blob = GitBlob(repo, 'file.lua')
      assert.is_not_nil(blob)
    end)

    it('should default commit to HEAD', function()
      local blob = GitBlob('/my/repo', 'file.lua')
      assert.are.equal('HEAD', blob:get_commit())
    end)

    it('should accept custom commit', function()
      local blob = GitBlob('/my/repo', 'file.lua', 'abc123')
      assert.are.equal('abc123', blob:get_commit())
    end)
  end)

  describe('get_filename', function()
    it('should return the filename', function()
      local blob = GitBlob('/my/repo', 'src/main.lua')
      assert.are.equal('src/main.lua', blob:get_filename())
    end)
  end)

  describe('get_commit', function()
    it('should return HEAD when no commit specified', function()
      local blob = GitBlob('/my/repo', 'file.lua')
      assert.are.equal('HEAD', blob:get_commit())
    end)

    it('should return specified commit', function()
      local blob = GitBlob('/my/repo', 'file.lua', 'v1.0')
      assert.are.equal('v1.0', blob:get_commit())
    end)
  end)

  -- Integration tests (real repo)
  describe('integration', function()
    local repo
    local it = async.it
    local before_each = async.before_each
    local after_each = async.after_each

    before_each(function()
      local err
      repo, err = test_repo.create_repo({
        initial_commit = true,
        files = {
          ['file.txt'] = { 'line one', 'line two', 'line three' },
        },
      })
      assert(not err, 'Failed to create test repo: ' .. tostring(err))
    end)

    after_each(function()
      if repo then test_repo.cleanup(repo) end
    end)

    describe('exists', function()
      it('should return true for committed file at HEAD', function()
        local blob = GitBlob(repo, 'file.txt')
        local result, err = blob:exists()
        assert.is_nil(err)
        assert.is_true(result)
      end)

      it('should return false for non-existent file', function()
        local blob = GitBlob(repo, 'nonexistent.txt')
        local result, err = blob:exists()
        assert.is_nil(err)
        assert.is_false(result)
      end)

      it('should work with specific commit hash', function()
        local commit_hash = test_repo.get_head_commit(repo)
        local blob = GitBlob(repo, 'file.txt', commit_hash)
        local result, err = blob:exists()
        assert.is_nil(err)
        assert.is_true(result)
      end)
    end)

    describe('lines', function()
      it('should return file lines as table', function()
        local blob = GitBlob(repo, 'file.txt')
        local lines, err = blob:lines()
        assert.is_nil(err)
        assert.is_not_nil(lines)
        assert.is_true(#lines >= 3)
        eq('line one', lines[1])
        eq('line two', lines[2])
        eq('line three', lines[3])
      end)
    end)

    describe('with multiple commits', function()
      it('should return content from specific commit', function()
        -- Modify file and create second commit
        test_repo.write_file(repo, 'file.txt', { 'modified content' })
        test_repo.create_commit(repo, {
          files = { ['file.txt'] = { 'modified content' } },
          message = 'Modify file',
        })

        -- Get content at HEAD (modified)
        local blob_head = GitBlob(repo, 'file.txt', 'HEAD')
        local lines_head, err1 = blob_head:lines()
        assert.is_nil(err1)
        eq('modified content', lines_head[1])

        -- Get content at HEAD~1 (original)
        local blob_old = GitBlob(repo, 'file.txt', 'HEAD~1')
        local lines_old, err2 = blob_old:lines()
        assert.is_nil(err2)
        eq('line one', lines_old[1])
      end)
    end)
  end)
end)
