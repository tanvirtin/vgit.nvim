local a = require('plenary.async.tests')
local GitFile = require('vgit.git.GitFile')
local git_toolkit = require('tests.lib.git_toolkit')

a.describe('GitFile:', function()
  local reponame = string.format('%s/tests/test_repo/', vim.loop.cwd())

  a.before_each(function()
    git_toolkit.setup_repo(reponame)
  end)

  a.after_each(function()
    git_toolkit.cleanup_repo(reponame)
  end)

  a.describe('is_tracked', function()
    a.it('should return true for a tracked file', function()
      local filename = 'tracked.txt'
      git_toolkit.create_file(reponame, filename, 'Content')
      git_toolkit.stage_file(reponame, filename)
      git_toolkit.commit_file(reponame, 'Add tracked file')

      local git_file = GitFile(reponame, filename, 'INDEX')
      local is_tracked, err = git_file:is_tracked()

      assert.is_nil(err)
      assert.is_true(is_tracked)
    end)

    a.it('should return false for an untracked file', function()
      local filename = 'untracked.txt'
      git_toolkit.create_file(reponame, filename, 'Content')

      local git_file = GitFile(reponame, filename, 'INDEX')
      local is_tracked, err = git_file:is_tracked()

      assert.is_nil(err)
      assert.is_false(is_tracked)
    end)

    a.it('should cache the result', function()
      local filename = 'cached.txt'
      git_toolkit.create_file(reponame, filename, 'Content')
      git_toolkit.stage_file(reponame, filename)
      git_toolkit.commit_file(reponame, 'Add cached file')

      local git_file = GitFile(reponame, filename, 'INDEX')
      local is_tracked1, err1 = git_file:is_tracked()
      local is_tracked2, err2 = git_file:is_tracked()

      assert.is_nil(err1)
      assert.is_nil(err2)
      assert.is_true(is_tracked1)
      assert.is_true(is_tracked2)
      assert.are.equal(is_tracked1, is_tracked2)
    end)
  end)

  a.describe('status', function()
    a.it('should detect untracked file', function()
      local filename = 'untracked.txt'
      git_toolkit.create_untracked_file(reponame, filename)
      local git_file = GitFile(reponame, filename, 'INDEX')
      local status = git_file:status()

      assert.are.same('??', status:__tostring())
    end)

    a.it('should detect modified file', function()
      local filename = 'modified.txt'
      git_toolkit.create_modified_file(reponame, filename)

      local git_file = GitFile(reponame, filename, 'INDEX')
      local status = git_file:status()

      assert.are.same(' M', status:__tostring())
    end)

    a.it('should detect staged modified file', function()
      local filename = 'staged_modified.txt'
      git_toolkit.create_staged_modified_file(reponame, filename)

      local git_file = GitFile(reponame, filename, 'INDEX')
      local status = git_file:status()

      assert.are.same('M ', status:__tostring())
    end)

    a.it('should detect modified staged modified file', function()
      local filename = 'modified_staged_modified.txt'
      git_toolkit.create_modified_staged_modified_file(reponame, filename)
      local git_file = GitFile(reponame, filename, 'INDEX')
      local status = git_file:status()

      assert.are.same('MM', status:__tostring())
    end)

    a.it('should detect unmerged file', function()
      local filename = 'unmerged.txt'
      git_toolkit.create_unmerged_file(reponame, filename)

      local git_file = GitFile(reponame, filename, 'INDEX')
      local status = git_file:status()

      assert.are.same('UU', status:__tostring())
    end)

    a.it('should detect new staged file', function()
      local filename = 'new_staged.txt'
      git_toolkit.create_new_staged_file(reponame, filename)

      local git_file = GitFile(reponame, filename, 'INDEX')
      local status = git_file:status()

      assert.are.same('A ', status:__tostring())
    end)

    a.it('should detect deleted file', function()
      local filename = 'deleted.txt'
      git_toolkit.create_deleted_file(reponame, filename)

      local git_file = GitFile(reponame, filename, 'INDEX')
      local status = git_file:status()

      assert.are.same(' D', status:__tostring())
    end)

    a.it('should detect staged deleted file', function()
      local filename = 'staged_deleted.txt'
      git_toolkit.create_staged_deleted_file(reponame, filename)

      local git_file = GitFile(reponame, filename, 'INDEX')
      local status = git_file:status()

      assert.are.same('D ', status:__tostring())
    end)

    a.it('should detect added then deleted file', function()
      local filename = 'added_then_deleted.txt'
      git_toolkit.create_new_staged_file(reponame, filename)
      git_toolkit.delete_file(reponame, filename)

      local git_file = GitFile(reponame, filename, 'INDEX')
      local status = git_file:status()

      assert.are.same('AD', status:__tostring())
    end)

    a.it('should detect added then modified file', function()
      local filename = 'added_then_modified.txt'
      git_toolkit.create_new_staged_file(reponame, filename)
      git_toolkit.modify_file(reponame, filename, 'Modified content')

      local git_file = GitFile(reponame, filename, 'INDEX')
      local status = git_file:status()

      assert.are.same('AM', status:__tostring())
    end)

    a.it('should detect renamed file', function()
      local old_filename = 'old_name.txt'
      local new_filename = 'new_name.txt'
      git_toolkit.create_renamed_file(reponame, old_filename, new_filename)

      local git_file = GitFile(reponame, new_filename, 'INDEX')
      local status = git_file:status()

      assert.are.same(status:__tostring(), 'A ')
    end)

    a.it('should detect renamed then modified file', function()
      local old_filename = 'old_name.txt'
      local new_filename = 'renamed_then_modified.txt'
      git_toolkit.create_renamed_file(reponame, old_filename, new_filename)
      git_toolkit.modify_file(reponame, new_filename, 'Modified content')

      local git_file = GitFile(reponame, new_filename, 'INDEX')
      local status = git_file:status()

      assert.are.same('AM', status:__tostring())
    end)

    a.it('should detect unmerged, deleted by them (UD)', function()
      local filename = 'unmerged_ud.txt'
      git_toolkit.create_unmerged_file_ud(reponame, filename)

      local git_file = GitFile(reponame, filename, 'INDEX')
      local status = git_file:status()

      assert.are.same('UD', status:__tostring())
    end)

    a.it('should detect unmerged, deleted by us (DU)', function()
      local filename = 'unmerged_du.txt'
      git_toolkit.create_unmerged_file_du(reponame, filename)

      local git_file = GitFile(reponame, filename, 'INDEX')
      local status = git_file:status()

      assert.are.same('DU', status:__tostring())
    end)
  end)
end)
