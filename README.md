<div align="center">
  <h1>VGit</h1>
  
  <table>
      <tr>
          <td>
              <strong>Visual Git Plugin for Neovim to enhance your git experience</strong>
          </tr>
      </td>
  </table>
  
  [![Lua](https://img.shields.io/badge/Lua-blue.svg?style=for-the-badge&logo=lua)](http://www.lua.org)
  [![Neovim](https://img.shields.io/badge/Neovim%200.8+-green.svg?style=for-the-badge&logo=neovim)](https://neovim.io)
  
  <a href="https://github.com/tanvirtin/vgit.nvim/actions?query=workflow%3ACI">
      <img src="https://github.com/tanvirtin/vgit.nvim/workflows/CI/badge.svg?branch=main" alt="CI" />
  </a>
  <a href="https://opensource.org/licenses/MIT">
      <img src="https://img.shields.io/badge/License-MIT-yellow.svg" alt="License" />
  </a>
</div>

<br />

<p align="center">
  VGit's feature views are designed to be lightning-fast. Whether you're diving into a file's history, comparing changes, or managing stashes.
</p>

### Project Diff Preview
---

Explore all changes in your project at a glance. The diff preview displays modified files and highlights the changes for better project-wide management.

![Project Diff Preview](https://github.com/user-attachments/assets/68d7e6bf-06da-4279-95b7-5baea5303c1f)

### Project Logs Preview
---

View and filter the logs of your current branch in an intuitive interface. Select logs and open detailed commit previews effortlessly.

![Project Logs Preview](https://github.com/user-attachments/assets/187ec555-47c4-4c43-b52f-aa5cd9f7b04c)

### Project Stash Preview
---

Easily manage and preview all your stashed changes in one place. Keep your work organized and accessible.

![Project Stash Preview](https://github.com/user-attachments/assets/b67b8594-c137-4497-915c-0c64595d8167)

### Buffer Diff Preview
---

Visually compare your current buffer with its version in the Git index. If focused on a hunk, this preview zooms into the relevant changes for a streamlined review experience.

![Buffer Diff Preview](https://github.com/user-attachments/assets/103122f1-4748-417c-9318-f1934da0186c)

### Buffer Blame Preview
---

Gain instant insight into the author and commit history of any line in your buffer. This feature enables seamless tracing of code changes.

![Buffer Blame Preview](https://github.com/user-attachments/assets/990110ac-4ca8-416e-a600-49f903bd93af)

### Buffer History Preview
---

Dive into the history of your file with a detailed view of all its Git iterations. See how the file has evolved through various commits.

![Buffer History Preview](https://github.com/user-attachments/assets/0c4ddc13-2245-4a49-aa5f-6150f8a2fad1)

### Conflict Management

VGit simplifies conflict resolution by clearly highlighting different segments of a conflict and giving you the flexibility to choose the necessary changes,
making it easy to merge and resolve conflicts efficiently.

![Conflict Management](https://github.com/user-attachments/assets/8b4e2eb6-e0b6-4702-8aad-9c46fd345a71)

### Live Blame
---

Enable live blame annotations directly in your editor to see the author and commit for each line in real time. Perfect for understanding the evolution of code at a glance.

![Live blame](https://github.com/user-attachments/assets/2dc4c57d-c9d1-40d4-9f20-54a5f5cf1743)

**Requirements**
---
- Neovim `0.10+`
- Git `2.18.0+`
- Supported Operating Systems:
    - `linux-gnu*`
    - `Darwin`

**Installation**
---

> [!NOTE]
> Package managers with lazy loading is necessary for installation.

Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  'tanvirtin/vgit.nvim',
  requires = { 'nvim-lua/plenary.nvim', 'nvim-tree/nvim-web-devicons' },
  -- Lazy loading on 'VimEnter' event is necessary.
  event = 'VimEnter',
  config = function() require("vgit").setup() end,
}
```

Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  'tanvirtin/vgit.nvim',
  dependencies = { 'nvim-lua/plenary.nvim', 'nvim-tree/nvim-web-devicons' },
  -- Lazy loading on 'VimEnter' event is necessary.
  event = 'VimEnter',
  config = function() require("vgit").setup() end,
}
```

**Setup**
---
You must instantiate the plugin in order for the features to work.
```lua
require('vgit').setup()
```

> [!NOTE]
> Highlights, signs, keymappings are few examples of what can be configured in VGit.
> Advanced setting should only be used if you intend to change functionality 
> provided by default. 

---

<details><summary><b>Show advanced setup</b></summary>

```lua
require('vgit').setup({
  keymaps = {
    ['n <C-k>'] = function() require('vgit').hunk_up() end,
    {
      mode = 'n',
      key = '<C-j>',
      handler = 'hunk_down',
      desc = 'Go down in the direction of the hunk',
    }
    ['n <leader>gs'] = function() require('vgit').buffer_hunk_stage() end,
    ['n <leader>gr'] = function() require('vgit').buffer_hunk_reset() end,
    ['n <leader>gp'] = function() require('vgit').buffer_hunk_preview() end,
    ['n <leader>gb'] = 'buffer_blame_preview',
    ['n <leader>gf'] = function() require('vgit').buffer_diff_preview() end,
    ['n <leader>gh'] = function() require('vgit').buffer_history_preview() end,
    ['n <leader>gu'] = function() require('vgit').buffer_reset() end,
    ['n <leader>gd'] = function() require('vgit').project_diff_preview() end,
    ['n <leader>gx'] = function() require('vgit').toggle_diff_preference() end,
  },
  settings = {
    libgit2 = {
      enabled = false,
      path = '<path-to>/libgit2/lib/libgit2.dylib',
    },
    -- You can either allow corresponding mapping for existing hl, or re-define them yourself entirely.
    hls = {
      GitCount = 'Keyword',
      GitSymbol = 'CursorLineNr',
      GitTitle = 'Directory',
      GitSelected = 'QuickfixLine',
      GitBackground = 'Normal',
      GitAppBar = 'StatusLine',
      GitHeader = 'NormalFloat',
      GitFooter = 'NormalFloat',
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
      GitConflictCurrentMark = 'DiffAdd',
      GitConflictAncestorMark = 'Visual',
      GitConflictIncomingMark = 'DiffChange',
      GitConflictCurrent = 'DiffAdd',
      GitConflictAncestor = 'Visual',
      GitConflictMiddle = 'Visual',
      GitConflictIncoming = 'DiffChange',
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
      edge_navigation = true, -- This allows users to navigate within a hunk
    },
    scene = {
      diff_preference = 'unified', -- unified or split
      keymaps = {
        quit = 'q'
      }
    },
    diff_preview = {
      keymaps = {
        reset = 'r',
        buffer_stage = 'S',
        buffer_unstage = 'U',
        buffer_hunk_stage = 's',
        buffer_hunk_unstage = 'u',
        toggle_view = 't',
      },
    },
    project_diff_preview = {
      keymaps = {
        commit = 'C',
        buffer_stage = 's',
        buffer_unstage = 'u',
        buffer_hunk_stage = 'gs',
        buffer_hunk_unstage = 'gu',
        buffer_reset = 'r',
        stage_all = 'S',
        unstage_all = 'U',
        reset_all = 'R',
      },
    },
    project_stash_preview = {
      keymaps = {
        add = 'A',
        apply = 'a',
        pop = 'p',
        drop = 'd',
        clear = 'C'
      },
    },
    project_logs_preview = {
      keymaps = {
        previous = '-',
        next = '=',
      },
    },
    project_commit_preview = {
      keymaps = {
        save = 'S',
      },
    },
    signs = {
      priority = 10,
      definitions = {
        -- The sign definitions you provide will automatically be instantiated for you.
        GitConflictCurrentMark = {
          linehl = 'GitConflictCurrentMark',
          texthl = nil,
          numhl = nil,
          icon = nil,
          text = '',
        },
        GitConflictAncestorMark = {
          linehl = 'GitConflictAncestorMark',
          texthl = nil,
          numhl = nil,
          icon = nil,
          text = '',
        },
        GitConflictIncomingMark = {
          linehl = 'GitConflictIncomingMark',
          texthl = nil,
          numhl = nil,
          icon = nil,
          text = '',
        },
        GitConflictCurrent = {
          linehl = 'GitConflictCurrent',
          texthl = nil,
          numhl = nil,
          icon = nil,
          text = '',
        },
        GitConflictAncestor = {
          linehl = 'GitConflictAncestor',
          texthl = nil,
          numhl = nil,
          icon = nil,
          text = '',
        },
        GitConflictMiddle = {
          linehl = 'GitConflictMiddle',
          texthl = nil,
          numhl = nil,
          icon = nil,
          text = '',
        },
        GitConflictIncoming = {
          linehl = 'GitConflictIncoming',
          texthl = nil,
          numhl = nil,
          icon = nil,
          text = '',
        },
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
        -- Please ensure these signs are defined.
        screen = {
          add = 'GitSignsAddLn',
          remove = 'GitSignsDeleteLn',
          conflict_current_mark = 'GitConflictCurrentMark',
          conflict_current = 'GitConflictCurrent',
          conflict_middle = 'GitConflictMiddle',
          conflict_incoming_mark = 'GitConflictIncomingMark',
          conflict_incoming = 'GitConflictIncoming',
          conflict_ancestor_mark = 'GitConflictAncestorMark',
          conflict_ancestor = 'GitConflictAncestor'
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
      open = '',
      close = '',
    },
  }
})
```

</details>


## Status Line

Use `b:vgit_status`, a table containing the current buffer's number of `added`, `removed`, `changed` lines.

Example:
```viml
set statusline+=%{get(b:,'vgit_status','')}
```

**API**
---

<img width="350" alt="VGit Commands" src="https://github.com/user-attachments/assets/f9718464-079b-42ea-a04f-084d8de1df18" />
<br />

| Function Name | Description |
|---------------|-------------|
| `help` | Vim documentation |
| `setup` | Sets VGit up for you. This plugin cannot be used before this function has been called. |
| `hunk_up` | Moves the cursor to the hunk above the current cursor position. |
| `hunk_down` | Moves the cursor to the hunk below the current cursor position. |
| `buffer_hunk_preview` | Opens a diff preview showing the diff of the current buffer in comparison to that found in index. This preview will open up in a smaller window relative to where your cursor is. |
| `buffer_diff_preview` | Opens a diff preview showing the diff of the current buffer in comparison to that found in index. If the command is called while being on a hunk, the window will open focused on the diff of that hunk. |
| `buffer_history_preview` | Opens a diff preview along with a table of logs, enabling users to see different iterations of the file through it's lifecycle in git. |
| `buffer_blame_preview` | Opens a preview detailing the blame of the line that based on the cursor position within the buffer. |
| `buffer_hunk_stage` | Stages a hunk, if a cursor is on the hunk. |
| `buffer_hunk_reset` | Removes all changes made in the buffer on the hunk the cursor is currently on to what exists in HEAD. |
| `buffer_stage` | Stages all changes in the current buffer. |
| `buffer_unstage` | Unstages all changes in the current buffer. |
| `buffer_reset` | Removes all current changes in the buffer and resets it to the version in HEAD. |
| `buffer_conflict_accept_both` | Acceps both changes from the conflict under cursor. |
| `buffer_conflict_accept_current` | Accepts the current changes form the conflict under cursor. |
| `buffer_conflict_accept_incoming` | Accepts the incoming changes form the conclict under cursor. |
| `project_diff_preview` | Opens a diff preview along with a list of all the files that have been changed, enabling users to see all the files that were changed in the current project |
| `project_logs_preview` [args] | Opens a preview listing all the logs in the current working branch. Users can filter the list by passing options to this list. Pressing the "tab" key on a list item will keep the item selected. Pressing the "enter" key on the preview will close the preview and open "project_commits_preview" with the selected commits |
| `project_commit_preview` | Opens a preview through which staged changes can be committed |
| `project_commits_preview` [args] | Opens a diff preview along with a list of all your commits |
| `project_stash_preview` | Opens a preview of all your stash changes and provides you with the ability to manage these changes |
| `toggle_diff_preference` | Used to switch between "split" and "unified" diff. |
| `toggle_live_gutter` | Enables/disables git gutter signs. |
| `toggle_live_blame` | Used to switch between "split" and "unified" diff. |
| `toggle_tracing` | Enables/disables debug logs that are used internally by VGit to make suppressed logs visible. |
