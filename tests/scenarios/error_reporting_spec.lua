local scenario = require('tests.scenario')({ it = it })

local function open_status(s, repo)
  s.editor:cmd('cd ' .. repo)
  s.editor:cmd('VGit status')
  s.editor:await_text('Changes')
  s.editor:settle()
end

local function lock_index(world, repo)
  world:write(repo .. '/.git/index.lock', '')
end

describe('scenario: mutation failures', function()
  scenario.test('a failed stage in the status view reports why nothing happened', function(s)
    local main = s.world:repo('main', { ['file.txt'] = { 'base' } })
    s.world:write(main .. '/file.txt', { 'changed' })

    open_status(s, main)
    lock_index(s.world, main)

    s.editor:keys('s')
    s.editor:settle(1200)

    assert.is_truthy(s.observe.contains(s, 'Failed to stage file'), 'the stage failure should be reported')
    assert.are.same(' M file.txt', s.world:git(main, 'status', '--porcelain'))

    s.editor:dismiss()
    vim.fn.delete(main .. '/.git/index.lock')
    s.editor:keys('s')
    s.editor:settle(1200)

    assert.are.same('M  file.txt', s.world:git(main, 'status', '--porcelain'))
  end)

  scenario.test('a failed stage in the file diff view reports why nothing happened', function(s)
    local main = s.world:repo('main', { ['file.txt'] = { 'base' } })
    s.world:write(main .. '/file.txt', { 'changed' })

    s.editor:cmd('cd ' .. main)
    s.editor:cmd('edit file.txt')
    s.editor:settle()
    s.editor:cmd('VGit diff --buffer')
    s.editor:await_text('file.txt')
    s.editor:settle()

    lock_index(s.world, main)

    s.editor:keys('s')
    s.editor:settle(1200)

    assert.is_truthy(s.observe.contains(s, 'Failed to stage file'), 'the stage failure should be reported')
    assert.are.same(' M file.txt', s.world:git(main, 'status', '--porcelain'))
  end)

  scenario.test('a failed buffer stage reports why nothing happened', function(s)
    local main = s.world:repo('main', { ['file.txt'] = { 'base' } })
    s.world:write(main .. '/file.txt', { 'changed' })

    s.editor:cmd('cd ' .. main)
    s.editor:cmd('edit file.txt')
    s.editor:settle(600)

    lock_index(s.world, main)

    s.editor:cmd('VGit buffer_stage')
    s.editor:settle(1200)

    assert.is_truthy(s.observe.contains(s, 'Unable to create'), 'the stage failure should be reported')
    assert.are.same(' M file.txt', s.world:git(main, 'status', '--porcelain'))

    s.editor:dismiss()
    vim.fn.delete(main .. '/.git/index.lock')
    s.editor:cmd('VGit buffer_stage')
    s.editor:settle(1200)

    assert.are.same('M  file.txt', s.world:git(main, 'status', '--porcelain'))
  end)

  scenario.test('resetting an untracked file says it will be deleted', function(s)
    local main = s.world:repo('main', { ['file.txt'] = { 'base' } })
    s.world:write(main .. '/junk.txt', { 'not committed' })

    open_status(s, main)
    s.editor:keys('r')
    s.editor:await_text('Delete untracked file \'junk.txt\'?')
    s.editor:keys('n<CR>')
    s.editor:settle()

    assert.are.same('?? junk.txt', s.world:git(main, 'status', '--porcelain'))
    assert.is_true(vim.fn.filereadable(main .. '/junk.txt') == 1)
  end)

  scenario.test('resetting a newly added file says it will be deleted', function(s)
    local main = s.world:repo('main', { ['file.txt'] = { 'base' } })
    s.world:write(main .. '/new.txt', { 'brand new' })
    s.world:git(main, 'add', 'new.txt')

    open_status(s, main)
    s.editor:keys('r')
    s.editor:await_text('Unstage and delete new file \'new.txt\'?')
    s.editor:keys('n<CR>')
    s.editor:settle()

    assert.are.same('A  new.txt', s.world:git(main, 'status', '--porcelain'))
    assert.is_true(vim.fn.filereadable(main .. '/new.txt') == 1)
  end)

  scenario.test('resetting everything says untracked files will be deleted', function(s)
    local main = s.world:repo('main', { ['file.txt'] = { 'base' } })
    s.world:write(main .. '/file.txt', { 'changed' })
    s.world:write(main .. '/junk.txt', { 'not committed' })

    open_status(s, main)
    s.editor:keys('<leader>R')
    s.editor:await_text('permanently delete untracked files')
    s.editor:keys('n<CR>')
    s.editor:settle()

    assert.is_true(vim.fn.filereadable(main .. '/junk.txt') == 1)
    assert.are.same(' M file.txt\n?? junk.txt', s.world:git(main, 'status', '--porcelain'))
  end)
end)
