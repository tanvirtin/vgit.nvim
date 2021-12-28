local hls_setting = require('vgit.settings.hls')
local highlight = require('vgit.core.highlight')
local mock = require('luassert.mock')
local spy = require('luassert.spy')

local it = it
local describe = describe
local before_each = before_each
local after_each = after_each
local eq = assert.are.same

describe('highlight:', function()
  before_each(function()
    vim.api = mock(vim.api, true)
    hls_setting.for_each = mock(hls_setting.for_each, true)
  end)

  after_each(function()
    mock.revert(vim.api)
    mock.revert(hls_setting.for_each)
  end)

  describe('define', function()
    it('should successfully define a highlight', function()
      highlight.define('VGitTestDefine', {
        fg = '#bb9af7',
        bg = '#3b4261',
      })
      assert.stub(vim.api.nvim_exec).was.called_with(
        'highlight VGitTestDefine gui = NONE guifg = #bb9af7 guibg = #3b4261 ',
        false
      )
    end)
  end)

  describe('register_module', function()
    it('should define highlights accordingly', function()
      highlight.register_module()
      assert.stub(hls_setting.for_each).was.called()
    end)
    it('should invoke dependencies if passed in', function()
      local s = spy.new(function() end)
      highlight.register_module(s)
      assert.spy(s).was.called(1)
    end)
  end)
end)
