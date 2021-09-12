local dimensions = require('vgit.dimensions')

return {
    blame_preview = {
        border = {
            enabled = true,
            virtual = false,
            chars = { '╭', '─', '╮', '│', '╯', '─', '╰', '│' },
            hl = 'VGitBorder',
            focus_hl = 'VGitBorderFocus',
        },
    },
    hunk_preview = {
        border = {
            enabled = true,
            virtual = false,
            chars = { '─', '─', '─', ' ', '─', '─', '─', ' ' },
            hl = 'VGitBorderFocus',
        },
    },
    gutter_blame_preview = {
        blame = {
            height = dimensions.global_height() - 3,
            width = math.ceil(dimensions.global_width() * 0.35),
            row = 1,
            col = 0,
        },
        preview = {
            height = dimensions.global_height() - 3,
            width = math.ceil(dimensions.global_width() * 0.65),
            row = 1,
            col = math.ceil(dimensions.global_width() * 0.35),
        },
    },
    diff_preview = {
        horizontal = {
            border = {
                ignore_title = true,
                enabled = true,
                hl = 'VGitBorder',
                focus_hl = 'VGitBorderFocus',
            },
            height = dimensions.global_height() - 5,
            width = dimensions.global_width(),
            row = 2,
            col = 0,
        },
        vertical = {
            previous = {
                border = {
                    ignore_title = true,
                    enabled = true,
                    hl = 'VGitBorder',
                    focus_hl = 'VGitBorderFocus',
                },
                height = dimensions.global_height() - 5,
                width = math.ceil(dimensions.global_width() / 2),
                row = 2,
                col = 0,
            },
            current = {
                border = {
                    ignore_title = true,
                    enabled = true,
                    hl = 'VGitBorder',
                    focus_hl = 'VGitBorderFocus',
                },
                height = dimensions.global_height() - 5,
                width = math.ceil(dimensions.global_width() / 2),
                row = 2,
                col = math.ceil(dimensions.global_width() / 2),
            },
        },
    },
    history_preview = {
        horizontal = {
            preview = {
                border = {
                    ignore_title = true,
                    enabled = true,
                    hl = 'VGitBorder',
                    focus_hl = 'VGitBorderFocus',
                },
                height = math.ceil(dimensions.global_height() - 15),
                width = dimensions.global_width(),
                row = 2,
                col = 0,
            },
            table = {
                border = {
                    title = 'History',
                    enabled = true,
                    hl = 'VGitBorder',
                    focus_hl = 'VGitBorderFocus',
                },
                height = 10,
                width = dimensions.global_width(),
                row = math.ceil(dimensions.global_height() - 12),
                col = 0,
                background_hl = 'PMenu',
            },
        },
        vertical = {
            previous = {
                border = {
                    ignore_title = true,
                    enabled = true,
                    hl = 'VGitBorder',
                    focus_hl = 'VGitBorderFocus',
                },
                height = math.ceil(dimensions.global_height() - 15),
                width = math.ceil((dimensions.global_width()) / 2),
                row = 2,
                col = 0,
            },
            current = {
                border = {
                    ignore_title = true,
                    enabled = true,
                    hl = 'VGitBorder',
                    focus_hl = 'VGitBorderFocus',
                },
                height = math.ceil(dimensions.global_height() - 15),
                width = math.ceil((dimensions.global_width()) / 2),
                row = 2,
                col = math.ceil((dimensions.global_width()) / 2),
            },
            table = {
                height = 10,
                width = dimensions.global_width(),
                row = math.ceil(dimensions.global_height() - 12),
                col = 0,
                background_hl = 'PMenu',
            },
        },
    },
    project_diff_preview = {
        horizontal = {
            table = {
                height = math.ceil(dimensions.global_height() - 4),
                width = math.ceil(dimensions.global_width() * 0.20),
                row = 2,
                col = 0,
            },
            preview = {
                border = {
                    ignore_title = true,
                    enabled = true,
                    hl = 'VGitBorder',
                    focus_hl = 'VGitBorderFocus',
                },
                height = math.ceil(dimensions.global_height() - 3),
                width = math.ceil(dimensions.global_width() - math.ceil(dimensions.global_width() * 0.20)),
                row = 1,
                col = math.ceil(dimensions.global_width() * 0.20),
            },
        },
        vertical = {
            table = {
                height = math.floor(dimensions.global_height() - 3),
                width = math.floor(dimensions.global_width() * 0.20),
                row = 1,
                col = 0,
            },
            previous = {
                border = {
                    ignore_title = true,
                    enabled = true,
                    hl = 'VGitBorder',
                    focus_hl = 'VGitBorderFocus',
                },
                height = math.floor(dimensions.global_height() - 4),
                width = math.floor((dimensions.global_width() - math.floor(dimensions.global_width() * 0.20)) / 2),
                row = 2,
                col = math.floor(dimensions.global_width() * 0.20),
            },
            current = {
                border = {
                    ignore_title = true,
                    enabled = true,
                    hl = 'VGitBorder',
                    focus_hl = 'VGitBorderFocus',
                },
                height = math.floor(dimensions.global_height() - 4),
                width = math.floor((dimensions.global_width() - math.floor(dimensions.global_width() * 0.20)) / 2),
                row = 2,
                col = math.floor(dimensions.global_width() * 0.20) + math.floor(
                    (dimensions.global_width() - math.floor(dimensions.global_width() * 0.20)) / 2
                ),
            },
        },
    },
}
