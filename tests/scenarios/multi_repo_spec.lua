local scenario = require('tests.scenario')({ it = it })
local World = require('tests.scenario.world')

local user_config = {
  keymaps = {
    ['n <leader>hs'] = 'buffer_hunk_stage',
  },
}

local function edited()
  local lines = World.numbered_lines(10, 'line')
  lines[5] = 'CHANGED'
  return lines
end

local function workspace(prepare)
  return function(ctx)
    ctx.ws = ctx.world.root
    ctx.repo = ctx.world:repo('alpha', { ['a.txt'] = World.numbered_lines(10, 'line') })
    ctx.world:repo('beta', { ['b.txt'] = { 'uno' } })
    if prepare then prepare(ctx) end
  end
end

local function change_alpha(ctx)
  ctx.world:write(ctx.repo .. '/a.txt', edited())
end

local function alpha_history(ctx)
  ctx.world:history(ctx.repo, { { message = 'alpha work', files = { ['a.txt'] = edited() } } })
end

local function from_both(name, case)
  for _, where in ipairs({ 'repo', 'ws' }) do
    local steps = { { cd = '$' .. where } }
    vim.list_extend(steps, case.steps)
    scenario.flow(name .. (where == 'repo' and ', from inside the repo' or ', from a folder of repos'), {
      arrange = workspace(case.prepare),
      config = case.config,
      steps = steps,
    })
  end
end

