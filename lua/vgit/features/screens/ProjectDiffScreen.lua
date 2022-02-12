local Window = require('vgit.core.Window')
local utils = require('vgit.core.utils')
local loop = require('vgit.core.loop')
local CodeComponent = require('vgit.ui.components.CodeComponent')
local HeaderComponent = require('vgit.ui.components.HeaderComponent')
local FoldableListComponent = require('vgit.ui.components.FoldedListComponent')
local CodeListScreen = require('vgit.ui.screens.CodeListScreen')
local Scene = require('vgit.ui.Scene')
local console = require('vgit.core.console')
local FileEntry = require('vgit.ui.FileEntry')
local fs = require('vgit.core.fs')
local Diff = require('vgit.Diff')
local project_diff_preview_setting = require(
  'vgit.settings.project_diff_preview'
)

local ProjectDiffScreen = CodeListScreen:extend()

function ProjectDiffScreen:new(...)
  return setmetatable(CodeListScreen:new(...), ProjectDiffScreen)
end

function ProjectDiffScreen:generate_dto(file_entry)
  local type = file_entry.type
  local git = self.git
  local state = self.state
  local filename = file_entry.file.filename
  local status = file_entry.file.status
  local lines_err, lines
  if status:has('D ') then
    lines_err, lines = git:show(filename, 'HEAD')
  elseif status:has(' D') then
    lines_err, lines = git:show(git:tracked_filename(filename))
  else
    lines_err, lines = fs.read_file(filename)
  end
  if lines_err then
    console.debug(lines_err, debug.traceback())
    state.err = lines_err
    return self
  end
  local hunks_err, hunks
  if status:has_both('??') then
    hunks = git:untracked_hunks(lines)
  elseif status:has_either('DD') then
    hunks = git:deleted_hunks(lines)
  elseif type == 'staged' then
    hunks_err, hunks = git:staged_hunks(filename)
  else
    hunks_err, hunks = git:index_hunks(filename)
  end
  if hunks_err then
    console.debug(hunks_err, debug.traceback())
    state.err = hunks_err
    return self
  end
  local dto
  if status:has_either('DD') then
    dto = Diff:new(hunks):call_deleted(lines, self.layout_type)
  else
    dto = Diff:new(hunks):call(lines, self.layout_type)
  end
  return dto
end

