local vim = vim
local uv = vim.loop

local Object = require('plenary.class')
local F = require('plenary.functional')

local Job = Object:extend()

local function close_safely(j, key)
  local handle = j[key]
  if not handle then
    return
  end
  if not handle:is_closing() then
    handle:close()
  end
end

local start_shutdown_check = function(child, options, code, signal)
  uv.check_start(child._shutdown_check, function()
    if not child:_pipes_are_closed(options) then
      return
    end
    uv.check_stop(child._shutdown_check)
    child._shutdown_check = nil
    child:_shutdown(code, signal)
    child = nil
  end)
end

local shutdown_factory = function(child, options)
  return function(code, signal)
    if uv.is_closing(child._shutdown_check) then
      return child:shutdown(code, signal)
    else
      start_shutdown_check(child, options, code, signal)
    end
  end
end

local function expand(path)
  if vim.in_fast_event() then
    return assert(
      uv.fs_realpath(path),
      string.format('Path must be valid: %s', path)
    )
  else
    return vim.fn.expand(path, true)
  end
end

function Job:new(o)
  if not o then
    error(debug.traceback('Options are required for Job:new'))
  end
  local command = o.command
  if not command then
    if o[1] then
      command = o[1]
    else
      error(debug.traceback('\'command\' is required for Job:new'))
    end
  elseif o[1] then
    error(debug.traceback('Cannot pass both \'command\' and array args'))
  end
  local args = o.args
  if not args then
    if #o > 1 then
      args = { select(2, unpack(o)) }
    end
  end
  local ok, is_exe = pcall(vim.fn.executable, command)
  if not o.skip_validation and ok and 1 ~= is_exe then
    error(debug.traceback(command .. ': Executable not found'))
  end
  local obj = {}
  obj.command = command
  obj.args = args
  obj._raw_cwd = o.cwd
  if o.env then
    if type(o.env) ~= 'table' then
      error('[plenary.job] env has to be a table')
    end
    local transform = {}
    for k, v in pairs(o.env) do
      if type(k) == 'number' then
        table.insert(transform, v)
      elseif type(k) == 'string' then
        table.insert(transform, k .. '=' .. tostring(v))
      end
    end
    obj.env = transform
  end
  if o.interactive == nil then
    obj.interactive = true
  else
    obj.interactive = o.interactive
  end
  obj.enable_handlers = F.if_nil(o.enable_handlers, true, o.enable_handlers)
  obj.enable_recording = F.if_nil(
    F.if_nil(o.enable_recording, o.enable_handlers, o.enable_recording),
    true,
    o.enable_recording
  )
  if not obj.enable_handlers and obj.enable_recording then
    error('[plenary.job] Cannot record items but disable handlers')
  end
  obj._user_on_start = o.on_start
  obj._user_on_stdout = o.on_stdout
  obj._user_on_stderr = o.on_stderr
  obj._user_on_exit = o.on_exit
  obj._maximum_results = o.maximum_results
  obj.user_data = {}
  self._reset(obj)
  return setmetatable(obj, self)
end

function Job:_reset()
  self.is_shutdown = nil
  if
    self._shutdown_check
    and uv.is_active(self._shutdown_check)
    and not uv.is_closing(self._shutdown_check)
  then
    vim.api.nvim_err_writeln(
      debug.traceback('We may be memory leaking here. Please report to TJ.')
    )
  end
  self._shutdown_check = uv.new_check()
  self.stdout = nil
  self.stderr = nil
  self._stdout_reader = nil
  self._stderr_reader = nil
  if self.enable_recording then
    self._stdout_results = {}
    self._stderr_results = {}
  else
    self._stdout_results = nil
    self._stderr_results = nil
  end
end

function Job:_stop()
  close_safely(self, 'stdin')
  close_safely(self, 'stderr')
  close_safely(self, 'stdout')
  close_safely(self, 'handle')
end

