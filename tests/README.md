# Scenario tests

Scenario tests drive a **real Neovim** with a **real git** repository and assert
what a user actually sees, end to end. They are slower than unit specs, so the
unit specs stay the first line of defence; scenarios are for the seams between
layers (keymap -> command -> feature -> git) and for anything visual.

Run them with:

```sh
make test-file FILE=tests/scenarios          # every scenario
make test-file FILE=tests/scenarios/views_spec.lua
make test                                 # everything (unit specs + scenarios)
```

`make` sets `GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=protocol.file.allow GIT_CONFIG_VALUE_0=always`
so git will operate on local `file://` remotes. Running bare `vusted` skips that
and some flows will fail.

## How it works

Each scenario spawns a child Neovim inside a **terminal buffer** of the test
process (`termopen`). The terminal buffer is the child's own pty screen, so its
lines are *exactly* what a user would see. Keystrokes are written to the pty as
bytes, the same as a keyboard.

- `tests/scenario/terminal.lua` - spawn/observe the child; `screen()`,
  `send()`, `idle()`, `rpc_eval()`, `messages()`.
- `tests/scenario/editor.lua` - `keys`, `cmd`, `settle`, `await_text`,
  `await_filetype`, `dismiss`, `answer`.
- `tests/scenario/observe.lua` - screen-first assertions: `screen`, `contains`,
  `cwd`, `repository_path`, `view_open`.
- `tests/scenario/world.lua` - the temp dir, `repo()`, `worktree()`, `write()`,
  `git()`, `commit()`.
- `tests/scenario/dsl.lua` + `scenario.flow` - the declarative layer below.

Internal state is read over the child's RPC socket, but **only non-blocking,
file-based** calls are used. A blocking `rpcrequest` would hang forever while the
child sits at a hit-enter prompt. Prefer the screen; use `rpc_eval` sparingly.

## Journeys

`tests/scenarios/journeys_spec.lua` holds end-to-end user journeys: several features used in
sequence the way a person would, with `{ expect = ... }` checkpoints along the way. They drive
the plugin only through keys, `:` commands and a user-style `config` (for example
`keymaps = { ['n <leader>hs'] = 'buffer_hunk_stage' }`), and they observe the screen and git.
Internal state over RPC is used only for things a text screen cannot show, such as signs.

## Declarative flows (preferred)

Most scenarios fit in one table. `scenario.flow(name, spec)`:

```lua
local scenario = require('tests.scenario')({ it = it })

scenario.flow('stage a file from the status view with s', {
  files = { ['file.txt'] = { 'base' } },   -- committed at HEAD
  changes = { ['file.txt'] = { 'changed' } }, -- left in the working tree
  steps = {
    { open = 'status' },                    -- :cd $repo; :VGit status; await "Changes"
    { keys = 's' },
  },
  expect = {
    git_status = 'M  file.txt',
    screen_has = { 'file.txt' },
    screen_hasnt = { 'E218' },
  },
})
```

### `arrange`

| field | meaning |
| --- | --- |
| `files` | files written and committed (HEAD) |
| `staged` | files written and `git add`ed |
| `changes` | files written but left unstaged |
| `untracked` / `deleted` | untracked files written / tracked files removed from the working tree |
| `history` | `{ { message, files } , ... }` extra commits on top of the initial one |
| `branches` | branch names created at HEAD |
| `conflict` | `{ path, ours, theirs }` leaves the repo mid-merge with a real conflict |
| `stashes` | list of stash messages; each stashes the current changes |
| `arrange` | `function(ctx)` escape hatch, runs **after** the shorthand above |

The resolved repo path is `ctx.repo`.

### `steps` (ordered)

Each step is one of:

| step | effect |
| --- | --- |
| `{ cd = path }` | `:cd path` (`$repo` resolves to `ctx.repo`) |
| `{ cmd = text }` | `:text<CR>`; `text` may be a `function(ctx)` |
| `{ open = view }` | `:cd $repo` then `:VGit <view>`; `status` also awaits `Changes` |
| `{ keys = seq }` | send keys (`s`, `C`, `<C-s>`, `<leader>R`, '...') |
| `{ await_text = t }` | wait until the screen shows `t` |
| `{ await_filetype = ft }` | wait until the current buffer's filetype is `ft` |
| `{ snap = name }` | capture the screen under a name |
| `{ dismiss = true }` | let the screen settle, then clear a "Press ENTER" prompt if one is showing |
| `{ settle = ms }` | wait for the screen to stop changing (default timeout) |
| `{ edit = path }` | `:edit path` |
| `{ write = { path, lines } }` | change a file on disk mid-flow (live gutter, external edits) |
| `{ git = { ... } }` | run git in `$repo` mid-flow |
| `{ cursor = { line, col } }` | place the cursor |
| `{ search = text }` | `/text<CR>` |
| `{ focus = filetype }` or `{ focus = { filetype, mapped } }` | focus the window with that filetype and/or a normal-mode mapping for `mapped` (over RPC, safe from insert-mode inputs; errors if nothing matches) |
| `{ wait_until = fn, desc = '' }` | poll `fn(ctx)` until true |
| `{ expect = { ... } }` | checkpoint mid-flow: any `expect` field, retried for up to 3 s (`settle_ms` overrides) because a user sees results "soon", not instantly |
| `{ run = function(ctx) }` | escape hatch |

Every step that sends input settles afterwards; pass `settle_ms` to override.

