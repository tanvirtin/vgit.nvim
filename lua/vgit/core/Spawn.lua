local loop = require('vgit.core.loop')
local Object = require('vgit.core.Object')

local Spawn = Object:extend()

function Spawn:constructor(spec)
  return { spec = spec }
end

function Spawn:parse_result(output, callback)
  if not callback then return end

  local line = {}
  output = table.concat(output)

  for i = 1, #output do
    local char = output:sub(i, i)
    if char == '\n' then
      callback(table.concat(line))
      line = {}
    else
      line[#line + 1] = char
    end
  end

  if #line > 0 then callback(table.concat(line)) end
end

function Spawn:start()
  local stdout_result = {}
  local stderr_result = {}
  local stdout = vim.loop.new_pipe(false)
  local stderr = vim.loop.new_pipe(false)

  local on_stdout = function(_, chunk)
    if chunk then stdout_result[#stdout_result + 1] = chunk end
  end

  local on_stderr = function(_, chunk)
    if chunk then stderr_result[#stderr_result + 1] = chunk end
  end

  local on_exit = loop.coroutine(function(code, signal)
    stdout:read_stop()
    stderr:read_stop()

    if not stdout:is_closing() then stdout:close() end
    if not stderr:is_closing() then stderr:close() end

    self:parse_result(stdout_result, self.spec.on_stdout)
    self:parse_result(stderr_result, self.spec.on_stderr)

    if self.spec.on_exit then self.spec.on_exit(code, signal) end
  end)

  vim.loop.spawn(self.spec.command, {
    args = self.spec.args,
    stdio = { nil, stdout, stderr },
    cwd = self.spec.cwd,
  }, on_exit)

  stdout:read_start(on_stdout)
  stderr:read_start(on_stderr)

  return self
end

return Spawn
