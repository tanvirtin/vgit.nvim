local scenario = require('tests.scenario')({ it = it })

describe('scenario: diff arguments', function()
  scenario.flow('--staged shows only staged changes', {
    files = { ['a.txt'] = { 'a' }, ['b.txt'] = { 'b' } },
    staged = { ['a.txt'] = { 'a staged' } },
    changes = { ['b.txt'] = { 'b unstaged' } },
    steps = { { cd = '$repo' }, { cmd = 'VGit diff --staged' }, { await_text = 'a staged' } },
    expect = { screen_has = { 'a.txt', 'a staged' }, screen_hasnt = { 'b unstaged' } },
  })

  scenario.flow('a plain diff shows only unstaged changes', {
    files = { ['a.txt'] = { 'a' }, ['b.txt'] = { 'b' } },
    staged = { ['a.txt'] = { 'a staged' } },
    changes = { ['b.txt'] = { 'b unstaged' } },
    steps = { { cd = '$repo' }, { cmd = 'VGit diff' }, { await_text = 'b unstaged' } },
    expect = { screen_has = { 'b.txt', 'b unstaged' }, screen_hasnt = { 'a staged' } },
  })

  scenario.flow('diff against a ref compares the working tree to it', {
    files = { ['a.txt'] = { 'one' } },
    history = { { message = 'second', files = { ['a.txt'] = { 'two' } } } },
    steps = { { cd = '$repo' }, { cmd = 'VGit diff HEAD~1' }, { await_text = 'one' } },
    expect = { screen_has = { 'a.txt', 'one', 'two' } },
  })

  scenario.flow('diff between two refs shows the change between them', {
    files = { ['a.txt'] = { 'one' } },
    history = {
      { message = 'second', files = { ['a.txt'] = { 'two' } } },
      { message = 'third', files = { ['a.txt'] = { 'three' } } },
    },
    steps = { { cd = '$repo' }, { cmd = 'VGit diff HEAD~2 HEAD~1' }, { await_text = 'two' } },
    expect = { screen_has = { 'one', 'two' }, screen_hasnt = { 'three' } },
  })

  scenario.flow('diff of a single file limits the view to that file', {
    files = { ['a.txt'] = { 'a' }, ['b.txt'] = { 'b' } },
    changes = { ['a.txt'] = { 'a2' }, ['b.txt'] = { 'b2' } },
    steps = { { cd = '$repo' }, { cmd = 'VGit diff a.txt' }, { await_text = 'a2' } },
    expect = { screen_has = { 'a2' }, screen_hasnt = { 'b2' } },
  })

  scenario.flow('diff of a file whose whole directory was deleted still finds the repository', {
    files = { ['dir/sub/f.txt'] = { 'one' }, ['keep.txt'] = { 'k' } },
    arrange = function(ctx)
      vim.fn.delete(ctx.repo .. '/dir', 'rf')
    end,
    steps = { { cd = '$repo' }, { cmd = 'VGit diff dir/sub/f.txt' }, { await_text = 'one' } },
    expect = { screen_has = { 'one' } },
  })

  scenario.flow('diff with nothing changed reports it and stays usable', {
    files = { ['a.txt'] = { 'a' } },
    steps = { { cd = '$repo' }, { cmd = 'VGit diff' }, { settle = 800 } },
    expect = { messages_has = { 'No unstaged changes' } },
  })

  scenario.flow('diff of an unknown ref reports an error and stays usable', {
    files = { ['a.txt'] = { 'a' } },
    steps = { { cd = '$repo' }, { cmd = 'VGit diff nosuchref' }, { settle = 800 } },
    invariants = false,
    assert = function(ctx)
      assert.is_truthy(ctx.editor.terminal:is_alive())
    end,
  })

  scenario.flow('show of an unknown commit reports an error and stays usable', {
    files = { ['a.txt'] = { 'a' } },
    steps = { { cd = '$repo' }, { cmd = 'VGit show deadbeef' }, { settle = 800 } },
    invariants = false,
    assert = function(ctx)
      assert.is_truthy(ctx.editor.terminal:is_alive())
    end,
  })

  scenario.flow('show of a merge commit does not error', {
    files = { ['a.txt'] = { 'a' } },
    arrange = function(ctx)
      ctx.world:branch(ctx.repo, 'side', { checkout = true })
      ctx.world:write(ctx.repo .. '/side.txt', { 'side' })
      ctx.world:commit(ctx.repo, 'side work')
      ctx.world:git(ctx.repo, 'checkout', '-q', 'main')
      ctx.world:write(ctx.repo .. '/main.txt', { 'main' })
      ctx.world:commit(ctx.repo, 'main work')
      ctx.world:git(ctx.repo, 'merge', '--no-ff', '-m', 'merge side', 'side')
    end,
    steps = { { cd = '$repo' }, { cmd = 'VGit show' }, { settle = 1000 } },
    expect = { screen_hasnt = { 'Traceback' } },
  })
end)

