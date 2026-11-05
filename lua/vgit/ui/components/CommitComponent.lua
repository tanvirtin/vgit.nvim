local lazy = require('vgit.core.lazy')

local ElementComponent = lazy('vgit.ui.ElementComponent')

local CommitComponent = ElementComponent:extend()

function CommitComponent:get_buf_options()
  return {
    modifiable = true,
    buflisted = false,
    bufhidden = 'wipe',
    buftype = 'nofile',
    filetype = self.props.filetype or 'gitcommit',
  }
end

function CommitComponent:get_win_options()
  return {
    number = false,
    relativenumber = false,
    signcolumn = 'no',
    wrap = true,
    cursorline = true,
  }
end

function CommitComponent:get_layout_opts()
  return { flex = 1 }
end

function CommitComponent:on_mount()
  local confirm_key = self.props.confirm_key or '<C-s>'
  local cancel_key = self.props.cancel_key or 'q'

  self:with_element(function(el)
    el:set_keymap({ mode = { 'n', 'i' }, key = confirm_key, desc = 'Confirm commit' }, function()
      if self.props.on_confirm then self.props.on_confirm() end
    end)

    el:set_keymap({ mode = 'n', key = cancel_key, desc = 'Cancel commit' }, function()
      if self.props.on_cancel then self.props.on_cancel() end
    end)
  end)
end

return CommitComponent
