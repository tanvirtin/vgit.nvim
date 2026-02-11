local git_blame = require('vgit.git.git_blame')
local test_repo = require('tests.helpers.test_repo')
test_repo.use_driver('raw')
local async = require('tests.helpers.async')({ it = it, before_each = before_each, after_each = after_each })

local eq = assert.are.same
local it = async.it
local before_each = async.before_each
local after_each = async.after_each

describe('git_blame:', function()
  local repo

  before_each(function()
    local err
    repo, err = test_repo.create_repo({
      initial_commit = true,
      files = {
        ['file1.txt'] = { 'line 1', 'line 2', 'line 3' },
        ['file2.txt'] = { 'content' },
      },
    })
    assert(not err, 'Failed to create test repo: ' .. tostring(err))
  end)

  after_each(function()
    if repo then test_repo.cleanup(repo) end
  end)

  describe('list()', function()
    it('should return blame for entire file', function()
      local blames, err = git_blame.list(repo, 'file1.txt')

      assert(not err, 'Error occurred: ' .. tostring(err))
      assert(blames, 'blames should not be nil')
      eq(#blames, 3) -- 3 lines in file1.txt
    end)

    it('should parse blame info correctly', function()
      local blames, err = git_blame.list(repo, 'file1.txt')

      assert(not err)
      assert(blames[1])
      assert(blames[1].commit_hash, 'commit_hash should exist')
      assert(blames[1].author, 'author should exist')
      assert(blames[1].author_mail, 'author_mail should exist')
      assert(blames[1].author_time, 'author_time should exist')
      assert(blames[1].commit_message, 'commit_message should exist')
      eq(blames[1].lnum, 1)
    end)

    it('should handle multi-author files', function()
      -- Create second commit with different author
      test_repo.modify_file(repo, 'file1.txt', { 'line 1', 'modified by author 2', 'line 3' })
      test_repo.create_commit(repo, {
        files = { ['file1.txt'] = { 'line 1', 'modified by author 2', 'line 3' } },
        message = 'Second author commit',
        author = 'Second Author <second@example.com>',
      })

      local blames, err = git_blame.list(repo, 'file1.txt')

      assert(not err)
      eq(#blames, 3)

      -- Line 2 should have different author
      local authors = {}
      for _, blame in ipairs(blames) do
        authors[blame.lnum] = blame.author
      end

      -- First and third lines should have same author, second should differ
      eq(authors[1], authors[3])
      assert(authors[2] ~= authors[1], 'Line 2 should have different author')
    end)

    it('should work with specific commit', function()
      local first_commit = test_repo.get_head_commit(repo)

      -- Make another commit
      test_repo.modify_file(repo, 'file1.txt', { 'changed', 'line 2', 'line 3' })
      test_repo.create_commit(repo, {
        files = { ['file1.txt'] = { 'changed', 'line 2', 'line 3' } },
        message = 'Second commit',
      })

      -- Blame at first commit should show original content
      local blames, err = git_blame.list(repo, 'file1.txt', first_commit)

      assert(not err)
      eq(#blames, 3)
      -- All lines should have same commit hash (first commit)
      for _, blame in ipairs(blames) do
        eq(blame.commit_hash:sub(1, #first_commit), first_commit)
      end
    end)

    it('should handle files with merge commits', function()
      -- Create a branch
      test_repo.create_branch(repo, 'feature')

      -- Modify in branch
      test_repo.modify_file(repo, 'file1.txt', { 'branch change', 'line 2', 'line 3' })
      test_repo.create_commit(repo, {
        files = { ['file1.txt'] = { 'branch change', 'line 2', 'line 3' } },
        message = 'Branch commit',
      })

      -- Go back to main and merge
      test_repo.checkout(repo, 'master')
      vim.fn.system({ 'git', '-C', repo, 'merge', 'feature', '--no-edit' })

      local blames, err = git_blame.list(repo, 'file1.txt')

      assert(not err)
      assert(#blames > 0)
    end)

    it('should assign correct line numbers', function()
      local blames, err = git_blame.list(repo, 'file1.txt')

      assert(not err)
      eq(#blames, 3)

      -- Verify line numbers are sequential
      for i, blame in ipairs(blames) do
        eq(blame.lnum, i)
      end
    end)

    it('should handle single-line files', function()
      test_repo.write_file(repo .. '/single.txt', { 'one line' })
      test_repo.stage(repo, 'single.txt')
      test_repo.create_commit(repo, {
        files = { ['single.txt'] = { 'one line' } },
        message = 'Add single line file',
      })

      local blames, err = git_blame.list(repo, 'single.txt')

      assert(not err)
      eq(#blames, 1)
      eq(blames[1].lnum, 1)
    end)

    it('should handle files with empty lines', function()
      test_repo.write_file(repo .. '/empty_lines.txt', { 'line 1', '', 'line 3' })
      test_repo.stage(repo, 'empty_lines.txt')
      test_repo.create_commit(repo, {
        files = { ['empty_lines.txt'] = { 'line 1', '', 'line 3' } },
        message = 'Add file with empty lines',
      })

      local blames, err = git_blame.list(repo, 'empty_lines.txt')

      assert(not err)
      eq(#blames, 3)
    end)

    it('should error on nonexistent file', function()
      local blames, err = git_blame.list(repo, 'nonexistent.txt')

      assert(err, 'Should return error for nonexistent file')
      assert(not blames)
    end)

    it('should error when reponame is missing', function()
      local blames, err = git_blame.list(nil, 'file1.txt')

      assert(err)
      eq(err, { 'reponame is required' })
      assert(not blames)
    end)

    it('should error when filename is missing', function()
      local blames, err = git_blame.list(repo, nil)

      assert(err)
      eq(err, { 'filename is required' })
      assert(not blames)
    end)

    it('should default to HEAD when commit is nil', function()
      local blames_head, err1 = git_blame.list(repo, 'file1.txt', 'HEAD')
      local blames_nil, err2 = git_blame.list(repo, 'file1.txt', nil)

      assert(not err1)
      assert(not err2)
      eq(#blames_head, #blames_nil)
    end)

    it('should handle files in subdirectories', function()
      test_repo.write_file(repo .. '/subdir/nested.txt', { 'nested content' })
      test_repo.stage(repo, 'subdir/nested.txt')
      test_repo.create_commit(repo, {
        files = { ['subdir/nested.txt'] = { 'nested content' } },
        message = 'Add nested file',
      })

      local blames, err = git_blame.list(repo, 'subdir/nested.txt')

      assert(not err)
      eq(#blames, 1)
    end)

    it('should parse author email correctly', function()
      local blames, err = git_blame.list(repo, 'file1.txt')

      assert(not err)
      -- Should strip angle brackets if present
      assert(not blames[1].author_mail:match('[<>]'), 'Email should not contain angle brackets')
    end)

    it('should parse timestamps as numbers', function()
      local blames, err = git_blame.list(repo, 'file1.txt')

      assert(not err)
      assert.is_number(blames[1].author_time)
      assert.is_number(blames[1].committer_time)
    end)
  end)

  describe('get()', function()
    it('should return blame for specific line', function()
      local blame, err = git_blame.get(repo, 'file1.txt', 2)

      assert(not err)
      assert(blame)
      eq(blame.lnum, 2)
    end)

    it('should work for first line', function()
      local blame, err = git_blame.get(repo, 'file1.txt', 1)

      assert(not err)
      assert(blame)
      eq(blame.lnum, 1)
    end)

    it('should work for last line', function()
      local blame, err = git_blame.get(repo, 'file1.txt', 3)

      assert(not err)
      assert(blame)
      eq(blame.lnum, 3)
    end)

    it('should parse blame info correctly', function()
      local blame, err = git_blame.get(repo, 'file1.txt', 1)

      assert(not err)
      assert(blame.commit_hash)
      assert(blame.author)
      assert(blame.author_mail)
      assert(blame.author_time)
      assert(blame.commit_message)
    end)

    it('should handle different line numbers', function()
      -- Create file with multiple commits
      local first_commit = test_repo.get_head_commit(repo)

      test_repo.modify_file(repo, 'file1.txt', { 'line 1', 'modified line 2', 'line 3' })
      test_repo.create_commit(repo, {
        files = { ['file1.txt'] = { 'line 1', 'modified line 2', 'line 3' } },
        message = 'Modify line 2',
      })
      local second_commit = test_repo.get_head_commit(repo)

      local blame1, err1 = git_blame.get(repo, 'file1.txt', 1)
      local blame2, err2 = git_blame.get(repo, 'file1.txt', 2)

      assert(not err1)
      assert(not err2)

      -- Line 1 should still be from first commit
      eq(blame1.commit_hash:sub(1, #first_commit), first_commit)
      -- Line 2 should be from second commit
      eq(blame2.commit_hash:sub(1, #second_commit), second_commit)
    end)

    it('should error on invalid line number (too high)', function()
      local blame, err = git_blame.get(repo, 'file1.txt', 999)

      assert(err)
      assert(not blame)
    end)

    it('should error on invalid line number (zero)', function()
      local blame, err = git_blame.get(repo, 'file1.txt', 0)

      assert(err)
      assert(not blame)
    end)

    it('should error on invalid line number (negative)', function()
      local blame, err = git_blame.get(repo, 'file1.txt', -1)

      assert(err)
      assert(not blame)
    end)

    it('should error when reponame is missing', function()
      local blame, err = git_blame.get(nil, 'file1.txt', 1)

      assert(err)
      eq(err, { 'reponame is required' })
      assert(not blame)
    end)

    it('should error when filename is missing', function()
      local blame, err = git_blame.get(repo, nil, 1)

      assert(err)
      eq(err, { 'filename is required' })
      assert(not blame)
    end)

    it('should error when lnum is missing', function()
      local blame, err = git_blame.get(repo, 'file1.txt', nil)

      assert(err)
      eq(err, { 'lnum is required' })
      assert(not blame)
    end)

    it('should error on nonexistent file', function()
      local blame, err = git_blame.get(repo, 'nonexistent.txt', 1)

      assert(err)
      assert(not blame)
    end)

    it('should handle files in subdirectories', function()
      test_repo.write_file(repo .. '/subdir/nested.txt', { 'nested line 1', 'nested line 2' })
      test_repo.stage(repo, 'subdir/nested.txt')
      test_repo.create_commit(repo, {
        files = { ['subdir/nested.txt'] = { 'nested line 1', 'nested line 2' } },
        message = 'Add nested file',
      })

      local blame, err = git_blame.get(repo, 'subdir/nested.txt', 2)

      assert(not err)
      eq(blame.lnum, 2)
    end)
  end)
end)
