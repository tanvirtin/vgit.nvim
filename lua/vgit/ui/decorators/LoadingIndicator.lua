local lazy = require('vgit.core.lazy')

local Object = lazy('vgit.core.Object')

local frames = { '· · ·', '· · ●', '· ● ●', '● ● ●', '· ● ●', '· · ●', '· · ·' }

local LoadingIndicator = Object:extend()

function LoadingIndicator:constructor()
  return {
    _active = false,
    _frame = 1,
    _timer = nil,
  }
end

function LoadingIndicator:start(on_frame)
  if self._active then return end
  self._active = true
  self._frame = 1

  self._timer = vim.uv.new_timer()
  self._timer:start(0, 150, vim.schedule_wrap(function()
    if not self._active then
      self:stop()
      return
    end
    self._frame = (self._frame % #frames) + 1
    if on_frame then on_frame() end
  end))
end

function LoadingIndicator:stop()
  self._active = false

  if self._timer then
    if not self._timer:is_closing() then
      self._timer:stop()
      self._timer:close()
    end
    self._timer = nil
  end
end

function LoadingIndicator:is_active()
  return self._active
end

function LoadingIndicator:render(element)
  if not element or not element:is_valid() then return end

  element:clear_extmark_highlights()

  local frame = frames[self._frame]
  local height = element:get_height()
  local width = element:get_width()

  local vertical_pad = math.max(0, math.floor((height - 1) / 2))
  local horizontal_pad = math.max(0, math.floor((width - #frame) / 2))

  local lines = {}
  for _ = 1, vertical_pad do
    lines[#lines + 1] = ''
  end
  lines[#lines + 1] = string.rep(' ', horizontal_pad) .. frame

  element:set_lines(lines)
  element:place_extmark_highlight({
    hl = 'GitComment',
    row = vertical_pad,
    col_range = { from = 0, to = horizontal_pad + #frame },
  })
end

return LoadingIndicator
