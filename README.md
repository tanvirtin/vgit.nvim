# VGit
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
<a href="http://makeapullrequest.com">
    <img src="https://img.shields.io/badge/PRs-welcome-brightgreen.svg?style=shields" alt="CI" />
</a>

### Features
<details>
    <summary>Hunk as signs</summary>
    <br />
    <img src="https://user-images.githubusercontent.com/25164326/117505704-7df02000-af52-11eb-996b-91063b5dd832.gif" alt="hunk_signs" />
</details>
<details>
    <summary>Preview a hunk</summary>
    <br />
    <img src="https://user-images.githubusercontent.com/25164326/117380403-9a834e00-aea7-11eb-9117-f90cb4ab2ff1.gif" alt="hunk_preview" />
</details>
<details>
    <summary>Reset a hunk</summary>
    <br />
    <img src="https://user-images.githubusercontent.com/25164326/117384279-9dcf0780-aeb0-11eb-96d8-0b85239d94f7.gif" alt="reset_hunk" />
</details>
<details>
    <summary>Navigate through hunks</summary>
    <br />
    <img src="https://user-images.githubusercontent.com/25164326/117380412-9f480200-aea7-11eb-8630-c70781e7e2ce.gif" alt="hunk_navigation" />
</details>
<details>
    <summary>Diff a buffer with HEAD</summary>
    <br />
    <img src="https://user-images.githubusercontent.com/25164326/117380396-95be9a00-aea7-11eb-8fad-f9b6c6b87a5f.gif" alt="diff_preview" />
</details>
<details>
    <summary>Reset a buffer to HEAD</summary>
    <br />
    <img src="https://user-images.githubusercontent.com/25164326/117384280-9e679e00-aeb0-11eb-850a-551925c81d3e.gif" alt="buffer_reset" />
</details>
<details>
    <summary>Blame a line</summary>
    <br />
    <img src="https://user-images.githubusercontent.com/25164326/117505703-7d578980-af52-11eb-82c8-22ea0c4bbd2a.gif" alt="blame_a_line" />
</details>
<details>
    <summary>Quickfix your hunks (a.k.a git diff)</summary>
    <br />
    <img src="https://user-images.githubusercontent.com/25164326/118189592-fc940400-b40f-11eb-9741-75bb81d5ed64.gif" alt="hunks_quickfix_list" />
</details>
<details>
    <summary>Git History</summary>
    <br />
    <img src="https://user-images.githubusercontent.com/25164326/118910341-4be7a200-b8f2-11eb-9dae-1888486c2d4d.gif" alt="history" />
</details>

## Prerequisites
- [Git](https://git-scm.com/)
- [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter)
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)

## Recommended Settings
- `vim.o.updatetime = 100` (see :help updatetime).

