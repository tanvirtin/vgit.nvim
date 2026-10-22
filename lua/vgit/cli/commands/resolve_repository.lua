local lazy = require('vgit.core.lazy')

local console = lazy('vgit.core.console')
local repository = lazy('vgit.git.repository')

return function()
  local repo, err = repository.current()
  if repo then return repo, nil end

  local repos = repository.list()
  if #repos == 0 then return nil, err end
  if #repos == 1 then return repos[1], nil end

  local choice = console.select(repos, {
    prompt = 'Choose a repository',
    format_item = function(item)
      return item:get_name()
    end,
  })
  if not choice then return nil, { 'No repository selected' } end

  return choice, nil
end
