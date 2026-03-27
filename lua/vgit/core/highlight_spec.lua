local highlight = require('vgit.core.highlight')
local mock = require('luassert.mock')

local eq = assert.are.same

describe('highlight:', function()
  before_each(function()
    vim.api = mock(vim.api, true)
  end)

  after_each(function()
    mock.revert(vim.api)
  end)

  describe('define', function()
    it('should produce highlight link command for string color', function()
      highlight.define('VGitTest', 'Normal')

      assert.stub(vim.api.nvim_exec2).was.called_with('highlight default link VGitTest Normal', {})
    end)

    it('should produce RGB highlight for table color', function()
      highlight.define('VGitTest', {
        fg = '#bb9af7',
        bg = '#3b4261',
      })

      assert
        .stub(vim.api.nvim_exec2).was
        .called_with('highlight VGitTest gui = NONE guifg = #bb9af7 guibg = #3b4261 ', {})
    end)

    it('should use NONE for missing fg/bg/gui fields', function()
      highlight.define('VGitTest', {})

      assert.stub(vim.api.nvim_exec2).was.called_with('highlight VGitTest gui = NONE guifg = NONE guibg = NONE ', {})
    end)

    it('should include gui value when provided', function()
      highlight.define('VGitTest', {
        fg = '#ffffff',
        gui = 'bold',
      })

      assert.stub(vim.api.nvim_exec2).was.called_with('highlight VGitTest gui = bold guifg = #ffffff guibg = NONE ', {})
    end)

    it('should include guisp when sp is provided', function()
      highlight.define('VGitTest', {
        fg = '#ffffff',
        sp = '#ff0000',
      })

      assert
        .stub(vim.api.nvim_exec2).was
        .called_with('highlight VGitTest gui = NONE guifg = #ffffff guibg = NONE guisp = #ff0000', {})
    end)

    it('should use default keyword when override is false', function()
      highlight.define('VGitTest', {
        fg = '#ffffff',
        override = false,
      })

      assert
        .stub(vim.api.nvim_exec2).was
        .called_with('highlight default VGitTest gui = NONE guifg = #ffffff guibg = NONE ', {})
    end)

    it('should not use default keyword when override is not false', function()
      highlight.define('VGitTest', {
        fg = '#ffffff',
      })

      assert.stub(vim.api.nvim_exec2).was.called_with('highlight VGitTest gui = NONE guifg = #ffffff guibg = NONE ', {})
    end)

    it('should call function and use result as table', function()
      highlight.define('VGitTest', function()
        return { fg = '#aabbcc', bg = '#112233' }
      end)

      assert
        .stub(vim.api.nvim_exec2).was
        .called_with('highlight VGitTest gui = NONE guifg = #aabbcc guibg = #112233 ', {})
    end)

    it('should return highlight module for chaining', function()
      local result = highlight.define('VGitTest', 'Normal')
      eq(highlight, result)
    end)

    it('should return highlight module for table color chaining', function()
      local result = highlight.define('VGitTest', { fg = '#fff' })
      eq(highlight, result)
    end)
  end)

  describe('register_module', function()
    local save_package, restore_packages = require('tests.helpers.package_mock').create()
    local for_each_called

    before_each(function()
      for_each_called = false
      save_package('vgit.settings.hls')
      package.loaded['vgit.settings.hls'] = {
        for_each = function(_, callback)
          for_each_called = true
          callback('TestHl', { fg = '#fff' })
        end,
      }
    end)

    after_each(function()
      restore_packages()
    end)

    it('should call hls_setting:for_each', function()
      highlight.register_module()
      assert.is_true(for_each_called)
    end)

    it('should invoke dependency if provided', function()
      local called = false
      highlight.register_module(function()
        called = true
      end)

      assert.is_true(called)
    end)

    it('should return highlight module for chaining', function()
      local result = highlight.register_module()
      eq(highlight, result)
    end)
  end)
end)
