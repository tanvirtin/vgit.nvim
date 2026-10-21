local lazy = require('vgit.core.lazy')

local event = lazy('vgit.core.event')
local Object = lazy('vgit.core.Object')

local Spawn = Object:extend()

function Spawn:constructor(spec)
  return {
    ['$spec'] = spec,
    stdout_buffer = { parts = {} },
    stderr_buffer = { parts = {} },
  }
end

function Spawn:process_chunk(chunk, buffer, callback)
  if not callback or not chunk then return end

  local parts = buffer.parts
  local start = 1
  while true do
    local newline_index = chunk:find('\n', start, true)
    if not newline_index then break end

    local line = chunk:sub(start, newline_index - 1)
    if #parts > 0 then
      parts[#parts + 1] = line
      line = table.concat(parts)
      parts = {}
    end
    callback(line)
    start = newline_index + 1
  end

  if start <= #chunk then parts[#parts + 1] = chunk:sub(start) end
  buffer.parts = parts
end

function Spawn:flush(buffer, cb)
  if not cb then return end
  if #buffer.parts > 0 then cb(table.concat(buffer.parts)) end
  buffer.parts = {}
end

function Spawn:start()
  local stdin = self.spec.stdin and vim.uv.new_pipe(false) or nil
  local stdout = vim.uv.new_pipe(false)
  local stderr = vim.uv.new_pipe(false)

  local on_stdout = function(_, chunk)
    self:process_chunk(chunk, self.stdout_buffer, self.spec.on_stdout)
  end

  local on_stderr = function(_, chunk)
    self:process_chunk(chunk, self.stderr_buffer, self.spec.on_stderr)
  end

  local handle

  local on_exit = event.async(function(code, signal)
    stdout:read_stop()
    stderr:read_stop()
    stdout:close()
    stderr:close()
    if handle and not handle:is_closing() then handle:close() end

    self:flush(self.stdout_buffer, self.spec.on_stdout)
    self:flush(self.stderr_buffer, self.spec.on_stderr)

    if self.spec.on_exit then self.spec.on_exit(code, signal) end
  end)

  handle = vim.uv.spawn(self.spec.command, {
    args = self.spec.args,
    stdio = { stdin, stdout, stderr },
    cwd = self.spec.cwd,
    env = self.spec.env,
  }, on_exit)

  if not handle then
    if stdin then stdin:close() end
    stdout:close()
    stderr:close()
    if self.spec.on_exit then self.spec.on_exit(1) end
    return self
  end

  stdout:read_start(on_stdout)
  stderr:read_start(on_stderr)

  if stdin then
    stdin:write(self.spec.stdin)
    stdin:shutdown(function()
      stdin:close()
    end)
  end

  return self
end

return Spawn
