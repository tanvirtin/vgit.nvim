local Object = require('vgit.core.Object')
local Job = Object:extend()

function Job:new(spec)
  return setmetatable({
    spec = spec,
  }, Job)
end

function Job:parse_result(output, callback)
  if not callback then
    return
  end
  local line = ''
  for i = 1, #output do
    local char = output:sub(i, i)
    if char == '\n' then
      callback(line)
      line = ''
    else
      line = line .. char
    end
  end
  if #line ~= 0 then
    callback(line)
  end
end

function Job:start()
  local stdout_result = ''
  local stderr_result = ''

  local stdout = vim.loop.new_pipe(false)
  local stderr = vim.loop.new_pipe(false)

  vim.loop.spawn(self.spec.command, {
    args = self.spec.args,
    stdio = { nil, stdout, stderr },
    cwd = self.spec.cwd,
  }, function(code, signal)
    stdout:read_stop()
    stderr:read_stop()

    if not stdout:is_closing() then
      stdout:close()
    end
    if not stderr:is_closing() then
      stderr:close()
    end

    self:parse_result(stdout_result, self.spec.on_stdout)
    self:parse_result(stderr_result, self.spec.on_stderr)

    if self.spec.on_exit then
      self.spec.on_exit(code, signal)
    end
  end)

  stdout:read_start(function(_, chunk)
    if chunk then
      stdout_result = stdout_result .. chunk
    end
  end)

  stderr:read_start(function(_, chunk)
    if chunk then
      stderr_result = stderr_result .. chunk
    end
  end)

  return self
end

return Job
