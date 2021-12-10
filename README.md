# VGit :zap:
<table>
    <tr>
        <td>
            <strong>Visual Git Plugin for Neovim to enhance your git experience.</strong>
        </tr>
    </td>
</table>

<br />

<a href="https://github.com/tanvirtin/vgit.nvim/actions?query=workflow%3ACI">
    <img src="https://github.com/tanvirtin/vgit.nvim/workflows/CI/badge.svg?branch=main" alt="CI" />
</a>
<a href="https://opensource.org/licenses/MIT">
    <img src="https://img.shields.io/badge/License-MIT-yellow.svg" alt="License" />
</a>

<br />
<br />
<img src="https://user-images.githubusercontent.com/25164326/135163103-6f869926-1cb8-4aaf-a217-4f132aefb237.gif" alt="preview" />

## Highlighted Features
- Gutter changes annotation to highlight any local (unpublished) changes or lines changed by the most recent commit
- Current line blame as virtual text
- See the details of a blame related to the current line (`:VGit buffer_blame_preview`)
- See the blames of a buffer in a VGit preview (`:VGit buffer_gutter_blame_preview`)
- See all hunks in a VGit preview (`:VGit buffer_hunk_preview`)
- See the buffer changes in a VGit preview (`:VGit buffer_diff_preview`)
- See the buffer changes that were staged in a VGit preview (`:VGit buffer_staged_diff_preview`)
- See all the history of a buffer in a VGit preview (`:VGit buffer_history`)
- See changes in your project in a VGit diff preview (`:VGit project_diff_preview`)
- See changes in your project in a quickfix list (`:VGit project_hunks_qf`)
- Enhance your workflow by using VGit's buffer navigation `:VGit hunk_up` and `:VGit hunk_down` that can be used on any VGit previews with changes.

If you have Telescope feel free to run `:VGit actions` to quickly checkout your execution options.
<br />
<br />
<img src="https://user-images.githubusercontent.com/25164326/135162562-648a3b64-e403-439f-b4fc-6bc7fc7ddcd0.PNG" alt="commands"/>

## Supported Neovim Versions:
- Neovim **>=** 0.5

## Supported Opperating System:
- linux-gnu*
- Darwin

## Prerequisites
- [Git](https://git-scm.com/)
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)

## Recommended Settings
- `vim.o.updatetime = 100` (see :help updatetime).
- `vim.wo.signcolumn = 'yes'` (see :help signcolumn)

## Installation
Default installation via Packer.
```lua
use {
  'tanvirtin/vgit.nvim',
  requires = {
    'nvim-lua/plenary.nvim'
  }
}
```

Lazy loading via Packer.
```lua
use({
    'tanvirtin/vgit.nvim',
    event = 'BufWinEnter',
    requires = {
        'nvim-lua/plenary.nvim',
    },
    config = function()
        require('vgit').setup()
    end,
})
```

## Setup
You must instantiate the plugin in order for the features to work.
```lua
require('vgit').setup()
```

To embed the above code snippet in a .vim file wrap it in lua << EOF code-snippet EOF:
```lua
lua << EOF
require('vgit').setup()
EOF
```

