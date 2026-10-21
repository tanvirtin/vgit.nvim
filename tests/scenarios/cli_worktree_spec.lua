-- End-to-end coverage for the `:VGit worktree` CLI subcommands (add/remove/switch),
-- which is separate from the picker-driven flows in worktree_flow_spec.lua.
local scenario = require('tests.scenario')({ it = it })

describe('scenario: worktree CLI', function()
  scenario.flow('switch moves the working directory and repo resolution to the target', {
    files = { ['file.txt'] = { 'base' } },
    arrange = function(ctx)
      ctx.feature = ctx.world:worktree(ctx.repo, 'feature')
    end,
    steps = {
      { cd = '$repo' },
      {
        cmd = function(ctx)
          return 'VGit worktree switch ' .. ctx.feature
        end,
      },
      -- The switch reports the full path, which can overflow the message line
      -- and raise "Press ENTER"; clear it like a user would before reading state.
      { await_text = 'Switched to worktree:' },
      { dismiss = true },
    },
    assert = function(ctx)
      assert.are.same(ctx.feature, ctx.observe.cwd(ctx))
      assert.are.same(ctx.feature, ctx.observe.repository_path(ctx))
    end,
  })

  scenario.flow('remove deletes the worktree from the list', {
    files = { ['file.txt'] = { 'base' } },
    arrange = function(ctx)
      ctx.feature = ctx.world:worktree(ctx.repo, 'feature')
    end,
    steps = {
      { cd = '$repo' },
      {
        cmd = function(ctx)
          return 'VGit worktree remove ' .. ctx.feature
        end,
      },
    },
    assert = function(ctx)
      assert.is_nil(ctx.world:git(ctx.repo, 'worktree', 'list'):find('feature', 1, true))
    end,
  })

  scenario.flow('add creates a worktree from an existing branch', {
    files = { ['file.txt'] = { 'base' } },
    arrange = function(ctx)
      ctx.target = ctx.world.root .. '/added-wt'
      ctx.world:git(ctx.repo, 'branch', 'develop')
    end,
    steps = {
      { cd = '$repo' },
      {
        cmd = function(ctx)
          return 'VGit worktree add ' .. ctx.target .. ' develop'
        end,
      },
    },
    assert = function(ctx)
      assert.is_truthy(ctx.world:git(ctx.repo, 'worktree', 'list'):find('added-wt', 1, true))
    end,
  })

  scenario.flow('add with only a path lets git derive the branch name', {
    files = { ['file.txt'] = { 'base' } },
    arrange = function(ctx)
      ctx.target = ctx.world.root .. '/auto-wt'
    end,
    steps = {
      { cd = '$repo' },
      {
        cmd = function(ctx)
          return 'VGit worktree add ' .. ctx.target
        end,
      },
    },
    assert = function(ctx)
      local list = ctx.world:git(ctx.repo, 'worktree', 'list', '--porcelain')
      assert.is_truthy(list:find('auto%-wt'))
    end,
  })
end)
