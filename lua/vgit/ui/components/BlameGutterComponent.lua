local lazy = require('vgit.core.lazy')

local Component = lazy('vgit.ui.Component')

local BlameGutterComponent = Component({
  win_options = {
    winhl = 'Normal:GitBackground',
    signcolumn = 'no',
    wrap = false,
    number = false,
    cursorline = true,
  },
  win_plot = { focusable = false },
  layout_opts = { width = '35%' },

  on_props = function(self, prev_props)
    if self.props.blames ~= prev_props.blames then self:render() end
  end,
})

function BlameGutterComponent:get_layout_spec()
  local LayoutSpec = require('vgit.ui.layout.LayoutSpec')
  return LayoutSpec.view(self._element, {
    width = self.props.width or '35%',
  })
end

function BlameGutterComponent:render()
  local blames = self.props.blames
  local get_author_hl = self.props.get_author_hl
  if not blames or not get_author_hl then return end

  local lines = {}
  local highlights = {}
  local line_highlights = {}
  local line_count = #blames
  local group_index = 0
  local blame_segments = {}

  local i = 1
  while i <= line_count do
    local blame = blames[i]
    local hash = blame.commit_hash or blame.hash
    local group_start = i

    while i <= line_count do
      local b = blames[i]
      local h = b.commit_hash or b.hash
      if h ~= hash then break end
      i = i + 1
    end
    local group_end = i - 1

    table.insert(blame_segments, { start = group_start, finish = group_end })

    local is_uncommitted = blame:is_uncommitted()
    local bg_hl = group_index % 2 == 0 and 'GitBlameEven' or 'GitBlameOdd'
    group_index = group_index + 1

    local short_hash = ''
    if not is_uncommitted then short_hash = (blame:short_hash() or ''):sub(1, 7) end

    local message = blame.message or blame.commit_message or ''
    if #message > 35 then message = message:sub(1, 34) .. '..' end

    local age_display = ''
    if blame.author_time then
      local age = blame:age()
      if age then age_display = age.display end
    end

    local author = blame.author or 'Unknown'
    if #author > 16 then author = author:sub(1, 15) .. '..' end

    local initial = ''
    if not is_uncommitted and #author > 0 then initial = author:sub(1, 1):upper() end

    local line1
    if is_uncommitted then
      line1 = '  Uncommitted'
    else
      line1 = string.format(' %s %s  %s  %s', initial, short_hash, message, age_display)
    end
    lines[#lines + 1] = line1
    line_highlights[#line_highlights + 1] = { row = group_start - 1, hl = bg_hl }

    if is_uncommitted then
      highlights[#highlights + 1] = {
        row = group_start - 1,
        hl = 'GitComment',
        from = 0,
        to = #line1,
      }
    else
      local author_hl = get_author_hl(author)
      highlights[#highlights + 1] = {
        row = group_start - 1,
        hl = author_hl,
        from = 1,
        to = 1 + #initial,
      }
      local hash_start = 1 + #initial + 1
      highlights[#highlights + 1] = {
        row = group_start - 1,
        hl = 'NonText',
        from = hash_start,
        to = hash_start + #short_hash,
      }
      local msg_start = hash_start + #short_hash + 2
      highlights[#highlights + 1] = {
        row = group_start - 1,
        hl = 'Normal',
        from = msg_start,
        to = msg_start + #message,
      }
      if #age_display > 0 then
        local age_start = msg_start + #message + 2
        highlights[#highlights + 1] = {
          row = group_start - 1,
          hl = 'GitComment',
          from = age_start,
          to = age_start + #age_display,
        }
      end
    end

    if group_end > group_start then
      local line2
      if is_uncommitted then
        line2 = '  '
      else
        local author_hl = get_author_hl(author)
        line2 = string.format('   %s', author)
        highlights[#highlights + 1] = {
          row = group_start,
          hl = author_hl,
          from = 3,
          to = 3 + #author,
        }
      end
      lines[#lines + 1] = line2
      line_highlights[#line_highlights + 1] = { row = group_start, hl = bg_hl }
    end

    for j = group_start + 2, group_end do
      lines[#lines + 1] = ''
      line_highlights[#line_highlights + 1] = { row = j - 1, hl = bg_hl }
    end
  end

  while #lines < line_count do
    lines[#lines + 1] = ''
  end

  self:with_element(function(el)
    el:set_lines(lines)
    el:clear_extmark_highlights()

    for _, lh in ipairs(line_highlights) do
      el:place_extmark_highlight({
        hl = lh.hl,
        row = lh.row,
        line_hl = true,
      })
    end

    for _, h in ipairs(highlights) do
      el:place_extmark_highlight({
        hl = h.hl,
        row = h.row,
        col_range = { from = h.from, to = h.to },
      })
    end
  end)

  return blame_segments
end

function BlameGutterComponent:render_blame(blames, get_author_hl)
  self:set_props({ blames = blames, get_author_hl = get_author_hl })
end

return BlameGutterComponent
