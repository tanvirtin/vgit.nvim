local CodeComponent = require('vgit.ui.components.CodeComponent')
local StagedDiffScreen = require('vgit.features.screens.StagedDiffScreen')

local StagedDiffHunkScreen = StagedDiffScreen:extend()

function StagedDiffHunkScreen:new(...)
  return setmetatable(StagedDiffScreen:new(...), StagedDiffHunkScreen)
end

function StagedDiffHunkScreen:get_unified_scene_definition()
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

function StagedDiffHunkScreen:get_split_scene_definition()
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

return StagedDiffHunkScreen
