local highlight = require('vgit.highlight')

local it = it
local describe = describe
local eq = assert.are.same

describe('highlight:', function()
  describe('setup', function()
    it(
      'should override state highlights with highlights specified through the config',
      function()
        highlight.setup({
          VGitSignAdd = {
            fg = 'red',
            bg = nil,
          },
        })
        eq(highlight.state.data.VGitSignAdd, {
          fg = 'red',
          bg = nil,
        })
      end
    )
  end)

  describe('create', function()
    it('should successfully create a highlight', function()
      local hl = 'VGitTestHighlight'
      highlight.create(hl, {
        bg = nil,
        fg = '#464b59',
      })
      vim.cmd(string.format('hi %s', hl))
    end)
  end)
end)
