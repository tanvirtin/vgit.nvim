local loop = require('vgit.core.loop')
local Object = require('vgit.core.Object')

local Spawn = Object:extend()

function Spawn:constructor(spec)
  return { spec = spec }
end

function Spawn:parse_result(output, callback)
  if not callback then return end

  output = table.concat(output)

  local start = 1
  while true do
    local newline_pos = output:find('\n', start, true)
    if not newline_pos then
      -- Last line without newline
      if start <= #output then
        callback(output:sub(start))
      end
      break
    end
    callback(output:sub(start, newline_pos - 1))
    start = newline_pos + 1
  end
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
