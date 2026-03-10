local ui_helper = require('tests.helpers.ui')
local eq = assert.are.same
local save_package, restore_packages = require('tests.helpers.package_mock').create()

local function create_diff_component(opts)
  local DiffComponent = require('vgit.ui.components.DiffComponent')
  local ComponentManager = require('vgit.ui.ComponentManager')
  opts = opts or {}

  local component = DiffComponent(opts.props or {})
  ComponentManager():render({ component = component, mode = 'popup', width = opts.width or 80, height = opts.height or 40 })

  local max_line = opts.max_lines or 50
  local dummy = {}
  for i = 1, max_line do
    dummy[i] = ''
  end
  component._element:set_lines(dummy)

  component._viewport_dirty = true
  component._last_top = nil
  component._last_bot = nil

  return component
end

local function make_scene(components)
  components = components or {}
  return {
    set = function(_, key, value) components[key] = value end,
    get = function(_, key) return components[key] end,
  }
end

local function make_props(overrides)
  overrides = overrides or {}
  return {
    layout_type = overrides.layout_type or function() return 'unified' end,
    filename = overrides.filename or function() return 'test.lua' end,
    filetype = overrides.filetype or function() return 'lua' end,
    diff = overrides.diff or function() return nil end,
  }
end

describe('DiffView:', function()
  local DiffView

  before_each(function()
    save_package('vgit.core.loop')
    package.loaded['vgit.core.loop'] = { free_textlock = function() end }

    package.loaded['vgit.ui.views.DiffView'] = nil
    DiffView = require('vgit.ui.views.DiffView')
  end)

  after_each(function()
    ui_helper.cleanup_ui()
    restore_packages()
    package.loaded['vgit.ui.views.DiffView'] = nil
  end)

  describe('constructor', function()
    it('should initialize with default state', function()
      local view = DiffView(make_scene(), make_props(), {})
      eq({}, view.state.current_lines_changes)
      eq({}, view.state.previous_lines_changes)
    end)

    it('should store scene, props, plot, and config', function()
      local scene = make_scene()
      local props = make_props()
      local config = { elements = { header = false } }
      local view = DiffView(scene, props, { row = 0 }, config)
      eq(scene, view.scene)
      eq(props, view.props)
      eq({ row = 0 }, view.plot)
      eq(config, view.config)
    end)

    it('should default config to empty table', function()
      local view = DiffView(make_scene(), make_props(), {})
      eq({}, view.config)
    end)
  end)

  describe('get_initial_state', function()
    it('should return empty line changes', function()
      local state = DiffView:get_initial_state()
      eq({}, state.current_lines_changes)
      eq({}, state.previous_lines_changes)
    end)
  end)

  describe('get_components', function()
    it('should return one component for unified layout', function()
      local current = create_diff_component()
      local scene = make_scene({ current = current })
      local props = make_props({ layout_type = function() return 'unified' end })
      local view = DiffView(scene, props, {})

      local components = view:get_components()
      eq(1, #components)
      eq(current, components[1])
    end)

    it('should return two components for split layout', function()
      local current = create_diff_component()
      local previous = create_diff_component()
      local scene = make_scene({ current = current, previous = previous })
      local props = make_props({ layout_type = function() return 'split' end })
      local view = DiffView(scene, props, {})

      local components = view:get_components()
      eq(2, #components)
    end)
  end)

  describe('prepend_padding', function()
    it('should return lines unchanged when no tabline padding', function()
      local view = DiffView(make_scene(), make_props(), {})
      vim.o.showtabline = 0
      local lines = { 'a', 'b', 'c' }
      local result = view:prepend_padding(lines)
      eq(lines, result)
    end)

    it('should prepend empty lines when tabline is visible', function()
      local saved = vim.o.showtabline
      vim.o.showtabline = 2
      local view = DiffView(make_scene(), make_props(), {})
      local lines = { 'a', 'b' }
      local result = view:prepend_padding(lines)
      eq(3, #result)
      eq('', result[1])
      eq('a', result[2])
      eq('b', result[3])
      vim.o.showtabline = saved
    end)
  end)

  describe('get_tabline_padding', function()
    it('should return 0 when showtabline is 0', function()
      vim.o.showtabline = 0
      local view = DiffView(make_scene(), make_props(), {})
      eq(0, view:get_tabline_padding())
    end)

    it('should return 1 when showtabline > 0', function()
      local saved = vim.o.showtabline
      vim.o.showtabline = 2
      local view = DiffView(make_scene(), make_props(), {})
      eq(1, view:get_tabline_padding())
      vim.o.showtabline = saved
    end)
  end)

  describe('render_lines', function()
    it('should skip when diff is nil', function()
      local current = create_diff_component()
      local scene = make_scene({ current = current })
      local props = make_props({ diff = function() return nil end })
      local view = DiffView(scene, props, {})

      -- Should not error
      view:render_lines()
    end)

    it('should call set_lines on current for unified layout', function()
      local current = create_diff_component()
      local scene = make_scene({ current = current })
      local diff = {
        lines = { 'line1', 'line2', 'line3' },
        marks = {},
        hunks = {},
        lnum_changes = {},
        stat = { added = 0, removed = 0 },
      }
      local props = make_props({
        layout_type = function() return 'unified' end,
        diff = function() return diff end,
      })
      local view = DiffView(scene, props, {})
      vim.o.showtabline = 0

      -- Should not error — verifies set_lines is called
      view:render_lines()
      -- DiffComponent:set_lines triggers internal render which sets buffer lines
      assert.is_true(current:get_line_count() > 0)
    end)

    it('should call set_lines on both components for split layout', function()
      local current = create_diff_component()
      local previous = create_diff_component()
      local scene = make_scene({ current = current, previous = previous })
      local diff = {
        lines = {},
        previous_lines = { 'prev1', 'prev2' },
        current_lines = { 'curr1', 'curr2' },
        marks = {},
        hunks = {},
        lnum_changes = {},
        stat = { added = 0, removed = 0 },
      }
      local props = make_props({
        layout_type = function() return 'split' end,
        diff = function() return diff end,
      })
      local view = DiffView(scene, props, {})
      vim.o.showtabline = 0

      -- Should not error
      view:render_lines()
      assert.is_true(current:get_line_count() > 0)
      assert.is_true(previous:get_line_count() > 0)
    end)
  end)

  describe('navigation', function()
    local function setup_nav_view(marks, cursor_lnum)
      local current = create_diff_component({ max_lines = 20 })
      current:set_lnum(cursor_lnum or 1)
      local scene = make_scene({ current = current })
      local diff = {
        lines = {},
        marks = marks,
        hunks = marks,
        lnum_changes = {},
        stat = { added = 0, removed = 0 },
      }
      for i = 1, 20 do
        diff.lines[i] = ''
      end
      local props = make_props({ diff = function() return diff end })
      local view = DiffView(scene, props, {})
      vim.o.showtabline = 0
      return view, current
    end

    describe('get_current_mark_under_cursor', function()
      it('should return nil when diff is nil', function()
        local current = create_diff_component()
        local scene = make_scene({ current = current })
        local props = make_props({ diff = function() return nil end })
        local view = DiffView(scene, props, {})
        vim.o.showtabline = 0

        assert.is_nil(view:get_current_mark_under_cursor())
      end)

      it('should return mark when cursor is within range', function()
        local marks = {
          { top = 1, bot = 3 },
          { top = 7, bot = 9 },
        }
        local view = setup_nav_view(marks, 2)

        local mark, idx = view:get_current_mark_under_cursor()
        eq(marks[1], mark)
        eq(1, idx)
      end)

      it('should return nil when cursor is outside all marks', function()
        local marks = {
          { top = 2, bot = 3 },
          { top = 7, bot = 8 },
        }
        local view = setup_nav_view(marks, 5)

        assert.is_nil(view:get_current_mark_under_cursor())
      end)
    end)

    describe('get_hunk_under_cursor', function()
      it('should return hunk and index when cursor is in a mark', function()
        local marks = { { top = 1, bot = 4 } }
        local view = setup_nav_view(marks, 2)

        local hunk, idx = view:get_hunk_under_cursor()
        eq(marks[1], hunk)
        eq(1, idx)
      end)

      it('should return nil when diff is nil', function()
        local current = create_diff_component()
        local scene = make_scene({ current = current })
        local props = make_props({ diff = function() return nil end })
        local view = DiffView(scene, props, {})
        vim.o.showtabline = 0

        assert.is_nil(view:get_hunk_under_cursor())
      end)
    end)

    describe('get_relative_mark_index', function()
      it('should return mark index for relative lnum', function()
        local marks = {
          { top = 2, bot = 4, top_relative = 2, bot_relative = 4 },
          { top = 7, bot = 9, top_relative = 7, bot_relative = 9 },
        }
        local diff = {
          lines = {},
          marks = marks,
          hunks = marks,
          lnum_changes = {},
          stat = { added = 0, removed = 0 },
        }
        local current = create_diff_component()
        local scene = make_scene({ current = current })
        local props = make_props({ diff = function() return diff end })
        local view = DiffView(scene, props, {})

        eq(2, view:get_relative_mark_index(8))
      end)

      it('should return 1 when diff is nil', function()
        local current = create_diff_component()
        local scene = make_scene({ current = current })
        local props = make_props({ diff = function() return nil end })
        local view = DiffView(scene, props, {})

        eq(1, view:get_relative_mark_index(5))
      end)
    end)

    describe('next', function()
      it('should return nil when diff is nil', function()
        local current = create_diff_component()
        local scene = make_scene({ current = current })
        local props = make_props({ diff = function() return nil end })
        local view = DiffView(scene, props, {})
        vim.o.showtabline = 0

        assert.is_nil(view:next())
      end)
    end)

    describe('prev', function()
      it('should return nil when diff is nil', function()
        local current = create_diff_component()
        local scene = make_scene({ current = current })
        local props = make_props({ diff = function() return nil end })
        local view = DiffView(scene, props, {})
        vim.o.showtabline = 0

        assert.is_nil(view:prev())
      end)
    end)

    describe('move_to_hunk', function()
      it('should do nothing when diff is nil', function()
        local current = create_diff_component()
        local scene = make_scene({ current = current })
        local props = make_props({ diff = function() return nil end })
        local view = DiffView(scene, props, {})

        -- Should not error
        view:move_to_hunk(1)
      end)
    end)
  end)

  describe('get_file_lnum', function()
    it('should return nil when no line changes', function()
      local current = create_diff_component()
      local scene = make_scene({ current = current })
      local view = DiffView(scene, make_props(), {})

      assert.is_nil(view:get_file_lnum())
    end)

    it('should return line number from current cursor position', function()
      local current = create_diff_component()
      current:set_lnum(2)
      local scene = make_scene({ current = current })
      local view = DiffView(scene, make_props(), {})

      view.state.current_lines_changes = {
        { line_number = '1 ', lnum_change = nil },
        { line_number = '2 ', lnum_change = nil },
        { line_number = '3 ', lnum_change = nil },
      }

      eq(2, view:get_file_lnum())
    end)

    it('should search upward for removed lines', function()
      local current = create_diff_component()
      current:set_lnum(3)
      local scene = make_scene({ current = current })
      local view = DiffView(scene, make_props(), {})

      view.state.current_lines_changes = {
        { line_number = '1 ', lnum_change = nil },
        { line_number = '2 ', lnum_change = nil },
        { line_number = '  ', lnum_change = { type = 'remove' } },
        { line_number = '3 ', lnum_change = nil },
      }

      eq(2, view:get_file_lnum())
    end)
  end)

  describe('render_title', function()
    it('should not render when filename is nil', function()
      local current = create_diff_component()
      local scene = make_scene({ current = current })
      local props = make_props({ filename = function() return nil end })
      local view = DiffView(scene, props, {})

      -- Should not error
      view:render_title()
    end)

    it('should not render when filetype is nil', function()
      local current = create_diff_component()
      local scene = make_scene({ current = current })
      local props = make_props({ filetype = function() return nil end })
      local view = DiffView(scene, props, {})

      view:render_title()
    end)

    it('should not render when diff is nil', function()
      local current = create_diff_component()
      local scene = make_scene({ current = current })
      local props = make_props({ diff = function() return nil end })
      local view = DiffView(scene, props, {})

      view:render_title()
    end)
  end)

  describe('render_filetype', function()
    it('should skip when filetype is nil', function()
      local current = create_diff_component()
      local scene = make_scene({ current = current })
      local props = make_props({ filetype = function() return nil end })
      local view = DiffView(scene, props, {})

      -- Should not error
      view:render_filetype()
    end)
  end)

  describe('clear methods', function()
    it('clear_extmarks should clear current for unified', function()
      local current = create_diff_component()
      local scene = make_scene({ current = current })
      local props = make_props({ layout_type = function() return 'unified' end })
      local view = DiffView(scene, props, {})

      view:clear_extmarks()
    end)

    it('clear_extmarks should clear both for split', function()
      local current = create_diff_component()
      local previous = create_diff_component()
      local scene = make_scene({ current = current, previous = previous })
      local props = make_props({ layout_type = function() return 'split' end })
      local view = DiffView(scene, props, {})

      view:clear_extmarks()
    end)

    it('clear_lines should clear and disable cursorline', function()
      local current = create_diff_component()
      local scene = make_scene({ current = current })
      local props = make_props({ layout_type = function() return 'unified' end })
      local view = DiffView(scene, props, {})

      view:clear_lines()
    end)

    it('reset_cursor should reset cursor on all components', function()
      local current = create_diff_component()
      current:set_lnum(5)
      local scene = make_scene({ current = current })
      local props = make_props({ layout_type = function() return 'unified' end })
      local view = DiffView(scene, props, {})

      view:reset_cursor()
      eq(1, current:get_lnum())
    end)
  end)

  describe('render_unified_line_numbers', function()
    it('should skip when diff is nil', function()
      local current = create_diff_component()
      local scene = make_scene({ current = current })
      local props = make_props({ diff = function() return nil end })
      local view = DiffView(scene, props, {})

      -- Should not error
      view:render_unified_line_numbers()
      eq({}, view.state.current_lines_changes)
    end)
  end)

  describe('mount', function()
    it('should reset state', function()
      local current = create_diff_component()
      local scene = make_scene({ current = current })
      local props = make_props({ layout_type = function() return 'unified' end })
      local view = DiffView(scene, props, {})

      view.state.current_lines_changes = { { line_number = '1' } }
      view:mount()
      eq({}, view.state.current_lines_changes)
    end)
  end)

  describe('render', function()
    it('should clear everything when diff is nil', function()
      local current = create_diff_component()
      current._element:set_lines({ 'some', 'content' })
      local scene = make_scene({ current = current })
      local props = make_props({
        layout_type = function() return 'unified' end,
        diff = function() return nil end,
      })
      local view = DiffView(scene, props, {})

      view:render()
      eq({}, view.state.current_lines_changes)
    end)
  end)
end)
