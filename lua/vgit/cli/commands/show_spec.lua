local show_command = require('vgit.cli.commands.show')

local eq = assert.are.same

describe('show_command:', function()
  it('should default commit to HEAD when no args', function()
    local opts = show_command.parse_args({})
    assert.are.equal('HEAD', opts.commit)
    eq({}, opts.flags)
  end)

  it('should parse commit hash', function()
    local opts = show_command.parse_args({ 'abc1234' })
    assert.are.equal('abc1234', opts.commit)
  end)

  it('should parse HEAD variant', function()
    local opts = show_command.parse_args({ 'HEAD~3' })
    assert.are.equal('HEAD~3', opts.commit)
  end)

  it('should parse flags', function()
    local opts = show_command.parse_args({ '--stat', '--name-only' })
    eq({ '--stat', '--name-only' }, opts.flags)
    assert.are.equal('HEAD', opts.commit)
  end)

  it('should parse commit with flags', function()
    local opts = show_command.parse_args({ '--stat', 'abc1234' })
    assert.are.equal('abc1234', opts.commit)
    eq({ '--stat' }, opts.flags)
  end)

  it('should only use first non-flag arg as commit', function()
    local opts = show_command.parse_args({ 'first', 'second' })
    assert.are.equal('first', opts.commit)
  end)
end)
