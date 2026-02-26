local lazy = require('vgit.core.lazy')

local Object = lazy('vgit.core.Object')

local FoldCalculator = Object:extend()

function FoldCalculator:calculate_folds(marks, line_count, num_focus_lines)
  num_focus_lines = num_focus_lines or 7
  local folds = {}

  if #marks == 0 or line_count < num_focus_lines * 4 then return folds end

  local function is_safe_fold(fold_top, fold_bot)
    for _, m in ipairs(marks) do
      if not (fold_bot < m.top or fold_top > m.bot) then return false end
    end
    return true
  end

  for i = 1, #marks do
    local previous_mark = marks[i - 1]
    local mark = marks[i]
    local next_mark = marks[i + 1]

    if not previous_mark then
      local top = num_focus_lines + 1
      local bot = mark.top - num_focus_lines - 1
      if top <= bot and bot <= line_count and (bot - top + 1) >= 10 and is_safe_fold(top, bot) then
        folds[#folds + 1] = { top = top, bot = bot }
      end
    end

    if previous_mark then
      local top = previous_mark.bot + num_focus_lines + 1
      local bot = mark.top - num_focus_lines - 1
      if top <= bot and bot <= line_count and (bot - top + 1) >= 10 and is_safe_fold(top, bot) then
        folds[#folds + 1] = { top = top, bot = bot }
      end
    end

    if not next_mark then
      local top = mark.bot + num_focus_lines + 1
      local bot = line_count - num_focus_lines
      if
        top <= bot
        and top <= line_count
        and bot <= line_count
        and (bot - top + 1) >= 10
        and is_safe_fold(top, bot)
      then
        folds[#folds + 1] = { top = top, bot = bot }
      end
    end
  end

  return folds
end

function FoldCalculator:apply_folds(element, folds)
  if #folds == 0 then return end

  element:call(function()
    for _, fold in ipairs(folds) do
      vim.cmd(string.format('%s,%sfold', fold.top, fold.bot))
    end
  end)
end

function FoldCalculator:clear_folds(element)
  element:call(function()
    vim.api.nvim_command('normal! zR')
  end)
end

return FoldCalculator
