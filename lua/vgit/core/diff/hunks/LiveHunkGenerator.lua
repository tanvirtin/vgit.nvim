local lazy = require('vgit.core.lazy')
local GitHunk = lazy('vgit.git.GitHunk')
local assertion = lazy('vgit.core.assertion')
local HunkGenerator = lazy('vgit.core.diff.hunks.HunkGenerator')

local LiveHunkGenerator = HunkGenerator:extend()

function LiveHunkGenerator:_determine_type(count_o, count_c)
  if count_o == 0 and count_c > 0 then
    return 'add'
  elseif count_o > 0 and count_c == 0 then
    return 'remove'
  else
    return 'change'
  end
end

function LiveHunkGenerator:_create_hunk(start_o, count_o, start_c, count_c, orig, curr)
  local hunk = GitHunk()
  hunk.top = start_c
  hunk.bot = start_c + math.max(count_c - 1, 0)
  hunk.type = self:_determine_type(count_o, count_c)

  for i = 1, count_o do
    if orig[start_o + i - 1] then hunk:push('-' .. orig[start_o + i - 1]) end
  end

  for i = 1, count_c do
    if curr[start_c + i - 1] then hunk:push('+' .. curr[start_c + i - 1]) end
  end

  hunk.header = hunk:generate_header({ start_o, count_o }, { start_c, count_c })

  return hunk
end

function LiveHunkGenerator:generate(original_lines, current_lines, opts)
  opts = opts or {}

  assertion.assert(original_lines, 'original_lines is required').assert(current_lines, 'current_lines is required')

  local hunks = {}

  vim.diff(table.concat(original_lines, '\n'), table.concat(current_lines, '\n'), {
    on_hunk = function(start_o, count_o, start_c, count_c)
      local hunk = self:_create_hunk(start_o, count_o, start_c, count_c, original_lines, current_lines)
      hunks[#hunks + 1] = hunk
    end,
    algorithm = opts.algorithm or 'myers',
  })

  return hunks
end

return LiveHunkGenerator
