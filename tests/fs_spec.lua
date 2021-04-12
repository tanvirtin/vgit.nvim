local fs = require('git.fs')

local it = it
local describe = describe

describe('fs:', function()

      describe('read_file', function()

        it('should retrieve contents of a file as a string for a given file path', function()
            local err, data = fs.read_file('README.md')
            assert.are.same(err, nil)
            assert.are.same(type(data), 'string')
        end)

        it('should retrieve an err_result for a given file path that does not exist', function()
            local err, data = fs.read_file('IDONTEXIST.md')
            assert.are_not.same(err, nil)
            assert.are.same(data, nil)
        end)

    end)

    describe('file_type', function()

        it('should return file type from a filename', function()
            local type = fs.file_type('foo.lua')
            assert.are.same(type, 'lua')

            type = fs.file_type('foo.rb')
            assert.are.same(type, 'rb')

            type = fs.file_type('foo.spec.ts')
            assert.are.same(type, 'ts')

            type = fs.file_type('foo.js')
            assert.are.same(type, 'js')
        end)

        it('should return empty string on invalid filename', function()
            local type = fs.file_type('foo')
            assert.are.same(type, '')

            type = fs.file_type('')
            assert.are.same(type, '')

            type = fs.file_type('.gitignore')
            assert.are.same(type, 'gitignore')
        end)

    end)

end)
