local sign = require('vgit.core.sign')
local mock = require('luassert.mock')
local spy = require('luassert.spy')

local it = it
local describe = describe
local before_each = before_each
local after_each = after_each
local eq = assert.are.same

describe('sign:', function()
  before_each(function()
    vim.fn.sign_define = mock(vim.fn.sign_define, true)
  end)

  after_each(function()
    mock.revert(vim.fn.sign_define)
  end)

  describe('define', function()
    it('defines a sign by calling vim api', function()
      sign.define('GitChange', {
        texthl = 'GitChange',
        text = '┃',
      })
      assert.stub(vim.fn.sign_define).was_called_with('GitChange', {
        text = '┃',
        texthl = 'GitChange',
      })
    end)
  end)

  describe('register_module', function()
    it('should define the necessary autocmd group', function()
      sign.define = spy.new(function() end)
      sign.register_module()
      assert.spy(sign.define).was.called()
    end)

    it('should invoke dependencies if passed in', function()
      local s = spy.new(function() end)
      sign.register_module(s)
      assert.spy(s).was.called(1)
    end)
  end)
end)
