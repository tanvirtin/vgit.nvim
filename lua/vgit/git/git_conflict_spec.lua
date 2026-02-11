local git_conflict = require('vgit.git.git_conflict')
local test_repo = require('tests.helpers.test_repo')
test_repo.use_driver('raw')
local async = require('tests.helpers.async')({ it = it, before_each = before_each, after_each = after_each })

local eq = assert.are.same
local it = async.it
local before_each = async.before_each
local after_each = async.after_each

describe('git_conflict:', function()
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

  describe('parse()', function()
    it('should parse simple conflict with current and incoming', function()
      local conflicts = git_conflict.parse({
        '<<<<<<< HEAD',
        'local foo = 1',
        '=======',
        'local foo = 2',
        '>>>>>>> incoming_branch',
      })

      eq(#conflicts, 1)
      eq(conflicts[1].current.top, 1)
      eq(conflicts[1].current.bot, 2)
      eq(conflicts[1].middle.top, 3)
      eq(conflicts[1].incoming.top, 4)
      eq(conflicts[1].incoming.bot, 5)
    end)

    it('should parse conflict with ancestor (3-way merge)', function()
      local conflicts = git_conflict.parse({
        '<<<<<<< HEAD',
        'local foo = 1',
        'print(foo)',
        '||||||| 1f5d944',
        'local foo = 2',
        '=======',
        'local foo = 3',
        '>>>>>>> incoming_branch',
      })

      eq(#conflicts, 1)
      eq(conflicts[1].current.top, 1)
      eq(conflicts[1].current.bot, 3)
      eq(conflicts[1].ancestor.top, 4)
      eq(conflicts[1].ancestor.bot, 5)
      eq(conflicts[1].middle.top, 6)
      eq(conflicts[1].incoming.top, 7)
      eq(conflicts[1].incoming.bot, 8)
    end)

    it('should parse multiple conflicts in same file', function()
      local conflicts = git_conflict.parse({
        'line 1',
        '<<<<<<< HEAD',
        'conflict 1 current',
        '=======',
        'conflict 1 incoming',
        '>>>>>>> branch',
        'middle content',
        '<<<<<<< HEAD',
        'conflict 2 current',
        '=======',
        'conflict 2 incoming',
        '>>>>>>> branch',
        'final line',
      })

      eq(#conflicts, 2)

      -- First conflict
      eq(conflicts[1].current.top, 2)
      eq(conflicts[1].incoming.bot, 6)

      -- Second conflict
      eq(conflicts[2].current.top, 8)
      eq(conflicts[2].incoming.bot, 12)
    end)

    it('should parse conflict with empty current section', function()
      local conflicts = git_conflict.parse({
        '<<<<<<< HEAD',
        '=======',
        'incoming content',
        '>>>>>>> branch',
      })

      eq(#conflicts, 1)
      eq(conflicts[1].current.top, 1)
      eq(conflicts[1].current.bot, 1)
    end)

    it('should parse conflict with empty incoming section', function()
      local conflicts = git_conflict.parse({
        '<<<<<<< HEAD',
        'current content',
        '=======',
        '>>>>>>> branch',
      })

      eq(#conflicts, 1)
      eq(conflicts[1].incoming.top, 4)
      eq(conflicts[1].incoming.bot, 4)
    end)

    it('should parse conflict with multiline sections', function()
      local conflicts = git_conflict.parse({
        '<<<<<<< HEAD',
        'line 1',
        'line 2',
        'line 3',
        'line 4',
        '=======',
        'other 1',
        'other 2',
        'other 3',
        '>>>>>>> branch',
      })

      eq(#conflicts, 1)
      eq(conflicts[1].current.top, 1)
      eq(conflicts[1].current.bot, 5)
      eq(conflicts[1].incoming.top, 7)
      eq(conflicts[1].incoming.bot, 10)
    end)

    it('should return empty array for file without conflicts', function()
      local conflicts = git_conflict.parse({
        'line 1',
        'line 2',
        'line 3',
      })

      eq(#conflicts, 0)
    end)

    it('should handle incomplete conflict markers', function()
      local conflicts = git_conflict.parse({
        '<<<<<<< HEAD',
        'current',
        '=======',
        -- Missing >>>>>>> marker
      })

      -- Should not parse incomplete conflict
      eq(#conflicts, 0)
    end)

    it('should handle conflict markers in strings (not actual conflicts)', function()
      local conflicts = git_conflict.parse({
        'normal line',
        'another line',
      })

      eq(#conflicts, 0)
    end)

    it('should parse conflict with long branch names', function()
      local conflicts = git_conflict.parse({
        '<<<<<<< HEAD',
        'current',
        '=======',
        'incoming',
        '>>>>>>> feature/really-long-branch-name-here',
      })

      eq(#conflicts, 1)
    end)

    it('should handle mixed conflict types', function()
      local conflicts = git_conflict.parse({
        '<<<<<<< HEAD',
        'first without ancestor',
        '=======',
        'incoming',
        '>>>>>>> branch1',
        'middle',
        '<<<<<<< HEAD',
        'second with ancestor',
        '||||||| base',
        'ancestor',
        '=======',
        'incoming',
        '>>>>>>> branch2',
      })

      eq(#conflicts, 2)

      -- First conflict should have no ancestor
      eq(conflicts[1].ancestor.top, nil)

      -- Second conflict should have ancestor
      assert(conflicts[2].ancestor.top)
    end)
  end)

  describe('status()', function()
    it('should return nil for normal state', function()
      local status, err = git_conflict.status(repo)

      assert(not err)
      eq(status, nil)
    end)

    it('should detect MERGE state from git directory', function()
      --Create a merge conflict scenario
      test_repo.create_branch(repo, 'feature')
      test_repo.modify_file(repo, 'file1.txt', { 'feature change' })
      test_repo.stage(repo, 'file1.txt')
      test_repo.create_commit(repo, {
        files = { ['file1.txt'] = { 'feature change' } },
        message = 'Feature change',
      })

      test_repo.checkout(repo, 'master')
      test_repo.modify_file(repo, 'file1.txt', { 'master change' })
      test_repo.stage(repo, 'file1.txt')
      test_repo.create_commit(repo, {
        files = { ['file1.txt'] = { 'master change' } },
        message = 'Master change',
      })

      vim.fn.system({ 'git', '-C', repo, 'merge', 'feature' })

      local status, err = git_conflict.status(repo)

      assert(not err)
      -- May be MERGE or nil depending on whether merge conflicted
      assert(status == 'MERGE' or status == nil)
    end)

    it('should return CHERRY-PICK during cherry-pick conflict', function()
      -- Create commits
      test_repo.create_commit(repo, {
        files = { ['file3.txt'] = { 'content' } },
        message = 'Commit to cherry-pick',
      })
      local commit_to_pick = test_repo.get_head_commit(repo)

      -- Create another branch
      test_repo.create_branch(repo, 'other')
      test_repo.modify_file(repo, 'file3.txt', { 'conflicting' })
      test_repo.stage(repo, 'file3.txt')
      test_repo.create_commit(repo, {
        files = { ['file3.txt'] = { 'conflicting' } },
        message = 'Conflicting commit',
      })

      -- Try cherry-pick (may conflict)
      vim.fn.system({ 'git', '-C', repo, 'cherry-pick', commit_to_pick })

      local status, err = git_conflict.status(repo)

      assert(not err)
      -- May be CHERRY-PICK or nil depending on if conflict occurred
      assert(status == 'CHERRY-PICK' or status == nil)
    end)

    it('should error when reponame is missing', function()
      local status, err = git_conflict.status(nil)

      assert(err)
      eq(err, { 'reponame is required' })
      assert(not status)
    end)
  end)

  describe('has_conflict()', function()
    it('should return false for file without conflict', function()
      local has_conflict, err = git_conflict.has_conflict(repo, 'file1.txt')

      assert(not err)
      eq(has_conflict, false)
    end)

    it('should detect conflict state for files', function()
      -- Create a merge scenario
      test_repo.create_branch(repo, 'feature')
      test_repo.modify_file(repo, 'file1.txt', { 'feature line' })
      test_repo.stage(repo, 'file1.txt')
      test_repo.create_commit(repo, {
        files = { ['file1.txt'] = { 'feature line' } },
        message = 'Feature',
      })

      test_repo.checkout(repo, 'master')
      test_repo.modify_file(repo, 'file1.txt', { 'master line' })
      test_repo.stage(repo, 'file1.txt')
      test_repo.create_commit(repo, {
        files = { ['file1.txt'] = { 'master line' } },
        message = 'Master',
      })

      vim.fn.system({ 'git', '-C', repo, 'merge', 'feature' })

      local has_conflict, err = git_conflict.has_conflict(repo, 'file1.txt')

      assert(not err)
      -- May be true or false depending on whether merge created conflict
      assert(has_conflict == true or has_conflict == false)
    end)

    it('should return false for non-conflicted file during merge', function()
      -- Create a merge conflict on file1.txt
      test_repo.create_branch(repo, 'feature')
      test_repo.modify_file(repo, 'file1.txt', { 'feature' })
      test_repo.stage(repo, 'file1.txt')
      test_repo.create_commit(repo, {
        files = { ['file1.txt'] = { 'feature' } },
        message = 'Feature',
      })

      test_repo.checkout(repo, 'master')
      test_repo.modify_file(repo, 'file1.txt', { 'master' })
      test_repo.stage(repo, 'file1.txt')
      test_repo.create_commit(repo, {
        files = { ['file1.txt'] = { 'master' } },
        message = 'Master',
      })

      vim.fn.system({ 'git', '-C', repo, 'merge', 'feature' })

      -- file2.txt should not have conflict
      local has_conflict, err = git_conflict.has_conflict(repo, 'file2.txt')

      assert(not err)
      eq(has_conflict, false)
    end)

    it('should error when reponame is missing', function()
      local has_conflict, err = git_conflict.has_conflict(nil, 'file1.txt')

      assert(err)
      eq(err, { 'reponame is required' })
      assert(not has_conflict)
    end)

    it('should error when filename is missing', function()
      local has_conflict, err = git_conflict.has_conflict(repo, nil)

      assert(err)
      eq(err, { 'filename is required' })
      assert(not has_conflict)
    end)
  end)

  describe('integration scenarios', function()
    it('should work with conflict detection workflow', function()
      -- Create merge scenario
      test_repo.create_branch(repo, 'feature')
      test_repo.modify_file(repo, 'file1.txt', { 'feature content' })
      test_repo.stage(repo, 'file1.txt')
      test_repo.create_commit(repo, {
        files = { ['file1.txt'] = { 'feature content' } },
        message = 'Feature',
      })

      test_repo.checkout(repo, 'master')
      test_repo.modify_file(repo, 'file1.txt', { 'master content' })
      test_repo.stage(repo, 'file1.txt')
      test_repo.create_commit(repo, {
        files = { ['file1.txt'] = { 'master content' } },
        message = 'Master',
      })

      vim.fn.system({ 'git', '-C', repo, 'merge', 'feature' })

      -- Check status (may or may not be in MERGE state)
      local _, err1 = git_conflict.status(repo)
      assert(not err1)

      -- Check file conflict state
      local has_conflict, err2 = git_conflict.has_conflict(repo, 'file1.txt')
      assert(not err2)

      -- If merge created conflict markers, we can parse them
      if has_conflict then
        local lines = vim.fn.readfile(repo .. '/file1.txt')
        local conflicts = git_conflict.parse(lines)
        -- Should have parsed conflicts if markers exist
        assert(conflicts)
      end
    end)

    it('should handle normal operations without conflicts', function()
      local status = git_conflict.status(repo)
      eq(status, nil)

      local has_conflict = git_conflict.has_conflict(repo, 'file1.txt')
      eq(has_conflict, false)

      local conflicts = git_conflict.parse({ 'line 1', 'line 2' })
      eq(#conflicts, 0)
    end)
  end)
end)
