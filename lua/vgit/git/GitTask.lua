local lazy = require('vgit.core.lazy')

local Object = lazy('vgit.core.Object')

local GitTask = Object:extend()

function GitTask:constructor(task, resolve)
  return {
    ['$_task'] = task,
    ['$_resolve'] = resolve,
  }
end

function GitTask:is_done()
  return self._task:completed()
end

function GitTask:wait()
  return self._resolve(self._task)
end

function GitTask:map(fn)
  local resolve = self._resolve
  return GitTask(self._task, function(task)
    local result, err = resolve(task)
    if err then return nil, err end
    return fn(result)
  end)
end

return GitTask
