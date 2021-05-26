local Bstate = require('vgit.Bstate')

local it = it
local describe = describe
local eq = assert.are.same

describe('Bstate:', function()

    describe('new', function()

        it('should create a Bstate object', function()
            local bstate = Bstate.new()
            eq(bstate, { bufs = {} })
        end)

    end)

    describe('add', function()

        it('should save a buf id and create necessary buf_state', function()
            local bstate = Bstate.new()
            for i = 1, 2, 1 do
                bstate:add(i)
            end
            eq(bstate.bufs, {
                ['1'] = {
                    current = {
                        blame_is_shown = false,
                        blames = {},
                        disabled = false,
                        hunks = {},
                        last_lnum = 1,
                        logs = {},
                    },
                    initial = {
                        blame_is_shown = false,
                        blames = {},
                        disabled = false,
                        hunks = {},
                        last_lnum = 1,
                        logs = {},
                    }
                },
                ['2'] = {
                    current = {
                        blame_is_shown = false,
                        blames = {},
                        disabled = false,
                        hunks = {},
                        last_lnum = 1,
                        logs = {},
                    },
                    initial = {
                        blame_is_shown = false,
                        blames = {},
                        disabled = false,
                        hunks = {},
                        last_lnum = 1,
                        logs = {},
                    }
                },
            })
        end)
    end)

    describe('contains', function()

        it('should return true for a given buf number if it exists in the object', function()
            local bstate = Bstate.new()
            local num_bufs = 100
            for i = 1, num_bufs, 1 do
                bstate:add(i)
            end
            for i = 1, num_bufs, 1 do
                assert(bstate:contains(i))
            end
        end)

        it('should return false for a buf number that does not exist in the object', function()
            local bstate = Bstate.new()
            local num_bufs = 100
            for i = 1, num_bufs, 1 do
                bstate:add(i)
            end
            for i = 101, num_bufs, 1 do
                eq(bstate:contains(i), false)
            end
        end)

    end)

--     describe('remove', function()
--         local bstate = Bstate.new()
--         local num_bufs = 100
--         for i = 1, num_bufs, 1 do
--             bstate:add(i)
--         end
--         bstate:remove(10)
--         bstate:remove(20)
--         bstate:remove(100)
--         bstate:remove(200)

--         eq(bstate:contains(20), false)
--         eq(bstate:contains(20), false)
--         eq(bstate:contains(20), false)
--     end)

end)
