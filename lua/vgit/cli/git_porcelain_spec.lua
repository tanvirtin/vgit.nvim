local GitPorcelain = require('vgit.cli.git_porcelain')

describe('GitPorcelain', function()
  local porcelain

  before_each(function()
    porcelain = GitPorcelain()
  end)

  describe('parse_args', function()
    it('should return defaults for empty args', function()
      local result = porcelain:parse_args({})
      assert.is_nil(result.command)
      assert.are.same({}, result.arguments)
      assert.are.same({}, result.options)
      assert.are.same({}, result.files)
      assert.are.same({}, result.commits)
    end)

    it('should return defaults for nil args', function()
      local result = porcelain:parse_args(nil)
      assert.is_nil(result.command)
    end)

    it('should extract command from first arg', function()
      local result = porcelain:parse_args({ 'diff' })
      assert.are.equal('diff', result.command)
    end)

    it('should parse boolean long option', function()
      local result = porcelain:parse_args({ 'diff', '--cached' })
      assert.is_true(result.options.cached)
    end)

    it('should parse boolean long option --staged', function()
      local result = porcelain:parse_args({ 'diff', '--staged' })
      assert.is_true(result.options.staged)
    end)

    it('should parse number option with = syntax', function()
      local result = porcelain:parse_args({ 'diff', '--unified=5' })
      assert.are.equal(5, result.options.unified)
    end)

    it('should parse number option with separate value', function()
      local result = porcelain:parse_args({ 'diff', '--unified', '10' })
      assert.are.equal(10, result.options.unified)
    end)

    it('should parse string option with = syntax', function()
      local result = porcelain:parse_args({ 'blame', '--date=relative' })
      assert.are.equal('relative', result.options.date)
    end)

    it('should parse string option with separate value', function()
      local result = porcelain:parse_args({ 'blame', '--date', 'short' })
      assert.are.equal('short', result.options.date)
    end)

    it('should parse optional-value option without value using default', function()
      local result = porcelain:parse_args({ 'diff', '--buffer' })
      assert.are.equal(0, result.options.buffer)
    end)

    it('should parse optional-value option with explicit value', function()
      local result = porcelain:parse_args({ 'diff', '--buffer=5' })
      assert.are.equal(5, result.options.buffer)
    end)

    it('should parse short flags as individual options', function()
      local result = porcelain:parse_args({ 'blame', '-CM' })
      assert.is_true(result.options.C)
      assert.is_true(result.options.M)
    end)

    it('should parse single short flag', function()
      local result = porcelain:parse_args({ 'blame', '-w' })
      assert.is_true(result.options.w)
    end)

    it('should handle multiple boolean options', function()
      local result = porcelain:parse_args({ 'diff', '--cached', '--stat', '--name_only' })
      assert.is_true(result.options.cached)
      assert.is_true(result.options.stat)
      assert.is_true(result.options.name_only)
    end)
  end)

  describe('validate', function()
    it('should pass with nil command', function()
      local ok, err = porcelain:validate({ command = nil, options = {} })
      assert.is_true(ok)
      assert.is_nil(err)
    end)

    it('should fail for unknown command', function()
      local ok, err = porcelain:validate({ command = 'foobar', options = {} })
      assert.is_false(ok)
      assert.is_not_nil(err)
      assert.truthy(err:match('Unknown command'))
    end)

    it('should fail for unknown option', function()
      local ok, err = porcelain:validate({
        command = 'diff',
        options = { nonexistent = true },
      })
      assert.is_false(ok)
      assert.truthy(err:match('Unknown option'))
    end)

    it('should fail when number option has non-number value', function()
      local ok, err = porcelain:validate({
        command = 'diff',
        options = { unified = 'abc' },
      })
      assert.is_false(ok)
      assert.truthy(err:match('requires a number'))
    end)

    it('should pass for valid diff options', function()
      local ok, err = porcelain:validate({
        command = 'diff',
        options = { cached = true },
      })
      assert.is_true(ok)
      assert.is_nil(err)
    end)

    it('should pass for valid blame options', function()
      local ok, err = porcelain:validate({
        command = 'blame',
        options = { w = true },
      })
      assert.is_true(ok)
      assert.is_nil(err)
    end)
  end)

  describe('_validate_diff_options', function()
    it('should fail when --split and --unified_view are both set', function()
      local ok, err = porcelain:validate({
        command = 'diff',
        options = { split = true, unified_view = true },
      })
      assert.is_false(ok)
      assert.truthy(err:match('Cannot use both'))
    end)

    it('should fail when --lens and --screen are both set', function()
      local ok, err = porcelain:validate({
        command = 'diff',
        options = { lens = true, screen = true },
      })
      assert.is_false(ok)
      assert.truthy(err:match('Cannot use both'))
    end)

    it('should pass with only --split', function()
      local ok, err = porcelain:validate({
        command = 'diff',
        options = { split = true },
      })
      assert.is_true(ok)
    end)

    it('should pass with only --lens', function()
      local ok, err = porcelain:validate({
        command = 'diff',
        options = { lens = true },
      })
      assert.is_true(ok)
    end)
  end)

  describe('_validate_blame_options', function()
    it('should fail when --lens and --screen are both set', function()
      local ok, err = porcelain:validate({
        command = 'blame',
        options = { lens = true, screen = true },
      })
      assert.is_false(ok)
      assert.truthy(err:match('Cannot use both'))
    end)

    it('should fail when line is not a positive integer', function()
      local ok, err = porcelain:validate({
        command = 'blame',
        options = { line = 0 },
      })
      assert.is_false(ok)
      assert.truthy(err:match('positive integer'))
    end)

    it('should fail when line is negative', function()
      local ok, err = porcelain:validate({
        command = 'blame',
        options = { line = -5 },
      })
      assert.is_false(ok)
    end)

    it('should pass when line is a valid positive number', function()
      local ok, err = porcelain:validate({
        command = 'blame',
        options = { line = 42 },
      })
      assert.is_true(ok)
    end)
  end)

  describe('get_display_mode', function()
    it('should return lens when lens option is set', function()
      assert.are.equal('lens', porcelain:get_display_mode({ options = { lens = true } }))
    end)

    it('should return screen when screen option is set', function()
      assert.are.equal('screen', porcelain:get_display_mode({ options = { screen = true } }))
    end)

    it('should default to screen', function()
      assert.are.equal('screen', porcelain:get_display_mode({ options = {} }))
    end)
  end)

  describe('get_layout_type', function()
    it('should return split when split option is set', function()
      assert.are.equal('split', porcelain:get_layout_type({ options = { split = true } }))
    end)

    it('should return unified when unified_view option is set', function()
      assert.are.equal('unified', porcelain:get_layout_type({ options = { unified_view = true } }))
    end)

    it('should return nil when no layout option is set', function()
      assert.is_nil(porcelain:get_layout_type({ options = {} }))
    end)
  end)

  describe('get_git_diff_options', function()
    it('should return empty for no options', function()
      local result = porcelain:get_git_diff_options({ options = {} })
      assert.are.same({}, result)
    end)

    it('should add --cached for cached option', function()
      local result = porcelain:get_git_diff_options({ options = { cached = true } })
      assert.are.same({ '--cached' }, result)
    end)

    it('should add --cached for staged option', function()
      local result = porcelain:get_git_diff_options({ options = { staged = true } })
      assert.are.same({ '--cached' }, result)
    end)

    it('should add --unified=N for unified option', function()
      local result = porcelain:get_git_diff_options({ options = { unified = 5 } })
      assert.are.same({ '--unified=5' }, result)
    end)

    it('should add --unified=0 for no_unified option', function()
      local result = porcelain:get_git_diff_options({ options = { no_unified = true } })
      assert.are.same({ '--unified=0' }, result)
    end)

    it('should add --name-only for name_only option', function()
      local result = porcelain:get_git_diff_options({ options = { name_only = true } })
      assert.are.same({ '--name-only' }, result)
    end)

    it('should add --stat for stat option', function()
      local result = porcelain:get_git_diff_options({ options = { stat = true } })
      assert.are.same({ '--stat' }, result)
    end)

    it('should combine multiple options', function()
      local result = porcelain:get_git_diff_options({
        options = { cached = true, stat = true },
      })
      assert.are.equal(2, #result)
      -- Both should be present
      local has_cached = vim.tbl_contains(result, '--cached')
      local has_stat = vim.tbl_contains(result, '--stat')
      assert.is_true(has_cached)
      assert.is_true(has_stat)
    end)
  end)

  describe('get_git_blame_options', function()
    it('should return empty for no options', function()
      local result = porcelain:get_git_blame_options({ options = {} })
      assert.are.same({}, result)
    end)

    it('should add -L for line option', function()
      local result = porcelain:get_git_blame_options({ options = { line = 42 } })
      assert.are.same({ '-L', '42,+1' }, result)
    end)

    it('should add -C for C option', function()
      local result = porcelain:get_git_blame_options({ options = { C = true } })
      assert.are.same({ '-C' }, result)
    end)

    it('should add -M for M option', function()
      local result = porcelain:get_git_blame_options({ options = { M = true } })
      assert.are.same({ '-M' }, result)
    end)

    it('should add -w for w option', function()
      local result = porcelain:get_git_blame_options({ options = { w = true } })
      assert.are.same({ '-w' }, result)
    end)

    it('should add --show-email for show_email option', function()
      local result = porcelain:get_git_blame_options({ options = { show_email = true } })
      assert.are.same({ '--show-email' }, result)
    end)

    it('should add --date= for date option', function()
      local result = porcelain:get_git_blame_options({ options = { date = 'relative' } })
      assert.are.same({ '--date=relative' }, result)
    end)

    it('should add --pretty= for pretty option', function()
      local result = porcelain:get_git_blame_options({ options = { pretty = 'oneline' } })
      assert.are.same({ '--pretty=oneline' }, result)
    end)
  end)

  describe('get_help', function()
    it('should return nil for unknown command', function()
      assert.is_nil(porcelain:get_help('foobar'))
    end)

    it('should return help string for diff command', function()
      local help = porcelain:get_help('diff')
      assert.is_not_nil(help)
      assert.truthy(help:match('vgit diff'))
      assert.truthy(help:match('Options:'))
    end)

    it('should return help string for blame command', function()
      local help = porcelain:get_help('blame')
      assert.is_not_nil(help)
      assert.truthy(help:match('vgit blame'))
    end)
  end)

  describe('get_all_help', function()
    it('should include all commands', function()
      local help = porcelain:get_all_help()
      assert.truthy(help:match('diff'))
      assert.truthy(help:match('blame'))
    end)
  end)
end)
