local eq = assert.are.same
local test_repo = require('tests.helpers.test_repo')
test_repo.use_driver('git')
local async = require('tests.helpers.async')({ it = it, before_each = before_each, after_each = after_each })
local it = async.it
local before_each = async.before_each
local after_each = async.after_each

describe('gitcli', function()
  local gitcli = require('vgit.git.gitcli')
  local repo

  before_each(function()
    local err
    repo, err = test_repo.create_repo({
      files = { ['test.txt'] = 'hello' },
      initial_commit = true,
    })
    assert.is_nil(err)
    assert.is_not_nil(repo)
  end)

  after_each(function()
    if repo then test_repo.cleanup(repo) end
  end)

  describe('run', function()
    it('should return stdout lines for successful git command', function()
      local result, err, code = gitcli.run({ '-C', repo:get_path(), 'rev-parse', '--git-dir' })

      assert.is_nil(err)
      assert.is_table(result)
      assert.is_true(#result > 0)
      eq('.git', result[1])
    end)

    it('should return error for invalid git command', function()
      local result, err, code = gitcli.run({ '-C', repo:get_path(), 'invalid-cmd-xyz' })

      assert.is_not_nil(err)
    end)

    it('should return exit code as number', function()
      local result, err, code = gitcli.run({ '-C', repo:get_path(), 'rev-parse', '--git-dir' })

      assert.is_number(code)
      eq(0, code)
    end)

    it('should accept opts parameter', function()
      local result, err, code = gitcli.run({ '-C', repo:get_path(), 'status', '--short' }, { debug = false })

      assert.is_nil(err)
      assert.is_table(result)
    end)
  end)
end)
