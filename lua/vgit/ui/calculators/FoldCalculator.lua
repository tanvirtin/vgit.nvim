local FoldCalculator = {}

function FoldCalculator.calculate_folds(marks, line_count, num_focus_lines)
  num_focus_lines = num_focus_lines or 7
  local folds = {}

  if #marks == 0 or line_count < num_focus_lines * 4 then return folds end

  for i = 1, #marks do
    local previous_mark = marks[i - 1]
    local mark = marks[i]
    local next_mark = marks[i + 1]

    if not previous_mark then
      local top = num_focus_lines + 1
      local bot = mark.top - num_focus_lines - 1
      if top <= bot and bot <= line_count and (bot - top + 1) >= 10 then
        folds[#folds + 1] = { top = top, bot = bot }
      end
    end

    if previous_mark then
      local top = previous_mark.bot + num_focus_lines + 1
      local bot = mark.top - num_focus_lines - 1
      if top <= bot and bot <= line_count and (bot - top + 1) >= 10 then
        folds[#folds + 1] = { top = top, bot = bot }
      end
    end

    if not next_mark then
      local top = mark.bot + num_focus_lines + 1
      local bot = line_count - num_focus_lines
      if top <= bot and bot <= line_count and (bot - top + 1) >= 10 then
        folds[#folds + 1] = { top = top, bot = bot }
      end
    end
  end

  return folds
end

return FoldCalculator
