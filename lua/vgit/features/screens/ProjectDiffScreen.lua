local Window = require('vgit.core.Window')
local utils = require('vgit.core.utils')
local loop = require('vgit.core.loop')
local CodeComponent = require('vgit.ui.components.CodeComponent')
local HeaderComponent = require('vgit.ui.components.HeaderComponent')
local FoldableListComponent = require('vgit.ui.components.FoldedListComponent')
local CodeDataScreen = require('vgit.ui.screens.CodeDataScreen')
local Scene = require('vgit.ui.Scene')
local console = require('vgit.core.console')
local FileEntry = require('vgit.ui.FileEntry')
local fs = require('vgit.core.fs')
local Diff = require('vgit.Diff')
local project_diff_preview_setting = require(
  'vgit.settings.project_diff_preview'
)

local ProjectDiffScreen = CodeDataScreen:extend()

function ProjectDiffScreen:new(...)
  return setmetatable(CodeDataScreen:new(...), ProjectDiffScreen)
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
  if self.layout_type == 'unified' then
    if status:has_either('DD') then
      dto = Diff:new(hunks):deleted_unified(lines)
    else
      dto = Diff:new(hunks):unified(lines)
    end
  else
    if status:has_either('DD') then
      dto = Diff:new(hunks):deleted_split(lines)
    else
      dto = Diff:new(hunks):split(lines)
    end
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

function ProjectDiffScreen:get_file_entry(lnum)
  local scene = self.scene
  local data = self.state.data
  local changed_files = data.changed_files
  local staged_files = data.staged_files
  local first_changed_file, last_changed_file, first_staged_file, last_staged_file =
    changed_files[1],
    changed_files[#changed_files],
    staged_files[1],
    staged_files[#staged_files]
  if scene then
    local item = scene.components.table:get_list_item(lnum)
    if item then
      local file_entry = item.file_entry
      if file_entry then
        return file_entry
      end
    end
    if data.file_entry then
      return nil
    end
    if last_staged_file then
      return FileEntry:new(last_staged_file, 'staged')
    end
    if last_changed_file then
      return FileEntry:new(last_changed_file, 'changed')
    end
  end
  if first_changed_file then
    return FileEntry:new(first_changed_file, 'changed')
  end
  if first_staged_file then
    return FileEntry:new(first_staged_file, 'staged')
  end
end

function ProjectDiffScreen:generate_file_entry(lnum)
  lnum = lnum or 1
  local state = self.state
  local file_entry = self:get_file_entry(lnum)
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

function ProjectDiffScreen:fetch(lnum, opts)
  lnum = lnum or 1
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
    table = FoldableListComponent:new({
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
    table = FoldableListComponent:new(utils.object.assign({
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
  local table = components.table
  loop.await_fast_event()
  local lnum = table:get_lnum()
  local item = table:get_list_item(lnum)
  if table:is_fold(item) then
    return self
  end
  local file_entry = self:get_file_entry(lnum)
  local filename = file_entry.file.filename
  if type(command) == 'function' then
    command(filename)
  end
  return self:refresh(lnum)
end

function ProjectDiffScreen:refresh(lnum)
  local table = self.scene.components.table
  loop.await_fast_event()
  self:reset():fetch(lnum)
  loop.await_fast_event()
  if self:hide_when_no_data() then
    return self
  end
  table:define(self:define_foldable_list())
  loop.await_fast_event()
  table:render()
  return self:generate_file_entry(lnum):render()
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

ProjectDiffScreen.refetch_and_render = loop.debounce(
  loop.async(function(self, lnum)
    self
      :fetch(lnum, {
        cached = true,
      })
      :generate_file_entry(lnum)
      :render()
  end),
  50
)

function ProjectDiffScreen:table_move(direction)
  self:clear_state_err()
  local components = self.scene.components
  local table = components.table
  local lnum = table:get_lnum()
  if direction == 'up' then
    lnum = lnum - 1
  elseif direction == 'down' then
    lnum = lnum + 1
  end
  table:set_lnum(lnum)
  local state = self.state
  if state.last_lnum ~= lnum then
    state.last_lnum = lnum
    self:refetch_and_render(lnum)
  end
  return self
end

function ProjectDiffScreen:open_file()
  local components = self.scene.components
  local table = components.table
  local lnum = table:get_lnum()
  local state = self.state
  local data = state.data
  loop.await_fast_event()
  local focused_component_name = self.scene:get_focused_component_name()
  local is_in_code_window = focused_component_name == 'current'
    or focused_component_name == 'previous'
  local item = table:get_list_item(lnum)
  if not is_in_code_window then
    table:toggle_list_item(item)
    table:render()
  end
  if table:is_fold(item) then
    return self
  end
  local dto = data.dto
  local marks = dto.marks
  local file_entry = self:get_file_entry(lnum)
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
    items = utils.list.map(data.changed_files, function(file, i)
      return {
        value = string.format(
          '%s %s',
          fs.short_filename(file.filename),
          file.status:to_string()
        ),
        lnum = i,
        file_entry = FileEntry:new(file, 'changed'),
      }
    end),
  }
  local staged_fold_list = {
    value = 'Staged',
    open = true,
    items = utils.list.map(data.staged_files, function(file, i)
      return {
        value = string.format(
          '%s %s',
          fs.short_filename(file.filename),
          file.status:to_string()
        ),
        lnum = i,
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

function ProjectDiffScreen:make_table()
  local table = self.scene.components.table
  local keymaps = project_diff_preview_setting:get('keymaps')

  table
    :define(self:define_foldable_list())
    :set_keymap('n', 'j', 'keys.j', function()
      self:table_move('down')
    end)
    :set_keymap('n', 'k', 'keys.k', function()
      self:table_move('up')
    end)
    :set_keymap('n', '<enter>', 'keys.enter', function()
      self:open_file()
    end)
    :render()
    :set_lnum(2) -- lnum #1 is the fold list header
    :focus()

  utils.object.each(keymaps, function(key, action)
    table:set_keymap('n', key, action)
  end)

  self.state.last_lnum = 2
  return self
end

function ProjectDiffScreen:make_code()
  local mode = 'n'
  local key = '<enter>'
  local action = 'keys.enter'
  local callback = function()
    self:open_file()
  end
  CodeDataScreen.make_code(self)
  local components = self.scene.components
  components.current:set_keymap(mode, key, action, callback)
  if self.layout_type == 'split' then
    components.previous:set_keymap(mode, key, action, callback)
  end
  return self
end

function ProjectDiffScreen:show(title, props)
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
  self:fetch():generate_file_entry()
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
  local data = self.state.data
  local file_entry = data.file_entry
  local file = file_entry.file
  self
    :set_title(title, {
      filename = file.filename,
      filetype = file.filetype,
      stat = data.dto.stat,
    })
    :make_code()
    :make_table()
    :paint_code()
    :set_code_cursor_on_mark(1)
  console.clear()
  return true
end

return ProjectDiffScreen
