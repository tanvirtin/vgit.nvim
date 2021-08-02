local fs = require('vgit.fs')

local vim = vim
local it = it
local describe = describe
local after_each = after_each
local eq = assert.are.same

describe('fs:', function()
    local filename = '/tmp/foo_vgit'

    after_each(function()
        os.remove(filename)
    end)

    describe('filename', function()
        it('should throw error on invalid argument types', function()
            assert.has_error(function()
                fs.filename(true)
            end)
            assert.has_error(function()
                fs.filename({})
            end)
            assert.has_error(function()
                fs.filename('foo')
            end)
            assert.has_error(function()
                fs.filename(nil)
            end)
            assert.has_error(function()
                fs.filename(function() end)
            end)
        end)

        it('should return the relative path associated with the buffer', function()
            local name = 'lua/vgit/init.lua'
            local current = vim.loop.cwd()
            local filepath = current .. '/' .. name
            local buf = vim.api.nvim_create_buf(true, true)
            vim.api.nvim_buf_set_name(buf, filepath)
            eq(fs.filename(buf), name)
        end)

        it('should return empty string if buffer has no name', function()
            local buf = vim.api.nvim_create_buf(true, true)
            eq(fs.filename(buf), '')
        end)
    end)

    describe('relative_filename', function()
        it('should throw error on invalid argument types', function()
            assert.has_error(function()
                fs.relative_filename(true)
            end)
            assert.has_error(function()
                fs.relative_filename({})
            end)
            assert.has_error(function()
                fs.relative_filename(1)
            end)
            assert.has_error(function()
                fs.relative_filename(nil)
            end)
            assert.has_error(function()
                fs.relative_filename(function() end)
            end)
        end)

        it('should convert an absolute path to a relative path', function()
            local current = vim.loop.cwd()
            local path = current .. '/lua/vgit/init.lua'
            local filepath = fs.relative_filename(path)
            eq(filepath, 'lua/vgit/init.lua')
        end)

        it('should return the unchanged path if it is not absolute', function()
            local path = 'lua/vgit/init.lua'
            local filepath = fs.relative_filename(path)
            eq(filepath, 'lua/vgit/init.lua')
        end)
    end)

    describe('short_filename', function()
        it('should throw error on invalid argument types', function()
            assert.has_error(function()
                fs.short_filename(true)
            end)
            assert.has_error(function()
                fs.short_filename({})
            end)
            assert.has_error(function()
                fs.short_filename(1)
            end)
            assert.has_error(function()
                fs.short_filename(nil)
            end)
            assert.has_error(function()
                fs.short_filename(function() end)
            end)
        end)

        it('should take a long path and give you the filename', function()
            eq(fs.short_filename('lua/vgit/init.lua'), 'init.lua')
            eq(fs.short_filename('/init.lua'), 'init.lua')
            eq(fs.short_filename('a/b/c/d/init.lua'), 'init.lua')
            eq(fs.short_filename('init.lua'), 'init.lua')
            eq(fs.short_filename(''), '')
            eq(fs.short_filename('init/.lua'), '.lua')
        end)
    end)

    describe('filetype', function()
        it('should throw error on invalid argument types', function()
            assert.has_error(function()
                fs.filetype(true)
            end)
            assert.has_error(function()
                fs.filetype({})
            end)
            assert.has_error(function()
                fs.filetype('foo')
            end)
            assert.has_error(function()
                fs.filetype(nil)
            end)
            assert.has_error(function()
                fs.filetype(function() end)
            end)
        end)

        it('should retrieve the correct filetype for a given buffer', function()
            local buf = vim.api.nvim_create_buf(true, true)
            vim.api.nvim_buf_set_option(buf, 'filetype', 'bar')
            eq(fs.filetype(buf), 'bar')
        end)

        it('should retrieve empty string for a buffer with no filetype', function()
            local buf = vim.api.nvim_create_buf(true, true)
            eq(fs.filetype(buf), '')
        end)
    end)

    describe('read_file', function()
        it('should throw error on invalid argument types', function()
            assert.has_error(function()
                fs.read_file(true)
            end)
            assert.has_error(function()
                fs.read_file({})
            end)
            assert.has_error(function()
                fs.read_file(1)
            end)
            assert.has_error(function()
                fs.read_file(nil)
            end)
            assert.has_error(function()
                fs.read_file(function() end)
            end)
        end)

        it('should retrieve an err_result for a given file path that does not exist', function()
            local err, data = fs.read_file('IDONTEXIST.md')
            assert.are_not.same(err, nil)
            eq(data, nil)
        end)
    end)

    describe('tmpname', function()
        it('should generate a string', function()
            eq(type(fs.tmpname()), 'string')
        end)

        it('should be 16 character long', function()
            eq(#fs.tmpname(), 16)
        end)

        it('should start with /tmp/', function()
            eq(vim.startswith(fs.tmpname(), '/tmp/'), true)
        end)

        it('should end with _vgit', function()
            local name = fs.tmpname()
            eq(name:sub(#name - 4, #name), '_vgit')
        end)
    end)

    describe('detect', function()
        it('should throw error on invalid argument types', function()
            assert.has_error(function()
                fs.detect_filetype(true)
            end)
            assert.has_error(function()
                fs.detect_filetype({})
            end)
            assert.has_error(function()
                fs.detect_filetype(1)
            end)
            assert.has_error(function()
                fs.detect_filetype(nil)
            end)
            assert.has_error(function()
                fs.detect_filetype(function() end)
            end)
        end)

        it('should work for md', function()
            eq('markdown', fs.detect_filetype('Readme.md'))
        end)

        it('should work for CMakeList.txt', function()
            eq('cmake', fs.detect_filetype('CMakeLists.txt'))
        end)

        it('should work with extensions with dot', function()
            eq('rst', fs.detect_filetype('example.rst.txt'))
            eq('rst', fs.detect_filetype('example.rest.txt'))
            eq('yaml', fs.detect_filetype('example.yaml.sed'))
            eq('yaml', fs.detect_filetype('example.yml.mysql'))
            eq('erlang', fs.detect_filetype('asdf/example.app.src'))
            eq('cmake', fs.detect_filetype('/asdf/example.cmake.in'))
            eq('desktop', fs.detect_filetype('/asdf/asdf.desktop.in'))
            eq('xml', fs.detect_filetype('example.dll.config'))
            eq('haml', fs.detect_filetype('example.haml.deface'))
            eq('html', fs.detect_filetype('example.html.hl'))
            eq('yaml', fs.detect_filetype('example.model.lkml'))
            eq('rust', fs.detect_filetype('example.rs.in'))
            eq('sh', fs.detect_filetype('example.sh.in'))
            eq('json', fs.detect_filetype('example.tfstate.backup'))
            eq('yaml', fs.detect_filetype('example.view.lkml'))
            eq('xml', fs.detect_filetype('example.xml.dist'))
            eq('xml', fs.detect_filetype('example.xsp.metadata'))
        end)

        it('should work for ext==ft even without a table value', function()
            eq('bib', fs.detect_filetype('file.bib'))
            eq('bst', fs.detect_filetype('file.bst'))
        end)

        it('should work for common filenames, like makefile', function()
            eq('make', fs.detect_filetype('Makefile'))
            eq('make', fs.detect_filetype('makefile'))
        end)

        it('should work for CMakeList.txt', function()
            eq('cmake', fs.detect_filetype('CMakeLists.txt'))
        end)

        it('should work for common filetypes, like python', function()
            eq('python', fs.detect_filetype('__init__.py'))
        end)

        it('should work for common filenames, like makefile', function()
            eq('make', fs.detect_filetype('Makefile'))
            eq('make', fs.detect_filetype('makefile'))
        end)

        it('should work for CMakeList.txt', function()
            eq('cmake', fs.detect_filetype('CMakeLists.txt'))
        end)

        it('should work for common files, even with .s, like .bashrc', function()
            eq('sh', fs.detect_filetype('.bashrc'))
        end)

        it('should work fo custom filetypes, like fennel', function()
            eq('fennel', fs.detect_filetype('init.fnl'))
        end)

        it('should work for custom filenames, like Cakefile', function()
            eq('coffee', fs.detect_filetype('Cakefile'))
        end)
    end)

    describe('write_file', function()
        it('should throw error on invalid argument types', function()
            assert.has_error(function()
                fs.write_file(true, {})
            end)
            assert.has_error(function()
                fs.write_file({}, {})
            end)
            assert.has_error(function()
                fs.write_file(1, {})
            end)
            assert.has_error(function()
                fs.write_file(nil, {})
            end)
            assert.has_error(function()
                fs.write_file(function() end, {})
            end)
            assert.has_error(function()
                fs.write_file('', true)
            end)
            assert.has_error(function()
                fs.write_file('', '')
            end)
            assert.has_error(function()
                fs.write_file('', 1)
            end)
            assert.has_error(function()
                fs.write_file('', nil)
            end)
            assert.has_error(function()
                fs.write_file('', { foo = 'bar' })
            end)
            assert.has_error(function()
                fs.write_file('', function() end)
            end)
        end)

        it('should create a new file and append the contents inside it', function()
            local lines = { 'foo', 'bar' }
            fs.write_file(filename, lines)
            local err, data = fs.read_file(filename)
            eq(err, nil)
            eq(data, { 'foo', 'bar', '' })
        end)

        it('should replace contents in an existing file with new contents', function()
            local lines = { 'foo', 'baz' }
            local file = io.open(filename, 'w')
            file:write('hello world')
            file:close()
            fs.write_file(filename, lines)
            local err, data = fs.read_file(filename)
            eq(err, nil)
            eq(data, { 'foo', 'baz', '' })
        end)
    end)

    describe('remove_file', function()
        it('should throw error on invalid argument types', function()
            assert.has_error(function()
                fs.remove_file(true)
            end)
            assert.has_error(function()
                fs.remove_file({})
            end)
            assert.has_error(function()
                fs.remove_file(1)
            end)
            assert.has_error(function()
                fs.remove_file(nil)
            end)
            assert.has_error(function()
                fs.remove_file(function() end)
            end)
        end)

        it('should remove a file succesfully', function()
            local num_files = 5
            local file_exists = function(name)
                local f = io.open(name, 'r')
                if f ~= nil then
                    io.close(f)
                    return true
                else
                    return false
                end
            end
            local create_file = function(name)
                local file = io.open(name, 'w')
                file:write('hello world')
                file:close()
                fs.write_file(name, { '' })
            end
            for i = 1, num_files do
                create_file(string.format('%s_%s', filename, i))
            end
            for i = 1, num_files do
                eq(file_exists(string.format('%s_%s', filename, i)), true)
            end
            for i = 1, num_files do
                fs.remove_file(string.format('%s_%s', filename, i))
            end
            for i = 1, num_files do
                eq(file_exists(string.format('%s_%s', filename, i)), false)
            end
        end)
    end)

    describe('exists', function()
        it('should throw error on invalid argument types', function()
            assert.has_error(function()
                fs.exists(true)
            end)
            assert.has_error(function()
                fs.exists({})
            end)
            assert.has_error(function()
                fs.exists(1)
            end)
            assert.has_error(function()
                fs.exists(nil)
            end)
            assert.has_error(function()
                fs.exists(function() end)
            end)
        end)

        it('should return true if file exists', function()
            eq(fs.exists('lua/vgit/init.lua'), true)
            eq(fs.exists('lua/vgit/buffer.lua'), true)
        end)

        it('should return false if file does not exists', function()
            eq(fs.exists('lua/vgit/doesnotexist1.lua'), false)
            eq(fs.exists('lua/vgit/doesnotexist2.lua'), false)
        end)

        it('should return true when it\'s a director', function()
            eq(fs.exists('lua/vgit'), true)
            eq(fs.exists('lua'), true)
        end)
    end)
end)
