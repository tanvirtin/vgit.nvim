# vgit.nvim

[![CI](https://github.com/tanvirtin/vgit.nvim/workflows/CI/badge.svg?branch=develop)](https://github.com/tanvirtin/vgit.nvim/actions?query=workflow%3ACI)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Visual Git Plugin for Neovim to enhance your git experience.

### Features
- [x] Hunk signs

 ![hunk_signs](https://user-images.githubusercontent.com/25164326/117505704-7df02000-af52-11eb-996b-91063b5dd832.gif)

- [x] Reset a hunk

![hunk_reset](https://user-images.githubusercontent.com/25164326/117384279-9dcf0780-aeb0-11eb-96d8-0b85239d94f7.gif)

- [x] Hunk preview

![hunk_preview](https://user-images.githubusercontent.com/25164326/117380403-9a834e00-aea7-11eb-9117-f90cb4ab2ff1.gif)

- [x] Hunk navigation in current buffer

![hunk_navigation](https://user-images.githubusercontent.com/25164326/117380412-9f480200-aea7-11eb-8630-c70781e7e2ce.gif)

- [x] Show original file and current file in a split window with diffs highlighted

![diff_preview](https://user-images.githubusercontent.com/25164326/117380396-95be9a00-aea7-11eb-8fad-f9b6c6b87a5f.gif)

- [x] Reset changes in a buffer

![buffer_reset](https://user-images.githubusercontent.com/25164326/117384280-9e679e00-aeb0-11eb-850a-551925c81d3e.gif)

- [x] Blame a line

![blames](https://user-images.githubusercontent.com/25164326/117505703-7d578980-af52-11eb-82c8-22ea0c4bbd2a.gif)

- [x] Quickfix your hunks

![hunks_quickfix_list](https://user-images.githubusercontent.com/25164326/118189592-fc940400-b40f-11eb-9741-75bb81d5ed64.gif)

- [x] Check how your file looked in previous versions

![history](https://user-images.githubusercontent.com/25164326/118910341-4be7a200-b8f2-11eb-9dae-1888486c2d4d.gif)

## Prerequisites
- [Git](https://git-scm.com/)
- [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter)
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)

## Recommended
- Have neovim be open inside the current git working directory.
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

You also use in the built-in package manager:
```bash
$ git clone --depth 1 https://github.com/tanvirtin/vgit.nvim $XDG_CONFIG_HOME/nvim/pack/plugins/start/vgit.nvim
```

### Configure your own settings
By default these are the default settings provided by the app, you can change them to your liking.
```
:lua require('vgit').setup({
    hunks_enabled = true,
    blames_enabled = true,
    hl_groups = {
        VGitBlame = {
            bg = nil,
            fg = '#b1b1b1',
        },
        VGitDiffWindow = {
            bg = nil,
            fg = '#ffffff',
        },
        VGitDiffBorder = {
            bg = nil,
            fg = '#464b59',
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
        VGitHunkWindow = {
            bg = nil,
            fg = '#ffffff',
        },
        VGitHunkBorder = {
            bg = nil,
            fg = '#464b59',
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
        VGitLogsWindow = {
            bg = nil,
            fg = '#ffffff',
        },
        VGitLogsBorder = {
            bg = nil,
            fg = '#464b59',
        },
        VGitLogsIndicator = {
            fg = '#a6e22e',
            bg = nil,
        }
    },
    blame = {
        hl_group = 'VGitBlame',
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
        window = {
            hl_group = 'VGitDiffWindow',
            border = {
                { '╭', 'VGitDiffBorder' },
                { '─', 'VGitDiffBorder' },
                { '╮', 'VGitDiffBorder' },
                { '│', 'VGitDiffBorder' },
                { '╯', 'VGitDiffBorder' },
                { '─', 'VGitDiffBorder' },
                { '╰', 'VGitDiffBorder' },
                { '│', 'VGitDiffBorder' },
            }
        },
        types = {
            add = {
                name = 'VGitDiffAddSign',
                sign_hl_group = 'VGitDiffAddSign',
                text_hl_group = 'VGitDiffAddText',
                text = '+'
            },
            remove = {
                name = 'VGitDiffRemoveSign',
                sign_hl_group = 'VGitDiffRemoveSign',
                text_hl_group = 'VGitDiffRemoveText',
                text = '-'
            },
        },
    },
    hunk = {
        types = {
            add = {
                name = 'VGitHunkAddSign',
                sign_hl_group = 'VGitHunkAddSign',
                text_hl_group = 'VGitHunkAddText',
                text = '+'
            },
            remove = {
                name = 'VGitHunkRemoveSign',
                sign_hl_group = 'VGitHunkRemoveSign',
                text_hl_group = 'VGitHunkRemoveText',
                text = '-'
            },
        },
        window = {
            hl_group = 'VGitHunkWindow',
            border = {
                { '', 'VGitHunkBorder' },
                { '─', 'VGitHunkBorder' },
                { '', 'VGitHunkBorder' },
                { '', 'VGitHunkBorder' },
                { '', 'VGitHunkBorder' },
                { '─', 'VGitHunkBorder' },
                { '', 'VGitHunkBorder' },
                { '', 'VGitHunkBorder' },
            }
        },
    },
    hunk_sign = {
        priority = 10,
        types = {
            add = {
                name = 'VGitSignAdd',
                hl_group = 'VGitSignAdd',
                text = '│'
            },
            remove = {
                name = 'VGitSignRemove',
                hl_group = 'VGitSignRemove',
                text = '│'
            },
            change = {
                name = 'VGitSignChange',
                hl_group = 'VGitSignChange',
                text = '│'
            },
        },
    }
})
```

### Configure Mappings
```
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
vim.api.nvim_set_keymap('n', '<leader>gd', ':VGit buffer_preview<CR>', {
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
vim.api.nvim_set_keymap('n', '<leader>gq', ':VGit hunks_quickfix_list<CR>', {
    noremap = true,
    silent = true,
})
```

### API
| Function Name | Description |
|---------------|-------------|
| setup | Sets up the plugin to run necessary git commands on loaded buffers |
| toggle_buffer_hunks | Shows hunk signs on current buffer, if hunks are shown then hides them |
| toggle_buffer_blames | Enables blames feature on current buffer, if blames are enabled then disables it instead |
| hunk_preview | If a file has a hunk of diff associated with it, invoking this function will reveal that hunk if it exists on the current cursor |
| hunk_reset | Resets the hunk the cursor is on right now to it's previous step
| hunk_down | Navigate downward through a github hunk |
| hunk_up | Navigate upwards through a github hunk |
| buffer_preview | Opens two windows, showing origin and cwd buffers and the diff between them |
| buffer_history | Opens two windows, showing origin and cwd buffers and the diff between them, with a list of history logs associated with the buffer |
| buffer_reset | Resets a current buffer you are on |
| hunks_quickfix_list | Opens a populated quickfix window with all the hunks of the project |
