local KeyHelpBarView = require('vgit.ui.views.KeyHelpBarView')

local PaginationView = KeyHelpBarView:extend()

function PaginationView:render()
  local component = self.scene:get('app_bar')
  self:render_help_text(component)

  component:clear_extmarks()
  component:place_extmark_highlight({
    hl = 'Keyword',
    pattern = '%(([%a%-=]+)%)',
  })
  component:place_extmark_highlight({
    hl = 'Number',
    pattern = '|',
  })

  local pagination = self.props.pagination()
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
