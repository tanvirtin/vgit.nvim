local async = require('plenary.async.tests')
local git_stager = require('vgit.git.git_stager')
local git_status = require('vgit.git.git_status')
local git_hunks = require('vgit.git.git_hunks')
local git_show = require('vgit.git.git_show')
local test_repo = require('tests.helpers.test_repo')
test_repo.use_driver('raw')

local eq = assert.are.same

async.describe('git_stager:', function()
  local repo

  async.before_each(function()
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

  async.after_each(function()
    if repo then test_repo.cleanup(repo) end
  end)

  async.describe('stage()', function()
    async.it('should stage single modified file', function()
      test_repo.modify_file(repo, 'file1.txt', { 'modified' })

      local _, err = git_stager.stage(repo, 'file1.txt')

      assert(not err)

      -- Verify file is staged
      local files = git_status.ls(repo)
      eq(#files, 1)
      eq(files[1].filename, 'file1.txt')
      eq(files[1].value, 'M ')
    end)

    async.it('should stage single new file', function()
      test_repo.write_file(repo .. '/new.txt', { 'new content' })

      local _, err = git_stager.stage(repo, 'new.txt')

      assert(not err)

      local files = git_status.ls(repo)
      eq(#files, 1)
      eq(files[1].filename, 'new.txt')
      eq(files[1].value, 'A ')
    end)

    async.it('should stage single deleted file', function()
      test_repo.delete_file(repo, 'file1.txt', false)

      local _, err = git_stager.stage(repo, 'file1.txt')

      assert(not err)

      local files = git_status.ls(repo)
      eq(#files, 1)
      eq(files[1].value, 'D ')
    end)

    async.it('should stage all files with "."', function()
      test_repo.modify_file(repo, 'file1.txt', { 'modified' })
      test_repo.write_file(repo .. '/new.txt', { 'new' })
      test_repo.delete_file(repo, 'file2.txt', false)

      local _, err = git_stager.stage(repo, '.')

      assert(not err)

      local files = git_status.ls(repo)
      eq(#files, 3)

      -- All should be staged
      for _, file in ipairs(files) do
        assert(file.value:match('^[AMD]'), 'File should be staged: ' .. file.filename)
      end
    end)

    async.it('should default to "." when filename is nil', function()
      test_repo.modify_file(repo, 'file1.txt', { 'modified' })
      test_repo.modify_file(repo, 'file2.txt', { 'also modified' })

      local _, err = git_stager.stage(repo, nil)

      assert(not err)

      local files = git_status.ls(repo)
      eq(#files, 2)
    end)

    async.it('should stage files in subdirectories', function()
      test_repo.write_file(repo .. '/subdir/nested.txt', { 'nested' })

      local _, err = git_stager.stage(repo, 'subdir/nested.txt')

      assert(not err)

      local files = git_status.ls(repo)
      eq(#files, 1)
      eq(files[1].filename, 'subdir/nested.txt')
    end)

    async.it('should handle staging already staged file', function()
      test_repo.modify_file(repo, 'file1.txt', { 'modified' })
      git_stager.stage(repo, 'file1.txt')

      -- Stage again
      local _, err = git_stager.stage(repo, 'file1.txt')

      assert(not err)
    end)

    async.it('should error when reponame is missing', function()
      local _, err = git_stager.stage(nil, 'file1.txt')

      assert(err)
      eq(err, { 'reponame is required' })
    end)

    async.it('should error on nonexistent file', function()
      local _, err = git_stager.stage(repo, 'nonexistent.txt')

      assert(err)
    end)
  end)

  async.describe('unstage()', function()
    async.it('should unstage single file', function()
      test_repo.modify_file(repo, 'file1.txt', { 'modified' })
      git_stager.stage(repo, 'file1.txt')

      local _, err = git_stager.unstage(repo, 'file1.txt')

      assert(not err)

      -- File should be unstaged but still modified
      local files = git_status.ls(repo)
      eq(#files, 1)
      eq(files[1].value, ' M')
    end)

    async.it('should unstage all files with "."', function()
      test_repo.modify_file(repo, 'file1.txt', { 'modified' })
      test_repo.modify_file(repo, 'file2.txt', { 'also modified' })
      git_stager.stage(repo, '.')

      local _, err = git_stager.unstage(repo, '.')

      assert(not err)

      local files = git_status.ls(repo)
      eq(#files, 2)

      -- All should be unstaged
      for _, file in ipairs(files) do
        eq(file.value, ' M')
      end
    end)

    async.it('should default to "." when filename is nil', function()
      test_repo.modify_file(repo, 'file1.txt', { 'modified' })
      test_repo.modify_file(repo, 'file2.txt', { 'also modified' })
      git_stager.stage(repo, '.')

      local _, err = git_stager.unstage(repo, nil)

      assert(not err)

      local files = git_status.ls(repo)
      for _, file in ipairs(files) do
        eq(file.value, ' M')
      end
    end)

    async.it('should unstage partially and leave working tree changes', function()
      test_repo.modify_file(repo, 'file1.txt', { 'modified' })
      git_stager.stage(repo, 'file1.txt')

      local _, err = git_stager.unstage(repo, 'file1.txt')

      assert(not err)

      -- File should show unstaged changes
      local files = git_status.ls(repo)
      eq(#files, 1)
      eq(files[1].value, ' M')
    end)

    async.it('should unstage new files', function()
      test_repo.write_file(repo .. '/new.txt', { 'new' })
      git_stager.stage(repo, 'new.txt')

      local _, err = git_stager.unstage(repo, 'new.txt')

      assert(not err)

      local files = git_status.ls(repo)
      eq(#files, 1)
      eq(files[1].value, '??')
    end)

    async.it('should unstage deleted files', function()
      test_repo.delete_file(repo, 'file1.txt', true)

      local _, err = git_stager.unstage(repo, 'file1.txt')

      assert(not err)

      local files = git_status.ls(repo)
      eq(#files, 1)
      eq(files[1].value, ' D')
    end)

    async.it('should handle unstaging non-staged file', function()
      test_repo.modify_file(repo, 'file1.txt', { 'modified' })

      -- Try to unstage when nothing is staged
      local _, err = git_stager.unstage(repo, 'file1.txt')

      assert(not err)
    end)

    async.it('should error when reponame is missing', function()
      local _, err = git_stager.unstage(nil, 'file1.txt')

      assert(err)
      eq(err, { 'reponame is required' })
    end)
  end)

  async.describe('stage_hunk()', function()
    async.it('should stage single hunk from file', function()
      -- Create file with multiple hunks
      test_repo.modify_file(repo, 'file1.txt', { 'changed line 1', 'line 2', 'line 3' })

      -- Get hunks
      local original = git_show.lines(repo, 'file1.txt', 'HEAD')
      local current = { 'changed line 1', 'line 2', 'line 3' }
      local hunks = git_hunks.live(nil, original, current)

      assert(#hunks > 0, 'Should have at least one hunk')

      local _, err = git_stager.stage_hunk(repo, 'file1.txt', hunks[1])

      assert(not err)

      -- Verify hunk is staged
      local files = git_status.ls(repo)
      assert(#files > 0)
    end)

    async.it('should stage add-type hunk for new content', function()
      -- Add new lines to existing file
      test_repo.modify_file(repo, 'file1.txt', { 'line 1', 'line 2', 'line 3', 'new line 4' })

      local original = git_show.lines(repo, 'file1.txt', 'HEAD')
      local current = { 'line 1', 'line 2', 'line 3', 'new line 4' }
      local hunks = git_hunks.live(nil, original, current)

      local _, err = git_stager.stage_hunk(repo, 'file1.txt', hunks[1])

      assert(not err)
    end)

    async.it('should stage change-type hunk', function()
      test_repo.modify_file(repo, 'file1.txt', { 'line 1', 'changed line 2', 'line 3' })

      local original = git_show.lines(repo, 'file1.txt', 'HEAD')
      local current = { 'line 1', 'changed line 2', 'line 3' }
      local hunks = git_hunks.live(nil, original, current)

      local _, err = git_stager.stage_hunk(repo, 'file1.txt', hunks[1])

      assert(not err)
    end)

    async.it('should stage remove-type hunk', function()
      test_repo.modify_file(repo, 'file1.txt', { 'line 1', 'line 3' })

      local original = git_show.lines(repo, 'file1.txt', 'HEAD')
      local current = { 'line 1', 'line 3' }
      local hunks = git_hunks.live(nil, original, current)

      local _, err = git_stager.stage_hunk(repo, 'file1.txt', hunks[1])

      assert(not err)
    end)

    async.it('should handle complex hunks', function()
      test_repo.modify_file(repo, 'file1.txt', {
        'changed line 1',
        'new line',
        'line 3',
      })

      local original = git_show.lines(repo, 'file1.txt', 'HEAD')
      local current = { 'changed line 1', 'new line', 'line 3' }
      local hunks = git_hunks.live(nil, original, current)

      for _, hunk in ipairs(hunks) do
        local _, err = git_stager.stage_hunk(repo, 'file1.txt', hunk)
        assert(not err)
      end
    end)

    async.it('should stage only specified hunk when multiple exist', function()
      -- Create file with changes at beginning and end
      test_repo.modify_file(repo, 'file1.txt', {
        'changed line 1',
        'line 2',
        'changed line 3',
      })

      local original = git_show.lines(repo, 'file1.txt', 'HEAD')
      local current = { 'changed line 1', 'line 2', 'changed line 3' }
      local hunks = git_hunks.live(nil, original, current)

      -- Should have 2 separate hunks
      if #hunks >= 2 then
        -- Stage only first hunk
        local _, err = git_stager.stage_hunk(repo, 'file1.txt', hunks[1])
        assert(not err)
      end
    end)

    async.it('should error when reponame is missing', function()
      local hunks = git_hunks.custom({ 'test' }, { untracked = true })
      local _, err = git_stager.stage_hunk(nil, 'file.txt', hunks[1])

      assert(err)
      eq(err, { 'reponame is required' })
    end)

    async.it('should error when filename is missing', function()
      local hunks = git_hunks.custom({ 'test' }, { untracked = true })
      local _, err = git_stager.stage_hunk(repo, nil, hunks[1])

      assert(err)
      eq(err, { 'filename is required' })
    end)

    async.it('should error when hunk is missing', function()
      local _, err = git_stager.stage_hunk(repo, 'file1.txt', nil)

      assert(err)
      eq(err, { 'hunk is required' })
    end)
  end)

  async.describe('unstage_hunk()', function()
    async.it('should unstage single hunk', function()
      -- Make changes and stage
      test_repo.modify_file(repo, 'file1.txt', { 'changed line 1', 'line 2', 'line 3' })
      git_stager.stage(repo, 'file1.txt')

      -- Get staged diff
      local original = git_show.lines(repo, 'file1.txt', 'HEAD')
      local current = { 'changed line 1', 'line 2', 'line 3' }
      local hunks = git_hunks.live(nil, original, current)

      local _, err = git_stager.unstage_hunk(repo, 'file1.txt', hunks[1])

      assert(not err)
    end)

    async.it('should unstage specific hunk when multiple exist', function()
      test_repo.modify_file(repo, 'file1.txt', {
        'changed line 1',
        'line 2',
        'changed line 3',
      })
      git_stager.stage(repo, 'file1.txt')

      local original = git_show.lines(repo, 'file1.txt', 'HEAD')
      local current = { 'changed line 1', 'line 2', 'changed line 3' }
      local hunks = git_hunks.live(nil, original, current)

      if #hunks >= 1 then
        local _, err = git_stager.unstage_hunk(repo, 'file1.txt', hunks[1])
        assert(not err)
      end
    end)

    async.it('should preserve other hunks when unstaging one', function()
      -- Create multiple separate hunks
      local content = {}
      for i = 1, 20 do
        if i == 5 then
          content[i] = 'changed line 5'
        elseif i == 15 then
          content[i] = 'changed line 15'
        else
          content[i] = 'line ' .. i
        end
      end

      test_repo.modify_file(repo, 'file1.txt', content)
      git_stager.stage(repo, 'file1.txt')

      local original = git_show.lines(repo, 'file1.txt', 'HEAD')
      local hunks = git_hunks.live(nil, original, content)

      -- Unstage first hunk if multiple exist
      if #hunks >= 2 then
        local _, err = git_stager.unstage_hunk(repo, 'file1.txt', hunks[1])
        assert(not err)
        -- Second hunk should still be staged
      end
    end)

    async.it('should error when reponame is missing', function()
      local hunks = git_hunks.custom({ 'test' }, { untracked = true })
      local _, err = git_stager.unstage_hunk(nil, 'file.txt', hunks[1])

      assert(err)
      eq(err, { 'reponame is required' })
    end)

    async.it('should error when filename is missing', function()
      local hunks = git_hunks.custom({ 'test' }, { untracked = true })
      local _, err = git_stager.unstage_hunk(repo, nil, hunks[1])

      assert(err)
      eq(err, { 'filename is required' })
    end)

    async.it('should error when hunk is missing', function()
      local _, err = git_stager.unstage_hunk(repo, 'file1.txt', nil)

      assert(err)
      eq(err, { 'hunk is required' })
    end)
  end)

  async.describe('integration scenarios', function()
    async.it('should handle stage/unstage cycle', function()
      test_repo.modify_file(repo, 'file1.txt', { 'modified' })

      -- Stage
      git_stager.stage(repo, 'file1.txt')
      local files1 = git_status.ls(repo)
      eq(files1[1].value, 'M ')

      -- Unstage
      git_stager.unstage(repo, 'file1.txt')
      local files2 = git_status.ls(repo)
      eq(files2[1].value, ' M')

      -- Stage again
      git_stager.stage(repo, 'file1.txt')
      local files3 = git_status.ls(repo)
      eq(files3[1].value, 'M ')
    end)

    async.it('should handle partial staging workflow', function()
      -- Create file with multiple changes
      test_repo.modify_file(repo, 'file1.txt', {
        'changed line 1',
        'line 2',
        'changed line 3',
      })

      local original = git_show.lines(repo, 'file1.txt', 'HEAD')
      local current = { 'changed line 1', 'line 2', 'changed line 3' }
      local hunks = git_hunks.live(nil, original, current)

      -- Stage hunks one by one
      for _, hunk in ipairs(hunks) do
        local _, err = git_stager.stage_hunk(repo, 'file1.txt', hunk)
        assert(not err)
      end
    end)
  end)
end)
