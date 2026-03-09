local M = {}

function M.create(overrides)
  local mock = {
    await = function() end,
    async = function(fn)
      return fn
    end,
    debounce = function(fn)
      return fn, function() end
    end,
    debounce_async = function(fn)
      return fn, function() end
    end,
    on = function() end,
    emit = function() end,
    custom_on = function()
      return function() end
    end,
    buffer_on = function() end,
    promisify = function(fn)
      return fn
    end,
    group = 'VGitGroup',
    register_module = function() end,
  }

  if overrides then
    for k, v in pairs(overrides) do
      mock[k] = v
    end
  end

  return mock
end

function M.install(overrides)
  local mock = M.create(overrides)
  package.loaded['vgit.core.event'] = mock

  return mock
end

return M
