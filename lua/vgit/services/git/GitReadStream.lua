local utils = require('vgit.core.utils')
local console = require('vgit.core.console')
local ReadStream = require('vgit.core.ReadStream')

local GitReadStream = ReadStream:extend()

function GitReadStream:constructor(...) return ReadStream.constructor(self, ...) end

function GitReadStream:start()
  console.debug.info(
    string.format(
      '%s %s',
      self.spec.command,
      utils.list.reduce(self.spec.args, '', function(acc, value) return string.format('%s %s', acc, value) end)
    )
  )

  ReadStream.start(self)
  return self
end

return GitReadStream
