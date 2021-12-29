local Command = require('vgit.Command')
local mock = require('luassert.mock')

local describe = describe
local it = it
local before_each = before_each
local after_each = after_each
local eq = assert.are.same

describe('Command:', function()
  describe('new', function()
    it('should create an instance of the command object', function()
      local command = Command:new()
      eq(command:is(Command), true)
    end)
  end)

  describe('execute', function()
    local command
    local vgit
    before_each(function()
      command = Command:new()
      vgit = mock(require('vgit'), true)
    end)
    after_each(function()
      mock.revert(vgit)
    end)
    it('should execute a vgit command', function()
      command:execute('hunk_up')
      assert.stub(vgit.hunk_up).was_called_with()
    end)
  end)
end)
