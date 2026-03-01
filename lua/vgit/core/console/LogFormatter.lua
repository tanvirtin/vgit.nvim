local utils = require('vgit.core.utils')
local Object = require('vgit.core.Object')
local assertion = require('vgit.core.assertion')

local LogFormatter = Object:extend()

function LogFormatter.clean(msg)
  local cleaned_msg = ''

  if type(msg) == 'string' then
    cleaned_msg = msg
  elseif type(msg) == 'table' and utils.list.is_list(msg) then
    msg = utils.list.filter(msg, function(entry)
      return type(entry) == 'string'
    end)

    if #msg == 1 then
      cleaned_msg = msg[1]
    elseif not utils.list.is_empty(msg) then
      cleaned_msg = msg
    end
  end

  return cleaned_msg
end

function LogFormatter:constructor(msg, opts)
  opts = utils.value.default(opts, {})
  opts.timestamp = utils.value.default(opts.timestamp, true)

  return {
    _is_formatted = false,
    _msg = LogFormatter.clean(msg),
    ['$_should_show_timestamp'] = opts.timestamp,
  }
end

function LogFormatter:add_prefix(line, log_type, fn_source, fn_name)
  local parts = { '[VGit]' }

  if not utils.value.is_nil(log_type) then
    assertion.assert_type(log_type, 'string')
    log_type = string.upper(log_type)
    parts[#parts + 1] = '[' .. log_type .. ']'
  end

  if self._should_show_timestamp then
    local timestamp = os.date('%H:%M:%S')
    parts[#parts + 1] = '[' .. timestamp .. ']'
  end

  if fn_source then
    assertion.assert_type(fn_source, 'string')
    parts[#parts + 1] = '[' .. fn_source .. ']'
  end
  if fn_name then
    assertion.assert_type(fn_name, 'string')
    parts[#parts + 1] = '[' .. fn_name .. ']'
  end

  parts[#parts + 1] = ' ' .. line

  return table.concat(parts, '')
end

function LogFormatter:add_indentation(line)
  assertion.assert_type(line, 'string')
  local indentation_template = '       %s'
  return string.format(indentation_template, line)
end

function LogFormatter:format(log_type, fn_source, fn_name)
  if self._is_formatted then return end

  self._is_formatted = true

  if type(self._msg) == 'string' then
    self._msg = self:add_prefix(self._msg, log_type, fn_source, fn_name)
    return self
  end

  self._msg = utils.list.reduce(self._msg, '', function(acc, line, i)
    if i == 1 then
      line = self:add_prefix(line, log_type, fn_source, fn_name)
      acc = string.format('%s\n', line)
    elseif i ~= #self._msg then
      line = self:add_indentation(line)
      acc = string.format('%s%s\n', acc, line)
    else
      line = self:add_indentation(line)
      acc = string.format('%s%s', acc, line)
    end

    return acc
  end)

  return self
end

function LogFormatter:value()
  return self._msg
end

return LogFormatter
