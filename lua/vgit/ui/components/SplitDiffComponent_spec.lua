local ui_helper = require('tests.helpers.ui')
local eq = assert.are.same

describe('SplitDiffComponent:', function()
  local SplitDiffComponent

  before_each(function()
    SplitDiffComponent = require('vgit.ui.components.SplitDiffComponent')
  end)

  after_each(ui_helper.cleanup_ui)

  -- mount() creates child DiffComponents.
  -- We then mount each child to create their Elements (simulating ComponentManager),
  -- and call _element:mount() to open real Neovim windows for tests that need UI.
  local function create_split_component(overrides)
    overrides = overrides or {}
    local component = SplitDiffComponent(overrides.props or {})
    component:mount()
    if component.children.previous then
      component.children.previous:mount()
    end
    if component.children.current then
      component.children.current:mount()
    end
    for k, v in pairs(overrides.state or {}) do
      component.state[k] = v
    end
    return component
  end

  describe('calculate_split_line_numbers', function()
    -- Pure logic tests: only need _line_number_calculator — no real UI required
    it('should separate lnum_changes by buftype', function()
      local component = SplitDiffComponent({})
      local diff = {
        lines = { 'line1', 'line2', 'line3' },
        current_lines = { 'line1', 'line2', 'line3' },
        previous_lines = { 'line1', 'line2', 'line3' },
        marks = {},
        lnum_changes = {
          { buftype = 'current', lnum = 1, type = 'add' },
          { buftype = 'previous', lnum = 1, type = 'remove' },
          { buftype = 'current', lnum = 2, type = 'void' },
          { buftype = 'previous', lnum = 2, type = 'void' },
        },
      }

      local result = component:calculate_split_line_numbers(diff)

      assert.is_not_nil(result.previous)
      assert.is_not_nil(result.current)
      assert.are.equal(#diff.previous_lines, #result.previous.lines)
      assert.are.equal(#diff.current_lines, #result.current.lines)
      assert.are.equal(#result.previous.lines, #result.current.lines)
      assert.are.equal(#diff.previous_lines, #result.previous.changes)
      assert.are.equal(#diff.current_lines, #result.current.changes)
    end)

    it('should handle empty lnum_changes', function()
      local component = SplitDiffComponent({})
      local diff = {
        lines = {},
        current_lines = {},
        previous_lines = {},
        marks = {},
        lnum_changes = {},
      }

      local result = component:calculate_split_line_numbers(diff)

      assert.is_not_nil(result.previous)
      assert.is_not_nil(result.current)
      assert.are.equal(0, #result.previous.lines)
      assert.are.equal(0, #result.current.lines)
    end)

    it('should produce equal-length results when sides have equal lines', function()
      local component = SplitDiffComponent({})
      local lines = { 'a', 'b', 'c', 'd', 'e' }
      local diff = {
        lines = lines,
        current_lines = lines,
        previous_lines = lines,
        marks = {},
        lnum_changes = {
          { buftype = 'current', lnum = 2, type = 'add' },
          { buftype = 'previous', lnum = 2, type = 'void' },
          { buftype = 'current', lnum = 4, type = 'void' },
          { buftype = 'previous', lnum = 4, type = 'remove' },
        },
      }

      local result = component:calculate_split_line_numbers(diff)

      assert.are.equal(#result.previous.lines, #result.current.lines)
      assert.are.equal(5, #result.current.lines)
    end)
  end)

  describe('on_props', function()
    -- Tests that set_props triggers render when diff or filetype changes
    it('should trigger render when diff changes', function()
      local diff_ref = { lines = {} }
      local component = SplitDiffComponent({ diff = diff_ref, filetype = 'lua' })
      local render_called = false
      component.render = function() render_called = true end
      component._mounted = true

      component:set_props({ diff = { lines = {} } })
      assert.is_true(render_called)
    end)

    it('should trigger render when filetype changes', function()
      local diff_ref = { lines = {} }
      local component = SplitDiffComponent({ diff = diff_ref, filetype = 'lua' })
      local render_called = false
      component.render = function() render_called = true end
      component._mounted = true

      component:set_props({ filetype = 'python' })
      assert.is_true(render_called)
    end)

    it('should not trigger render when nothing changes', function()
      local diff_ref = { lines = {} }
      local component = SplitDiffComponent({ diff = diff_ref, filetype = 'lua' })
      local render_called = false
      component.render = function() render_called = true end
      component._mounted = true

      component:set_props({ diff = diff_ref, filetype = 'lua' })
      assert.is_false(render_called)
    end)
  end)

  describe('_for_both', function()
    it('should apply operation to both child components', function()
      local component = create_split_component()
      local prev_called = false
      local curr_called = false

      component.children.previous.test_method = function()
        prev_called = true
      end
      component.children.current.test_method = function()
        curr_called = true
      end

      component:_for_both(function(c)
        c:test_method()
      end)

      assert.is_true(prev_called)
      assert.is_true(curr_called)
    end)

    it('should handle nil previous component gracefully', function()
      local component = create_split_component()
      local curr_called = false

      component.children.previous = nil
      component.children.current.test_method = function()
        curr_called = true
      end

      component:_for_both(function(c)
        c:test_method()
      end)

      assert.is_true(curr_called)
    end)

    it('should handle nil current component gracefully', function()
      local component = create_split_component()
      local prev_called = false

      component.children.previous.test_method = function()
        prev_called = true
      end
      component.children.current = nil

      component:_for_both(function(c)
        c:test_method()
      end)

      assert.is_true(prev_called)
    end)

    it('should handle both nil gracefully', function()
      local component = create_split_component()
      component.children.previous = nil
      component.children.current = nil

      -- should not error
      component:_for_both(function(c)
        c:test_method()
      end)
    end)
  end)

  describe('get_hunks', function()
    it('should delegate to current child', function()
      local hunks = {
        { header = '@@ -1,3 +1,4 @@', diff = {}, top = 1, bot = 4 },
        { header = '@@ -10,2 +10,3 @@', diff = {}, top = 10, bot = 12 },
      }
      local component = create_split_component()
      component.children.current.get_hunks = function()
        return hunks
      end

      eq(hunks, component:get_hunks())
    end)

    it('should return empty table when current child is nil', function()
      local component = create_split_component()
      component.children.current = nil

      eq({}, component:get_hunks())
    end)

    it('should return empty table when current child has no hunks', function()
      local component = create_split_component()
      component.children.current.get_hunks = function()
        return {}
      end

      eq({}, component:get_hunks())
    end)
  end)

  describe('get_marks', function()
    it('should delegate to current child', function()
      local marks = {
        { top = 5, bot = 10 },
        { top = 15, bot = 20 },
      }
      local component = create_split_component()
      component.children.current.get_marks = function()
        return marks
      end

      eq(marks, component:get_marks())
    end)

    it('should return empty table when current child is nil', function()
      local component = create_split_component()
      component.children.current = nil

      eq({}, component:get_marks())
    end)
  end)

  describe('get_hunk_under_cursor', function()
    it('should delegate to current child', function()
      local hunk = { header = '@@ -1,3 +1,4 @@', diff = {} }
      local component = create_split_component()
      component.children.current.get_hunk_under_cursor = function()
        return hunk
      end

      eq(hunk, component:get_hunk_under_cursor())
    end)

    it('should return nil when current child is nil', function()
      local component = create_split_component()
      component.children.current = nil

      assert.is_nil(component:get_hunk_under_cursor())
    end)
  end)

  describe('get_current_mark_under_cursor', function()
    it('should delegate to current child', function()
      local mark = { top = 5, bot = 10 }
      local component = create_split_component()
      component.children.current.get_current_mark_under_cursor = function()
        return mark
      end

      eq(mark, component:get_current_mark_under_cursor())
    end)

    it('should return nil when current child is nil', function()
      local component = create_split_component()
      component.children.current = nil

      assert.is_nil(component:get_current_mark_under_cursor())
    end)
  end)

  describe('get_relative_mark_index', function()
    it('should delegate to current child', function()
      local component = create_split_component()
      component.children.current.get_relative_mark_index = function(_, lnum)
        return lnum < 10 and 1 or 2
      end

      eq(1, component:get_relative_mark_index(5))
      eq(2, component:get_relative_mark_index(15))
    end)

    it('should return 1 when current child is nil', function()
      local component = create_split_component()
      component.children.current = nil

      eq(1, component:get_relative_mark_index(5))
    end)
  end)

  describe('get_lnum', function()
    it('should delegate to current child', function()
      local component = create_split_component()
      component.children.current.get_lnum = function()
        return 42
      end

      eq(42, component:get_lnum())
    end)

    it('should return 1 when current child is nil', function()
      local component = create_split_component()
      component.children.current = nil

      eq(1, component:get_lnum())
    end)
  end)

  describe('is_valid', function()
    it('should return true when current child is valid', function()
      local component = create_split_component()
      component.children.previous = nil
      component.children.current = { is_valid = function() return true end }

      assert.is_truthy(component:is_valid())
    end)

    it('should return true when previous child is valid', function()
      local component = create_split_component()
      component.children.current = nil
      component.children.previous = { is_valid = function() return true end }

      assert.is_truthy(component:is_valid())
    end)

    it('should return false when both children are nil', function()
      local component = create_split_component()
      component.children.previous = nil
      component.children.current = nil

      assert.is_falsy(component:is_valid())
    end)
  end)

  describe('hunk_down', function()
    it('should delegate to current child', function()
      local mark = { top = 15, bot = 20 }
      local component = create_split_component()
      component.children.current.hunk_down = function()
        return mark
      end

      eq(mark, component:hunk_down())
    end)

    it('should return nil when current child is nil', function()
      local component = create_split_component()
      component.children.current = nil

      assert.is_nil(component:hunk_down())
    end)
  end)

  describe('hunk_up', function()
    it('should delegate to current child', function()
      local mark = { top = 5, bot = 10 }
      local component = create_split_component()
      component.children.current.hunk_up = function()
        return mark
      end

      eq(mark, component:hunk_up())
    end)

    it('should return nil when current child is nil', function()
      local component = create_split_component()
      component.children.current = nil

      assert.is_nil(component:hunk_up())
    end)
  end)

  describe('split data pipeline with real Diff', function()
    local Diff = require('vgit.core.diff.Diff')
    local GitHunk = require('vgit.git.GitHunk')

    local function make_hunk(header, diff_lines)
      local hunk = GitHunk(header)
      for _, line in ipairs(diff_lines or {}) do
        hunk:push(line)
      end
      return hunk
    end

    it('should produce equal-length previous and current line_numbers from real Diff', function()
      local hunk = make_hunk('@@ -2,1 +2,1 @@', { '-old', '+new' })
      local diff = Diff():generate_split({ hunk }, { 'a', 'new', 'c' })

      local component = SplitDiffComponent({})
      local result = component:calculate_split_line_numbers(diff)

      eq(#result.previous.lines, #result.current.lines)
      eq(#diff.current_lines, #result.current.lines)
    end)

    it('should produce equal-length changes for both sides', function()
      local hunk = make_hunk('@@ -0,0 +1,2 @@', { '+new1', '+new2' })
      local diff = Diff():generate_split({ hunk }, { 'new1', 'new2' })

      local component = SplitDiffComponent({})
      local result = component:calculate_split_line_numbers(diff)

      eq(#result.previous.changes, #result.current.changes)
      eq(#diff.current_lines, #result.current.changes)
    end)

    it('should assign void entries on correct side for add hunk', function()
      local hunk = make_hunk('@@ -0,0 +1,2 @@', { '+new1', '+new2' })
      local diff = Diff():generate_split({ hunk }, { 'new1', 'new2' })

      local component = SplitDiffComponent({})
      local result = component:calculate_split_line_numbers(diff)

      -- Previous side should have void highlights for added lines
      local prev_void_count = 0
      for _, change in ipairs(result.previous.changes) do
        if change.lnum_change and change.lnum_change.type == 'void' then prev_void_count = prev_void_count + 1 end
      end
      assert.is_true(prev_void_count > 0, 'previous side should have void entries for adds')
    end)

    it('should assign void entries on correct side for remove hunk', function()
      local hunk = make_hunk('@@ -3,2 +3,0 @@', { '-removed1', '-removed2' })
      local diff = Diff():generate_split({ hunk }, { 'a', 'b', 'c', 'd' })

      local component = SplitDiffComponent({})
      local result = component:calculate_split_line_numbers(diff)

      -- Current side should have void highlights for removed lines
      local curr_void_count = 0
      for _, change in ipairs(result.current.changes) do
        if change.lnum_change and change.lnum_change.type == 'void' then curr_void_count = curr_void_count + 1 end
      end
      assert.is_true(curr_void_count > 0, 'current side should have void entries for removes')
    end)

    it('should handle mixed hunks with correct line number separation', function()
      local hunk1 = make_hunk('@@ -0,0 +1,2 @@', { '+new1', '+new2' })
      local hunk2 = make_hunk('@@ -4,2 +6,0 @@', { '-removed1', '-removed2' })
      local diff = Diff():generate_split({ hunk1, hunk2 }, { 'new1', 'new2', 'a', 'b', 'c', 'd' })

      local component = SplitDiffComponent({})
      local result = component:calculate_split_line_numbers(diff)

      eq(#result.previous.lines, #result.current.lines)
      eq(#result.previous.changes, #result.current.changes)
    end)

    it('should produce line_number highlights matching change types per side', function()
      local hunk = make_hunk('@@ -2,1 +2,1 @@', { '-old', '+new' })
      local diff = Diff():generate_split({ hunk }, { 'a', 'new', 'c' })

      local component = SplitDiffComponent({})
      local result = component:calculate_split_line_numbers(diff)

      -- Check that highlight groups appear in the results
      local prev_hls = {}
      for _, ln in ipairs(result.previous.lines) do
        prev_hls[ln[2]] = true
      end
      local curr_hls = {}
      for _, ln in ipairs(result.current.lines) do
        curr_hls[ln[2]] = true
      end
      -- Previous side should have at least delete or context hl
      assert.is_true(prev_hls['GitSignsDelete'] ~= nil or prev_hls['GitLineNr'] ~= nil)
      -- Current side should have at least add or context hl
      assert.is_true(curr_hls['GitSignsAdd'] ~= nil or curr_hls['GitLineNr'] ~= nil)
    end)
  end)

  describe('get_filetype', function()
    it('should delegate to current child', function()
      local component = create_split_component()
      component.children.current.get_filetype = function()
        return 'lua'
      end

      eq('lua', component:get_filetype())
    end)

    it('should return empty string when current child is nil', function()
      local component = create_split_component()
      component.children.current = nil

      eq('', component:get_filetype())
    end)
  end)
end)
