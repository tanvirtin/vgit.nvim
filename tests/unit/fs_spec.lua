local fs = require('vgit.fs')

local vim = vim
local it = it
local describe = describe
local eq = assert.are.same

describe('fs:', function()

    describe('filename', function()

        it('should return the relative path associated with the buffer', function()
            local current = vim.loop.cwd()
            local filename = 'lua/vgit/init.lua'
            local filepath = current .. '/' .. filename
            local buf = vim.api.nvim_create_buf(true, true)
            vim.api.nvim_buf_set_name(buf, filepath)
            eq(fs.filename(buf), filename)
        end)

        it('should return empty string if buffer has no name', function()
            local buf = vim.api.nvim_create_buf(true, true)
            eq(fs.filename(buf), '')
        end)

    end)

    describe('relative_path', function()

        it('should convert an absolute path to a relative path', function()
            local current = vim.loop.cwd()
            local path = current .. '/lua/vgit/init.lua'
            local filepath = fs.relative_path(path)
            eq(filepath, 'lua/vgit/init.lua')
        end)

        it('should return the unchanged path if it is not absolute', function()
            local path = 'lua/vgit/init.lua'
            local filepath = fs.relative_path(path)
            eq(filepath, 'lua/vgit/init.lua')
        end)

    end)

    describe('read_file', function()

        it('should retrieve an err_result for a given file path that does not exist', function()
            local err, data = fs.read_file('IDONTEXIST.md')
            assert.are_not.same(err, nil)
            eq(data, nil)
        end)

    end)

end)
