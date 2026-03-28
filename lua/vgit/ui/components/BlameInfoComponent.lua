local lazy = require('vgit.core.lazy')

local Component = lazy('vgit.ui.Component')

local BlameInfoComponent = Component({
  win_options = {
    winhl = 'Normal:GitBackground',
    cursorline = false,
    wrap = false,
  },
  layout_opts = { height = 3 },

  on_mount = function(self)
    self:render()
  end,

  on_props = function(self, prev_props)
    if self.props.blame ~= prev_props.blame then self:render() end
  end,
})

function BlameInfoComponent:render()
  local blame = self.props.blame
  if not blame then return end

  local max_line_length = 88
  local commit_message = blame.commit_message or ''

  if #commit_message > max_line_length then commit_message = commit_message:sub(1, max_line_length) .. '...' end

  local commit_details = blame.commit_hash
  if blame.parent_hash then commit_details = string.format('%s -> %s', blame.parent_hash, blame.commit_hash) end

  local lines = {
    commit_details,
    string.format('%s (%s)', blame.author, blame.author_mail),
    commit_message,
  }

  self:with_element(function(el)
    el:set_lines(lines)
    el:clear_extmarks()

    if lines[1]:match('^[a-f0-9]+%s*%->%s*[a-f0-9]+$') then
      el:place_extmark_highlight({
        hl = 'Character',
        pattern = '^([a-f0-9]+)',
        row = 0,
      })
      el:place_extmark_highlight({
        hl = 'Constant',
        pattern = '([a-f0-9]+)$',
        row = 0,
      })
    else
      el:place_extmark_highlight({
        hl = 'Constant',
        row = 0,
        col_range = {
          from = 0,
          to = #lines[1],
        },
      })
    end

    local age = blame:age()
    if age then
      el:place_extmark_text({
        text = string.format('%s (%s)', age.display, os.date('%c', blame.author_time)),
        hl = 'GitComment',
        row = 1,
        col = 0,
        pos = 'eol',
      })
    end
  end)
end

return BlameInfoComponent