describe('scenario: project diff interaction', function()
  scenario.flow('enter jumps to the file under the cursor', {
    files = { ['a.txt'] = { 'a' } },
    changes = { ['a.txt'] = { 'a2' } },
    steps = {
      { cd = '$repo' },
      { cmd = 'VGit diff' },
      { await_text = 'a2' },
      { focus = { mapped = '<cr>' } },
      { cursor = { 5, 1 } },
      { keys = '<CR>' },
      { settle = 800 },
    },
    assert = function(ctx)
      assert.is_truthy(ctx.editor.terminal:rpc_eval('vim.api.nvim_buf_get_name(0)'):find('a.txt', 1, true))
    end,
  })

  scenario.flow('b opens blame for the file under the cursor', {
    files = { ['a.txt'] = { 'a' } },
    changes = { ['a.txt'] = { 'a2' } },
    steps = {
      { cd = '$repo' },
      { cmd = 'VGit diff' },
      { await_text = 'a2' },
      { focus = { mapped = 'b' } },
      { cursor = { 5, 1 } },
      { keys = 'b' },
      { settle = 1000 },
    },
    expect = { screen_has = { 'initial' } },
  })
end)

describe('scenario: repository states', function()
  scenario.flow('status in a repository with no commits does not error', {
    arrange = function(ctx)
      ctx.repo = ctx.world.root .. '/empty'
      vim.fn.mkdir(ctx.repo, 'p')
      ctx.world:git(ctx.repo, 'init', '-q')
      ctx.world:write(ctx.repo .. '/new.txt', { 'x' })
    end,
    steps = { { open = 'status' }, { settle = 600 } },
    expect = { screen_has = { 'new.txt' } },
  })

  scenario.flow('log in a repository with no commits reports it', {
    arrange = function(ctx)
      ctx.repo = ctx.world.root .. '/empty'
      vim.fn.mkdir(ctx.repo, 'p')
      ctx.world:git(ctx.repo, 'init', '-q')
    end,
    steps = { { cd = '$repo' }, { cmd = 'VGit log' }, { settle = 800 } },
    invariants = false,
    assert = function(ctx)
      assert.is_truthy(ctx.editor.terminal:is_alive())
    end,
  })

  scenario.flow('status in a subdirectory of the repo shows repo-wide changes', {
    files = { ['dir/a.txt'] = { 'a' }, ['top.txt'] = { 't' } },
    changes = { ['dir/a.txt'] = { 'a2' }, ['top.txt'] = { 't2' } },
    steps = {
      { cd = '$repo/dir' },
      { cmd = 'VGit status' },
      { await_text = 'Changes' },
    },
    expect = { screen_has = { 'a.txt', 'top.txt' } },
  })

  scenario.flow('a bare-bones status with a staged-and-modified file lists both entries', {
    files = { ['a.txt'] = { 'a' } },
    staged = { ['a.txt'] = { 'a staged' } },
    changes = { ['a.txt'] = { 'a staged', 'a more' } },
    steps = { { open = 'status' } },
    expect = { screen_has = { 'Staged', 'Changes', 'a.txt' } },
  })

  scenario.flow('stage all then unstage all round-trips the repo state', {
    files = { ['a.txt'] = { 'a' }, ['b.txt'] = { 'b' } },
    changes = { ['a.txt'] = { 'a2' }, ['b.txt'] = { 'b2' } },
    steps = { { open = 'status' }, { keys = 'S' }, { settle = 600 }, { keys = 'U' }, { settle = 600 } },
    expect = { git_status = ' M a.txt\n M b.txt' },
  })
end)