## Themes
Predefined supported themes:
- [tokyonight](https://github.com/folke/tokyonight.nvim)
- [monokai](https://github.com/tanvirtin/monokai.nvim)

Colorscheme definitions can be found in `lua/vgit/themes/`, feel free to open a pull request with your own colorscheme!

## Layouts
Predefined supported layouts:
- default (Full screen previews)

Layout definitions can be found in `lua/vgit/layouts/`, feel free to open a pull request with your own layout!

## API
| Function Name | Description |
|---------------|-------------|
| setup | Sets up the plugin for success |
| toggle_buffer_hunks | Shows hunk signs on buffers/Hides hunk signs on buffers |
| toggle_buffer_blames | Enables blames feature on buffers/Disables blames feature on buffers |
| toggle_diff_preference | Switches between "horizontal" and "vertical" layout for previews |
| buffer_stage | Stages a buffer you are currently on |
| buffer_unstage | Unstages a buffer you are currently on |
| buffer_diff_preview | Opens a diff preview of the changes in the current buffer |
| buffer_staged_diff_preview | Shows staged changes in a preview window |
| buffer_hunk_preview | Gives you a view through which you can navigate and see the current hunk or other hunks |
| buffer_history_preview | Opens a buffer preview along with a table of logs, enabling users to see different iterations of the buffer in the git history |
| buffer_blame_preview | Opens a preview detailing the blame of the line that the user is currently on |
| buffer_gutter_blame_preview | Opens a preview which shows the blames related to all the lines of a buffer |
| buffer_reset | Resets the current buffer to HEAD |
| buffer_hunk_stage | Stages a hunk, if cursor is over it |
| buffer_hunk_reset | Removes the hunk from the buffer, if cursor is over it |
| project_hunks_qf | Opens a populated quickfix window with all the hunks of the project |
| project_diff_preview | Opens a preview listing all the files that have been changed |
| hunk_down | Navigate downward through a hunk, this works on any view with diff highlights |
| hunk_up | Navigate upwards through a hunk, this works on any view with diff highlights |
| get_diff_base | Returns the current diff base that all diff and hunks are being compared for all buffers |
| get_diff_preference | Returns the current diff preference of the diff, the value will either be "horizontal" or "vertical" |
| get_diff_strategy | Returns the current diff strategy used to compute hunk signs and buffer preview, the value will either be "remote" or "index" |
| set_diff_base | Sets the current diff base to a different commit, going forward all future hunks and diffs for a given buffer will be against this commit |
| set_diff_strategy | Sets the diff strategy that will be used to show hunk signs and buffer preview, the value can only be "remote" or "index" |
| show_debug_logs | Shows all errors that has occured during program execution |

## Advanced Setup
```lua
local vgit = require('vgit')
local utils = require('vgit.utils')

vgit.setup({
    debug = false, -- Only enable this to trace issues related to the app,
    keymaps = {
        ['n <C-k>'] = 'hunk_up',
        ['n <C-j>'] = 'hunk_down',
        ['n <leader>g'] = 'actions',
        ['n <leader>gs'] = 'buffer_hunk_stage',
        ['n <leader>gr'] = 'buffer_hunk_reset',
        ['n <leader>gp'] = 'buffer_hunk_preview',
        ['n <leader>gb'] = 'buffer_blame_preview',
        ['n <leader>gf'] = 'buffer_diff_preview',
        ['n <leader>gh'] = 'buffer_history_preview',
        ['n <leader>gu'] = 'buffer_reset',
        ['n <leader>gg'] = 'buffer_gutter_blame_preview',
        ['n <leader>gd'] = 'project_diff_preview',
        ['n <leader>gq'] = 'project',
        ['n <leader>gx'] = 'toggle_diff_preference',
    },
    controller = {
        hunks_enabled = true,
        blames_enabled = true,
        diff_strategy = 'index',
        diff_preference = 'horizontal',
        predict_hunk_signs = true,
        predict_hunk_throttle_ms = 300,
        predict_hunk_max_lines = 50000,
        blame_line_throttle_ms = 150,
        action_delay_ms = 300,
    },
    hls = vgit.themes.tokyonight,
    signs = {
        VGitViewSignAdd = {
            name = 'DiffAdd',
            line_hl = 'DiffAdd',
            text_hl = nil,
            num_hl = nil,
            icon = nil,
            text = '',
        },
        VGitViewSignRemove = {
            name = 'DiffDelete',
            line_hl = 'DiffDelete',
            text_hl = nil,
            num_hl = nil,
            icon = nil,
            text = '',
        },
        VGitSignAdd = {
            name = 'VGitSignAdd',
            text_hl = 'VGitSignAdd',
            num_hl = nil,
            icon = nil,
            line_hl = nil,
            text = '┃',
        },
        VGitSignRemove = {
            name = 'VGitSignRemove',
            text_hl = 'VGitSignRemove',
            num_hl = nil,
            icon = nil,
            line_hl = nil,
            text = '┃',
        },
        VGitSignChange = {
            name = 'VGitSignChange',
            text_hl = 'VGitSignChange',
            num_hl = nil,
            icon = nil,
            line_hl = nil,
            text = '┃',
        },
    },
    render = {
        layout = vgit.layouts.default,
        sign = {
            priority = 10,
            hls = {
                add = 'VGitSignAdd',
                remove = 'VGitSignRemove',
                change = 'VGitSignChange',
            },
        },
        line_blame = {
            hl = 'Comment',
            format = function(blame, git_config)
                local config_author = git_config['user.name']
                local author = blame.author
                if config_author == author then
                    author = 'You'
                end
                local time = os.difftime(os.time(), blame.author_time) / (24 * 60 * 60)
                local time_format = string.format('%s days ago', utils.round(time))
                local time_divisions = { { 24, 'hours' }, { 60, 'minutes' }, { 60, 'seconds' } }
                local division_counter = 1
                while time < 1 and division_counter ~= #time_divisions do
                    local division = time_divisions[division_counter]
                    time = time * division[1]
                    time_format = string.format('%s %s ago', utils.round(time), division[2])
                    division_counter = division_counter + 1
                end
                local commit_message = blame.commit_message
                if not blame.committed then
                    author = 'You'
                    commit_message = 'Uncommitted changes'
                    local info = string.format('%s • %s', author, commit_message)
                    return string.format(' %s', info)
                end
                local max_commit_message_length = 255
                if #commit_message > max_commit_message_length then
                    commit_message = commit_message:sub(1, max_commit_message_length) .. '...'
                end
                local info = string.format('%s, %s • %s', author, time_format, commit_message)
                return string.format(' %s', info)
            end,
        },
    },
})
```


