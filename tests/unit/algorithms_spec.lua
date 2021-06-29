local algorithms = require('vgit.algorithms')

local it = it
local describe = describe
local eq = assert.are.same

describe('algorithms:', function()

    describe('myers_difference', function()

        it('should throw error on invalid argument types', function()
            assert.has_error(function()
                algorithms.myers_difference(true, {})
            end)
            assert.has_error(function()
                algorithms.myers_difference({ foo = 3 }, {})
            end)
            assert.has_error(function()
                algorithms.myers_difference(1, {})
            end)
            assert.has_error(function()
                algorithms.myers_difference('foo', {})
            end)
            assert.has_error(function()
                algorithms.myers_difference(nil, {})
            end)
            assert.has_error(function()
                algorithms.myers_difference(function() end, {})
            end)
            assert.has_error(function()
                algorithms.myers_difference({}, true)
            end)
            assert.has_error(function()
                algorithms.myers_difference({}, { foo = 3 })
            end)
            assert.has_error(function()
                algorithms.myers_difference({}, 1)
            end)
            assert.has_error(function()
                algorithms.myers_difference({}, 'foo')
            end)
            assert.has_error(function()
                algorithms.myers_difference({}, nil)
            end)
            assert.has_error(function()
                algorithms.myers_difference({}, function() end)
            end)
        end)

        it('should compute the difference between two list tables', function()
            eq(algorithms.myers_difference({ 'a', 'b', 'c', 'd' }, { 'j', 'l', 'c', 'n' }), {
                { -1, 'a' },
                { -1, 'b' },
                { 1, 'j' },
                { 1, 'l' },
                { 0, 'c' },
                { -1, 'd' },
                { 1, 'n' },
            })
        end)

    end)

    describe('hunks', function()

        it('should throw error on invalid argument types', function()
            assert.has_error(function()
                algorithms.hunks(true, {})
            end)
            assert.has_error(function()
                algorithms.hunks({ foo = 3 }, {})
            end)
            assert.has_error(function()
                algorithms.hunk(1, {})
            end)
            assert.has_error(function()
                algorithms.hunks('foo', {})
            end)
            assert.has_error(function()
                algorithms.hunks(nil, {})
            end)
            assert.has_error(function()
                algorithms.hunks(function() end, {})
            end)
            assert.has_error(function()
                algorithms.hunks({}, true)
            end)
            assert.has_error(function()
                algorithms.hunks({}, { foo = 3 })
            end)
            assert.has_error(function()
                algorithms.hunks({}, 1)
            end)
            assert.has_error(function()
                algorithms.hunks({}, 'foo')
            end)
            assert.has_error(function()
                algorithms.hunks({}, nil)
            end)
            assert.has_error(function()
                algorithms.hunks({}, function() end)
            end)
        end)

        it('should compute the hunks of difference between the two different lines', function()
            eq(algorithms.hunks({ 'a', 'b', 'c', 'd' }, { 'j', 'l', 'c', 'n' }), {
                {
                    diff = {
                        '-a',
                        '-b',
                        '+j',
                        '+l',
                    },
                    finish = 2,
                    start = 1,
                    type = 'change',
                },
                {
                    diff = {
                        '-d',
                        '+n',
                    },
                    finish = 4,
                    start = 4,
                    type = 'change',
                }
            })
        end)

    end)

end)
