local fs = require('vgit.core.fs')
local utils = require('vgit.core.utils')
local Object = require('vgit.core.Object')

local File = Object:extend()

function File:constructor(filename, status, log)
  local is_dir = fs.is_dir(filename)
  local dirname = fs.dirname(filename)
  local filetype = fs.detect_filetype(filename)

  return {
    id = utils.math.uuid(),
    is_dir = is_dir,
    dirname = dirname,
    filename = filename,
    filetype = filetype,
    status = status,
    log = log,
  }
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
