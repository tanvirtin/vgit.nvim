local Object = require('vgit.core.Object')
local console = require('vgit.core.console')

local Store = Object:extend()

function Store:constructor()
  return {
    err = nil,
    data = nil,
    source = nil,
  }
end

function Store:reset()
  self.err = nil
  self.data = nil

  return self
end

function Store:fetch(source, opts)
  opts = opts or {}

  if not source then
    return { 'No source provided' }, nil
  end

  self:reset()

  self.err = nil
  self.data = console.debug.source[source]
  self.source = source

  if not self.data then
    return { string.format('Unknown debug source "%s"', source) }, nil
  end

  return self.err, self.data
end

function Store:get_lines() return self.err, self.data end

function Store:get_title() return nil, string.format('%s', self.source):gsub('^%l', string.upper) end

return Store