### `expect`

| field | meaning |
| --- | --- |
| `git_status` | exact `git status --porcelain` |
| `screen_has` | list of substrings the screen must contain |
| `screen_hasnt` | list of substrings the screen must NOT contain |
| `screen_changed` | `{ before, after }` snapshot names that must differ |
| `screen_same` | `{ before, after }` snapshot names that must be equal |
| `git_log` | exact `git log --format=%s` subjects, newest first |
| `file` | `{ path = lines }` working-tree file contents |
| `messages_has` | substrings that must appear in `:messages` (for transient notices gone from the screen) |
| `cursor_line` | the cursor line in the child (RPC) |
| `buffer_lines` | lines of the current buffer |
| `signs` | `{ { lnum = 2, hl = 'GroupName' } }` sign extmarks in the current buffer |
| `assert` | `function(ctx)` escape hatch for anything else |

**Invariants.** After every flow the harness fails on a dead child, any `E123:` Vim
error, a Lua traceback or an "Error executing" message in the screen/`:messages`
(the pty's `E1568` startup notice is ignored). Opt out with `invariants = false`.

**Fixtures.** `World.numbered_lines(count, prefix)` builds `{ 'prefix1', 'prefix2', ... }` for
files that need many lines.

**Isolation.** The child and every git call run with a throwaway `HOME`, no global/system
git config, and a fixed identity and date (2024-01-01), so hashes and blame are stable.

`ctx.world` (the `World`) is available for extra git assertions, e.g.
`ctx.world:git(ctx.repo, 'log', '-1', '--format=%s')`.

## When a flow does not fit: imperative

Drop down to the primitives. `scenario.test(name, fn)` gives you `ctx` with
`world` and `editor`:

```lua
scenario.test('...', function(s)
  local main = s.world:repo('main', { ['file.txt'] = { 'base' } })
  s.editor:cmd('cd ' .. main)
  s.editor:cmd('VGit status')
  s.editor:await_text('Changes')
  s.editor:keys('s')
  s.editor:settle()
  assert.are.same('M  file.txt', s.world:git(main, 'status', '--porcelain'))
end)
```

## Known bugs

When a flow reproduces a bug you cannot fix yet, add `known_bug = 'reason'` to it.
It **passes while the bug reproduces and fails once it is fixed**, prompting you to
remove the marker. This keeps the suite green while preserving the reproduction.

A known bug passes on any failure, including a typo in the flow. Run it once without
the marker and check that it fails for the reason you expect, and where you can, keep
a passing flow with the same steps in a setting that works.

## Gotchas

- **Picker inputs are insert-mode.** `:VGit stash` and similar open an input that swallows
  keys as text; `<Esc>` there closes the view. Use `{ focus = 'diff' }` to reach the
  normal-mode action keys. `<Esc>` followed immediately by a key in one `keys` string
  reaches Neovim as a single Alt chord, so send them as separate steps.
- **Coverage report.** `tests/scenarios/coverage_spec.lua` prints commands with no scenario.

- **Hit-enter prompts.** A long message (e.g. a full path in
  `console.info('Switched to worktree: ' .. path)`) overflows the command line
  and blocks the child at "Press ENTER". Until it is cleared the child does not
  service RPC, so `observe.*` returns `nil`. Call `{ dismiss = true }` (or
  `editor:dismiss()`) like a real user would. Whether a message overflows
  depends on the path length and terminal width, so never assert that the
  prompt appears: wait for the message, then dismiss.
- **The commit buffer opens in insert mode.** Type the message directly; do not
  prefix `i`. Cancel is normal-mode `q`, so send `<Esc>q`.
- **File-diff hunks are chosen by the cursor line.** There are no hunk-nav
  keymaps; move with `/text<CR>`.
- **`<leader>` is `\`** in the child (mapped by `tests/scenario/keys.lua`).
- **macOS has no `timeout`.** Use
  `perl -e 'alarm N; exec @ARGV' make test-file FILE=...` and
  `pkill -f "nvim.*listen"` afterwards. That pkill kills the children of every running
  suite, so never use it while another run is in progress.

## Keeping the harness small

The harness exists to serve scenarios, not the other way round.

- **Add vocabulary only with a user.** A new step, arrange key, expectation or helper
  goes in only alongside the scenario that needs it. No speculative features.
- **Escape hatches before new vocabulary.** If one flow needs something unusual, use
  `arrange`, `{ run = fn }` or `assert`. Promote it to vocabulary when a second flow
  needs the same thing.
- **Delete what nothing uses.** When a scenario stops using a feature and nothing else
  does, remove the feature in the same change.
- **One owner per concern.** Sandbox and git setup belong to `World`, keystrokes to
  `keys`, the pty to `Terminal`, reading the screen to `observe`. Don't duplicate
  across them.
- **Prefer the screen.** Read internal state over RPC only when the user-visible result
  can't be seen on screen, as with signs and virtual text.

## Adding coverage

1. Find the behaviour: a keymap (`lua/vgit/settings/*.lua`), a command
   (`lua/vgit/cli/commands/*.lua`), or a view (`lua/vgit/features/screens/*.lua`).
2. Write a `scenario.flow` that reproduces the user path.
3. If it fails, decide: fix the code, or mark it `known_bug`, or fix the
   test if the expectation was wrong.
4. Verify: the flow, then the whole scenario suite, then the affected unit specs.
