local lazy = require('vgit.core.lazy')

local GitQueryBuilder = lazy('vgit.git.GitQueryBuilder')

local git_show = {}

local function object_name(filename, commit_hash)
  commit_hash = commit_hash or ''

  if commit_hash == 'index' then commit_hash = ':' end

  if commit_hash == ':' then return string.format(':%s', filename) end
  return string.format('%s:%s', commit_hash, filename)
end

local function parse_batch(output, count)
  local results = {}
  local i = 1

  for n = 1, count do
    local header = output[i]
    if not header then break end
    i = i + 1

    local size = tonumber(header:match('^%x+ %a+ (%d+)$'))
    if size then
      local lines = {}
      local consumed = 0
      while consumed < size + 1 and output[i] do
        lines[#lines + 1] = output[i]
        consumed = consumed + #output[i] + 1
        i = i + 1
      end
      if lines[#lines] == '' then lines[#lines] = nil end
      results[n] = lines
    end
  end

  return results
end

function git_show.lines(reponame, filename, commit_hash)
  if not reponame then return nil, { 'reponame is required' } end

  return GitQueryBuilder(reponame):show():raw_arg(object_name(filename, commit_hash)):execute()
end

function git_show.batch_lines(reponame, objects)
  if not reponame then return nil, { 'reponame is required' } end
  if #objects == 0 then return {} end

  local names = {}
  for i, object in ipairs(objects) do
    names[i] = object_name(object.filename, object.commit)
  end

  local output, err =
    GitQueryBuilder(reponame):raw_args('cat-file', '--batch'):execute({ stdin = table.concat(names, '\n') .. '\n' })
  if err then return nil, err end

  return parse_batch(output, #objects)
end

return git_show
