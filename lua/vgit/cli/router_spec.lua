local last_error = nil

-- Stub console before requiring router so it never touches the async runtime.
package.loaded['vgit.core.console'] = {
  error = function(msg)
    last_error = msg
  end,
}

local router = require('vgit.cli.router')

local eq = assert.are.same

describe('router:', function()
  before_each(function()
    last_error = nil
  end)

  describe('execute', function()
    it('should error when args is nil', function()
      router.execute(nil)
      assert.are.equal('No command provided', last_error)
    end)

    it('should error when args is empty', function()
      router.execute({})
      assert.are.equal('No command provided', last_error)
    end)

    it('should error for an unknown command', function()
      router.execute({ 'nonexistent' })
      assert.are.equal('Unknown command: nonexistent', last_error)
    end)

    it('should error for another unknown command', function()
      router.execute({ 'foobar' })
      assert.are.equal('Unknown command: foobar', last_error)
    end)

    for _, cmd in ipairs({ 'diff', 'blame', 'hunk', 'status', 'show' }) do
      describe('command: ' .. cmd, function()
        local captured_args

        before_each(function()
          captured_args = nil
          -- Inject a mock handler module into package.loaded so require() returns it.
          package.loaded['vgit.cli.commands.' .. cmd] = {
            execute = function(args)
              captured_args = args
            end,
          }
        end)

        after_each(function()
          -- Clean up mock so it does not leak between tests.
          package.loaded['vgit.cli.commands.' .. cmd] = nil
        end)

        it('should dispatch to the handler with no extra args', function()
          router.execute({ cmd })
          assert.is_nil(last_error)
          eq({}, captured_args)
        end)

        it('should forward extra args to the handler', function()
          router.execute({ cmd, '--cached', 'file.lua' })
          assert.is_nil(last_error)
          eq({ '--cached', 'file.lua' }, captured_args)
        end)

        it('should forward a single extra arg to the handler', function()
          router.execute({ cmd, '--staged' })
          assert.is_nil(last_error)
          eq({ '--staged' }, captured_args)
        end)
      end)
    end

    it('should error when the handler module fails to load', function()
      -- Temporarily replace package.loaded entry with a broken module (no execute).
      package.loaded['vgit.cli.commands.diff'] = { not_execute = true }

      router.execute({ 'diff' })
      assert.are.equal('Failed to load command: diff', last_error)

      package.loaded['vgit.cli.commands.diff'] = nil
    end)

    it('should error when the handler module has execute as a non-function', function()
      package.loaded['vgit.cli.commands.blame'] = { execute = 'not a function' }

      router.execute({ 'blame' })
      assert.are.equal('Failed to load command: blame', last_error)

      package.loaded['vgit.cli.commands.blame'] = nil
    end)
  end)
end)
