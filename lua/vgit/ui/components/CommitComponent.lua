local lazy = require('vgit.core.lazy')

local Component = lazy('vgit.ui.Component')

local CommitComponent = Component({
  buf_options = function(props)
    return {
      modifiable = true,
      buflisted = false,
      bufhidden = 'wipe',
      buftype = 'nofile',
      filetype = props.filetype or 'gitcommit',
    }
  end,
  win_options = {
    number = false,
    relativenumber = false,
    signcolumn = 'no',
    wrap = true,
    cursorline = true,
  },
  layout_opts = { flex = 1 },

  on_mount = function(self)
    local confirm_key = self.props.confirm_key or '<C-s>'
    local cancel_key = self.props.cancel_key or 'q'

    self:with_element(function(el)
      el:set_keymap({ mode = { 'n', 'i' }, key = confirm_key, desc = 'Confirm commit' }, function()
        if self.props.on_confirm then self.props.on_confirm() end
      end)

      el:set_keymap('n', cancel_key, function()
        if self.props.on_cancel then self.props.on_cancel() end
      end, 'Cancel commit')
    end)
  end,
})

function CommitComponent:get_lines()
  return self:with_element(function(el)
    return el:get_lines()
  end) or {}
end

return CommitComponent
