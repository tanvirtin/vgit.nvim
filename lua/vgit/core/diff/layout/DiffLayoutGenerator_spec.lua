local eq = assert.are.same

local DiffLayoutGenerator = require('vgit.core.diff.layout.DiffLayoutGenerator')

describe('DiffLayoutGenerator', function()
  describe('assert_layout_type', function()
    local gen

    before_each(function()
      gen = DiffLayoutGenerator()
    end)

    it('should return true for unified', function()
      assert.is_true(gen:assert_layout_type('unified', { 'unified', 'split' }))
    end)

    it('should return true for split', function()
      assert.is_true(gen:assert_layout_type('split', { 'unified', 'split' }))
    end)

    it('should return false for invalid layout type', function()
      assert.is_false(gen:assert_layout_type('invalid', { 'unified', 'split' }))
    end)

    it('should return false for nil layout type', function()
      assert.is_false(gen:assert_layout_type(nil, { 'unified', 'split' }))
    end)

    it('should return false for empty valid list', function()
      assert.is_false(gen:assert_layout_type('unified', {}))
    end)
  end)

  describe('generate', function()
    local gen
    local original_require
    local mock_diff_instance
    local captured_constructor_opts
    local captured_generate_args

    before_each(function()
      captured_constructor_opts = nil
      captured_generate_args = nil

      mock_diff_instance = {
        generate = function(self, hunks, lines, layout_type, opts)
          captured_generate_args = {
            hunks = hunks,
            lines = lines,
            layout_type = layout_type,
            opts = opts,
          }
          return { mock = 'result' }
        end,
      }

      -- Mock the Diff module by replacing it in package.loaded
      -- Must be a table with __call metamethod to work with lazy proxy
      original_require = package.loaded['vgit.core.diff.Diff']
      local mock_diff = setmetatable({}, {
        __call = function(_, opts)
          captured_constructor_opts = opts
          return mock_diff_instance
        end,
      })
      package.loaded['vgit.core.diff.Diff'] = mock_diff

      -- Re-require to pick up the mock
      package.loaded['vgit.core.diff.layout.DiffLayoutGenerator'] = nil
      DiffLayoutGenerator = require('vgit.core.diff.layout.DiffLayoutGenerator')
      gen = DiffLayoutGenerator()
    end)

    after_each(function()
      package.loaded['vgit.core.diff.Diff'] = original_require
      package.loaded['vgit.core.diff.layout.DiffLayoutGenerator'] = nil
      DiffLayoutGenerator = require('vgit.core.diff.layout.DiffLayoutGenerator')
    end)

    it('should pass hunks and lines to Diff constructor', function()
      local hunks = { { type = 'add' } }
      local lines = { 'line1', 'line2' }

      gen:generate(hunks, lines)

      eq({ hunks = hunks, lines = lines }, captured_constructor_opts)
    end)

    it('should default layout_type to unified', function()
      gen:generate({ { type = 'add' } }, { 'line1' })

      eq('unified', captured_generate_args.layout_type)
    end)

    it('should pass specified layout_type', function()
      gen:generate({ { type = 'add' } }, { 'line1' }, { layout_type = 'split' })

      eq('split', captured_generate_args.layout_type)
    end)

    it('should pass conflict option', function()
      local conflicts = { { current = {}, incoming = {} } }
      gen:generate({}, { 'line1' }, { conflict = conflicts })

      eq({ conflicts = conflicts, is_deleted = nil }, captured_generate_args.opts)
    end)

    it('should pass is_deleted option', function()
      gen:generate({}, { 'line1' }, { is_deleted = true })

      eq({ conflicts = nil, is_deleted = true }, captured_generate_args.opts)
    end)

    it('should pass both conflict and is_deleted options', function()
      local conflicts = { { current = {} } }
      gen:generate({}, { 'line1' }, { conflict = conflicts, is_deleted = true })

      eq({ conflicts = conflicts, is_deleted = true }, captured_generate_args.opts)
    end)

    it('should return the result from Diff:generate', function()
      local result = gen:generate({}, { 'line1' })

      eq({ mock = 'result' }, result)
    end)

    it('should error when hunks is nil', function()
      assert.has_error(function()
        gen:generate(nil, { 'line1' })
      end)
    end)

    it('should error when lines is nil', function()
      assert.has_error(function()
        gen:generate({}, nil)
      end)
    end)
  end)
end)
