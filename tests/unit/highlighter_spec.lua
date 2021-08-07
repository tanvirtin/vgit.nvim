local highlighter = require('vgit.highlighter')

local vim = vim
local it = it
local describe = describe
local eq = assert.are.same

describe('highlighter:', function()
    describe('setup', function()
        it('should override state highlights with highlights specified through the config', function()
            highlighter.setup({
                VGitSignAdd = {
                    fg = 'red',
                    bg = nil,
                },
            })
            eq(highlighter.state.data.VGitSignAdd, {
                fg = 'red',
                bg = nil,
            })
        end)
    end)

    describe('create', function()
        it('should successfully create a highlight', function()
            local hl = 'VGitTestHighlight'
            highlighter.create(hl, {
                bg = nil,
                fg = '#464b59',
            })
            vim.cmd(string.format('hi %s', hl))
        end)
    end)
end)
