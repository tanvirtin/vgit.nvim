local mock = require('luassert.mock')
local utils = require('vgit.core.utils')

local eq = assert.are.same

describe('utils.date:', function()
  describe('date.format', function()
    it('should format the date using the default format', function()
      local time = 1609477200  -- January 1, 2021
      local formatted_date = utils.date.format(time)
      assert.are.equal(formatted_date, '01 Jan 2021')
    end)

    it('should format the date using a custom format', function()
      local current_time = os.time({ year = 2021, month = 1, day = 1, hour = 5, min = 0, sec = 0 })
      local formatted_date = utils.date.format(current_time, '%Y-%m-%d %H:%M:%S')
      eq(formatted_date, '2021-01-01 05:00:00')
    end)

    it('should handle invalid time input gracefully', function()
      local invalid_time = 'invalid'
      local formatted_date = utils.date.format(invalid_time)
      local expected_date = os.date('%d %b %Y', os.time())  -- Use the current date
      assert.are.equal(formatted_date, expected_date)
    end)

    it('should handle nil time input gracefully', function()
      local formatted_date = utils.date.format(nil)
      local expected_date = os.date('%d %b %Y', os.time())  -- Use the current date
      assert.are.equal(formatted_date, expected_date)
    end)

    it('should handle nil format input gracefully', function()
      local time = 1609477200  -- January 1, 2021
      local formatted_date = utils.date.format(time, nil)
      assert.are.equal(formatted_date, '01 Jan 2021')
    end)
  end)

  describe('age', function()
    before_each(function()
      os.time = mock(os.time, true)
    end)

    after_each(function()
      mock.revert(os.time)
    end)

    it('should handle a single second', function()
      local current_time = 1609477202
      local blame_time = 1609477201

      os.time.returns(current_time)

      local age = utils.date.age(blame_time)

      eq(age.unit, 1)
      eq(age.how_long, 'second')
      eq(age.display, '1 second ago')
    end)

    it('should handle seconds', function()
      local current_time = 1609477205
      local blame_time = 1609477200

      os.time.returns(current_time)

      local age = utils.date.age(blame_time)

      eq(age.unit, 5)
      eq(age.how_long, 'seconds')
      eq(age.display, '5 seconds ago')
    end)

    it('should handle a single minute', function()
      local current_time = 1609477320
      local blame_time = 1609477260

      os.time.returns(current_time)

      local age = utils.date.age(blame_time)

      eq(age.unit, 1)
      eq(age.how_long, 'minute')
      eq(age.display, '1 minute ago')
    end)

    it('should handle minutes', function()
      local current_time = 1609477500
      local blame_time = 1609477200

      os.time.returns(current_time)

      local age = utils.date.age(blame_time)
      eq(age.unit, 5)
      eq(age.how_long, 'minutes')
      eq(age.display, '5 minutes ago')
    end)

    it('should handle a single hour', function()
      local current_time = 1609484400
      local blame_time = 1609480800

      os.time.returns(current_time)

      local age = utils.date.age(blame_time)

      eq(age.unit, 1)
      eq(age.how_long, 'hour')
      eq(age.display, '1 hour ago')
    end)

    it('should handle hours', function()
      local current_time = 1609495200
      local blame_time = 1609477200

      os.time.returns(current_time)

      local age = utils.date.age(blame_time)

      eq(age.unit, 5)
      eq(age.how_long, 'hours')
      eq(age.display, '5 hours ago')
    end)

    it('should handle days', function()
      local current_time = 1609822800
      local blame_time = 1609477200

      os.time.returns(current_time)

      local age = utils.date.age(blame_time)

      eq(age.unit, 4)
      eq(age.how_long, 'days')
      eq(age.display, '4 days ago')
    end)

    it('should handle a single month', function()
      local current_time = 1612155600
      local blame_time = 1609477200

      os.time.returns(current_time)

      local age = utils.date.age(blame_time)

      eq(age.unit, 1)
      eq(age.how_long, 'month')
      eq(age.display, '1 month ago')
    end)

    it('should handle months', function()
      local current_time = 1619841600
      local blame_time = 1609477200

      os.time.returns(current_time)

      local age = utils.date.age(blame_time)

      eq(age.unit, 4)
      eq(age.how_long, 'months')
      eq(age.display, '4 months ago')
    end)

    it('should handle a single year', function()
      local current_time = 1641020885
      local blame_time = 1609484885

      os.time.returns(current_time)

      local age = utils.date.age(blame_time)

      eq(age.unit, 1)
      eq(age.how_long, 'year')
      eq(age.display, '1 year ago')
    end)

    it('should handle years', function()
      local current_time = 1609477200
      local blame_time = 1451624400

      os.time.returns(current_time)

      local age = utils.date.age(blame_time)

      eq(age.unit, 5)
      eq(age.how_long, 'years')
      eq(age.display, '5 years ago')
    end)
  end)
end)
