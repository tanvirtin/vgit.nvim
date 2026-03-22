local ui_helper = require('tests.helpers.ui')
local eq = assert.are.same

describe('BlameInfoComponent:', function()
  local BlameInfoComponent

  before_each(function()
    BlameInfoComponent = require('vgit.ui.components.BlameInfoComponent')
  end)

  after_each(ui_helper.cleanup_ui)

  local function mount_component(props)
    local component = BlameInfoComponent(props or {})
    ui_helper.mount({ component = component, mode = 'popup', width = 80, height = 20 })
    return component
  end

  describe('get_initial_state', function()
    it('should return table with blame = nil', function()
      local instance = BlameInfoComponent({})

      assert.is_table(instance.state)
      assert.is_nil(instance.state.blame)
    end)
  end)

  describe('get_layout_spec', function()
    it('should return a view spec with height 3', function()
      local instance = mount_component()
      local spec = instance:get_layout_spec()

      eq('view', spec.type)
      eq(3, spec.height)
    end)
  end)

  describe('render', function()
    local function make_blame(overrides)
      local blame = {
        commit_hash = 'abc1234def5678',
        commit_message = 'Fix important bug',
        author = 'Alice',
        author_mail = 'alice@example.com',
        author_time = 1700000000,
        age = function()
          return { display = '2 months ago' }
        end,
      }
      if overrides then
        for k, v in pairs(overrides) do
          blame[k] = v
        end
      end
      return blame
    end

    it('should not error when blame is nil', function()
      local component = mount_component()
      component:set_props({ blame = nil })
    end)

    it('should render commit hash on line 1', function()
      local blame = make_blame()
      local component = mount_component({ blame = blame })
      local lines = component:with_element(function(el)
        return el:get_lines()
      end)

      eq(blame.commit_hash, lines[1])
    end)

    it('should render parent -> hash format when parent_hash exists', function()
      local blame = make_blame({ parent_hash = 'parent123' })
      local component = mount_component({ blame = blame })
      local lines = component:with_element(function(el)
        return el:get_lines()
      end)

      eq('parent123 -> abc1234def5678', lines[1])
    end)

    it('should render author and mail on line 2', function()
      local blame = make_blame()
      local component = mount_component({ blame = blame })
      local lines = component:with_element(function(el)
        return el:get_lines()
      end)

      eq('Alice (alice@example.com)', lines[2])
    end)

    it('should render commit message on line 3', function()
      local blame = make_blame()
      local component = mount_component({ blame = blame })
      local lines = component:with_element(function(el)
        return el:get_lines()
      end)

      eq('Fix important bug', lines[3])
    end)

    it('should truncate message longer than 88 chars', function()
      local long_msg = string.rep('x', 100)
      local blame = make_blame({ commit_message = long_msg })
      local component = mount_component({ blame = blame })
      local lines = component:with_element(function(el)
        return el:get_lines()
      end)

      eq(string.rep('x', 88) .. '...', lines[3])
    end)

    it('should not truncate message at exactly 88 chars', function()
      local msg = string.rep('y', 88)
      local blame = make_blame({ commit_message = msg })
      local component = mount_component({ blame = blame })
      local lines = component:with_element(function(el)
        return el:get_lines()
      end)

      eq(msg, lines[3])
    end)

    it('should always produce exactly 3 lines', function()
      local blame = make_blame()
      local component = mount_component({ blame = blame })
      local lines = component:with_element(function(el)
        return el:get_lines()
      end)

      eq(3, #lines)
    end)

    it('should update lines when props change', function()
      local blame1 = make_blame({ commit_message = 'First message' })
      local blame2 = make_blame({ commit_message = 'Second message' })

      local component = mount_component({ blame = blame1 })
      local lines1 = component:with_element(function(el)
        return el:get_lines()
      end)
      eq('First message', lines1[3])

      component:set_props({ blame = blame2 })
      local lines2 = component:with_element(function(el)
        return el:get_lines()
      end)
      eq('Second message', lines2[3])
    end)
  end)
end)