describe('scenario: a folder of repos', function()
  from_both('the gutter marks an edited line', {
    prepare = change_alpha,
    steps = {
      { edit = '$repo/a.txt' },
      { expect = { signs = { { lnum = 5 } } } },
    },
  })

  from_both('a commit outside the editor clears the gutter', {
    prepare = change_alpha,
    steps = {
      { edit = '$repo/a.txt' },
      { expect = { signs = { { lnum = 5 } } } },
      { git = { 'commit', '-q', '-am', 'external commit' } },
      {
        expect = {
          assert = function(ctx)
            assert.are.same(0, #ctx.observe.signs(ctx))
          end,
        },
        settle_ms = 8000,
      },
    },
  })

  from_both('a hunk is staged from the buffer with a keymap', {
    prepare = change_alpha,
    config = user_config,
    steps = {
      { edit = '$repo/a.txt' },
      { expect = { signs = { { lnum = 5 } } } },
      { keys = '5G' },
      { keys = '<leader>hs' },
      { expect = { git_status = 'M  a.txt' } },
    },
  })

  from_both('live blame describes the line under the cursor', {
    prepare = alpha_history,
    steps = {
      { cmd = 'set updatetime=100' },
      { edit = '$repo/a.txt' },
      { keys = '5G' },
      { expect = { screen_has = { 'alpha work' } } },
    },
  })

  from_both('b:vgit_status counts the changed lines of the open file', {
    prepare = change_alpha,
    steps = {
      { edit = '$repo/a.txt' },
      {
        expect = {
          assert = function(ctx)
            local status = ctx.editor.terminal:rpc_eval_json('vim.b.vgit_status')
            assert.are.same({ added = 0, changed = 1, removed = 0 }, status)
          end,
        },
      },
    },
  })

  from_both(':VGit hunk previews the hunk under the cursor', {
    prepare = change_alpha,
    steps = {
      { edit = '$repo/a.txt' },
      { keys = '5G' },
      { cmd = 'VGit hunk' },
      { expect = { screen_has = { 'line5' } } },
    },
  })

  from_both(':VGit blame shows the blame of the line under the cursor', {
    prepare = alpha_history,
    steps = {
      { edit = '$repo/a.txt' },
      { keys = '5G' },
      { cmd = 'VGit blame' },
      { expect = { screen_has = { 'Scenario (scenario@example.test)', 'alpha work' } } },
    },
  })

  from_both(':VGit blame --screen lists the commits behind the open file', {
    prepare = alpha_history,
    steps = {
      { edit = '$repo/a.txt' },
      { cmd = 'VGit blame --screen' },
      { expect = { screen_has = { 'alpha work' } } },
    },
  })

  from_both(':VGit diff of a file shows its changes', {
    prepare = change_alpha,
    steps = {
      { cmd = 'VGit diff $repo/a.txt' },
      { expect = { screen_has = { 'CHANGED', 'line5' } } },
    },
  })

  from_both(':VGit status lists the open file and stages it', {
    prepare = change_alpha,
    steps = {
      { edit = '$repo/a.txt' },
      { cmd = 'VGit status' },
      { expect = { screen_has = { 'Changes', 'a.txt' } } },
      { keys = 's' },
      { expect = { git_status = 'M  a.txt' } },
    },
  })

  from_both(':VGit diff lists the changes of the open file', {
    prepare = change_alpha,
    steps = {
      { edit = '$repo/a.txt' },
      { cmd = 'VGit diff' },
      { expect = { screen_has = { 'line5', 'CHANGED' } } },
    },
  })

  from_both(':VGit log lists the history of the open file', {
    prepare = alpha_history,
    steps = {
      { edit = '$repo/a.txt' },
      { cmd = 'VGit log' },
      { expect = { screen_has = { 'alpha work', 'initial' } } },
    },
  })

  from_both(':VGit show shows the last commit of the open file', {
    prepare = alpha_history,
    steps = {
      { edit = '$repo/a.txt' },
      { cmd = 'VGit show' },
      { expect = { screen_has = { 'line5', 'CHANGED' } } },
    },
  })

  from_both(':VGit branch lists the branches of the open file', {
    prepare = function(ctx)
      ctx.world:branch(ctx.repo, 'alpha-topic')
    end,
    steps = {
      { edit = '$repo/a.txt' },
      { cmd = 'VGit branch' },
      { expect = { screen_has = { 'alpha-topic', '(current)' } } },
    },
  })

  from_both('switching branch from the picker switches the repo of the open file', {
    prepare = function(ctx)
      ctx.world:branch(ctx.repo, 'alpha-topic')
    end,
    steps = {
      { edit = '$repo/a.txt' },
      { cmd = 'VGit branch' },
      { expect = { screen_has = { 'alpha-topic' } } },
      { keys = 'alpha-topic<CR>' },
      {
        expect = {
          assert = function(ctx)
            assert.are.same('alpha-topic', ctx.world:git(ctx.repo, 'rev-parse', '--abbrev-ref', 'HEAD'))
          end,
        },
      },
    },
  })

  from_both('choosing a commit in the log shows its changes', {
    prepare = alpha_history,
    steps = {
      { edit = '$repo/a.txt' },
      { cmd = 'VGit log' },
      { expect = { screen_has = { 'alpha work' } } },
      { keys = '<CR>' },
      { expect = { screen_has = { 'line5' } } },
    },
  })

  from_both('b in the project diff opens the blame of the file', {
    prepare = function(ctx)
      alpha_history(ctx)
      local lines = edited()
      lines[2] = 'AGAIN'
      ctx.world:write(ctx.repo .. '/a.txt', lines)
    end,
    steps = {
      { edit = '$repo/a.txt' },
      { cmd = 'VGit diff' },
      { expect = { screen_has = { 'AGAIN' } } },
      { focus = { mapped = 'b' } },
      { cursor = { 5, 1 } },
      { keys = 'b' },
      { expect = { screen_has = { 'alpha work' } } },
    },
  })

  scenario.flow('the open file decides the repo, even inside another repo', {
    arrange = workspace(function(ctx)
      ctx.beta = ctx.ws .. '/beta'
      ctx.world:history(ctx.beta, { { message = 'beta work', files = { ['b.txt'] = { 'dos' } } } })
    end),
    steps = {
      { cd = '$repo' },
      { edit = '$beta/b.txt' },
      { cmd = 'VGit log' },
      { expect = { screen_has = { 'beta work' }, screen_hasnt = { 'alpha' } } },
    },
  })

  from_both(':VGit stash lists the stashes of the open file', {
    prepare = function(ctx)
      change_alpha(ctx)
      ctx.world:stash(ctx.repo, 'alpha stash')
    end,
    steps = {
      { edit = '$repo/a.txt' },
      { cmd = 'VGit stash' },
      { expect = { screen_has = { 'alpha stash' } } },
    },
  })

  from_both(':VGit commit commits to the repo of the open file', {
    prepare = function(ctx)
      change_alpha(ctx)
      ctx.world:git(ctx.repo, 'add', 'a.txt')
    end,
    steps = {
      { edit = '$repo/a.txt' },
      { cmd = 'VGit commit' },
      { keys = 'alpha commit<C-s>' },
      { expect = { git_log = { 'alpha commit', 'initial' } } },
    },
  })

  scenario.flow(':VGit status with no file open lists the changes of every repo', {
    arrange = workspace(function(ctx)
      change_alpha(ctx)
      ctx.world:write(ctx.ws .. '/beta/b.txt', { 'dos' })
    end),
    steps = {
      { cd = '$ws' },
      { cmd = 'VGit status' },
      { expect = { screen_has = { 'alpha', 'a.txt', 'beta', 'b.txt' } } },
    },
    known_bug = 'status shows one repo, not a group per repo',
  })
end)
