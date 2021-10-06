local dimensions = require('vgit.dimensions')

return {
  decorator = {
    app_bar = {
      border = {
        chars = { '─', '─', '─', ' ', '─', '─', '─', ' ' },
        hl = 'VGitBorder',
      },
    },
  },
  blame_preview = {
    border = {
      enabled = true,
      chars = { '╭', '─', '╮', '│', '╯', '─', '╰', '│' },
      hl = 'FloatBorder',
    },
  },
  hunk_preview = {
    height = function()
      return 20
    end,
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
      height = function()
        return dimensions.global_height() - 1
      end,
      width = function()
        return dimensions.global_width()
      end,
      row = 0,
      col = 0,
    },
    vertical = {
      previous = {
        height = function()
          return dimensions.global_height() - 1
        end,
        width = function()
          return math.ceil(dimensions.global_width() / 2)
        end,
        row = 0,
        col = 0,
      },
      current = {
        height = function()
          return dimensions.global_height() - 1
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
        height = function()
          return math.ceil(dimensions.global_height() - 10)
        end,
        width = function()
          return dimensions.global_width()
        end,
        row = 0,
        col = 0,
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
    vertical = {
      previous = {
        height = function()
          return math.ceil(dimensions.global_height() - 10)
        end,
        width = function()
          return math.ceil(dimensions.global_width() / 2)
        end,
        row = 0,
        col = 0,
      },
      current = {
        height = function()
          return math.ceil(dimensions.global_height() - 10)
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
        height = function()
          return math.ceil(dimensions.global_height() - 10)
        end,
        width = function()
          return dimensions.global_width()
        end,
        row = 0,
        col = 0,
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
    vertical = {
      previous = {
        height = function()
          return math.ceil(dimensions.global_height() - 10)
        end,
        width = function()
          return math.ceil(dimensions.global_width() / 2)
        end,
        row = 0,
        col = 0,
      },
      current = {
        height = function()
          return math.ceil(dimensions.global_height() - 10)
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
