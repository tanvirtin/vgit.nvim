local Command = require('vgit.Command')
local mock = require('luassert.mock')

local eq = assert.are.same

describe('Command:', function()
  describe('new', function()
    it('should create an instance of the command object', function()
      local command = Command()

      eq(command:is(Command), true)
    end)
  end)

  describe('execute', function()
    local command
    local vgit

    before_each(function()
      command = Command()
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
