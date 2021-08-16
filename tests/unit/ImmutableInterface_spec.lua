local ImmutableInterface = require('vgit.ImmutableInterface')

local it = it
local describe = describe
local before_each = before_each
local eq = assert.are.same

describe('ImmutableInterface:', function()
    local initial_state = {}

    before_each(function()
        initial_state = {
            foo = 'bar',
            bar = 'foo',
            baz = {
                foo = 'bar',
                bar = 'foo',
            },
        }
    end)

    describe('new', function()
        it('should bind the object provided into into the state object', function()
            local state = ImmutableInterface.new(initial_state)
            eq(state, {
                data = initial_state,
            })
        end)

        it('should throw error if invalid data type is provided', function()
            assert.has_error(function()
                ImmutableInterface.new(42)
            end)
        end)
    end)

    describe('get', function()
        it('should throw error on invalid argument types', function()
            local state = ImmutableInterface.new({
                foo = 'bar',
            })
            assert.has_error(function()
                state:get(true)
            end)
            assert.has_error(function()
                state:get({})
            end)
            assert.has_error(function()
                state:get(1)
            end)
            assert.has_error(function()
                state:get(nil)
            end)
            assert.has_error(function()
                state:get(function() end)
            end)
        end)

        it('should succesfully retrieve a value given a key from the state object', function()
            local state = ImmutableInterface.new(initial_state)
            eq(state:get('foo'), 'bar')
            eq(state:get('bar'), 'foo')
            eq(state:get('baz'), {
                foo = 'bar',
                bar = 'foo',
            })
        end)

        it('should throw an error if a state object does not have the given key', function()
            local state = ImmutableInterface.new(initial_state)
            assert.has_error(function()
                eq(state:get('test'), nil)
            end)
        end)
    end)

    describe('immutability', function()
        it('should not be mutable', function()
            local state = ImmutableInterface.new({
                foo = 'bar',
                bar = 'foo',
                baz = {
                    foo = 'bar',
                    bar = 'foo',
                },
            })
            assert.has_error(function()
                state.data.foo = 'should not work'
            end)
            assert.has_error(function()
                state.data.bar = 'should not work'
            end)
            assert.has_error(function()
                state.data.baz = 'should not work'
            end)
            assert.has_error(function()
                state.data.baz = {}
            end)
        end)
    end)
end)
