local fs = require('vgit.core.fs')
local Status = require('vgit.cli.models.Status')
local Object = require('vgit.core.Object')

local File = Object:extend()

function File:new(line)
  local filename = line:sub(4, #line)
  local is_dir = fs.is_dir(filename)
  return setmetatable({
    is_dir = is_dir,
    filename = filename,
    filetype = not is_dir and fs.detect_filetype(filename) or nil,
    status = not is_dir and Status:new(line:sub(1, 2)) or nil,
  }, File)
end

function File:is_untracked()
  return self.status:has('??')
end

function File:is_staged()
  return self.status:has('* ')
end

function File:is_unstaged()
  return self.status:has(' *')
end

return File
