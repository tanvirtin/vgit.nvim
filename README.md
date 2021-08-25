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

## Supported Neovim versions:
- Neovim >= 0.5

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
| Plugin Manager                                       | Command                                                                        |
|------------------------------------------------------|--------------------------------------------------------------------------------|
| [Packer](https://github.com/wbthomason/packer.nvim)  | `use { 'tanvirtin/vgit.nvim', requires = 'nvim-lua/plenary.nvim' }`            |
| [Vim-plug](https://github.com/junegunn/vim-plug)     | `Plug 'tanvirtin/vgit.nvim'`                                                   |
| [NeoBundle](https://github.com/Shougo/neobundle.vim) | `NeoBundle 'tanvirtin/vgit.nvim'`                                              |
| [Vundle](https://github.com/VundleVim/Vundle.vim)    | `Bundle 'tanvirtin/vgit.nvim'`                                                 |
| [Pathogen](https://github.com/tpope/vim-pathogen)    | `git clone https://github.com/tanvirtin/vgit.nvim.git ~/.vim/bundle/vgit.nvim` |
| [Dein](https://github.com/Shougo/dein.vim)           | `call dein#add('tanvirtin/vgit.nvim')`                                         |

## Setup
You must instantiate the plugin in order for the features to work.
```lua
require('vgit').setup()
```

To embed the above code snippet in a .vim file wrap it in lua << EOF code-snippet EOF:
```lua
lua << EOF
require('vgit').setup({
  -- ...
})
EOF
```

## API
| Function Name | Description |
|---------------|-------------|
| setup | Sets up the plugin for success |
| toggle_buffer_hunks | Shows hunk signs on buffers/Hides hunk signs on buffers |
| toggle_buffer_blames | Enables blames feature on buffers /Disables blames feature on buffers |
| buffer_stage | Stages a buffer you are currently on |
| buffer_unstage | Unstages a buffer you are currently on |
| buffer_diff_preview | Shows the current differences in lines in the current buffer |
| buffer_staged_diff_preview | Shows staged changes in a preview window |
| buffer_hunk_preview | Gives you a view view through which you can navigate and see the current hunk or other hunks, this is similar to buffer preview, also an alternate for hunk_preview |
| buffer_history_preview | Opens a buffer preview along with a table of logs, enabling users to see different iterations of the buffer in the git history |
| buffer_blame_preview | Opens a view detailing the blame of the line that the user is currently on |
| buffer_blames_preview | Resets the current buffer to HEAD |
| buffer_reset | Resets the current buffer to HEAD |
| buffer_hunk_stage | Stages a hunk, if cursor is on a hunk |
| buffer_hunk_reset | Removes the hunk from the buffer, if cursor is on a hunk |
| buffer_hunks_qf | TBD |
| project_hunks_qf | Opens a populated quickfix window with all the hunks of the project |
| project_diff_view | TBD |
| hunk_down | Navigate downward through a hunk, this works on any view with diff highlights |
| hunk_up | Navigate upwards through a hunk, this works on any view with diff highlights |
| get_diff_base | Returns the current diff base that all diff and hunks are being compared for all buffers |
| get_diff_preference | Returns the current diff preference of the diff, the value will either be "horizontal" or "vertical" |
| get_diff_strategy | Returns the current diff strategy used to compute hunk signs and buffer preview, the value will either be "remote" or "index" |
| set_diff_base | Sets the current diff base to a different commit, going forward all future hunks and diffs for a given buffer will be against this commit |
| set_diff_preference | Sets the diff preference to your given output, the value can only be "horizontal" or "vertical" |
| set_diff_strategy | Sets the diff strategy that will be used to show hunk signs and buffer preview, the value can only be "remote" or "index" |
| show_debug_logs | Shows all errors that has occured during program execution |
