local Object = require('vgit.core.Object')
local dimensions = require('vgit.ui.dimensions')
local AppBarComponent = require('vgit.ui.components.AppBarComponent')

local KeyHelpBarView = Object:extend()

function KeyHelpBarView:constructor(scene, props, plot)
  return {
    plot = plot,
    scene = scene,
    props = props,
  }
end

function KeyHelpBarView:define()
  self.scene:set(
    'app_bar',
    AppBarComponent({
      config = {
        win_plot = dimensions.relative_win_plot(self.plot, {
          height = '100vh',
          width = '100vw',
        }),
      },
    })
  )
end

function KeyHelpBarView:get_components()
  return { self.scene:get('app_bar') }
end

function KeyHelpBarView:mount(opts)
  self.scene:get('app_bar'):mount(opts)
end

function KeyHelpBarView:render()
  local keymaps = self.props.keymaps()

  local text = ''
  for i, keymap in ipairs(keymaps) do
    local action = keymap[1]
    local key = keymap[2]

    text = i == 1 and string.format('%s (%s)', action, key) or string.format('%s | %s (%s)', text, action, key)
  end

  self.scene:get('app_bar'):set_lines({ text })
  self.scene:get('app_bar'):place_extmark_highlight({
    hl = 'Keyword',
    pattern = '%((%a+)%)',
  })
  self.scene:get('app_bar'):place_extmark_highlight({
    hl = 'Number',
    pattern = '|',
  })
end

return KeyHelpBarView
