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
        add = '#32a85b',
        remove = '#a83232',
        change = '#a232a8',
    }
})
```
<img width="1792" alt="Screen Shot 2021-03-21 at 9 14 08 PM" src="https://user-images.githubusercontent.com/25164326/111928766-ed857b00-8a8a-11eb-9218-6dbc15fbe04e.png">

### Configure Mappings
```
vim.api.nvim_set_keymap("n", '<leader>gh', ':lua require("git").preview_hunk()<CR>', { noremap = true, silent = true })
```
<img width="1792" alt="Screen Shot 2021-03-22 at 1 24 18 AM" src="https://user-images.githubusercontent.com/25164326/111944347-cd1ae800-8aad-11eb-9792-f23117ffe912.png">


### API
| Function Name | Description |
|---------------|-------------|
| setup | Sets up the plugin to run necessary git commands on loaded buffers |
| preview_hunk | If a file has a hunk of diff associated with it, invoking this function will reveal that hunk if it exists on the current cursor |

### Fetures

- [x] Colored hunk signs
- [ ] Coloured hunk view
- [ ] Undo a hunk
- [ ] Show file diff
