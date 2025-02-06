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

function KeyHelpBarView:render_help_text(component)
  local keymaps = self.props.keymaps()

  local text = ''
  for i, keymap in ipairs(keymaps) do
    local key
    local desc

    if type(keymap[2]) == 'table' then
      key = keymap[2].key
      desc = keymap[2].desc
    else
      key = keymap[2]
      desc = keymap[1]
    end

    text = i == 1 and string.format('%s (%s)', desc, key) or string.format('%s | %s (%s)', text, desc, key)
  end

  component:set_lines({ text })
end

function KeyHelpBarView:render()
  local component = self.scene:get('app_bar')
  self:render_help_text(component)

  component:place_extmark_highlight({
    hl = 'Keyword',
    pattern = '%((%a+)%)',
  })
  component:place_extmark_highlight({
    hl = 'Number',
    pattern = '|',
  })
end

return KeyHelpBarView
