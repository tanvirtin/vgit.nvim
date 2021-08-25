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

## Features
<details>
    <summary>Hunk as signs</summary>
    <br />
    <img src="https://user-images.githubusercontent.com/25164326/119602593-771e3580-bdb9-11eb-95f6-3758394bc297.gif" alt="hunk_signs" />
</details>
<details>
    <summary>Reset a hunk</summary>
    <br />
    <img src="https://user-images.githubusercontent.com/25164326/119602598-79808f80-bdb9-11eb-974c-aaa2a4445313.gif" alt="reset_hunk" />
</details>
<details>
    <summary>Stage a hunk</summary>
    <br />
    <img src="https://user-images.githubusercontent.com/25164326/127396247-a3e16213-5865-455e-9f72-72da1315abd6.gif" alt="hunk_stage" />
</details>
<details>
    <summary>Navigate through hunks</summary>
    <br />
    <img src="https://user-images.githubusercontent.com/25164326/119602585-75547200-bdb9-11eb-868c-0e43c41c378f.gif" alt="hunk_navigation" />
</details>
<details>
    <summary>Diff a buffer</summary>
    <br />
    <img src="https://user-images.githubusercontent.com/25164326/119602595-77b6cc00-bdb9-11eb-94c8-f62478ff8a16.gif" alt="diff_preview" />
</details>
<details>
    <summary>See what changes you staged</summary>
    <br />
    <img src="https://user-images.githubusercontent.com/25164326/127720416-e4130098-f8fc-4d8f-ab88-8adf701f384d.gif" alt="staged_preview" />
</details>
<details>
    <summary>Reset a buffer</summary>
    <br />
    <img src="https://user-images.githubusercontent.com/25164326/119602597-79808f80-bdb9-11eb-94ed-8bd557164f84.gif" alt="buffer_reset" />
</details>
<details>
    <summary>Blame a line</summary>
    <br />
    <img src="https://user-images.githubusercontent.com/25164326/119602582-74bbdb80-bdb9-11eb-8f70-1ab43e9213df.gif" alt="blame_a_line" />
</details>
<details>
    <summary>Show Blame</summary>
    <br />
    <img width="1792" alt="show_blame" src="https://user-images.githubusercontent.com/25164326/122292020-83cb1080-cec3-11eb-9a46-b07dddb4bd65.png">
</details>
<details>
    <summary>Quickfix your hunks</summary>
    <br />
    <img src="https://user-images.githubusercontent.com/25164326/119602589-75ed0880-bdb9-11eb-98fa-9e5a615dae31.gif" alt="hunks_quickfix_list" />
</details>
<details>
    <summary>Git History</summary>
    <br />
    <img src="https://user-images.githubusercontent.com/25164326/119602600-7a192600-bdb9-11eb-9ef9-709ea154aeaa.gif" alt="history" />
</details>
<details>
    <summary>Switch between different ways to see your diffs</summary>
    <br />
    <img src="https://user-images.githubusercontent.com/25164326/121595739-95687000-ca0c-11eb-8f1d-9b5b398e3b0d.gif" alt="diff_preference" />
</details>
<details>
    <summary>Get a deeper dive into all the blames for a buffer</summary>
    <br />
    <img src="https://user-images.githubusercontent.com/25164326/129825907-3bd8479b-fc68-4b8c-9cfd-8a89755c5540.PNG" />
</details>

## Supported Neovim versions:
- Neovim > 0.5

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
| stage_buffer | Stages a buffer you are currently on |
| unstage_buffer | Unstages a buffer you are currently on |
| staged_buffer_preview | Shows staged changes in a preview window |
| buffer_preview | Shows the current differences in lines in the current buffer |
| buffer_hunk_lens | Gives you a lens view through which you can navigate and see the current hunk or other hunks, this is similar to buffer preview, also an alternate for hunk_preview |
| buffer_history | Opens a buffer preview along with a table of logs, enabling users to see different iterations of the buffer in the git history |
| buffer_reset | Resets the current buffer to HEAD |
| hunk_preview | Please see "buffer_hunk_lens" |
| hunk_reset | Removes the hunk from the buffer, if cursor is on a hunk |
| hunk_stage | Stages a hunk, if cursor is on a hunk |
| hunk_down | Navigate downward through a hunk, this works on any view with diff highlights |
| hunk_up | Navigate upwards through a hunk, this works on any view with diff highlights |
| hunks_quickfix_list | Opens a populated quickfix window with all the hunks of the project |
| show_blame | Opens a view detailing the blame of the line that the user is currently on |
| diff | Please see "hunks_quickfix_list" |
| instantiated | Returns true if setup has been called, false otherwise |
| enabled | Returns true, if plugin is enabled, false otherwise |
| get_diff_base | Returns the current diff base that all diff and hunks are being compared for all buffers |
| set_diff_base | Sets the current diff base to a different commit, going forward all future hunks and diffs for a given buffer will be against this commit |
| get_diff_preference | Returns the current diff preference of the diff, the value will either be "horizontal" or "vertical" |
| set_diff_preference | Sets the diff preference to your given output, the value can only be "horizontal" or "vertical" |
| get_diff_strategy | Returns the current diff strategy used to compute hunk signs and buffer preview, the value will either be "remote" or "index" |
| set_diff_strategy | Sets the diff strategy that will be used to show hunk signs and buffer preview, the value can only be "remote" or "index" |
| show_debug_logs | Shows all errors that has occured during program execution |

<br/>

**NOTE**: *This project is still in development. API and functionality is unstable and subject to change in the future. For a more stable experiece please checkout other great community plugins such as [Gitsigns](https://github.com/lewis6991/gitsigns.nvim) and [Neogit](https://github.com/TimUntersberger/neogit)* 
