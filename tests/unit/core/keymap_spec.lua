local keymap = require('vgit.core.keymap')
local mock = require('luassert.mock')

local describe = describe
local it = it
local before_each = before_each
local after_each = after_each

describe('keymap<Cmd>', function()
  before_each(function()
    vim.api = mock(vim.api, true)
  end)

  after_each(function()
    mock.revert(vim.api)
  end)

  describe('define', function()
    it('should call vim api internally to define the given keys', function()
      local expected = {
        { 'n', '<C-k>', '<Cmd>lua require("vgit").hunk_up()<CR>' },
        { 'n', '<C-j>', '<Cmd>lua require("vgit").hunk_down()<CR>' },
        {
          'n',
          '<leader>gs',
          '<Cmd>lua require("vgit").buffer_hunk_stage()<CR>',
        },
        {
          'n',
          '<leader>gr',
          '<Cmd>lua require("vgit").buffer_hunk_reset()<CR>',
        },
        {
          'n',
          '<leader>gp',
          '<Cmd>lua require("vgit").buffer_hunk_preview()<CR>',
        },
        {
          'n',
          '<leader>gb',
          '<Cmd>lua require("vgit").buffer_blame_preview()<CR>',
        },
        {
          'n',
          '<leader>gf',
          '<Cmd>lua require("vgit").buffer_diff_preview()<CR>',
        },
        {
          'n',
          '<leader>gh',
          '<Cmd>lua require("vgit").buffer_history_preview()<CR>',
        },
        { 'n', '<leader>gu', '<Cmd>lua require("vgit").buffer_reset()<CR>' },
        {
          'n',
          '<leader>gg',
          '<Cmd>lua require("vgit").buffer_gutter_blame_preview()<CR>',
        },
        {
          'n',
          '<leader>gd',
          '<Cmd>lua require("vgit").project_diff_preview()<CR>',
        },
        {
          'n',
          '<leader>gx',
          '<Cmd>lua require("vgit").toggle_diff_preference()<CR>',
        },
      }
      keymap.define({
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
        ['n <leader>gd'] = 'project_diff_preview',
        ['n <leader>gx'] = 'toggle_diff_preference',
      })
      for index in ipairs(expected) do
        assert.stub(vim.api.nvim_set_keymap).was.called_with(
          expected[index][1],
          expected[index][2],
          expected[index][3],
          {
            noremap = true,
            silent = true,
          }
        )
      end
    end)
  end)
end)
