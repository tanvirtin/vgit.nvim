local Object = require('vgit.core.Object')
local console = require('vgit.core.console')

local Query = Object:extend()

function Query:constructor()
  return {
    err = nil,
    data = nil,
    source = nil,
  }
end

function Query:reset()
  self.err = nil
  self.data = nil

  return self
end

function Query:fetch(source)
  if not source then
    return { 'No source provided' }, nil
  end

  self:reset()

  self.source = source
  self.err = nil
  self.data = console.debug.source[source]

  if not self.data then
    return { string.format('Unknown debug source "%s"', source) }, nil
  end

  return self.err, self.data
end

function Query:get_lines()
  return self.err, self.data
end

function Query:get_title()
  return nil, string.format('%s', self.source):gsub('^%l', string.upper)
end

return Query
