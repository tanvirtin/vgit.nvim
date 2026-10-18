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
