local highlighter = require('vgit.highlighter')

local vim = vim
local it = it
local describe = describe

describe('highlighter:', function()

    describe('setup', function()

        it('should override state highlights with highlights specified through the config', function()
            highlighter.setup({
                hl_groups = {
                    VGitSignAdd = {
                        fg = '#25382a',
                        bg = nil,
                    },
                },
            })
            assert.are.same(highlighter.state, {
                hl_groups = {
                    VGitBlame = {
                        bg = nil,
                        fg = '#b1b1b1',
                    },
                    VGitDiffWindow = {
                        bg = nil,
                        fg = '#ffffff',
                    },
                    VGitDiffBorder = {
                        bg = nil,
                        fg = '#464b59',
                    },
                    VGitDiffAddSign = {
                        bg = '#3d5213',
                        fg = nil,
                    },
                    VGitDiffRemoveSign = {
                        bg = '#4a0f23',
                        fg = nil,
                    },
                    VGitDiffAddText = {
                        fg = '#6a8f1f',
                        bg = '#3d5213',
                    },
                    VGitDiffRemoveText = {
                        fg = '#a3214c',
                        bg = '#4a0f23',
                    },
                    VGitHunkWindow = {
                        bg = nil,
                        fg = '#ffffff',
                    },
                    VGitHunkBorder = {
                        bg = nil,
                        fg = '#464b59',
                    },
                    VGitHunkAddSign = {
                        bg = '#3d5213',
                        fg = nil,
                    },
                    VGitHunkRemoveSign = {
                        bg = '#4a0f23',
                        fg = nil,
                    },
                    VGitHunkAddText = {
                        fg = '#6a8f1f',
                        bg = '#3d5213',
                    },
                    VGitHunkRemoveText = {
                        fg = '#a3214c',
                        bg = '#4a0f23',
                    },
                    VGitHunkSignAdd = {
                        fg = '#d7ffaf',
                        bg = '#4a6317',
                    },
                    VGitHunkSignRemove = {
                        fg = '#e95678',
                        bg = '#63132f',
                    },
                    VGitSignAdd = {
                        fg = '#25382a',
                        bg = nil,
                    },
                    VGitSignChange = {
                        fg = '#7AA6DA',
                        bg = nil,
                    },
                    VGitSignRemove = {
                        fg = '#e95678',
                        bg = nil,
                    },
                    VGitLogsWindow = {
                        bg = nil,
                        fg = '#ffffff',
                    },
                    VGitLogsBorder = {
                        bg = nil,
                        fg = '#464b59',
                    },
                    VGitLogsIndicator = {
                        fg = '#a6e22e',
                        bg = nil,
                    }
                }
            });
        end)

    end)

    describe('create', function()

        it('should successfully create a highlight', function()
            local hl_group = 'VGitTestHighlight'
            highlighter.create(hl_group, {
                bg = nil,
                fg = '#464b59',
            })
            vim.cmd(string.format('hi %s', hl_group))
        end)
    end)


    describe('define', function()

        it('should not define a highlight if it does not exist in state hl_groups', function()
            local hl_group = 'VGitTestHighlight2'
            local result = highlighter.define(hl_group)
            assert.has_error(function()
                vim.cmd(string.format('hi %s', hl_group))
            end)
            assert.are.same(result, false)
        end)

         it('should successfully define a highlight group since it exists in the state hl_groups', function()
            local hl_group = 'VGitBlame'
            local result = highlighter.define(hl_group)
            assert.are.same(result, true)
            vim.cmd(string.format('hi %s', hl_group))
        end)

    end)

end)