function ProjectDiffScreen:partition_status(status_files)
  local changed_files = {}
  local staged_files = {}
  utils.list.each(status_files, function(file)
    if file:is_untracked() then
      changed_files[#changed_files + 1] = file
    else
      if file:is_unstaged() then
        changed_files[#changed_files + 1] = file
      end
      if file:is_staged() then
        staged_files[#staged_files + 1] = file
      end
    end
  end)
  return changed_files, staged_files
end

function ProjectDiffScreen:get_file_entry_from_list()
  local scene = self.scene
  if scene then
    local list = scene.components.list
    loop.await_fast_event()
    local item = list:get_list_item(self.list_control:i())
    if item then
      return item.file_entry
    end
  end
end

function ProjectDiffScreen:resync_code_data()
  local state = self.state
  local file_entry = self:get_file_entry_from_list()
  if file_entry then
    state.data = utils.object.assign(state.data, {
      file_entry = file_entry,
      filename = file_entry.file.filename,
      filetype = file_entry.file.filetype,
      dto = self:generate_dto(file_entry),
    })
  end
  return self
end

function ProjectDiffScreen:fetch(opts)
  opts = opts or {}
  local state = self.state
  local git = self.git
  local changed_files, staged_files
  if not opts.cached then
    local status_files_err, status_files = git:status()
    if status_files_err then
      console.debug(status_files_err, debug.traceback())
      state.err = status_files_err
      return self
    end
    changed_files, staged_files = self:partition_status(status_files)
    state.data = {
      changed_files = changed_files,
      staged_files = staged_files,
    }
    local first_changed_file, first_staged_file =
      changed_files[1], staged_files[1]
    local file_entry
    if first_changed_file then
      file_entry = FileEntry:new(first_changed_file, 'changed')
    elseif first_staged_file then
      file_entry = FileEntry:new(first_staged_file, 'staged')
    end
    if file_entry then
      state.data = utils.object.assign(state.data, {
        file_entry = file_entry,
        filename = file_entry.file.filename,
        filetype = file_entry.file.filetype,
        dto = self:generate_dto(file_entry),
      })
    end
  end
  return self
end

function ProjectDiffScreen:get_unified_scene_definition()
  return {
    header = HeaderComponent:new({
      config = {
        win_plot = {
          width = '100vw',
        },
      },
    }),
    current = CodeComponent:new({
      config = {
        elements = {
          header = false,
          footer = false,
        },
        win_options = {
          cursorbind = true,
          scrollbind = true,
          cursorline = true,
        },
        win_plot = {
          row = HeaderComponent:get_height(),
          height = '100vh',
          width = '80vw',
          col = '20vw',
        },
      },
    }),
    list = FoldableListComponent:new({
      config = {
        elements = {
          header = false,
          footer = false,
        },
        win_plot = {
          row = HeaderComponent:get_height(),
          height = '100vh',
          width = '20vw',
        },
      },
    }),
  }
end

function ProjectDiffScreen:get_split_scene_definition(props)
  return {
    header = HeaderComponent:new(utils.object.assign({
      config = {
        win_plot = {
          width = '100vw',
        },
      },
    }, props)),
    previous = CodeComponent:new(utils.object.assign({
      config = {
        elements = {
          header = false,
          footer = false,
        },
        win_options = {
          cursorbind = true,
          scrollbind = true,
          cursorline = true,
        },
        win_plot = {
          row = HeaderComponent:get_height(),
          height = '100vh',
          width = '40vw',
          col = '20vw',
        },
      },
    }, props)),
    current = CodeComponent:new(utils.object.assign({
      config = {
        elements = {
          header = false,
          footer = false,
        },
        win_options = {
          cursorbind = true,
          scrollbind = true,
          cursorline = true,
        },
        win_plot = {
          row = HeaderComponent:get_height(),
          height = '100vh',
          width = '40vw',
          col = '60vw',
        },
      },
    }, props)),
    list = FoldableListComponent:new(utils.object.assign({
      config = {
        elements = {
          header = false,
          footer = false,
        },
        win_plot = {
          row = HeaderComponent:get_height(),
          height = '100vh',
          width = '20vw',
        },
      },
    }, props)),
  }
end

function ProjectDiffScreen:has_data()
  local data = self.state.data
  return data and (#data.changed_files > 0 or #data.staged_files > 0)
end

function ProjectDiffScreen:hide_when_no_data()
  if not self:has_data() then
    self:hide()
    return true
  end
  return false
end

function ProjectDiffScreen:run_command(command)
  local components = self.scene.components
  local list = components.list
  loop.await_fast_event()
  local item = list:get_list_item(self.list_control:i())
  if list:is_fold(item) then
    return self
  end
  local file_entry = self:get_file_entry_from_list()
  local filename = file_entry.file.filename
  if type(command) == 'function' then
    command(filename)
  end
  return self:resync()
end

function ProjectDiffScreen:sync_list()
  loop.await_fast_event()
  self.scene.components.list:define(self:define_foldable_list()):sync()
  return self
end

function ProjectDiffScreen:resync()
  loop.await_fast_event()
  self:fetch()
  if self:hide_when_no_data() then
    return self
  end
  loop.await_fast_event()
  return self:sync_list():resync_code_data():resync_code()
end

function ProjectDiffScreen:git_reset()
  return self:run_command(function(filename)
    return self.git:reset(filename)
  end)
end

function ProjectDiffScreen:git_stage()
  return self:run_command(function(filename)
    return self.git:stage_file(filename)
  end)
end

function ProjectDiffScreen:git_unstage()
  return self:run_command(function(filename)
    return self.git:unstage_file(filename)
  end)
end

ProjectDiffScreen.sync = loop.debounce(
  loop.async(function(self)
    self
      :fetch({
        cached = true,
      })
      :resync_code_data()
      :resync_code()
  end),
  50
)

function ProjectDiffScreen:open()
  local components = self.scene.components
  local list = components.list
  local lnum = self.list_control:i()
  local state = self.state
  local data = state.data
  loop.await_fast_event()
  local focused_component_name = self.scene:get_focused_component_name()
  local is_in_code_window = focused_component_name == 'current'
    or focused_component_name == 'previous'
  local item = list:get_list_item(lnum)
  if not is_in_code_window then
    list:toggle_list_item(item):sync()
  end
  if list:is_fold(item) then
    return self
  end
  local dto = data.dto
  local marks = dto.marks
  local file_entry = self:get_file_entry_from_list()
  if not file_entry then
    return self
  end
  local filename = file_entry.file.filename
  local mark = marks[state.mark_index]
  if is_in_code_window then
    local component = components[focused_component_name]
    loop.await_fast_event()
    local current_lnum = component:get_lnum()
    for i = 1, #marks do
      local current_mark = marks[i]
      if
        current_lnum >= current_mark.top
        and current_lnum <= current_mark.bot
      then
        mark = current_mark
        break
      end
    end
  end
  lnum = mark and mark.top_lnum
  self:hide()
  vim.cmd(string.format('e %s', filename))
  if lnum then
    Window:new(0):set_lnum(lnum):call(function()
      vim.cmd('norm! zz')
    end)
  end
end

function ProjectDiffScreen:define_foldable_list()
  local data = self.state.data
  local changed_fold_list = {
    value = 'Changes',
    open = true,
    items = utils.list.map(data.changed_files, function(file)
      return {
        value = string.format(
          '%s %s',
          fs.short_filename(file.filename),
          file.status:to_string()
        ),
        file_entry = FileEntry:new(file, 'changed'),
      }
    end),
  }
  local staged_fold_list = {
    value = 'Staged',
    open = true,
    items = utils.list.map(data.staged_files, function(file)
      return {
        value = string.format(
          '%s %s',
          fs.short_filename(file.filename),
          file.status:to_string()
        ),
        file_entry = FileEntry:new(file, 'staged'),
      }
    end),
  }
  local foldable_list = {}
  if #changed_fold_list.items > 0 then
    foldable_list[#foldable_list + 1] = changed_fold_list
  end
  if #staged_fold_list.items > 0 then
    foldable_list[#foldable_list + 1] = staged_fold_list
  end
  return foldable_list
end

function ProjectDiffScreen:resync_list()
  local list = self.scene.components.list
  local keymaps = project_diff_preview_setting:get('keymaps')

  list
    :define(self:define_foldable_list())
    :set_keymap('n', 'j', 'keys.j', function()
      self:list_move('down')
    end)
    :set_keymap('n', 'k', 'keys.k', function()
      self:list_move('up')
    end)
    :set_keymap('n', '<enter>', 'keys.enter', function()
      self:open()
    end)
    :sync()
    :set_lnum(2) -- lnum #1 is the fold list header
    :focus()

  utils.object.each(keymaps, function(key, action)
    list:set_keymap('n', key, action)
  end)
  return self
end

function ProjectDiffScreen:make_code()
  local mode = 'n'
  local key = '<enter>'
  local action = 'keys.enter'
  local callback = function()
    self:open()
  end
  CodeListScreen.make_code(self)
  local components = self.scene.components
  components.current:set_keymap(mode, key, action, callback)
  if self.layout_type == 'split' then
    components.previous:set_keymap(mode, key, action, callback)
  end
  return self
end

function ProjectDiffScreen:show(title, props)
  self:clear_state()
  self.list_control:resync()
  local is_inside_git_dir = self.git:is_inside_git_dir()
  if not is_inside_git_dir then
    console.log('Project has no git folder')
    console.debug(
      'project_diff_preview is disabled, we are not in git store anymore'
    )
    return false
  end
  local state = self.state
  state.title = title
  state.props = props
  console.log('Processing project diff')
  self:fetch()
  if not state.err and not self:has_data() then
    console.log('No changes found')
    return false
  end
  if state.err then
    console.error(state.err)
    return false
  end
  loop.await_fast_event()
  self.scene = Scene:new(self:get_scene_definition(props)):mount()
  self:resync_list():resync_code()
  -- TODO: Foldable list index should start with 2
  self.list_control:set_i(2)
  console.clear()
  return true
end

return ProjectDiffScreen