function Job:_pipes_are_closed(options)
  for _, pipe in ipairs({ options.stdin, options.stdout, options.stderr }) do
    if pipe and not uv.is_closing(pipe) then
      return false
    end
  end
  return true
end

function Job:shutdown(code, signal)
  if not uv.is_active(self._shutdown_check) then
    vim.wait(1000, function()
      return self:_pipes_are_closed(self) and self.is_shutdown
    end, 1, true)
  end
  self:_shutdown(code, signal)
end

function Job:_shutdown(code, signal)
  if self.is_shutdown then
    return
  end
  self.code = code
  self.signal = signal
  if self._stdout_reader then
    pcall(self._stdout_reader, nil, nil, true)
  end
  if self._stderr_reader then
    pcall(self._stderr_reader, nil, nil, true)
  end
  if self._user_on_exit then
    self:_user_on_exit(code, signal)
  end
  if self.stdout then
    self.stdout:read_stop()
  end
  if self.stderr then
    self.stderr:read_stop()
  end
  self:_stop()
  self.is_shutdown = true
  self._stdout_reader = nil
  self._stderr_reader = nil
end

function Job:_create_uv_options()
  local options = {}
  options.command = self.command
  options.args = self.args
  options.stdio = { self.stdin, self.stdout, self.stderr }
  if self._raw_cwd then
    options.cwd = expand(self._raw_cwd)
  end
  if self.env then
    options.env = self.env
  end
  return options
end

local on_output = function(self, result_key, cb)
  return coroutine.wrap(function(err, data, is_complete)
    local result_index = 1
    local line, start, result_line, found_newline
    while true do
      if data then
        data = data:gsub('\r', '')
        local processed_index = 1
        local data_length = #data + 1
        repeat
          start = string.find(data, '\n', processed_index, true) or data_length
          line = string.sub(data, processed_index, start - 1)
          found_newline = start ~= data_length
          if result_line then
            result_line = result_line .. line
          elseif start ~= processed_index or found_newline then
            result_line = line
          end
          if found_newline then
            if not result_line then
              return vim.api.nvim_err_writeln(
                'Broken data thing due to: '
                  .. tostring(result_line)
                  .. ' '
                  .. tostring(data)
              )
            end
            if self.enable_recording then
              self[result_key][result_index] = result_line
            end
            if cb then
              cb(err, result_line, self)
            end
            if
              self._maximum_results and result_index > self._maximum_results
            then
              vim.schedule(function()
                self:shutdown()
              end)
              return
            end
            result_index = result_index + 1
            result_line = nil
          end
          processed_index = start + 1
        until not found_newline
      end
      if self.enable_recording then
        self[result_key][result_index] = result_line
      end
      if cb and is_complete and not found_newline then
        cb(err, result_line, self)
      end
      if (data == nil and not result_line) or is_complete then
        return
      end
      err, data, is_complete = coroutine.yield()
    end
  end)
end

function Job:_prepare_pipes()
  self:_stop()
  self.stdout = uv.new_pipe(false)
  self.stderr = uv.new_pipe(false)
end

function Job:_execute()
  local options = self:_create_uv_options()
  if self._user_on_start then
    self:_user_on_start()
  end
  self.handle, self.pid = uv.spawn(
    options.command,
    options,
    shutdown_factory(self, options)
  )
  if not self.handle then
    error(debug.traceback('Failed to spawn process: ' .. vim.inspect(self)))
  end
  if self.enable_handlers then
    self._stdout_reader = on_output(
      self,
      '_stdout_results',
      self._user_on_stdout
    )
    self.stdout:read_start(self._stdout_reader)
    self._stderr_reader = on_output(
      self,
      '_stderr_results',
      self._user_on_stderr
    )
    self.stderr:read_start(self._stderr_reader)
  end
  return self
end

function Job:start()
  self:_reset()
  self:_prepare_pipes()
  self:_execute()
end

function Job.is_job(item)
  if type(item) ~= 'table' then
    return false
  end
  return getmetatable(item) == Job
end

return Job
