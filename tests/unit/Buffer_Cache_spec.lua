local BufferCache = require('vgit.BufferCache')

local it = it
local describe = describe
local eq = assert.are.same

describe('BufferCache:', function()
    local atomic_buf_state = {
        blames = {},
        disabled = false,
        filename = '',
        filetype = '',
        tracked_filename = '',
        tracked_remote_filename = '',
        hunks = {},
        logs = {},
        temp_lines = {},
        last_lnum_blamed = 1,
        untracked = false,
    }

    describe('new', function()
        it('should create a BufferCache object', function()
            local buffer_cache = BufferCache:new()
            eq(buffer_cache, { buf_states = {} })
        end)
    end)

    describe('add', function()
        it('should throw error on invalid argument types', function()
            local buffer_cache = BufferCache:new()
            assert.has_error(function()
                buffer_cache:add(true)
            end)
            assert.has_error(function()
                buffer_cache:add({})
            end)
            assert.has_error(function()
                buffer_cache:add('hello')
            end)
            assert.has_error(function()
                buffer_cache:add(nil)
            end)
            assert.has_error(function()
                buffer_cache:add(function() end)
            end)
        end)

        it('should have every buf created with the default atomic state', function()
            local buffer_cache = BufferCache:new()
            local num_cache = 5
            for i = 1, num_cache, 1 do
                buffer_cache:add(i)
            end
            local buf_state = { data = atomic_buf_state }
            eq(buffer_cache.buf_states, {
                [1] = buf_state,
                [2] = buf_state,
                [3] = buf_state,
                [4] = buf_state,
                [5] = buf_state,
            })
        end)

        it('should save a buf id and create necessary buf_state', function()
            local buffer_cache = BufferCache:new()
            local num_cache = 10000
            for i = 1, num_cache, 1 do
                buffer_cache:add(i)
            end
            eq(#vim.tbl_keys(buffer_cache.buf_states), num_cache)
        end)
    end)

    describe('contains', function()
        it('should return true for a given buf number if it exists in the object', function()
            local buffer_cache = BufferCache:new()
            local num_bufs = 100
            for i = 1, num_bufs, 1 do
                buffer_cache:add(i)
            end
            for i = 1, num_bufs, 1 do
                assert(buffer_cache:contains(i))
            end
        end)

        it('should return false for a buf number that does not exist in the object', function()
            local buffer_cache = BufferCache:new()
            local num_bufs = 100
            for i = 1, num_bufs, 1 do
                buffer_cache:add(i)
            end
            for i = 101, num_bufs, 1 do
                eq(buffer_cache:contains(i), false)
            end
        end)
    end)

    describe('remove', function()
        it('should throw error on invalid argument types', function()
            local buffer_cache = BufferCache:new()
            assert.has_error(function()
                buffer_cache:remove(true)
            end)
            assert.has_error(function()
                buffer_cache:remove({})
            end)
            assert.has_error(function()
                buffer_cache:remove('hello')
            end)
            assert.has_error(function()
                buffer_cache:remove(nil)
            end)
            assert.has_error(function()
                buffer_cache:remove(function() end)
            end)
        end)

        it('should remove the buf from buffer_cache', function()
            local buffer_cache = BufferCache:new()
            local num_bufs = 100
            for i = 1, num_bufs, 1 do
                buffer_cache:add(i)
            end
            for i = 1, num_bufs, 1 do
                assert(buffer_cache:contains(i))
            end
            for i = 1, num_bufs, 1 do
                buffer_cache:remove(i)
            end
            for i = 1, num_bufs, 1 do
                eq(buffer_cache:contains(i), false)
            end
        end)
    end)

    describe('get', function()
        it('should throw error on invalid argument types', function()
            local buffer_cache = BufferCache:new()
            assert.has_error(function()
                buffer_cache:get(true)
            end)
            assert.has_error(function()
                buffer_cache:get({})
            end)
            assert.has_error(function()
                buffer_cache:get('hello')
            end)
            assert.has_error(function()
                buffer_cache:get(nil)
            end)
            assert.has_error(function()
                buffer_cache:get(function() end)
            end)
        end)

        it('should retrieve a value of a buffer state given a key for a specific buffer', function()
            local buffer_cache = BufferCache:new()
            local num_bufs = 100
            for i = 1, num_bufs, 1 do
                buffer_cache:add(i)
            end
            for i = 1, num_bufs, 1 do
                eq(buffer_cache:get(i, 'blames'), {})
                eq(buffer_cache:get(i, 'disabled'), false)
                eq(buffer_cache:get(i, 'filename'), '')
                eq(buffer_cache:get(i, 'filetype'), '')
                eq(buffer_cache:get(i, 'tracked_filename'), '')
                eq(buffer_cache:get(i, 'hunks'), {})
                eq(buffer_cache:get(i, 'logs'), {})
                eq(buffer_cache:get(i, 'last_lnum_blamed'), 1)
            end
        end)
    end)

    describe('set', function()
        it('should throw error on invalid argument types', function()
            local buffer_cache = BufferCache:new()
            local num_bufs = 100
            for i = 1, num_bufs, 1 do
                buffer_cache:add(i)
            end
            assert.has_error(function()
                buffer_cache:set(true, 'blames')
            end)
            assert.has_error(function()
                buffer_cache:set({}, 'blames')
            end)
            assert.has_error(function()
                buffer_cache:set('hello', 'blames')
            end)
            assert.has_error(function()
                buffer_cache:set(nil, 'blames')
            end)
            assert.has_error(function()
                buffer_cache:set(function() end, 'blames')
            end)
            assert.has_error(function()
                buffer_cache:set(1, true)
            end)
            assert.has_error(function()
                buffer_cache:set(1, {})
            end)
            assert.has_error(function()
                buffer_cache:set(1, 1)
            end)
            assert.has_error(function()
                buffer_cache:set(1, nil)
            end)
            assert.has_error(function()
                buffer_cache:set(1, function() end)
            end)
        end)

        it('should set a value of a buffer state given a key for a specific buffer', function()
            local buffer_cache = BufferCache:new()
            local num_bufs = 100
            for i = 1, num_bufs, 1 do
                buffer_cache:add(i)
            end
            for i = 1, num_bufs, 1 do
                buffer_cache:set(i, 'blames', { 'foo', 'bar' })
                buffer_cache:set(i, 'disabled', true)
                buffer_cache:set(i, 'filename', 'foo')
                buffer_cache:set(i, 'filetype', 'bar')
                buffer_cache:set(i, 'tracked_filename', 'baz')
                buffer_cache:set(i, 'hunks', { 'foo' })
                buffer_cache:set(i, 'logs', { 'bar' })
                buffer_cache:set(i, 'last_lnum_blamed', 10)
            end
            for i = 1, num_bufs, 1 do
                eq(buffer_cache:get(i, 'blames'), { 'foo', 'bar' })
                eq(buffer_cache:get(i, 'disabled'), true)
                eq(buffer_cache:get(i, 'filename'), 'foo')
                eq(buffer_cache:get(i, 'filetype'), 'bar')
                eq(buffer_cache:get(i, 'tracked_filename'), 'baz')
                eq(buffer_cache:get(i, 'hunks'), { 'foo' })
                eq(buffer_cache:get(i, 'logs'), { 'bar' })
                eq(buffer_cache:get(i, 'last_lnum_blamed'), 10)
            end
        end)
    end)

    describe('for_each', function()
        it('should throw error on invalid argument types', function()
            local buffer_cache = BufferCache:new()
            assert.has_error(function()
                buffer_cache:for_each(true)
            end)
            assert.has_error(function()
                buffer_cache:for_each({})
            end)
            assert.has_error(function()
                buffer_cache:for_each('hello')
            end)
            assert.has_error(function()
                buffer_cache:for_each(nil)
            end)
            assert.has_error(function()
                buffer_cache:for_each(1)
            end)
        end)

        it('should loop over each element in the buffer_cache', function()
            local buffer_cache = BufferCache:new()
            local num_bufs = 100
            for i = 1, num_bufs, 1 do
                buffer_cache:add(i)
            end
            buffer_cache:for_each(function(i, buf_state)
                eq(buffer_cache:get(i, 'blames'), buf_state:get('blames'))
                eq(buffer_cache:get(i, 'disabled'), buf_state:get('disabled'))
                eq(buffer_cache:get(i, 'filename'), buf_state:get('filename'))
                eq(buffer_cache:get(i, 'filetype'), buf_state:get('filetype'))
                eq(buffer_cache:get(i, 'tracked_filename'), buf_state:get('tracked_filename'))
                eq(buffer_cache:get(i, 'hunks'), buf_state:get('hunks'))
                eq(buffer_cache:get(i, 'logs'), buf_state:get('logs'))
                eq(buffer_cache:get(i, 'last_lnum_blamed'), buf_state:get('last_lnum_blamed'))
            end)
        end)
    end)

    describe('get_bufs', function()
        it('should return all the buf states that exists in the buffer_cache', function()
            local buffer_cache = BufferCache:new()
            local num_bufs = 100
            for i = 1, num_bufs, 1 do
                buffer_cache:add(i)
            end
            local buf_states = buffer_cache:get_buf_states()
            eq(#vim.tbl_keys(buf_states), num_bufs)
            for _, buf_state in pairs(buf_states) do
                assert(buf_state, nil)
            end
        end)

        it('should return empty table if there are no buf states in the buffer_cache', function()
            local buffer_cache = BufferCache:new()
            assert(buffer_cache:get_buf_states(), {})
        end)
    end)
end)
