local utils = require('vgit.core.utils')

local eq = assert.are.same
local matches = assert.matches

describe('utils.math:', function()
  describe('round', function()
    it('should round pi to 3', function()
      eq(utils.math.round(3.14159265359), 3)
    end)

    it('should round 2.5 to 3', function()
      eq(utils.math.round(2.5), 3)
    end)

    it('should round 2.4 to 2', function()
      eq(utils.math.round(2.4), 2)
    end)

    it('should round -2.5 to -3', function()
      eq(utils.math.round(-2.5), -3)
    end)

    it('should round -2.4 to -2', function()
      eq(utils.math.round(-2.4), -2)
    end)
  end)

  describe('uuid', function()
    it('should generate a valid UUID', function()
      local uuid = utils.math.uuid()
      matches('^[0-9a-fA-F-]+$', uuid) -- Check if the UUID is in the correct format
      eq(#uuid, 36) -- Check if the UUID has the correct length
    end)
  end)

  describe('scale_unit_up', function()
    it('should scale unit up by 50%', function()
      eq(utils.math.scale_unit_up(100, 50), 150)
    end)

    it('should scale unit up by 20%', function()
      eq(utils.math.scale_unit_up(200, 20), 240)
    end)
  end)

  describe('scale_unit_down', function()
    it('should scale unit down by 50%', function()
      eq(utils.math.scale_unit_down(100, 50), 50)
    end)

    it('should scale unit down by 20%', function()
      eq(utils.math.scale_unit_down(200, 20), 160)
    end)

    it('should not scale unit below 1', function()
      eq(utils.math.scale_unit_down(1, 50), 1)
    end)
  end)
end)
