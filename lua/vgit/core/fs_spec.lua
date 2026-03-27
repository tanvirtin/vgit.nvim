local Buffer = require('vgit.core.Buffer')
local fs = require('vgit.core.fs')

local eq = assert.are.same

describe('fs:', function()
  local filename = '/tmp/foo_vgit'

  after_each(function()
    os.remove(filename)
  end)

  describe('sep', function()
    it('should be a string', function()
      eq('string', type(fs.sep))
    end)

    it('should be a single character', function()
      eq(1, #fs.sep)
    end)

    it('should be / on unix-like systems', function()
      eq('/', fs.sep)
    end)
  end)

  describe('make_relative', function()
    it('should strip the directory prefix from a filepath', function()
      eq('file.txt', fs.make_relative('/home/user/project', '/home/user/project/file.txt'))
    end)

    it('should strip nested directory prefix', function()
      eq('src/main.lua', fs.make_relative('/home/user/project', '/home/user/project/src/main.lua'))
    end)

    it('should return filepath unchanged if it does not start with dirname', function()
      eq('/other/path/file.txt', fs.make_relative('/home/user/project', '/other/path/file.txt'))
    end)

    it('should return filepath unchanged when dirname is nil', function()
      eq('/some/file.txt', fs.make_relative(nil, '/some/file.txt'))
    end)

    it('should return nil when filepath is nil', function()
      assert.is_nil(fs.make_relative('/home/user', nil))
    end)

    it('should return nil when both are nil', function()
      assert.is_nil(fs.make_relative(nil, nil))
    end)

    it('should not strip partial directory matches', function()
      eq(
        '/home/user/project-extra/file.txt',
        fs.make_relative('/home/user/project', '/home/user/project-extra/file.txt')
      )
    end)

    it('should handle dirname without trailing separator', function()
      eq('file.txt', fs.make_relative('/dir', '/dir/file.txt'))
    end)

    it('should handle deeply nested paths', function()
      eq('a/b/c/d/e.txt', fs.make_relative('/root', '/root/a/b/c/d/e.txt'))
    end)

    it('should handle dirname with a trailing slash', function()
      eq('file.txt', fs.make_relative('/home/user/project/', '/home/user/project/file.txt'))
    end)

    it('should handle dirname with multiple trailing slashes', function()
      eq('file.txt', fs.make_relative('/home/user/project///', '/home/user/project/file.txt'))
    end)

    it('should handle root path without stripping the root separator', function()
      eq('file.txt', fs.make_relative('/', '/file.txt'))
    end)
  end)

  describe('is_dir', function()
    it('should return true for an existing directory', function()
      assert.is_true(fs.is_dir('lua'))
    end)

    it('should return true for nested directory', function()
      assert.is_true(fs.is_dir('lua/vgit'))
    end)

    it('should return false for a file', function()
      assert.is_false(fs.is_dir('lua/vgit.lua'))
    end)

    it('should return false for a nonexistent path', function()
      assert.is_false(fs.is_dir('/nonexistent/path/that/does/not/exist'))
    end)
  end)

  describe('absolute_path', function()
    it('should join base and relative paths', function()
      eq('/home/user/file.txt', fs.absolute_path('/home/user', 'file.txt'))
    end)

    it('should return relative_path if it starts with /', function()
      eq('/absolute/path.txt', fs.absolute_path('/home/user', '/absolute/path.txt'))
    end)

    it('should join nested relative paths', function()
      eq('/base/src/lib/init.lua', fs.absolute_path('/base', 'src/lib/init.lua'))
    end)

    it('should handle base path without trailing separator', function()
      eq('/dir/file.txt', fs.absolute_path('/dir', 'file.txt'))
    end)

    it('should handle base path with trailing slash', function()
      eq('/dir/file.txt', fs.absolute_path('/dir/', 'file.txt'))
    end)

    it('should handle base path with multiple trailing slashes', function()
      eq('/dir/file.txt', fs.absolute_path('/dir///', 'file.txt'))
    end)

    it('should handle root base path', function()
      eq('/file.txt', fs.absolute_path('/', 'file.txt'))
    end)
  end)

  describe('relative_filename', function()
    it('should convert an absolute path to a relative path', function()
      local current = vim.uv.cwd()
      local path = current .. '/lua/vgit/init.lua'
      local filepath = fs.relative_filename(path)

      eq(filepath, 'lua/vgit/init.lua')
    end)

    it('should return the unchanged path if it is not absolute', function()
      local path = 'lua/vgit/init.lua'
      local filepath = fs.relative_filename(path)

      eq(filepath, 'lua/vgit/init.lua')
    end)

    it('should return the unchanged path when it is outside cwd', function()
      local path = '/some/other/path/outside/cwd/file.txt'
      local filepath = fs.relative_filename(path)

      eq(filepath, path)
    end)
  end)

  describe('short_filename', function()
    it('should take a long path and give you the filename', function()
      eq(fs.short_filename('lua/vgit/init.lua'), 'init.lua')
      eq(fs.short_filename('/init.lua'), 'init.lua')
      eq(fs.short_filename('a/b/c/d/init.lua'), 'init.lua')
      eq(fs.short_filename('init.lua'), 'init.lua')
      eq(fs.short_filename(''), '')
      eq(fs.short_filename('init/.lua'), '.lua')
    end)

    it('should return the full string when no separator is present', function()
      eq(fs.short_filename('filename'), 'filename')
      eq(fs.short_filename('noext'), 'noext')
    end)

    it('should return empty string for a path that is only a separator', function()
      eq(fs.short_filename('/'), '')
    end)
  end)

  describe('filetype', function()
    it('should retrieve the correct filetype for a given buffer', function()
      local bufnr = vim.api.nvim_create_buf(true, true)
      local buffer = Buffer(bufnr)

      vim.api.nvim_set_option_value('filetype', 'bar', { buf = bufnr })
      eq(fs.filetype(buffer), 'bar')
    end)

    it('should retrieve empty string for a buffer with no filetype', function()
      local bufnr = vim.api.nvim_create_buf(true, true)
      local buffer = Buffer(bufnr)

      eq(fs.filetype(buffer), '')
    end)
  end)

  describe('read_file', function()
    it('should retrieve an err_result for a given file path that does not exist', function()
      local data, err = fs.read_file('IDONTEXIST.md')

      assert.are_not.same(err, nil)
      eq(data, nil)
    end)

    it('should read lines from an existing file', function()
      fs.write_file(filename, { 'hello', 'world' })

      local data, err = fs.read_file(filename)

      eq(err, nil)
      eq(data, { 'hello', 'world' })
    end)

    it('should return an empty table for an empty file', function()
      fs.write_file(filename, {})

      local data, err = fs.read_file(filename)

      eq(err, nil)
      eq(data, {})
    end)
  end)

  describe('tmpname', function()
    it('should generate a string', function()
      eq(type(fs.tmpname()), 'string')
    end)
    it('should start with /tmp/', function()
      eq(vim.startswith(fs.tmpname(), '/tmp/'), true)
    end)
    it('should return distinct names on successive calls', function()
      local a = fs.tmpname()
      local b = fs.tmpname()
      assert.are_not.same(a, b)
      os.remove(a)
      os.remove(b)
    end)
  end)

  describe('detect', function()
    it('should work for common extensions', function()
      eq('markdown', fs.detect_filetype('Readme.md'))
      eq('cmake', fs.detect_filetype('CMakeLists.txt'))
      eq('python', fs.detect_filetype('__init__.py'))
      eq('sh', fs.detect_filetype('.bashrc'))
      eq('fennel', fs.detect_filetype('init.fnl'))
    end)

    it('should work for common filenames', function()
      eq('make', fs.detect_filetype('Makefile'))
      eq('make', fs.detect_filetype('makefile'))
    end)

    it('should work for ext==ft even without a table value', function()
      eq('bib', fs.detect_filetype('file.bib'))
      eq('bst', fs.detect_filetype('file.bst'))
    end)

    it('should return nil for unknown extensions', function()
      assert.is_nil(fs.detect_filetype('file.unknownxyz123'))
      assert.is_nil(fs.detect_filetype('Cakefile'))
    end)

    it('should use last extension for compound filenames', function()
      eq('text', fs.detect_filetype('example.rst.txt'))
      eq('text', fs.detect_filetype('example.rest.txt'))
      eq('sed', fs.detect_filetype('example.yaml.sed'))
      eq('mysql', fs.detect_filetype('example.yml.mysql'))
    end)

    it('should handle explicit compound patterns (.cmake.in)', function()
      eq('cmake', fs.detect_filetype('/asdf/example.cmake.in'))
    end)

    it('should strip .in suffix to find base filetype', function()
      eq('rust', fs.detect_filetype('example.rs.in'))
      eq('desktop', fs.detect_filetype('/asdf/asdf.desktop.in'))
      eq('lua', fs.detect_filetype('example.lua.in'))
      eq('python', fs.detect_filetype('example.py.in'))
    end)

    it('should strip .bak suffix to find base filetype', function()
      eq('rust', fs.detect_filetype('example.rs.bak'))
      eq('python', fs.detect_filetype('example.py.bak'))
    end)

    it('should strip .orig and .old suffixes to find base filetype', function()
      eq('python', fs.detect_filetype('example.py.orig'))
      eq('lua', fs.detect_filetype('example.lua.old'))
      eq('sh', fs.detect_filetype('example.sh.new'))
    end)

    it('should strip chained strippable suffixes', function()
      eq('rust', fs.detect_filetype('example.rs.bak.in'))
      eq('python', fs.detect_filetype('example.py.orig.bak'))
    end)

    it('should terminate and return nil when all suffixes are strippable but base has no filetype', function()
      -- "only.bak" -> strip .bak -> "only" (no ext) -> break -> nil
      assert.is_nil(fs.detect_filetype('only.bak'))
      -- "file.in.bak" -> strip .bak -> "file.in" -> strip .in -> "file" -> break -> nil
      assert.is_nil(fs.detect_filetype('file.in.bak'))
      -- deeply chained: all strippable, no recognizable base
      assert.is_nil(fs.detect_filetype('noext.bak.in.orig.old'))
    end)

    it('should terminate correctly with a long chain of strippable suffixes before a real type', function()
      -- 5 strippable suffixes before .rs; loop must run all 5 and still resolve
      eq('rust', fs.detect_filetype('example.rs.in.bak.orig.old.new'))
    end)

    it('should strip distro-specific suffixes to find base filetype', function()
      eq('python', fs.detect_filetype('example.py.pacsave'))
      eq('python', fs.detect_filetype('example.py.pacnew'))
      eq('python', fs.detect_filetype('example.py.rpmsave'))
      eq('python', fs.detect_filetype('example.py.dpkg-bak'))
      eq('python', fs.detect_filetype('example.py.dpkg-dist'))
      eq('python', fs.detect_filetype('example.py.dpkg-old'))
      eq('python', fs.detect_filetype('example.py.dpkg-new'))
    end)
  end)

  describe('write_file', function()
    it('should create a new file and append the contents inside it', function()
      local lines = { 'foo', 'bar' }

      fs.write_file(filename, lines)

      local data, err = fs.read_file(filename)

      eq(err, nil)
      eq(data, { 'foo', 'bar' })
    end)

    it('should replace contents in an existing file with new contents', function()
      local lines = { 'foo', 'baz' }
      local file = io.open(filename, 'w')

      file:write('hello world')
      file:close()
      fs.write_file(filename, lines)

      local data, err = fs.read_file(filename)

      eq(err, nil)
      eq(data, { 'foo', 'baz' })
    end)

    it('should create an empty file when given an empty lines table', function()
      fs.write_file(filename, {})

      local data, err = fs.read_file(filename)

      eq(err, nil)
      eq(data, {})
    end)

    it('should return error when path is not writable', function()
      local result, err = fs.write_file('/nonexistent/path/file.txt', { 'line' })

      eq(result, nil)
      assert.is_not_nil(err)
    end)
  end)

  describe('append_file', function()
    it('should append lines to a new file', function()
      local lines = { 'line1', 'line2' }
      fs.append_file(filename, lines)

      local data, err = fs.read_file(filename)

      eq(err, nil)
      eq(data, { 'line1', 'line2' })
    end)

    it('should append lines to an existing file without overwriting', function()
      fs.write_file(filename, { 'existing content' })

      fs.append_file(filename, { 'appended line' })

      local data, err = fs.read_file(filename)

      eq(err, nil)
      eq(data, { 'existing content', 'appended line' })
    end)

    it('should return error for nonexistent file when using append mode', function()
      local lines = { 'line1', 'line2' }
      local result, err = fs.append_file('/nonexistent/path/file.txt', lines)

      eq(result, nil)
      assert.is_not_nil(err)
    end)
  end)

  describe('remove_file', function()
    it('should return falsy when removing a nonexistent file', function()
      local result = fs.remove_file('/tmp/vgit_nonexistent_file_xyz')

      assert.is_falsy(result)
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
    it('should return true if file exists', function()
      eq(fs.exists('lua/vgit.lua'), true)
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

  describe('dirname', function()
    it('should return the directory name for a given filename', function()
      eq(fs.dirname('a/b/c/d/e'), 'a/b/c/d')
      eq(fs.dirname('a'), '.')
      eq(fs.dirname(''), '.')
    end)

    it('should work for absolute paths', function()
      eq(fs.dirname('/a/b/c'), '/a/b')
      eq(fs.dirname('/home/user/file.txt'), '/home/user')
    end)

    it('should return / for root path', function()
      eq(fs.dirname('/'), '/')
    end)
  end)
end)