## Installation
| Plugin Manager                                       | Command                                                                        |
|------------------------------------------------------|--------------------------------------------------------------------------------|
| [Packer](https://github.com/wbthomason/packer.nvim)  | `use { 'tanvirtin/vgit.nvim', requires = 'nvim-lua/plenary.nvim' }`            |
| [Vim-plug](https://github.com/junegunn/vim-plug)     | `Plug 'tanvirtin/vgit.nvim'`                                                   |
| [NeoBundle](https://github.com/Shougo/neobundle.vim) | `NeoBundle 'tanvirtin/vgit.nvim'`                                              |
| [Vundle](https://github.com/VundleVim/Vundle.vim)    | `Bundle 'tanvirtin/vgit.nvim'`                                                 |
| [Pathogen](https://github.com/tpope/vim-pathogen)    | `git clone https://github.com/tanvirtin/vgit.nvim.git ~/.vim/bundle/vgit.nvim` |
| [Dein](https://github.com/Shougo/dein.vim)           | `call dein#add('tanvirtin/vgit.nvim')`                                         |

### Setup
You must instantiate the plugin in order for the features to work.
```lua
require('vgit').setup()
```

### Configure your own settings
By default these are the default settings provided by the app, you can change them to your liking.
```lua
require('vgit').setup({
    hunks_enabled = true,
    blames_enabled = true,
    hls = {
        VGitBlame = {
            bg = nil,
            fg = '#b1b1b1',
        },
        VGitDiffAddSign = {
            bg = '#3d5213',
            fg = nil,
        },
        VGitDiffRemoveSign = {
            bg = '#4a0f23',
            fg = nil,
        },
        VGitDiffAddText = {
            fg = '#6a8f1f',
            bg = '#3d5213',
        },
        VGitDiffRemoveText = {
            fg = '#a3214c',
            bg = '#4a0f23',
        },
        VGitHunkAddSign = {
            bg = '#3d5213',
            fg = nil,
        },
        VGitHunkRemoveSign = {
            bg = '#4a0f23',
            fg = nil,
        },
        VGitHunkAddText = {
            fg = '#6a8f1f',
            bg = '#3d5213',
        },
        VGitHunkRemoveText = {
            fg = '#a3214c',
            bg = '#4a0f23',
        },
        VGitHunkSignAdd = {
            fg = '#d7ffaf',
            bg = '#4a6317',
        },
        VGitHunkSignRemove = {
            fg = '#e95678',
            bg = '#63132f',
        },
        VGitSignAdd = {
            fg = '#d7ffaf',
            bg = nil,
        },
        VGitSignChange = {
            fg = '#7AA6DA',
            bg = nil,
        },
        VGitSignRemove = {
            fg = '#e95678',
            bg = nil,
        },
        VGitLogsIndicator = {
            fg = '#a6e22e',
            bg = nil,
        },
        VGitDiffCurrentBorder = {
            fg = '#a1b5b1',
            bg = nil,
        },
        VGitDiffPreviousBorder = {
            fg = '#a1b5b1',
            bg = nil,
        },
        VGitLogsBorder = {
            fg = '#a1b5b1',
            bg = nil,
        },
        VGitHunkBorder = {
            fg = '#a1b5b1',
            bg = nil,
        },
    },
    blame = {
        hl = 'VGitBlame',
        format = function(blame, git_config)
            local round = function(x)
                return x >= 0 and math.floor(x + 0.5) or math.ceil(x - 0.5)
            end
            local config_author = git_config['user.name']
            local author = blame.author
            if config_author == author then
                author = 'You'
            end
            local time = os.difftime(os.time(), blame.author_time) / (24 * 60 * 60)
            local time_format = string.format('%s days ago', round(time))
            local time_divisions = { { 24, 'hours' }, { 60, 'minutes' }, { 60, 'seconds' } }
            local division_counter = 1
            while time < 1 and division_counter ~= #time_divisions do
                local division = time_divisions[division_counter]
                time = time * division[1]
               time_format = string.format('%s %s ago', round(time), division[2])
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
        end
    },
    diff = {
        priority = 10,
        cwd_window = {
            title = 'Current',
            border = { '╭', '─', '╮', '│', '╯', '─', '╰', '│' },
            border_hl = 'VGitDiffCurrentBorder',
        },
        origin_window = {
            title = 'Previous',
            border = { '╭', '─', '╮', '│', '╯', '─', '╰', '│' },
            border_hl = 'VGitDiffPreviousBorder',
        },
        signs = {
            add = {
                name = 'VGitDiffAddSign',
                sign_hl = 'VGitDiffAddSign',
                text_hl = 'VGitDiffAddText',
                text = '+'
            },
            remove = {
                name = 'VGitDiffRemoveSign',
                sign_hl = 'VGitDiffRemoveSign',
                text_hl = 'VGitDiffRemoveText',
                text = '-'
            },
        },
    },
    logs = {
        indicator = {
            hl = 'VGitLogsIndicator'
        },
        window = {
            title = 'Git History',
            border = { '╭', '─', '╮', '│', '╯', '─', '╰', '│' },
            border_hl = 'VGitLogsBorder',
        },
    },
    hunk = {
        priority = 10,
        window = {
            border = { '╭', '─', '╮', '│', '╯', '─', '╰', '│' },
            border_hl = 'VGitHunkBorder',
        },
        signs = {
            add = {
                name = 'VGitHunkAddSign',
                sign_hl = 'VGitHunkAddSign',
                text_hl = 'VGitHunkAddText',
                text = '+'
            },
            remove = {
                name = 'VGitHunkRemoveSign',
                sign_hl = 'VGitHunkRemoveSign',
                text_hl = 'VGitHunkRemoveText',
                text = '-'
            },
        },
    },
    hunk_sign = {
        priority = 10,
        signs = {
            add = {
                name = 'VGitSignAdd',
                hl = 'VGitSignAdd',
                text = '│'
            },
            remove = {
                name = 'VGitSignRemove',
                hl = 'VGitSignRemove',
                text = '│'
            },
            change = {
                name = 'VGitSignChange',
                hl = 'VGitSignChange',
                text = '│'
            },
        },
    }
})
```

### Recommended Mappings
You can always call these commands yourself, but I find these mappings to be very helpful.
```lua
vim.api.nvim_set_keymap('n', '<leader>gp', ':VGit hunk_preview<CR>', {
    noremap = true,
    silent = true,
})
vim.api.nvim_set_keymap('n', '<leader>gr', ':VGit hunk_reset<CR>', {
    noremap = true,
    silent = true,
})
vim.api.nvim_set_keymap('n', '<C-k>', ':VGit hunk_up<CR>', {
    noremap = true,
    silent = true,
})
vim.api.nvim_set_keymap('n', '<C-j>', ':VGit hunk_down<CR>', {
    noremap = true,
    silent = true,
})
vim.api.nvim_set_keymap('n', '<leader>gf', ':VGit buffer_preview<CR>', {
    noremap = true,
    silent = true,
})
vim.api.nvim_set_keymap('n', '<leader>gh', ':VGit buffer_history<CR>', {
    noremap = true,
    silent = true,
})
vim.api.nvim_set_keymap('n', '<leader>gu', ':VGit buffer_reset<CR>', {
    noremap = true,
    silent = true,
})
vim.api.nvim_set_keymap('n', '<leader>gd', ':VGit diff<CR>', {
    noremap = true,
    silent = true,
})
vim.api.nvim_set_keymap('n', '<leader>gq', ':VGit hunks_quickfix_list<CR>', {
    noremap = true,
    silent = true,
})
```

### API
| Function Name | Description |
|---------------|-------------|
| setup | Sets up the plugin for success |
| toggle_buffer_hunks | Shows hunk signs on buffers/Hides hunk signs on buffers |
| toggle_buffer_blames | Enables blames feature on buffers /Disables blames feature on buffers |
| hunk_preview | Opens a VGit view of a hunk, if cursor is on a line with a git change |
| hunk_reset | Removes the hunk from the buffer |
| hunk_down | Navigate downward through a hunk |
| hunk_up | Navigate upwards through a hunk |
| buffer_preview | Opens two VGit views, one showing the previous version of the buffer and the second showing the new changes in the buffer |
| buffer_history | Opens a buffer preview along with a table of logs, enabling users to see different iterations of the buffer in the git history |
| buffer_reset | Resets the current buffer to HEAD |
| hunks_quickfix_list | Opens a populated quickfix window with all the hunks of the project |
| diff | Opens a populated quickfix window showing all the files that have a change in it |

### Similar Git Plugins
- [vim-fugitive](https://github.com/tpope/vim-fugitive) :crown:
- [vim-gitgutter](https://github.com/airblade/vim-gitgutter)
- [gitsigns.nvim](https://github.com/lewis6991/gitsigns.nvim)
- [neogit](https://github.com/TimUntersberger/neogit)
