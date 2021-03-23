# Git for Neovim (In Development)

Git plugin for neovim.

### Installation via Plug
```
Plug 'tanvirtin/git.nvim'
Plug 'nvim-lua/plenary.nvim'
```

### Installation via Packer

```
use {
    'tanvirtin/git.nvim'
    requires = {{'nvim-lua/plenary.nvim'}}
}
```

### Default Configuration
```
require('git').setup()
```
<img width="1792" alt="Screen Shot 2021-03-21 at 9 16 08 PM" src="https://user-images.githubusercontent.com/25164326/111928772-efe7d500-8a8a-11eb-854f-b0f4b620d893.png">

### Custom Configuration
```
require('git').setup({
    colors =  {
        add = '#32a85b', -- #d7ffaf
        remove = '#a83232', -- #e95678
        change = '#a232a8', -- #7AA6DA
    },
    signs = {
        add = 'CustomGitAdd', -- GitAdd
        remove = 'CustomGitRemove', -- GitRemove
        change = 'CustomGitChange', -- GitChange
    }
})
```
<img width="1792" alt="Screen Shot 2021-03-21 at 9 14 08 PM" src="https://user-images.githubusercontent.com/25164326/111928766-ed857b00-8a8a-11eb-9218-6dbc15fbe04e.png">

### Configure Mappings
```
vim.api.nvim_set_keymap("n", '<leader>gh', ':lua require("git").hunk_preview()<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", '<space>]', ':lua require("git").hunk_up()<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", '<space>[', ':lua require("git").hunk_down()<CR>', { noremap = true, silent = true })
```
<img width="1792" alt="Screen Shot 2021-03-22 at 1 24 18 AM" src="https://user-images.githubusercontent.com/25164326/111944347-cd1ae800-8aad-11eb-9792-f23117ffe912.png">

### API
| Function Name | Description |
|---------------|-------------|
| setup | Sets up the plugin to run necessary git commands on loaded buffers |
| hunk_preview | If a file has a hunk of diff associated with it, invoking this function will reveal that hunk if it exists on the current cursor |
| hunk_down | Navigate downward through a github hunk |
| hunk_up | Navigate upwards through a github hunk |


### Config
| Option Name   | Description | Defaults |
|---------------|-------------|----------|
| colors.add | Color when hunk contains all additions | #d7ffaf |
| colors.remove | Color when hunk contains all removals | #e95678 |
| colors.change | Color when hunk contains both addition and deletion | #7AA6DA |
| signs.add | Unique name of the add sign, also dictates highlight group | GitAdd |
| signs.remove | Unique name of the remove sign, also dictates highlight group | GitRemove |
| signs.change | Unique name of the change sign, also dictates highlight group | GitChange |

### Fetures

- [x] Hunk signs
- [x] Colored hunk signs
- [x] Hunk View
- [ ] Coloured hunk view
- [x] Hunk navigation
- [ ] Undo a hunk
- [ ] Show file diff
