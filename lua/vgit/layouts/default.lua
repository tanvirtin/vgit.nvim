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
                return dimensions.global_height()
            end,
            width = function()
                return math.ceil(dimensions.global_width() * 0.35)
            end,
            row = 0,
            col = 0,
        },
        preview = {
            height = function()
                return dimensions.global_height()
            end,
            width = function()
                return math.ceil(dimensions.global_width() * 0.65)
            end,
            row = 0,
            col = function()
                return math.ceil(dimensions.global_width() * 0.35)
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
                return dimensions.global_height() - 2
            end,
            width = function()
                return dimensions.global_width()
            end,
            row = 0,
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
                    return dimensions.global_height() - 2
                end,
                width = function()
                    return math.ceil(dimensions.global_width() / 2)
                end,
                row = 0,
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
                    return dimensions.global_height() - 2
                end,
                width = function()
                    return math.ceil(dimensions.global_width() / 2)
                end,
                row = 0,
                col = function()
                    return math.ceil(dimensions.global_width() / 2)
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
                    return math.ceil(dimensions.global_height() - 12)
                end,
                width = function()
                    return dimensions.global_width()
                end,
                row = 0,
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
                    return math.ceil(dimensions.global_height() - 10)
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
                    return math.ceil(dimensions.global_height() - 12)
                end,
                width = function()
                    return math.ceil(dimensions.global_width() / 2)
                end,
                row = 0,
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
                    return math.ceil(dimensions.global_height() - 12)
                end,
                width = function()
                    return math.ceil(dimensions.global_width() / 2)
                end,
                row = 0,
                col = function()
                    return math.ceil(dimensions.global_width() / 2)
                end,
            },
            table = {
                height = 9,
                width = function()
                    return dimensions.global_width()
                end,
                row = function()
                    return math.ceil(dimensions.global_height() - 10)
                end,
                col = 0,
            },
        },
    },
    project_diff_preview = {
        horizontal = {
            preview = {
                border = {
                    ignore_title = true,
                    enabled = true,
                    hl = 'FloatBorder',
                    focus_hl = 'VGitBorderFocus',
                },
                height = function()
                    return math.ceil(dimensions.global_height() - 12)
                end,
                width = function()
                    return dimensions.global_width()
                end,
                row = 0,
                col = 0,
            },
            table = {
                border = {
                    enabled = true,
                    hl = 'FloatBorder',
                    focus_hl = 'VGitBorderFocus',
                },
                height = 9,
                width = function()
                    return dimensions.global_width()
                end,
                row = function()
                    return math.ceil(dimensions.global_height() - 10)
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
                    return math.ceil(dimensions.global_height() - 12)
                end,
                width = function()
                    return math.ceil(dimensions.global_width() / 2)
                end,
                row = 0,
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
                    return math.ceil(dimensions.global_height() - 12)
                end,
                width = function()
                    return math.ceil(dimensions.global_width() / 2)
                end,
                row = 0,
                col = function()
                    return math.ceil(dimensions.global_width() / 2)
                end,
            },
            table = {
                height = 9,
                width = function()
                    return dimensions.global_width()
                end,
                row = function()
                    return math.ceil(dimensions.global_height() - 10)
                end,
                col = 0,
            },
        },
    },
}
