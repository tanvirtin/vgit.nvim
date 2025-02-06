local loop = require('vgit.core.loop')
local Object = require('vgit.core.Object')

local Spawn = Object:extend()

function Spawn:constructor(spec)
  return {
    spec = spec,
    stdout_buffer = {
      len = 0,
      index = 1,
      chunks = {},
    },
    stderr_buffer = {
      len = 0,
      index = 1,
      chunks = {},
    },
  }
end

function Spawn:process_chunk(chunk, buffer, callback)
  if not callback or not chunk then return end

  buffer.len = buffer.len + 1
  buffer.chunks[buffer.len] = chunk

  local line_parts = {}
  while buffer.index <= buffer.len do
    local current_chunk = buffer.chunks[buffer.index]

    if not current_chunk then
      buffer.index = buffer.index + 1
    else
      if #current_chunk == 0 then
        buffer.chunks[buffer.index] = nil
        buffer.index = buffer.index + 1
      else
        local newline_index = current_chunk:find('\n', 1, true)

        if not newline_index then
          buffer.index = buffer.index + 1
        else
          local remaining = current_chunk:sub(newline_index + 1)

          if buffer.index == 1 then
            callback(current_chunk:sub(1, newline_index - 1))
            buffer.chunks[1] = remaining
          else
            for i = 1, buffer.index - 1 do
              line_parts[#line_parts + 1] = buffer.chunks[i]
              buffer.chunks[i] = nil
            end
            line_parts[#line_parts + 1] = current_chunk:sub(1, newline_index - 1)
            callback(table.concat(line_parts))
            buffer.chunks[buffer.index] = remaining
            buffer.index = 1
            line_parts = {}
          end

          if #remaining == 0 then buffer.chunks[buffer.index] = nil end
        end
      end
    end
  end

  local compact = {}
  local new_len = 0
  for i = 1, buffer.len do
    if buffer.chunks[i] then
      new_len = new_len + 1
      compact[new_len] = buffer.chunks[i]
    end
  end

  buffer.chunks = compact
  buffer.len = new_len
  buffer.index = buffer.index > buffer.len and 1 or buffer.index
end

function Spawn:flush(buffer, cb)
  if not cb then return end
  if #buffer.chunks > 0 then
    local data = table.concat(buffer.chunks)
    cb(data)
    if data:sub(-1) == '\n' then cb('') end
  end

  buffer.chunks = {}
  buffer.index = 1
end

function Spawn:start()
  local stdout = vim.loop.new_pipe(false)
  local stderr = vim.loop.new_pipe(false)

  local on_stdout = function(_, chunk)
    self:process_chunk(chunk, self.stdout_buffer, self.spec.on_stdout)
  end

  local on_stderr = function(_, chunk)
    self:process_chunk(chunk, self.stderr_buffer, self.spec.on_stderr)
  end

  local on_exit = loop.coroutine(function(code, signal)
    stdout:read_stop()
    stderr:read_stop()
    stdout:close()
    stderr:close()

    self:flush(self.stdout_buffer, self.spec.on_stdout)
    self:flush(self.stderr_buffer, self.spec.on_stderr)

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
