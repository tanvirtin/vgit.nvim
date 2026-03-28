local GitPorcelain = require('vgit.cli.GitPorcelain')

describe('GitPorcelain:', function()
  local porcelain

  before_each(function()
    porcelain = GitPorcelain()
  end)

  describe('get_command', function()
    it('should return diff command definition', function()
      local cmd = porcelain:get_command('diff')
      assert.is_not_nil(cmd)
      assert.is_not_nil(cmd.options)
      assert.is_not_nil(cmd.options.cached)
      assert.is_not_nil(cmd.options.staged)
      assert.is_not_nil(cmd.options.split)
    end)

    it('should return blame command definition', function()
      local cmd = porcelain:get_command('blame')
      assert.is_not_nil(cmd)
      assert.is_not_nil(cmd.options)
      assert.is_not_nil(cmd.options.line)
      assert.is_not_nil(cmd.options.w)
    end)

    it('should return nil for unknown command', function()
      assert.is_nil(porcelain:get_command('foobar'))
    end)

    it('should return nil for nil command', function()
      assert.is_nil(porcelain:get_command(nil))
    end)
  end)
end)
