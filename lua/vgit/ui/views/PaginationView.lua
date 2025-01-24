local Object = require('vgit.core.Object')
local dimensions = require('vgit.ui.dimensions')
local AppBarComponent = require('vgit.ui.components.AppBarComponent')

local PaginationView = Object:extend()

function PaginationView:constructor(scene, props, plot)
  return {
    plot = plot,
    scene = scene,
    props = props,
  }
end

function PaginationView:define()
  self.scene:set(
    'pagination',
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

function PaginationView:get_components()
  return { self.scene:get('pagination') }
end

function PaginationView:mount(opts)
  self.scene:get('pagination'):mount(opts)
end

function PaginationView:render()
  local keymaps = self.props.keymaps()
  local pagination = self.props.pagination()

  local text = string.format('Prev (%s) | Next (%s)', keymaps[1], keymaps[2])
  local component = self.scene:get('pagination')

  component:set_lines({ text })

  component:clear_extmarks()
  component:place_extmark_highlight({
    hl = 'Keyword',
    pattern = '%(([%a%-=]+)%)',
  })
  component:place_extmark_highlight({
    hl = 'Number',
    pattern = '|',
  })

  if not pagination.display then return end
  component:place_extmark_text({
    text = pagination.display,
    hl = 'GitComment',
    row = 0,
    col = 0,
    pos = 'eol',
  })
end

return PaginationView
