local Buffer = require('vgit.core.Buffer')
local autocmd = require('vgit.core.autocmd')
local spy = require('luassert.spy')
local mock = require('luassert.mock')

local describe = describe
local it = it
local before_each = before_each
local after_each = after_each

describe('autocmd:', function()
  before_each(function()
    vim.api = mock(vim.api, true)
  end)

  after_each(function()
    mock.revert(vim.api)
  end)

  describe('register_module', function()
    it('should define the necessary autocmd group', function()
      autocmd.register_module()
      assert.stub(vim.api.nvim_exec).was.called_with(
        'aug VGit | autocmd! | aug END',
        false
      )
    end)

    it('should invoke dependencies if passed in', function()
      local s = spy.new(function() end)
      autocmd.register_module(s)
      assert.spy(s).was.called(1)
    end)
  end)

  describe('off', function()
    it('should redefine the autocmd group', function()
      autocmd.off()
      assert.stub(vim.api.nvim_exec).was.called_with(
        'aug VGit | autocmd! | aug END',
        false
      )
    end)
  end)

  describe('on', function()
    it('should define an autocmd', function()
      autocmd.on('BufWinEnter', 'buf_win_enter()')
      assert.stub(vim.api.nvim_exec).was.called_with(
        'au! VGit BufWinEnter *   :lua _G.package.loaded.vgit.buf_win_enter()',
        false
      )
    end)

    it('should define an autocmd with custom options', function()
      autocmd.on('BufWinEnter', 'buf_win_enter()', {
        once = true,
        override = false,
        nested = true,
      })
      assert.stub(vim.api.nvim_exec).was.called_with(
        'au VGit BufWinEnter * ++nested ++once :lua _G.package.loaded.vgit.buf_win_enter()',
        false
      )
    end)
  end)
end)
