local fs = require('vgit.fs')

local vim = vim
local it = it
local describe = describe

describe('fs:', function()

    describe('filename', function()

        it('should return the relative path associated with the buffer', function()
            local cwd = vim.loop.cwd()
            local filename = 'lua/vgit/init.lua'
            local filepath = cwd .. '/' .. filename
            local buf = vim.api.nvim_create_buf(false, true)
            vim.api.nvim_buf_set_name(buf, filepath)
            assert.are.same(fs.filename(buf), filename)
        end)

        it('should return empty string if buffer has no name', function()
            local buf = vim.api.nvim_create_buf(false, true)
            assert.are.same(fs.filename(buf), '')
        end)

    end)

    describe('relative_path', function()

        it('should convert an absolute path to a relative path', function()
            local cwd = vim.loop.cwd()
            local path = cwd .. '/lua/vgit/init.lua'
            local filepath = fs.relative_path(path)
            assert.are.same(filepath, 'lua/vgit/init.lua')
        end)

        it('should return the unchanged path if it is not absolute', function()
            local path = 'lua/vgit/init.lua'
            local filepath = fs.relative_path(path)
            assert.are.same(filepath, 'lua/vgit/init.lua')
        end)

    end)

    describe('read_file', function()

        local filename = 'tests/fixtures/simple_file'

        it('should retrieve contents of a file in a table of strings for a given file path', function()
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
