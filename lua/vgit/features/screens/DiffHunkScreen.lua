local CodeComponent = require('vgit.ui.components.CodeComponent')
local DiffScreen = require('vgit.features.screens.DiffScreen')

local DiffHunkScreen = DiffScreen:extend()

function DiffHunkScreen:new(...)
  return setmetatable(DiffScreen:new(...), DiffHunkScreen)
end

function DiffHunkScreen:get_unified_scene_definition()
  return {
    current = CodeComponent:new({
      config = {
        win_options = {
          cursorbind = true,
          scrollbind = true,
          cursorline = true,
        },
        win_plot = {
          relative = 'cursor',
          height = 20,
          width = '100vw',
        },
      },
    }),
  }
end

function DiffHunkScreen:get_split_scene_definition()
  return {
    previous = CodeComponent:new({
      config = {
        win_options = {
          cursorbind = true,
          scrollbind = true,
          cursorline = true,
        },
        win_plot = {
          relative = 'cursor',
          height = 20,
          width = '50vw',
        },
      },
    }),
    current = CodeComponent:new({
      config = {
        win_options = {
          cursorbind = true,
          scrollbind = true,
          cursorline = true,
        },
        win_plot = {
          relative = 'cursor',
          height = 20,
          width = '50vw',
          col = '50vw',
        },
      },
    }),
  }
end

return DiffHunkScreen
