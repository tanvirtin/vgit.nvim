local parser = require('vgit.cli.parser')
local router = require('vgit.cli.router')

describe('CLI Router', function()
  describe('route_diff', function()
    it('should route to hunk_lens with --lens flag', function()
      local parsed = parser.parse({ 'diff', '--lens' })
      local view_name, opts = router.route(parsed)

      assert.are.same('hunk_lens', view_name)
      assert.is_not_nil(opts)
    end)

    it('should route to diff_view for project mode (no args)', function()
      local parsed = parser.parse({ 'diff' })
      local view_name, opts = router.route(parsed)

      assert.are.same('diff_view', view_name)
      assert.is_nil(opts.file_path) -- No file_path = project mode
    end)

    it('should route to diff_view with file path when file provided', function()
      local parsed = parser.parse({ 'diff', 'file.lua' })
      local view_name, opts = router.route(parsed)

      assert.are.same('diff_view', view_name)
      assert.are.same('file.lua', opts.file_path)
    end)

    it('should include layout_type in options when --split', function()
      local parsed = parser.parse({ 'diff', '--split', 'file.lua' })
      local view_name, opts = router.route(parsed)

      assert.are.same('diff_view', view_name)
      assert.are.same('split', opts.layout_type)
    end)

    it('should include layout_type in options when --unified_view', function()
      local parsed = parser.parse({ 'diff', '--unified_view', 'file.lua' })
      local view_name, opts = router.route(parsed)

      assert.are.same('diff_view', view_name)
      assert.are.same('unified', opts.layout_type)
    end)

    it('should include git_diff_options for --cached', function()
      local parsed = parser.parse({ 'diff', '--cached', 'file.lua' })
      local view_name, opts = router.route(parsed)

      assert.are.same('diff_view', view_name)
      assert.is_not_nil(opts.git_diff_options)
      assert.is_true(vim.tbl_contains(opts.git_diff_options, '--cached'))
    end)

    it('should include git_diff_options for --staged (alias)', function()
      local parsed = parser.parse({ 'diff', '--staged', 'file.lua' })
      local view_name, opts = router.route(parsed)

      assert.are.same('diff_view', view_name)
      assert.is_not_nil(opts.git_diff_options)
      assert.is_true(vim.tbl_contains(opts.git_diff_options, '--cached'))
    end)

    it('should handle multiple git options', function()
      local parsed = parser.parse({ 'diff', '--cached', '--stat', 'file.lua' })
      local view_name, opts = router.route(parsed)

      assert.are.same('diff_view', view_name)
      assert.is_true(vim.tbl_contains(opts.git_diff_options, '--cached'))
      assert.is_true(vim.tbl_contains(opts.git_diff_options, '--stat'))
    end)
  end)

  describe('route_blame', function()
    it('should return error when no file context', function()
      local parsed = parser.parse({ 'blame' })
      local view_name, opts = router.route(parsed)

      -- Blame requires file context, so should return nil with error
      assert.is_nil(view_name)
      assert.is_table(opts) -- Error message
    end)

    it('should return error for line number without file', function()
      local parsed = parser.parse({ 'blame', '--line=42' })
      local view_name, opts = router.route(parsed)

      -- Blame requires file context
      assert.is_nil(view_name)
      assert.is_table(opts) -- Error message
    end)
  end)

  describe('route_help', function()
    it('should route to help_screen', function()
      local parsed = parser.parse({ 'help' })
      local view_name, opts = router.route(parsed)

      assert.are.same('help_screen', view_name)
      assert.is_not_nil(opts)
      assert.is_not_nil(opts.help_text)
    end)

    it('should provide help for specific command', function()
      local parsed = parser.parse({ 'help', 'diff' })
      local view_name, opts = router.route(parsed)

      assert.are.same('help_screen', view_name)
      assert.is_not_nil(opts.help_text)
      assert.is_true(opts.help_text:match('diff') ~= nil)
    end)
  end)

  describe('unknown commands', function()
    it('should return nil for unknown command', function()
      local parsed = parser.parse({ 'unknown_command' })
      local view_name, opts = router.route(parsed)

      assert.is_nil(view_name)
    end)

    it('should return nil for empty command', function()
      local parsed = parser.parse({})
      local view_name, opts = router.route(parsed)

      assert.is_nil(view_name)
    end)
  end)
end)
