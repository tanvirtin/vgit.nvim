local Object = require('vgit.core.Object')

local Hunk = Object:extend()

function Hunk:parse_header(header)
  header = header or self.header
  local diffkey = vim.trim(vim.split(header, '@@', true)[2])
  local parsed_diffkey = vim.split(diffkey, ' ')
  local parsed_header = {}
  for i = 1, #parsed_diffkey do
    parsed_header[#parsed_header + 1] = vim.split(
      string.sub(parsed_diffkey[i], 2),
      ','
    )
  end
  local previous, current = parsed_header[1], parsed_header[2]
  previous[1] = tonumber(previous[1])
  previous[2] = tonumber(previous[2]) or 1
  current[1] = tonumber(current[1])
  current[2] = tonumber(current[2]) or 1
  return previous, current
end

function Hunk:reconstruct_header(parsed_header)
  local previous, current = unpack(parsed_header)
  return string.format(
    '@@ -%s,%s +%s,%s @@',
    previous[1],
    previous[2],
    current[1],
    current[2]
  )
end

function Hunk:parse_diff(diff)
  diff = diff or self.diff
  local removed_lines = {}
  local added_lines = {}
  for i = 1, #diff do
    local line = diff[i]
    local type = line:sub(1, 1)
    local cleaned_diff_line = line:sub(2, #line)
    if type == '+' then
      added_lines[#added_lines + 1] = cleaned_diff_line
    elseif type == '-' then
      removed_lines[#removed_lines + 1] = cleaned_diff_line
    end
  end
  return removed_lines, added_lines
end

function Hunk:append_diff_line(line)
  local stat = self.stat
  local type = line:sub(1, 1)
  if type == '+' then
    stat.added = stat.added + 1
  elseif type == '-' then
    stat.removed = stat.removed + 1
  end
  local diff = self.diff
  diff[#diff + 1] = line
end

function Hunk:new(header)
  if not header then
    return setmetatable({
      header = nil,
      start = nil,
      finish = nil,
      type = nil,
      diff = {},
      stat = {
        added = 0,
        removed = 0,
      },
    }, Hunk)
  end
  local previous, current
  if type(header) == 'string' then
    previous, current = self:parse_header(header)
  else
    previous, current = unpack(header)
    header = self:reconstruct_header(header)
  end
  local hunk = {
    header = header,
    start = current[1],
    finish = current[1] + current[2] - 1,
    type = nil,
    diff = {},
    stat = {
      added = 0,
      removed = 0,
    },
  }
  if current[2] == 0 then
    hunk.finish = hunk.start
    hunk.type = 'remove'
  elseif previous[2] == 0 then
    hunk.type = 'add'
  else
    hunk.type = 'change'
  end
  return setmetatable(hunk, Hunk)
end

return Hunk
