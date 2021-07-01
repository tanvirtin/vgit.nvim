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
        temp_lines = {},
        last_lnum_blamed = 1,
    }

    describe('new', function()

        it('should create a Bstate object', function()
            local bstate = Bstate.new()
            eq(bstate, { buf_states = {} })
        end)

    end)

    describe('add', function()

        it('should throw error on invalid argument types', function()
            local bstate = Bstate.new()
            assert.has_error(function()
                bstate:add(true)
            end)
            assert.has_error(function()
                bstate:add({})
            end)
            assert.has_error(function()
                bstate:add('hello')
            end)
            assert.has_error(function()
                bstate:add(nil)
            end)
            assert.has_error(function()
                bstate:add(function() end)
            end)
        end)

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
                [1] = buf_state,
                [2] = buf_state,
                [3] = buf_state,
                [4] = buf_state,
                [5] = buf_state,
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

    describe('remove', function()

        it('should throw error on invalid argument types', function()
            local bstate = Bstate.new()
            assert.has_error(function()
                bstate:remove(true)
            end)
            assert.has_error(function()
                bstate:remove({})
            end)
            assert.has_error(function()
                bstate:remove('hello')
            end)
            assert.has_error(function()
                bstate:remove(nil)
            end)
            assert.has_error(function()
                bstate:remove(function() end)
            end)
        end)

        it('should remove the buf from bstate', function()
            local bstate = Bstate.new()
            local num_bufs = 100
            for i = 1, num_bufs, 1 do
                bstate:add(i)
            end
            for i = 1, num_bufs, 1 do
                assert(bstate:contains(i))
            end
            for i = 1, num_bufs, 1 do
                bstate:remove(i)
            end
            for i = 1, num_bufs, 1 do
                eq(bstate:contains(i), false)
            end
        end)

    end)

    describe('get', function()

        it('should throw error on invalid argument types', function()
            local bstate = Bstate.new()
            assert.has_error(function()
                bstate:get(true)
            end)
            assert.has_error(function()
                bstate:get({})
            end)
            assert.has_error(function()
                bstate:get('hello')
            end)
            assert.has_error(function()
                bstate:get(nil)
            end)
            assert.has_error(function()
                bstate:get(function() end)
            end)
        end)

        it('should retrieve a value of a buffer state given a key for a specific buffer', function()
            local bstate = Bstate.new()
            local num_bufs = 100
            for i = 1, num_bufs, 1 do
                bstate:add(i)
            end
            for i = 1, num_bufs, 1 do
                eq(bstate:get(i, 'blames'), {})
                eq(bstate:get(i, 'disabled'), false)
                eq(bstate:get(i, 'filename'), '')
                eq(bstate:get(i, 'filetype'), '')
                eq(bstate:get(i, 'project_relative_filename'), '')
                eq(bstate:get(i, 'hunks'), {})
                eq(bstate:get(i, 'logs'), {})
                eq(bstate:get(i, 'last_lnum_blamed'), 1)
            end
        end)

    end)

    describe('set', function()

        it('should throw error on invalid argument types', function()
            local bstate = Bstate.new()
            local num_bufs = 100
            for i = 1, num_bufs, 1 do
                bstate:add(i)
            end
            assert.has_error(function()
                bstate:set(true, 'blames')
            end)
            assert.has_error(function()
                bstate:set({}, 'blames')
            end)
            assert.has_error(function()
                bstate:set('hello', 'blames')
            end)
            assert.has_error(function()
                bstate:set(nil, 'blames')
            end)
            assert.has_error(function()
                bstate:set(function() end, 'blames')
            end)
            assert.has_error(function()
                bstate:set(1, true)
            end)
            assert.has_error(function()
                bstate:set(1, {})
            end)
            assert.has_error(function()
                bstate:set(1, 1)
            end)
            assert.has_error(function()
                bstate:set(1, nil)
            end)
            assert.has_error(function()
                bstate:set(1, function() end)
            end)
        end)

        it('should set a value of a buffer state given a key for a specific buffer', function()
            local bstate = Bstate.new()
            local num_bufs = 100
            for i = 1, num_bufs, 1 do
                bstate:add(i)
            end
            for i = 1, num_bufs, 1 do
                bstate:set(i, 'blames', { 'foo', 'bar' })
                bstate:set(i, 'disabled', true)
                bstate:set(i, 'filename', 'foo')
                bstate:set(i, 'filetype', 'bar')
                bstate:set(i, 'project_relative_filename', 'baz')
                bstate:set(i, 'hunks', { 'foo' })
                bstate:set(i, 'logs', { 'bar' })
                bstate:set(i, 'last_lnum_blamed', 10)
            end
            for i = 1, num_bufs, 1 do
                eq(bstate:get(i, 'blames'), { 'foo', 'bar' })
                eq(bstate:get(i, 'disabled'), true)
                eq(bstate:get(i, 'filename'), 'foo')
                eq(bstate:get(i, 'filetype'), 'bar')
                eq(bstate:get(i, 'project_relative_filename'), 'baz')
                eq(bstate:get(i, 'hunks'), { 'foo' })
                eq(bstate:get(i, 'logs'), { 'bar' })
                eq(bstate:get(i, 'last_lnum_blamed'), 10)
            end
        end)

    end)

    describe('for_each', function()

        it('should throw error on invalid argument types', function()
            local bstate = Bstate.new()
            assert.has_error(function()
                bstate:for_each(true)
            end)
            assert.has_error(function()
                bstate:for_each({})
            end)
            assert.has_error(function()
                bstate:for_each('hello')
            end)
            assert.has_error(function()
                bstate:for_each(nil)
            end)
            assert.has_error(function()
                bstate:for_each(1)
            end)
        end)

        it('should loop over each element in the bstate', function()
            local bstate = Bstate.new()
            local num_bufs = 100
            for i = 1, num_bufs, 1 do
                bstate:add(i)
            end
            bstate:for_each(function(i, buf_state)
                eq(bstate:get(i, 'blames'), buf_state:get('blames'))
                eq(bstate:get(i, 'disabled'), buf_state:get('disabled'))
                eq(bstate:get(i, 'filename'), buf_state:get('filename'))
                eq(bstate:get(i, 'filetype'), buf_state:get('filetype'))
                eq(bstate:get(i, 'project_relative_filename'), buf_state:get('project_relative_filename'))
                eq(bstate:get(i, 'hunks'), buf_state:get('hunks'))
                eq(bstate:get(i, 'logs'), buf_state:get('logs'))
                eq(bstate:get(i, 'last_lnum_blamed'), buf_state:get('last_lnum_blamed'))
            end)
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
                assert(buf_state, nil)
            end
        end)

        it('should return empty table if there are no buf states in the bstate', function()
            local bstate = Bstate.new()
            assert(bstate:get_buf_states(), {})
        end)

    end)

end)
