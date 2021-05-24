local highlighter = require('vgit.highlighter')

local vim = vim
local it = it
local describe = describe

describe('highlighter:', function()

    describe('setup', function()

        it('should override state highlights with highlights specified through the config', function()
            highlighter.setup({
                hls = {
                    VGitSignAdd = {
                        fg = 'red',
                        bg = nil,
                    },
                },
            })
            assert.are.same(highlighter.state.hls.VGitSignAdd, {
                fg = 'red',
                bg = nil,
            });
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


    describe('define', function()

        it('should not define a highlight if it does not exist in state hls', function()
            local hl = 'VGitTestHighlight2'
            local result = highlighter.define(hl)
            assert.has_error(function()
                vim.cmd(string.format('hi %s', hl))
            end)
            assert.are.same(result, false)
        end)

         it('should successfully define a highlight group since it exists in the state hls', function()
            local hl = 'VGitBlame'
            local result = highlighter.define(hl)
            assert.are.same(result, true)
            vim.cmd(string.format('hi %s', hl))
        end)

    end)

end)
