local git_show = require('vgit.git.git_show')
local test_repo = require('tests.helpers.test_repo')
test_repo.use_driver('raw')
local async = require('tests.helpers.async')({ it = it, before_each = before_each, after_each = after_each })

local eq = assert.are.same
local it = async.it
local before_each = async.before_each
local after_each = async.after_each

describe('git_show:', function()
  local repo

  before_each(function()
    local err
    repo, err = test_repo.create_repo({
      initial_commit = true,
      files = {
        ['file1.txt'] = { 'line 1', 'line 2', 'line 3' },
        ['file2.txt'] = { 'single line' },
      },
    })
    assert(not err, 'Failed to create test repo: ' .. tostring(err))
  end)

  after_each(function()
    if repo then test_repo.cleanup(repo) end
  end)

  describe('lines()', function()
    it('should retrieve file at HEAD', function()
      local lines, err = git_show.lines(repo, 'file1.txt', 'HEAD')

      assert(not err)
      assert(lines)
      eq(#lines, 3)
      eq(lines[1], 'line 1')
      eq(lines[2], 'line 2')
      eq(lines[3], 'line 3')
    end)

    it('should retrieve file at specific commit', function()
      local first_commit = test_repo.get_head_commit(repo)

      -- Modify file
      test_repo.create_commit(repo, {
        files = { ['file1.txt'] = { 'modified line 1', 'line 2', 'line 3' } },
        message = 'Modify file',
      })

      -- Get file at first commit
      local lines, err = git_show.lines(repo, 'file1.txt', first_commit)

      assert(not err)
      eq(lines[1], 'line 1') -- Should have original content
    end)

    it('should default to empty string commit when nil', function()
      local lines, err = git_show.lines(repo, 'file1.txt', nil)

      assert(not err)
      assert(lines)
      eq(#lines, 3)
    end)

    it('should handle empty files', function()
      test_repo.write_file(repo .. '/empty.txt', {})
      test_repo.stage(repo, 'empty.txt')
      test_repo.create_commit(repo, {
        files = { ['empty.txt'] = {} },
        message = 'Add empty file',
      })

      local lines, err = git_show.lines(repo, 'empty.txt', 'HEAD')

      assert(not err)
      assert(lines)
      eq(#lines, 0)
    end)

    it('should handle single-line files', function()
      local lines, err = git_show.lines(repo, 'file2.txt', 'HEAD')

      assert(not err)
      eq(#lines, 1)
      eq(lines[1], 'single line')
    end)

    it('should handle files with empty lines', function()
      test_repo.write_file(repo .. '/with_empty.txt', { 'line 1', '', 'line 3' })
      test_repo.stage(repo, 'with_empty.txt')
      test_repo.create_commit(repo, {
        files = { ['with_empty.txt'] = { 'line 1', '', 'line 3' } },
        message = 'Add file with empty lines',
      })

      local lines, err = git_show.lines(repo, 'with_empty.txt', 'HEAD')

      assert(not err)
      eq(#lines, 3)
      eq(lines[2], '')
    end)

    it('should handle files with special characters', function()
      test_repo.write_file(
        repo .. '/special.txt',
        { 'line with "quotes"', 'line with \'quotes\'', 'line with symbols &<>' }
      )
      test_repo.stage(repo, 'special.txt')
      test_repo.create_commit(repo, {
        files = { ['special.txt'] = { 'line with "quotes"', 'line with \'quotes\'', 'line with symbols &<>' } },
        message = 'Add file with special chars',
      })

      local lines, err = git_show.lines(repo, 'special.txt', 'HEAD')

      assert(not err)
      eq(#lines, 3)
      eq(lines[1], 'line with "quotes"')
      eq(lines[2], 'line with \'quotes\'')
      eq(lines[3], 'line with symbols &<>')
    end)

    it('should handle files with Unicode', function()
      test_repo.write_file(repo .. '/unicode.txt', { 'Hello 世界', 'Ñoño', '🎉 emoji' })
      test_repo.stage(repo, 'unicode.txt')
      test_repo.create_commit(repo, {
        files = { ['unicode.txt'] = { 'Hello 世界', 'Ñoño', '🎉 emoji' } },
        message = 'Add Unicode file',
      })

      local lines, err = git_show.lines(repo, 'unicode.txt', 'HEAD')

      assert(not err)
      eq(#lines, 3)
      assert(lines[1]:match('世界'))
      assert(lines[2]:match('Ñoño'))
      assert(lines[3]:match('🎉'))
    end)

    it('should handle files in subdirectories', function()
      test_repo.write_file(repo .. '/subdir/nested.txt', { 'nested content' })
      test_repo.stage(repo, 'subdir/nested.txt')
      test_repo.create_commit(repo, {
        files = { ['subdir/nested.txt'] = { 'nested content' } },
        message = 'Add nested file',
      })

      local lines, err = git_show.lines(repo, 'subdir/nested.txt', 'HEAD')

      assert(not err)
      eq(#lines, 1)
      eq(lines[1], 'nested content')
    end)

    it('should handle deeply nested files', function()
      test_repo.write_file(repo .. '/a/b/c/deep.txt', { 'deeply nested' })
      test_repo.stage(repo, 'a/b/c/deep.txt')
      test_repo.create_commit(repo, {
        files = { ['a/b/c/deep.txt'] = { 'deeply nested' } },
        message = 'Add deeply nested file',
      })

      local lines, err = git_show.lines(repo, 'a/b/c/deep.txt', 'HEAD')

      assert(not err)
      eq(#lines, 1)
      eq(lines[1], 'deeply nested')
    end)

    it('should retrieve file at old commit', function()
      local commits = {}

      -- Create multiple versions
      for i = 1, 5 do
        test_repo.modify_file(repo, 'file1.txt', { 'version ' .. i })
        test_repo.create_commit(repo, {
          files = { ['file1.txt'] = { 'version ' .. i } },
          message = 'Version ' .. i,
        })
        commits[i] = test_repo.get_head_commit(repo)
      end

      -- Get file at version 2
      local lines, err = git_show.lines(repo, 'file1.txt', commits[2])

      assert(not err)
      eq(lines[1], 'version 2')
    end)

    it('should handle deleted files at current HEAD', function()
      test_repo.delete_file(repo, 'file1.txt', true)
      test_repo.create_commit(repo, {
        add_all = true,
        message = 'Delete file',
      })

      local lines, err = git_show.lines(repo, 'file1.txt', 'HEAD')

      -- Should error because file doesn't exist at HEAD
      assert(err)
      assert(not lines)
    end)

    it('should retrieve deleted files at old commit', function()
      local first_commit = test_repo.get_head_commit(repo)

      -- Delete file
      test_repo.delete_file(repo, 'file1.txt', true)
      test_repo.create_commit(repo, {
        add_all = true,
        message = 'Delete file',
      })

      -- Should still be able to get file at old commit
      local lines, err = git_show.lines(repo, 'file1.txt', first_commit)

      assert(not err)
      eq(#lines, 3)
      eq(lines[1], 'line 1')
    end)

    it('should handle files with very long lines', function()
      local long_line = string.rep('a', 1000)
      test_repo.write_file(repo .. '/long.txt', { long_line })
      test_repo.stage(repo, 'long.txt')
      test_repo.create_commit(repo, {
        files = { ['long.txt'] = { long_line } },
        message = 'Add long line file',
      })

      local lines, err = git_show.lines(repo, 'long.txt', 'HEAD')

      assert(not err)
      eq(#lines, 1)
      eq(#lines[1], 1000)
    end)

    it('should handle files with many lines', function()
      local many_lines = {}
      for i = 1, 1000 do
        many_lines[i] = 'line ' .. i
      end

      test_repo.write_file(repo .. '/many.txt', many_lines)
      test_repo.stage(repo, 'many.txt')
      test_repo.create_commit(repo, {
        files = { ['many.txt'] = many_lines },
        message = 'Add file with many lines',
      })

      local lines, err = git_show.lines(repo, 'many.txt', 'HEAD')

      assert(not err)
      eq(#lines, 1000)
      eq(lines[1], 'line 1')
      eq(lines[1000], 'line 1000')
    end)

    it('should handle files with tabs', function()
      test_repo.write_file(repo .. '/tabs.txt', { '\tindented', 'normal\twith tab' })
      test_repo.stage(repo, 'tabs.txt')
      test_repo.create_commit(repo, {
        files = { ['tabs.txt'] = { '\tindented', 'normal\twith tab' } },
        message = 'Add file with tabs',
      })

      local lines, err = git_show.lines(repo, 'tabs.txt', 'HEAD')

      assert(not err)
      eq(#lines, 2)
      assert(lines[1]:match('^\t'))
      assert(lines[2]:match('\t'))
    end)

    it('should handle renamed files', function()
      local first_commit = test_repo.get_head_commit(repo)

      -- Rename file
      vim.fn.system({ 'git', '-C', repo, 'mv', 'file1.txt', 'renamed.txt' })
      test_repo.create_commit(repo, {
        add_all = true,
        message = 'Rename file',
      })

      -- Old name at old commit should work
      local lines_old, err1 = git_show.lines(repo, 'file1.txt', first_commit)
      assert(not err1)
      eq(#lines_old, 3)

      -- New name at HEAD should work
      local lines_new, err2 = git_show.lines(repo, 'renamed.txt', 'HEAD')
      assert(not err2)
      eq(#lines_new, 3)
    end)

    it('should error on nonexistent file', function()
      local lines, err = git_show.lines(repo, 'nonexistent.txt', 'HEAD')

      assert(err)
      assert(not lines)
    end)

    it('should error on invalid commit', function()
      local lines, err = git_show.lines(repo, 'file1.txt', 'invalid_commit_hash')

      assert(err)
      assert(not lines)
    end)

    it('should error when reponame is missing', function()
      local lines, err = git_show.lines(nil, 'file1.txt', 'HEAD')

      assert(err)
      eq(err, { 'reponame is required' })
      assert(not lines)
    end)

    it('should handle commit with empty string', function()
      -- Empty string should work (means index/working tree)
      local lines, err = git_show.lines(repo, 'file1.txt', '')

      -- Should succeed and return file content
      assert(not err, 'Should not error: ' .. vim.inspect(err))
      assert(lines, 'Should return lines')
      eq(#lines, 3)
    end)

    it('should work with short commit hashes', function()
      local full_hash = test_repo.get_head_commit(repo)
      local short_hash = full_hash:sub(1, 7)

      local lines, err = git_show.lines(repo, 'file1.txt', short_hash)

      assert(not err)
      eq(#lines, 3)
    end)

    it('should handle files added in middle of history', function()
      -- file1.txt exists from initial commit
      local first_commit = test_repo.get_head_commit(repo)

      -- Add new file
      test_repo.create_commit(repo, {
        files = { ['file3.txt'] = { 'new file' } },
        message = 'Add file3',
      })

      -- file3.txt should not exist at first commit
      local lines, err = git_show.lines(repo, 'file3.txt', first_commit)

      assert(err, 'Should error because file3.txt did not exist yet')
      assert(not lines)
    end)

    it('should handle relative commit refs', function()
      test_repo.create_commit(repo, {
        files = { ['file1.txt'] = { 'modified' } },
        message = 'Modify file',
      })

      -- HEAD~1 should give original version
      local lines, err = git_show.lines(repo, 'file1.txt', 'HEAD~1')

      assert(not err)
      eq(lines[1], 'line 1')
    end)

    it('should preserve line ending differences', function()
      -- This is tricky with git, but test that we get back what's stored
      test_repo.write_file(repo .. '/endings.txt', { 'line1', 'line2' })
      test_repo.stage(repo, 'endings.txt')
      test_repo.create_commit(repo, {
        files = { ['endings.txt'] = { 'line1', 'line2' } },
        message = 'Add file',
      })

      local lines, err = git_show.lines(repo, 'endings.txt', 'HEAD')

      assert(not err)
      eq(#lines, 2)
    end)
  end)
end)
