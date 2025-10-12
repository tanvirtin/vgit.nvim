local GitHunk = require('vgit.git.GitHunk')
local HunkGenerator = require('vgit.core.diff.hunks.HunkGenerator')

local CustomHunkGenerator = HunkGenerator:extend()

function CustomHunkGenerator:generate(lines, opts)
  opts = opts or {}

  if opts.untracked then
    return self:_generate_untracked(lines)
  elseif opts.deleted then
    return self:_generate_deleted(lines)
  end

  return {}
end

function CustomHunkGenerator:_generate_untracked(lines)
  if not lines or #lines == 0 then return {} end

  local hunk = GitHunk()
  hunk.type = 'add'
  hunk.header = string.format('@@ -0,0 +1,%d @@', #lines)
  hunk.top = 1
  hunk.bot = #lines

  for _, line in ipairs(lines) do
    hunk:push('+' .. line)
  end

  return { hunk }
end

function CustomHunkGenerator:_generate_deleted(lines)
  if not lines or #lines == 0 then return {} end

  local hunk = GitHunk()
  hunk.type = 'remove'
  hunk.header = string.format('@@ -1,%d +0,0 @@', #lines)
  hunk.top = 1
  hunk.bot = #lines

  for _, line in ipairs(lines) do
    hunk:push('-' .. line)
  end

  return { hunk }
end

return CustomHunkGenerator
