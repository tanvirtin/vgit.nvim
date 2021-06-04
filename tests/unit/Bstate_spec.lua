local Bstate = require('vgit.Bstate')

local vim = vim
local it = it
local describe = describe
local eq = assert.are.same

describe('Bstate:', function()

    local atomic_buf_state = {
        blames = {},
        disabled = false,
        filename = '',
        filetype = '',
        project_relative_filename = '',
        hunks = {},
        logs = {},
        last_lnum_blamed = 1,
    }

    describe('new', function()

        it('should create a Bstate object', function()
            local bstate = Bstate.new()
            eq(bstate, { buf_states = {} })
        end)

    end)

    describe('add', function()

        it('should have every buf created with the default atomic state', function()
            local bstate = Bstate.new()
            local num_cache = 5
            for i = 1, num_cache, 1 do
                bstate:add(i)
            end
            local buf_state = {
                current = atomic_buf_state,
                initial = atomic_buf_state,
            }
            eq(bstate.buf_states, {
                ['1'] = buf_state,
                ['2'] = buf_state,
                ['3'] = buf_state,
                ['4'] = buf_state,
                ['5'] = buf_state,
            })
        end)

        it('should save a buf id and create necessary buf_state', function()
            local bstate = Bstate.new()
            local num_cache = 10000
            for i = 1, num_cache, 1 do
                bstate:add(i)
            end
            eq(#vim.tbl_keys(bstate.buf_states), num_cache)
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

    describe('get_bufs', function()

        it('should return all the buf states that exists in the bstate', function()
            local bstate = Bstate.new()
            local num_bufs = 100
            for i = 1, num_bufs, 1 do
                bstate:add(i)
            end
            local buf_states = bstate:get_buf_states()
            eq(#vim.tbl_keys(buf_states), num_bufs)
            for _, buf_state in pairs(buf_states) do
                assert(buf_state, initial_state)
            end
        end)

        it('should return empty table if there are no buf states in the bstate', function()
            local bstate = Bstate.new()
            assert(bstate:get_buf_states(), {})
        end)

    end)

end)
