local scenario = require('tests.scenario')({ it = it })

local function open_status(s, repo)
  s.editor:cmd('cd ' .. repo)
  s.editor:cmd('VGit status')
  s.editor:await_text('Changes')
  s.editor:settle()
end

describe('scenario: status flows', function()
  scenario.test('stage a file from the status view with s', function(s)
    local main = s.world:repo('main', { ['file.txt'] = { 'base' } })
    s.world:write(main .. '/file.txt', { 'changed' })

    open_status(s, main)
    s.editor:keys('s')
    s.editor:settle()

    assert.are.same('M  file.txt', s.world:git(main, 'status', '--porcelain'))
  end)

  scenario.test('unstage a staged file with u', function(s)
    local main = s.world:repo('main', { ['file.txt'] = { 'base' } })
    s.world:write(main .. '/file.txt', { 'changed' })
    s.world:git(main, 'add', 'file.txt')

    open_status(s, main)
    s.editor:keys('u')
    s.editor:settle()

    assert.are.same(' M file.txt', s.world:git(main, 'status', '--porcelain'))
  end)

  scenario.test('stage everything with S', function(s)
    local main = s.world:repo('main', { ['a.txt'] = { 'a' }, ['b.txt'] = { 'b' } })
    s.world:write(main .. '/a.txt', { 'a changed' })
    s.world:write(main .. '/b.txt', { 'b changed' })

    open_status(s, main)
    s.editor:keys('S')
    s.editor:settle()

    assert.are.same('M  a.txt\nM  b.txt', s.world:git(main, 'status', '--porcelain'))
  end)

  scenario.test('commit through the commit buffer with C then <C-s>', function(s)
    local main = s.world:repo('main', { ['file.txt'] = { 'base' } })
    s.world:write(main .. '/file.txt', { 'changed' })
    s.world:git(main, 'add', 'file.txt')

    open_status(s, main)
    s.editor:keys('C')
    s.editor:await_filetype('gitcommit')
    s.editor:keys('scenario commit<C-s>')
    s.editor:settle()

    assert.are.same('scenario commit', s.world:git(main, 'log', '-1', '--format=%s'))
    assert.are.same('', s.world:git(main, 'status', '--porcelain'))
  end)

  scenario.test('stash everything with n', function(s)
    local main = s.world:repo('main', { ['file.txt'] = { 'base' } })
    s.world:write(main .. '/file.txt', { 'changed' })

    open_status(s, main)
    s.editor:keys('n')
    s.editor:settle(3000)

    assert.is_truthy(s.world:git(main, 'stash', 'list'):find('WIP', 1, true))
    assert.are.same('', s.world:git(main, 'status', '--porcelain'))
  end)

  scenario.test('stashing from the status view does not spam an autocmd error', function(s)
    local main = s.world:repo('main', { ['file.txt'] = { 'base' } })
    s.world:write(main .. '/file.txt', { 'changed' })

    open_status(s, main)
    s.editor:keys('n')
    s.editor:settle(3000)

    assert.is_falsy(s.observe.contains(s, 'E218: Autocommand nesting too deep'))
  end)

  scenario.test('reset a file with r after confirming', function(s)
    local main = s.world:repo('main', { ['file.txt'] = { 'base' } })
    s.world:write(main .. '/file.txt', { 'changed' })

    open_status(s, main)
    s.editor:keys('r')
    s.editor:await_text('(y/N)')
    s.editor:keys('y<CR>')
    s.editor:settle()

    assert.are.same('', s.world:git(main, 'status', '--porcelain'))
    assert.are.same({ 'base' }, vim.fn.readfile(main .. '/file.txt'))
  end)

  scenario.test('the diff pane toggles between staged and working content with t', function(s)
    local main = s.world:repo('main', { ['file.txt'] = { 'base' } })
    s.world:write(main .. '/file.txt', { 'staged version' })
    s.world:git(main, 'add', 'file.txt')
    s.world:write(main .. '/file.txt', { 'working version' })

    open_status(s, main)
    local before = s.observe.screen(s)

    s.editor:keys('t')
    s.editor:settle()
    local after = s.observe.screen(s)

    local flipped = (before:find('staged version', 1, true) and after:find('working version', 1, true))
      or (before:find('working version', 1, true) and after:find('staged version', 1, true))
    assert.is_truthy(flipped, 't should flip the diff between staged and working content')
  end)
end)
