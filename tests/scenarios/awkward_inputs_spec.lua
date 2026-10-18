local scenario = require('tests.scenario')({ it = it })

describe('scenario: awkward file names and content', function()
  scenario.flow('a file name with spaces can be staged from status', {
    files = { ['my file.txt'] = { 'a' } },
    changes = { ['my file.txt'] = { 'b' } },
    steps = { { open = 'status' }, { keys = 's' } },
    expect = { screen_has = { 'my file.txt' }, git_status = 'M  "my file.txt"' },
  })

  scenario.test('a unicode file name is shown and staged from status', function(s)
    local repo = s.world:repo('main', { ['café.txt'] = { 'a' } })
    s.world:write(repo .. '/café.txt', { 'b' })

    s.editor:cmd('cd ' .. repo)
    s.editor:cmd('VGit status')
    s.editor:await_text('Changes')
    s.editor:await_text('café.txt', 1500)
    s.editor:keys('s')
    s.editor:settle()
    assert.are.same('M  café.txt', s.world:git(repo, '-c', 'core.quotepath=false', 'status', '--porcelain'))
  end)

  scenario.test('project diff shows a unicode file name', function(s)
    local repo = s.world:repo('main', { ['café.txt'] = { 'a' } })
    s.world:write(repo .. '/café.txt', { 'b' })

    s.editor:cmd('cd ' .. repo)
    s.editor:cmd('VGit diff')
    s.editor:await_text('café.txt', 3000)
  end)

  scenario.test('show lists a unicode file name from a commit', function(s)
    local repo = s.world:repo('main', { ['a.txt'] = { 'a' } })
    s.world:history(repo, { { message = 'add unicode', files = { ['café.txt'] = { 'hello' } } } })

    s.editor:cmd('cd ' .. repo)
    s.editor:cmd('VGit show')
    s.editor:await_text('café.txt', 3000)
  end)

  scenario.test('a file name containing a double quote can be staged from status', function(s)
    local repo = s.world:repo('main', { ['say "hi".txt'] = { 'a' } })
    s.world:write(repo .. '/say "hi".txt', { 'b' })

    s.editor:cmd('cd ' .. repo)
    s.editor:cmd('VGit status')
    s.editor:await_text('Changes')
    s.editor:keys('s')
    s.editor:settle()
    assert.are.same('M  "say \\"hi\\".txt"', s.world:git(repo, 'status', '--porcelain'))
  end)

  scenario.flow('a file in a nested directory can be staged from status', {
    files = { ['dir/sub/deep.txt'] = { 'a' } },
    changes = { ['dir/sub/deep.txt'] = { 'b' } },
    steps = { { open = 'status' }, { keys = 's' } },
    expect = { screen_has = { 'deep.txt' }, git_status = 'M  dir/sub/deep.txt' },
  })

  scenario.flow('files with the same name in different directories are distinct', {
    files = { ['a/same.txt'] = { '1' }, ['b/same.txt'] = { '2' } },
    changes = { ['a/same.txt'] = { '1x' }, ['b/same.txt'] = { '2x' } },
    steps = { { open = 'status' }, { keys = 's' } },
    assert = function(ctx)
      local status = ctx.world:git(ctx.repo, 'status', '--porcelain')
      local staged = 0
      for _ in status:gmatch('\nM  ') do
        staged = staged + 1
      end
      if status:sub(1, 3) == 'M  ' then staged = staged + 1 end
      assert.are.same(1, staged, status)
    end,
  })

  scenario.flow('a file with CRLF line endings shows a diff without errors', {
    files = { ['crlf.txt'] = { 'one', 'two' } },
    arrange = function(ctx)
      local f = io.open(ctx.repo .. '/crlf.txt', 'wb')
      f:write('one\r\nTWO\r\n')
      f:close()
    end,
    steps = { { open = 'status' } },
    expect = { screen_has = { 'crlf.txt' } },
  })

  scenario.flow('a file with a very long line renders without errors', {
    files = { ['long.txt'] = { 'short' } },
    changes = { ['long.txt'] = { string.rep('x', 5000) } },
    steps = { { open = 'status' } },
    expect = { screen_has = { 'long.txt' } },
  })

  scenario.flow('an empty file added to the repo shows in status', {
    files = { ['a.txt'] = { 'a' } },
    arrange = function(ctx)
      vim.fn.writefile({}, ctx.repo .. '/empty.txt')
    end,
    steps = { { open = 'status' } },
    expect = { screen_has = { 'empty.txt' } },
  })

  scenario.flow('a file with no trailing newline diffs without errors', {
    files = { ['a.txt'] = { 'a' } },
    arrange = function(ctx)
      local f = io.open(ctx.repo .. '/a.txt', 'wb')
      f:write('changed without newline')
      f:close()
    end,
    steps = { { open = 'status' } },
    expect = { screen_has = { 'a.txt' } },
  })

  scenario.flow('a large file with many changes opens status quickly', {
    files = {
      ['big.txt'] = (function()
        local t = {}
        for i = 1, 5000 do
          t[i] = 'line ' .. i
        end
        return t
      end)(),
    },
    changes = {
      ['big.txt'] = (function()
        local t = {}
        for i = 1, 5000 do
          t[i] = i % 10 == 0 and ('changed ' .. i) or ('line ' .. i)
        end
        return t
      end)(),
    },
    timeout = 20000,
    steps = { { open = 'status' } },
    expect = { screen_has = { 'big.txt' } },
  })
end)

describe('scenario: layout preferences', function()
  scenario.flow('the split layout renders both sides in project diff', {
    files = { ['a.txt'] = { 'old line' } },
    changes = { ['a.txt'] = { 'new line' } },
    config = { settings = { scene = { diff_preference = 'split' } } },
    steps = {
      { cd = '$repo' },
      { cmd = 'VGit diff' },
      {
        await_text = 'new line',
      },
    },
    expect = { screen_has = { 'old line', 'new line' } },
  })

  scenario.flow('the unified layout shows removed and added lines together', {
    files = { ['a.txt'] = { 'old line' } },
    changes = { ['a.txt'] = { 'new line' } },
    config = { settings = { scene = { diff_preference = 'unified' } } },
    steps = {
      { cd = '$repo' },
      { cmd = 'VGit diff' },
      {
        await_text = 'new line',
      },
    },
    expect = { screen_has = { 'old line', 'new line' } },
  })

  scenario.flow('toggling the layout with x keeps both lines visible', {
    files = { ['a.txt'] = { 'old line' } },
    changes = { ['a.txt'] = { 'new line' } },
    steps = {
      { cd = '$repo' },
      { cmd = 'VGit diff' },
      { await_text = 'new line' },
      { keys = 'x' },
      { settle = 600 },
    },
    expect = { screen_has = { 'old line', 'new line' } },
  })
end)
