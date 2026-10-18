local scenario = require('tests.scenario')({ it = it })

describe('scenario: worktree flows', function()
  scenario.test('pick a worktree in the picker and the working directory follows', function(s)
    local main = s.world:repo('main', { ['file.txt'] = { 'base' } })
    local feature = s.world:worktree(main, 'feature')

    s.editor:cmd('cd ' .. main)
    s.editor:cmd('VGit worktree')
    s.editor:await_text('feature')

    s.editor:keys('feat')
    s.editor:settle()
    s.editor:keys('<CR>')
    s.editor:await_text('Switched to worktree:')
    s.editor:dismiss()

    assert.are.same(feature, s.observe.cwd(s))
  end)

  scenario.test('create a worktree from the picker by typing a new name and confirming', function(s)
    local main = s.world:repo('main', { ['file.txt'] = { 'base' } })

    s.editor:cmd('cd ' .. main)
    s.editor:cmd('VGit worktree')
    s.editor:await_text('main')
    s.editor:settle()

    s.editor:keys('newwt')
    s.editor:settle()
    s.editor:keys('<CR>')
    s.editor:await_text('(y/N)')
    s.editor:keys('y<CR>')
    s.editor:await_text('Worktree created')
    s.editor:dismiss()

    assert.is_truthy(s.world:git(main, 'worktree', 'list'):find('newwt', 1, true))
  end)

  scenario.test('status in the main checkout ignores changes inside a nested worktree', function(s)
    local main = s.world:repo('main', { ['file.txt'] = { 'base' } })
    local nested = s.world:worktree(main, 'nested', { path = main .. '/.worktrees/nested' })
    s.world:write(main .. '/file.txt', { 'main change' })
    s.world:write(nested .. '/inner.txt', { 'nested change' })

    s.editor:cmd('cd ' .. main)
    s.editor:cmd('VGit status')
    s.editor:await_text('file.txt')
    s.editor:settle()

    assert.is_truthy(s.observe.contains(s, 'file.txt'))
    assert.is_nil(s.observe.screen(s):find('inner.txt', 1, true))
  end)

  scenario.test('a sibling worktree sharing a name prefix does not hide a real directory', function(s)
    local main = s.world:repo('main', { ['file.txt'] = { 'base' } })
    s.world:worktree(main, 'main-feature', { path = s.world.root .. '/main-feature' })
    s.world:write(main .. '/-feature/x.txt', { 'real directory' })

    s.editor:cmd('cd ' .. main)
    s.editor:cmd('VGit status')
    s.editor:wait_for(function()
      return s.observe.contains(s, 'Changes') or s.observe.contains(s, 'No changes to display')
    end, 'the status view to render')
    s.editor:settle()

    assert.is_truthy(s.observe.contains(s, 'x.txt'))
  end)
end)
