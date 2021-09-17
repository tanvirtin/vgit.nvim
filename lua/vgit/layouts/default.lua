local dimensions = require('vgit.dimensions')

return {
    blame_preview = {
        border = {
            enabled = true,
            chars = { '╭', '─', '╮', '│', '╯', '─', '╰', '│' },
            hl = 'FloatBorder',
            focus_hl = 'VGitBorderFocus',
        },
    },
    hunk_preview = {
        border = {
            enabled = true,
            chars = { '─', '─', '─', ' ', '─', '─', '─', ' ' },
            hl = 'FloatBorder',
        },
    },
    gutter_blame_preview = {
        blame = {
            height = function()
                return dimensions.global_height() - 3
            end,
            width = function()
                return math.floor(dimensions.global_width() * 0.35)
            end,
            row = 1,
            col = 0,
        },
        preview = {
            height = function()
                return dimensions.global_height() - 3
            end,
            width = function()
                return math.floor(dimensions.global_width() * 0.65)
            end,
            row = 1,
            col = function()
                return math.floor(dimensions.global_width() * 0.35)
            end,
        },
    },
    diff_preview = {
        horizontal = {
            border = {
                ignore_title = true,
                enabled = true,
                hl = 'FloatBorder',
                focus_hl = 'VGitBorderFocus',
            },
            height = function()
                return dimensions.global_height() - 5
            end,
            width = function()
                return dimensions.global_width()
            end,
            row = 2,
            col = 0,
        },
        vertical = {
            previous = {
                border = {
                    ignore_title = true,
                    enabled = true,
                    hl = 'FloatBorder',
                    focus_hl = 'VGitBorderFocus',
                },
                height = function()
                    return dimensions.global_height() - 5
                end,
                width = function()
                    return math.floor(dimensions.global_width() / 2)
                end,
                row = 2,
                col = 0,
            },
            current = {
                border = {
                    ignore_title = true,
                    enabled = true,
                    hl = 'FloatBorder',
                    focus_hl = 'VGitBorderFocus',
                },
                height = function()
                    return dimensions.global_height() - 5
                end,
                width = function()
                    return math.floor(dimensions.global_width() / 2)
                end,
                row = 2,
                col = function()
                    return math.floor(dimensions.global_width() / 2)
                end,
            },
        },
    },
    history_preview = {
        horizontal = {
            preview = {
                border = {
                    ignore_title = true,
                    enabled = true,
                    hl = 'FloatBorder',
                    focus_hl = 'VGitBorderFocus',
                },
                height = function()
                    return math.floor(dimensions.global_height() - 15)
                end,
                width = function()
                    return dimensions.global_width() - 1
                end,
                row = 2,
                col = 0,
            },
            table = {
                border = {
                    title = 'History',
                    enabled = true,
                    hl = 'FloatBorder',
                    focus_hl = 'VGitBorderFocus',
                },
                height = 9,
                width = function()
                    return dimensions.global_width()
                end,
                row = function()
                    return math.floor(dimensions.global_height() - 12)
                end,
                col = 0,
            },
        },
        vertical = {
            previous = {
                border = {
                    ignore_title = true,
                    enabled = true,
                    hl = 'FloatBorder',
                    focus_hl = 'VGitBorderFocus',
                },
                height = function()
                    return math.floor(dimensions.global_height() - 15)
                end,
                width = function()
                    return math.floor(dimensions.global_width() / 2)
                end,
                row = 2,
                col = 0,
            },
            current = {
                border = {
                    ignore_title = true,
                    enabled = true,
                    hl = 'FloatBorder',
                    focus_hl = 'VGitBorderFocus',
                },
                height = function()
                    return math.floor(dimensions.global_height() - 15)
                end,
                width = function()
                    return math.floor(dimensions.global_width() / 2)
                end,
                row = 2,
                col = function()
                    return math.floor(dimensions.global_width() / 2)
                end,
            },
            table = {
                height = 10,
                width = function()
                    return dimensions.global_width()
                end,
                row = function()
                    return math.floor(dimensions.global_height() - 12)
                end,
                col = 0,
            },
        },
    },
    project_diff_preview = {
        horizontal = {
            table = {
                height = function()
                    return math.floor(dimensions.global_height() - 3)
                end,
                width = function()
                    return math.floor(dimensions.global_width() * 0.20) - 2
                end,
                row = 1,
                col = 0,
            },
            preview = {
                border = {
                    ignore_title = true,
                    enabled = true,
                    hl = 'FloatBorder',
                    focus_hl = 'VGitBorderFocus',
                },
                height = function()
                    return math.floor(dimensions.global_height() - 5)
                end,
                width = function()
                    return math.floor(dimensions.global_width() - math.floor(dimensions.global_width() * 0.20))
                end,
                row = 2,
                col = function()
                    return math.floor(dimensions.global_width() * 0.20)
                end,
            },
        },
        vertical = {
            table = {
                height = function()
                    return math.floor(dimensions.global_height() - 3)
                end,
                width = function()
                    return math.floor(dimensions.global_width() * 0.20) - 1
                end,
                row = 1,
                col = 0,
            },
            previous = {
                border = {
                    ignore_title = true,
                    enabled = true,
                    hl = 'FloatBorder',
                    focus_hl = 'VGitBorderFocus',
                },
                height = function()
                    return math.floor(dimensions.global_height() - 5)
                end,
                width = function()
                    return math.floor((dimensions.global_width() - math.floor(dimensions.global_width() * 0.20)) / 2)
                end,
                row = 2,
                col = function()
                    return math.floor(dimensions.global_width() * 0.20)
                end,
            },
            current = {
                border = {
                    ignore_title = true,
                    enabled = true,
                    hl = 'FloatBorder',
                    focus_hl = 'VGitBorderFocus',
                },
                height = function()
                    return math.floor(dimensions.global_height() - 5)
                end,
                width = function()
                    return math.floor((dimensions.global_width() - math.floor(dimensions.global_width() * 0.20)) / 2)
                end,
                row = 2,
                col = function()
                    return math.floor(dimensions.global_width() * 0.20)
                        + math.floor((dimensions.global_width() - math.floor(dimensions.global_width() * 0.20)) / 2)
                end,
            },
        },
    },
}