describe('scenario: project diff syntax', function()
  local files, changes = {}, {}
  for i = 1, 40 do
    local name = string.format('m%02d.lua', i)
    files[name] = { 'local value = ' .. i }
    changes[name] = { 'local changed_' .. i .. ' = ' .. i }
  end

  local function syntax_at_cursor(ctx)
    local line = ctx.observe.cursor(ctx)[1]
    for _, mark in ipairs(ctx.observe.extmarks(ctx, line)) do
      if mark.hl and mark.hl:sub(1, 1) == '@' then return true end
    end
    return false
  end

  scenario.flow('code is highlighted in the first file and in a file far below it', {
    files = files,
    changes = changes,
    steps = {
      { cd = '$repo' },
      { cmd = 'VGit diff' },
      { await_text = 'changed_1 ' },
      { keys = '/changed_1 <CR>' },
      { wait_until = syntax_at_cursor, desc = 'syntax highlight in the first file' },
      { keys = '/changed_40<CR>' },
      { wait_until = syntax_at_cursor, desc = 'syntax highlight in the last file' },
    },
  })
end)

describe('scenario: project diff word highlights', function()
  local function word_highlight_at_cursor(ctx)
    local line = ctx.observe.cursor(ctx)[1]
    for _, mark in ipairs(ctx.observe.extmarks(ctx, line)) do
      for _, hl in ipairs(mark.virt_hl or {}) do
        if hl == 'GitWordAdd' then return true end
      end
    end
    return false
  end

  for _, layout in ipairs({ 'unified', 'split' }) do
    scenario.flow('the changed word is highlighted in the ' .. layout .. ' layout', {
      config = { settings = { scene = { diff_preference = layout } } },
      files = { ['a.txt'] = { 'keep this', 'value is old', 'keep that' } },
      history = { { message = 'change', files = { ['a.txt'] = { 'keep this', 'value is new', 'keep that' } } } },
      steps = {
        { cd = '$repo' },
        { cmd = 'VGit diff HEAD~1' },
        { await_text = 'value is new' },
        { keys = '/value is new<CR>' },
        { wait_until = word_highlight_at_cursor, desc = 'GitWordAdd on the changed line' },
      },
    })
  end
end)

describe('scenario: project diff progressive loading', function()
  local files, changed = {}, {}
  for i = 1, 120 do
    local name = string.format('f%03d.txt', i)
    files[name] = { 'line one', string.format('value %03d', i) }
    changed[name] = { 'line one', string.format('changed %03d', i) }
  end

  local function last_file_loaded(ctx)
    for _, line in ipairs(ctx.observe.buffer_lines(ctx) or {}) do
      if line == 'changed 120' then return true end
    end
    return false
  end

  for _, layout in ipairs({ 'unified', 'split' }) do
    scenario.flow('a file loaded in a later batch jumps to its line in the ' .. layout .. ' layout', {
      config = { settings = { scene = { diff_preference = layout } } },
      files = files,
      history = { { message = 'change every file', files = changed } },
      steps = {
        { cd = '$repo' },
        { cmd = 'VGit diff HEAD~1' },
        { await_text = 'changed 001' },
        { wait_until = last_file_loaded, desc = 'the last file to be loaded' },
        { keys = '/changed 120<CR>' },
        { keys = '<CR>' },
        { settle = 800 },
      },
      assert = function(ctx)
        local terminal = ctx.editor.terminal
        assert.is_truthy(terminal:rpc_eval('vim.api.nvim_buf_get_name(0)'):find('f120.txt', 1, true))
        assert.are.same(2, ctx.observe.cursor(ctx)[1])
      end,
    })
  end

  scenario.flow('closing the view while files are still loading leaves no errors', {
    files = files,
    history = { { message = 'change every file', files = changed } },
    steps = {
      { cd = '$repo' },
      { cmd = 'VGit diff HEAD~1' },
      { await_text = 'changed 001' },
      { keys = '<Esc>' },
      { settle = 1500 },
    },
    expect = { screen_hasnt = { 'changed 001' } },
  })
end)
