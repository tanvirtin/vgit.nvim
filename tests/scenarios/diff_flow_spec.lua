local scenario = require('tests.scenario')({ it = it })

local function base_lines()
  local lines = {}
  for i = 1, 30 do
    lines[i] = 'line ' .. i
  end
  return lines
end

local function open_file_diff(s, repo)
  s.editor:cmd('cd ' .. repo)
  s.editor:cmd('edit file.txt')
  s.editor:settle()
  s.editor:cmd('VGit diff --buffer')
  s.editor:await_text('file.txt')
  s.editor:settle()
end

describe('scenario: file diff flows', function()
  scenario.test('stage only the hunk under the cursor with <leader>s', function(s)
    local main = s.world:repo('main', { ['file.txt'] = base_lines() })
    local changed = base_lines()
    changed[2] = 'changed near top'
    changed[28] = 'changed near bottom'
    s.world:write(main .. '/file.txt', changed)

    open_file_diff(s, main)

    s.editor:keys('/changed near bottom<CR>')
    s.editor:settle()
    s.editor:keys('<leader>s')
    s.editor:settle()

    local staged = s.world:git(main, 'diff', '--cached', '--unified=0')
    assert.is_truthy(staged:find('changed near bottom', 1, true))
    assert.is_nil(staged:find('changed near top', 1, true))
  end)

  scenario.test('stage the whole file from the diff view with s', function(s)
    local main = s.world:repo('main', { ['file.txt'] = { 'base' } })
    s.world:write(main .. '/file.txt', { 'changed' })

    open_file_diff(s, main)
    s.editor:keys('s')
    s.editor:settle()

    assert.are.same('M  file.txt', s.world:git(main, 'status', '--porcelain'))
  end)

  scenario.test('toggle the diff between working and staged content with t', function(s)
    local main = s.world:repo('main', { ['file.txt'] = { 'base' } })
    s.world:write(main .. '/file.txt', { 'staged version' })
    s.world:git(main, 'add', 'file.txt')
    s.world:write(main .. '/file.txt', { 'working version' })

    open_file_diff(s, main)
    local before = s.observe.screen(s)

    s.editor:keys('t')
    s.editor:settle()
    local after = s.observe.screen(s)

    local flipped = (before:find('staged version', 1, true) and after:find('working version', 1, true))
      or (before:find('working version', 1, true) and after:find('staged version', 1, true))
    assert.is_truthy(flipped, 't should flip the diff between staged and working content')
  end)
end)

describe('scenario: project diff with untracked files', function()
  scenario.test('a repository with only a new file shows that file and its lines', function(s)
    local repo = s.world:repo('main', { ['a.txt'] = { 'a' } })
    s.world:write(repo .. '/new.txt', { 'brand new line' })

    s.editor:cmd('cd ' .. repo)
    s.editor:cmd('VGit diff')
    s.editor:await_text('new.txt', 3000)
    s.editor:await_text('brand new line', 3000)
  end)

  scenario.test('a new file is listed next to modified files', function(s)
    local repo = s.world:repo('main', { ['a.txt'] = { 'a' } })
    s.world:write(repo .. '/a.txt', { 'changed a' })
    s.world:write(repo .. '/dir/new.txt', { 'brand new line' })

    s.editor:cmd('cd ' .. repo)
    s.editor:cmd('VGit diff')
    s.editor:await_text('changed a', 3000)
    s.editor:await_text('brand new line', 3000)
  end)

  scenario.test('a new binary file is left out of the diff', function(s)
    local repo = s.world:repo('main', { ['a.txt'] = { 'a' } })
    s.world:write(repo .. '/a.txt', { 'changed a' })
    local blob = assert(io.open(repo .. '/blob.bin', 'wb'))
    blob:write('bin\0ary')
    blob:close()

    s.editor:cmd('cd ' .. repo)
    s.editor:cmd('VGit diff')
    s.editor:await_text('changed a', 3000)
    s.editor:await_no_text('blob.bin', 500)
  end)

  scenario.test('enter on a new file opens it in the editor', function(s)
    local repo = s.world:repo('main', { ['a.txt'] = { 'a' } })
    s.world:write(repo .. '/a.txt', { 'changed a' })
    s.world:write(repo .. '/new.txt', { 'brand new line' })

    s.editor:cmd('cd ' .. repo)
    s.editor:cmd('VGit diff')
    s.editor:await_text('brand new line', 3000)
    s.editor:keys('/brand new<CR>')
    s.editor:settle()
    s.editor:keys('<CR>')
    s.editor:await_text('new.txt', 3000)
    s.editor:await_no_text('Scratch', 1000)
  end)
end)
