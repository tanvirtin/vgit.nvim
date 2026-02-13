local blame_command = require('vgit.cli.commands.blame')

local eq = assert.are.same

describe('blame_command:', function()
  it('should return defaults for empty args', function()
    local opts = blame_command.parse_args({})
    assert.is_nil(opts.file)
    assert.is_nil(opts.line_number)
    eq({}, opts.flags)
  end)

  it('should detect file path', function()
    local opts = blame_command.parse_args({ 'src/file.lua' })
    assert.are.equal('src/file.lua', opts.file)
  end)

  it('should detect line number', function()
    local opts = blame_command.parse_args({ '42' })
    assert.are.equal(42, opts.line_number)
  end)

  it('should detect flags', function()
    local opts = blame_command.parse_args({ '-w', '-C' })
    eq({ '-w', '-C' }, opts.flags)
  end)

  it('should parse file and line number together', function()
    local opts = blame_command.parse_args({ 'file.lua', '10' })
    assert.are.equal('file.lua', opts.file)
    assert.are.equal(10, opts.line_number)
  end)

  it('should parse file, line number, and flags together', function()
    local opts = blame_command.parse_args({ '-w', 'file.lua', '25' })
    assert.are.equal('file.lua', opts.file)
    assert.are.equal(25, opts.line_number)
    eq({ '-w' }, opts.flags)
  end)

  it('should use last file if multiple non-numeric, non-flag args given', function()
    local opts = blame_command.parse_args({ 'first.lua', 'second.lua' })
    assert.are.equal('second.lua', opts.file)
  end)

  it('should handle long flags', function()
    local opts = blame_command.parse_args({ '--show-email' })
    eq({ '--show-email' }, opts.flags)
  end)
end)
