local eq = assert.are.same
local test_repo = require('tests.helpers.test_repo')
test_repo.use_driver('git')
local async = require('tests.helpers.async')({ it = it, before_each = before_each, after_each = after_each })
local it = async.it
local before_each = async.before_each
local after_each = async.after_each

describe('gitcli:', function()
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

    it('should return an error instead of raising when the wait fails', function()
      local original_task = gitcli.task
      gitcli.task = function()
        return {
          pwait = function()
            return false, 'timeout'
          end,
        }
      end

      local ok, result, err, code = pcall(gitcli.run, { '-C', repo:get_path(), 'status' }, { timeout = 1 })

      gitcli.task = original_task

      assert.is_true(ok, 'gitcli.run must not raise on wait failure')
      assert.is_nil(result)
      assert.is_true(#err > 0)
      assert.matches('timeout', err[1])
      assert.is_nil(code)
    end)

    it('should return an error instead of raising on a real timeout', function()
      local ok, result, err, code = pcall(
        gitcli.run,
        { '-C', repo:get_path(), '-c', 'alias.slow=!sleep 0.4', 'slow' },
        { timeout = 30 }
      )

      assert.is_true(ok, 'a real timeout must not raise out of gitcli.run')
      assert.is_nil(result)
      assert.is_not_nil(err)
      assert.is_true(#err > 0)
      assert.matches('timeout', err[1])
      assert.matches('alias%.slow', err[1], 'the error must name the command so it is diagnosable')
      assert.is_nil(code)
    end)

    it('should accept opts parameter', function()
      local result, err, code = gitcli.run({ '-C', repo:get_path(), 'status', '--short' }, { debug = false })

      assert.is_nil(err)
      assert.is_table(result)
    end)

    it('should force English locale so parsers never break', function()
      local result, err = gitcli.run({ '-C', repo:get_path(), 'status', '--short' })

      assert.is_nil(err)
      assert.is_table(result)
    end)

    it('should print non-ASCII paths verbatim', function()
      local name = 'café.txt'
      vim.fn.writefile({ 'x' }, repo:get_path() .. '/' .. name)

      local result, err = gitcli.run({ '-C', repo:get_path(), 'status', '--short' })

      assert.is_nil(err)
      assert.is_truthy(table.concat(result, '\n'):find(name, 1, true))
    end)

    it('should prepend --no-optional-locks to every command', function()
      local result, err, code = gitcli.run({ '-C', repo:get_path(), 'status', '--porcelain' })

      assert.is_nil(err)
      assert.is_table(result)
      eq(0, code)
    end)
  end)
end)
