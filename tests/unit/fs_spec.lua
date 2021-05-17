local fs = require('vgit.fs')

local it = it
local describe = describe

describe('fs:', function()

    local filename = 'tests/fixtures/simple_file'

    describe('read_file', function()

        it('should retrieve contents of a file as a string for a given file path', function()
            local err, data = fs.read_file(filename)
            assert.are.same(err, nil)
            assert.are.same(type(data), 'table')
        end)

        it('should retrieve an err_result for a given file path that does not exist', function()
            local err, data = fs.read_file('IDONTEXIST.md')
            assert.are_not.same(err, nil)
            assert.are.same(data, nil)
        end)

    end)

end)
