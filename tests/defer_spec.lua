local defer = require('git.defer')

local it = it
local describe = describe

describe('defer:', function()

      describe('throttle_leading', function()
        local closure_creator = function(initial_value)
            local counter = initial_value
            return function()
                counter = counter + 1
                return counter
            end
        end

        it('should not execute function more than once in the given time', function()
            local result = nil
            local closure = closure_creator(1)
            local throttled_fn = defer.throttle_leading(function()
                result = closure()
                assert.are.same(result, 1)
            end, 100)
            for _ = 1, 1000 do
                throttled_fn()
            end
        end)

    end)

end)
