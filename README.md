<div align="center">
    
  # VGit
  
  <table>
      <tr>
          <td>
              <strong>Visual Git Plugin for Neovim to enhance your git experience</strong>
          </tr>
      </td>
  </table>
  
  [![Lua](https://img.shields.io/badge/Lua-blue.svg?style=for-the-badge&logo=lua)](http://www.lua.org)
  [![Neovim](https://img.shields.io/badge/Neovim%200.5+-green.svg?style=for-the-badge&logo=neovim)](https://neovim.io)
  
  <a href="https://github.com/tanvirtin/vgit.nvim/actions?query=workflow%3ACI">
      <img src="https://github.com/tanvirtin/vgit.nvim/workflows/CI/badge.svg?branch=main" alt="CI" />
  </a>
  <a href="https://opensource.org/licenses/MIT">
      <img src="https://img.shields.io/badge/License-MIT-yellow.svg" alt="License" />
  </a>

  <br />
  <br />

  <p>🚧 This is a work-in-progress project and can be unstable at times. 🚧</p>

</div>

<br />

<div align="center">
  <img width="1512" alt="Hunk Preview" src="https://user-images.githubusercontent.com/25164326/149684229-6fc1422a-3db2-4e17-88f9-eb5897ca5ddc.png">
</div>

**Features**
---
- Gutter changes
- Current line blame
- Authorship code lens (Scroll up on top of the file or press CTRL-B to see)
- Current line blame preview
- Gutter blame preview
- File history preview
- File diff preview
- File staged diff preview
- File hunk preview
- Project diff preview
- Project hunks preview
- Send all project hunks to quickfix list
- Smooth hunk navigations in all buffers with a diff
- Actions on a current git file:
  - Stage file
  - Unstage file
  - Reset file
  - Stage a hunk
  - Reset a hunk
- Actions on project:
  - Stage all changes in a project
  - Unstage all changes in a project
  - Reset all changes in a project

**Requirements**
---
- Neovim `0.5+`
- Git `2.18.0+`
- Supported Operating Systems:
    - `linux-gnu*`
    - `Darwin`

**Prerequisites**
---
- [Git](https://git-scm.com/)
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
- [nvim-web-devicons](https://github.com/kyazdani42/nvim-web-devicons) (optional dependency used to show icons)

**Recommended Settings**
---
```lua
vim.o.updatetime = 300
vim.o.incsearch = false
vim.wo.signcolumn = 'yes'
```

**Installation**
---
Default installation via Packer.
```lua
use {
  'tanvirtin/vgit.nvim',
  requires = {
    'nvim-lua/plenary.nvim'
  }
}
```

**Setup**
---
You must instantiate the plugin in order for the features to work.
```lua
require('vgit').setup()
```

To embed the above code snippet in a .vim file wrap it in lua << EOF code-snippet EOF.
```lua
lua << EOF
require('vgit').setup()
EOF
```

Highlights, signs, keymappings are few examples of what can be configured in VGit. Advanced setup below shows you all configurable parameters in VGit.

<details><summary><b>Show advanced setup</b></summary>

<br />

```lua
require('vgit').setup({
  keymaps = {
    ['n <C-k>'] = 'hunk_up',
    ['n <C-j>'] = 'hunk_down',
    ['n <leader>gs'] = 'buffer_hunk_stage',
    ['n <leader>gr'] = 'buffer_hunk_reset',
    ['n <leader>gp'] = 'buffer_hunk_preview',
    ['n <leader>gb'] = 'buffer_blame_preview',
    ['n <leader>gf'] = 'buffer_diff_preview',
    ['n <leader>gh'] = 'buffer_history_preview',
    ['n <leader>gu'] = 'buffer_reset',
    ['n <leader>gg'] = 'buffer_gutter_blame_preview',
    ['n <leader>gl'] = 'project_hunks_preview',
    ['n <leader>gd'] = 'project_diff_preview',
    ['n <leader>gq'] = 'project_hunks_qf',
    ['n <leader>gx'] = 'toggle_diff_preference',
  },
  settings = {
    hls = {
      GitBackgroundPrimary = 'NormalFloat',
      GitBackgroundSecondary = {
        gui = nil,
        fg = nil,
        bg = nil,
        sp = nil,
        override = false,
      },
      GitBorder = 'LineNr',
      GitLineNr = 'LineNr',
      GitComment = 'Comment',
      GitSignsAdd = {
        gui = nil,
        fg = '#d7ffaf',
        bg = nil,
        sp = nil,
        override = false,
      },
      GitSignsChange = {
        gui = nil,
        fg = '#7AA6DA',
        bg = nil,
        sp = nil,
        override = false,
      },
      GitSignsDelete = {
        gui = nil,
        fg = '#e95678',
        bg = nil,
        sp = nil,
        override = false,
      },
      GitSignsAddLn = 'DiffAdd',
      GitSignsDeleteLn = 'DiffDelete',
      GitWordAdd = {
        gui = nil,
        fg = nil,
        bg = '#5d7a22',
        sp = nil,
        override = false,
      },
      GitWordDelete = {
        gui = nil,
        fg = nil,
        bg = '#960f3d',
        sp = nil,
        override = false,
      },
    },
    live_blame = {
      enabled = true,
      format = function(blame, git_config)
        local config_author = git_config['user.name']
        local author = blame.author
        if config_author == author then
          author = 'You'
        end
        local time = os.difftime(os.time(), blame.author_time)
          / (60 * 60 * 24 * 30 * 12)
        local time_divisions = {
          { 1, 'years' },
          { 12, 'months' },
          { 30, 'days' },
          { 24, 'hours' },
          { 60, 'minutes' },
          { 60, 'seconds' },
        }
        local counter = 1
        local time_division = time_divisions[counter]
        local time_boundary = time_division[1]
        local time_postfix = time_division[2]
        while time < 1 and counter ~= #time_divisions do
          time_division = time_divisions[counter]
          time_boundary = time_division[1]
          time_postfix = time_division[2]
          time = time * time_boundary
          counter = counter + 1
        end
        local commit_message = blame.commit_message
        if not blame.committed then
          author = 'You'
          commit_message = 'Uncommitted changes'
          return string.format(' %s • %s', author, commit_message)
        end
        local max_commit_message_length = 255
        if #commit_message > max_commit_message_length then
          commit_message = commit_message:sub(1, max_commit_message_length) .. '...'
        end
        return string.format(
          ' %s, %s • %s',
          author,
          string.format(
            '%s %s ago',
            time >= 0 and math.floor(time + 0.5) or math.ceil(time - 0.5),
            time_postfix
          ),
          commit_message
        )
      end,
    },
    live_gutter = {
      enabled = true,
    },
    authorship_code_lens = {
      enabled = true,
    },
    screen = {
      diff_preference = 'unified',
    },
    project_diff_preview = {
      keymaps = {
        buffer_stage = 's',
        buffer_unstage = 'u',
        stage_all = 'a',
        unstage_all = 'd',
        reset_all = 'r',
      },
    },
    signs = {
      priority = 10,
      definitions = {
        GitSignsAddLn = {
          linehl = 'GitSignsAddLn',
          texthl = nil,
          numhl = nil,
          icon = nil,
          text = '',
        },
        GitSignsDeleteLn = {
          linehl = 'GitSignsDeleteLn',
          texthl = nil,
          numhl = nil,
          icon = nil,
          text = '',
        },
        GitSignsAdd = {
          texthl = 'GitSignsAdd',
          numhl = nil,
          icon = nil,
          linehl = nil,
          text = '┃',
        },
        GitSignsDelete = {
          texthl = 'GitSignsDelete',
          numhl = nil,
          icon = nil,
          linehl = nil,
          text = '┃',
        },
        GitSignsChange = {
          texthl = 'GitSignsChange',
          numhl = nil,
          icon = nil,
          linehl = nil,
          text = '┃',
        },
      },
      usage = {
        screen = {
          add = 'GitSignsAddLn',
          remove = 'GitSignsDeleteLn',
        },
        main = {
          add = 'GitSignsAdd',
          remove = 'GitSignsDelete',
          change = 'GitSignsChange',
        },
      },
    },
    symbols = {
      void = '⣿',
    },
  }
})
```

</details>

**API**
---

<img width="342" alt="VGit Commands" src="https://user-images.githubusercontent.com/25164326/147710754-fcbe0cef-3e74-41cd-a6d6-4b9a6a9eb258.png">
<br />

| Function Name | Description |
|---------------|-------------|
| setup | Sets VGit up for you. This plugin cannot be used before this function has been called. |
| buffer_hunk_preview | Opens a diff preview showing the diff of the current buffer in comparison to that found in index. This preview will open up in a smaller window relative to where your cursor is. |
| buffer_diff_preview | Opens a diff preview showing the diff of the current buffer in comparison to that found in index. If the command is called while being on a hunk, the window will open focused on the diff of that hunk. |
| buffer_history_preview | Opens a diff preview along with a table of logs, enabling users to see different iterations of the file through it's lifecycle in git. |
| buffer_blame_preview | Opens a preview detailing the blame of the line that based on the cursor position within the buffer. |
| buffer_gutter_blame_preview | Opens a preview which shows all the blames related to the lines of the buffer. |
| buffer_diff_staged_preview | Opens a diff preview showing the diff of the staged changes in the current buffer. |
| buffer_hunk_staged_preview | Opens a diff preview showing the diff of the staged changes in the current buffer. This preview will open up in a smaller window relative to where your cursor is. |
| project_diff_preview | Opens a diff preview along with a table of all the files that have been changed, enabling users to see all the files that were changed in the current project. This preview supports the following commands, "buffer_stage", "buffer_unstage", "buffer_reset", "stage_all" and "unstage_all". |
| project_hunks_preview | Opens a diff preview along with a table of all the current hunks in the project. Users can use this preview to cycle through all the hunks. |
| project_hunks_qf | Populate the quickfix list with hunks. Automatically opens the quickfix window. |
| buffer_hunk_stage | Stages a hunk, if a cursor is on the hunk. |
| buffer_hunk_reset | Removes all changes made in the buffer on the hunk the cursor is currently on to what exists in HEAD. |
| buffer_stage | Stages all changes in the current buffer. |
| buffer_unstage | Unstages all changes in the current buffer. |
| buffer_reset | Removes all current changes in the buffer and resets it to the version in HEAD. |
| stage_all | Stages all file changes in your project. |
| unstage_all | Unstages all file changes in your project. |
| reset_all | Discards all file changes that are not staged. |
| hunk_up | Moves the cursor to the hunk above the current cursor position. |
| hunk_down | Moves the cursor to the hunk below the current cursor position. |
| toggle_diff_preference | Used to switch between "split" and "unified" diff. |
| toggle_live_gutter | Enables/disables git gutter signs. |
| toggle_live_blame | Used to switch between "split" and "unified" diff. |
| toggle_authorship_code_lens | Enables/disables authorship code lens that can be found on top of the file |
| enable_tracing | Enables debug logs that are used internally by VGit to make suppressed logs visible. |
| disable_tracing | Disables debug logs that are used internally by VGit to make suppressed logs visible. |
