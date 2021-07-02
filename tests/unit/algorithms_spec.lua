local algorithms = require('vgit.algorithms')

local it = it
local describe = describe
local eq = assert.are.same

describe('algorithms:', function()

    describe('myers_difference', function()

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
