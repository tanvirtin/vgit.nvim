# Git for Neovim (In Development)

<details>
    <summary>Take a look</summary>
    <img width="1792" alt="Screen Shot 2021-04-13 at 10 23 40 PM" src="https://user-images.githubusercontent.com/25164326/114645560-b714d780-9ca7-11eb-9669-24fe60b50fa6.png">
    <img width="1792" alt="Screen Shot 2021-04-13 at 10 24 01 PM" src="https://user-images.githubusercontent.com/25164326/114645565-b8460480-9ca7-11eb-9fab-28a74cc4c4f3.png">
    <img width="1792" alt="Screen Shot 2021-04-13 at 10 28 10 PM" src="https://user-images.githubusercontent.com/25164326/114645566-b8460480-9ca7-11eb-95a9-c7b69304860d.png">
</details>

### Provided Features
- [ ] Provides configurations to your hearts content
- [x] Hunk signs
- [x] Reset a hunk
- [x] Hunk preview
- [x] Hunk navigation in current buffer
- [x] Show original file and current file in a split window with diffs highlighted

### Installation via Plug
```
Plug 'tanvirtin/git.nvim'
Plug 'nvim-lua/plenary.nvim'
```

### Installation via Packer
```
use {
    'tanvirtin/git.nvim',
    requires = {{ 'nvim-lua/plenary.nvim' }}
}
```

### Configure Mappings
```
vim.api.nvim_set_keymap('n', '<leader>gh', ':lua require("git").hunk_preview()<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<leader>gr', ':lua require("git").hunk_reset()<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<space>]', ':lua require("git").hunk_up()<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<space>[', ':lua require("git").hunk_down()<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<space>gd', ':lua require("git").diff_preview()<CR>', { noremap = true, silent = true })
```

### API
| Function Name | Description |
|---------------|-------------|
| setup | Sets up the plugin to run necessary git commands on loaded buffers |
| hunk_preview | If a file has a hunk of diff associated with it, invoking this function will reveal that hunk if it exists on the current cursor |
| hunk_reset | Resets the hunk the cursor is on right now to it's previous step
| hunk_down | Navigate downward through a github hunk |
| hunk_up | Navigate upwards through a github hunk |
| diff_preview | Opens two windows, showing cwd and origin buffers and the diff between them |
