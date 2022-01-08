local Window = require('vgit.core.Window')
local icons = require('vgit.core.icons')
local utils = require('vgit.core.utils')
local loop = require('vgit.core.loop')
local CodeComponent = require('vgit.ui.components.CodeComponent')
local TableComponent = require('vgit.ui.components.TableComponent')
local CodeDataScene = require('vgit.ui.abstract_scenes.CodeDataScene')
local Scene = require('vgit.ui.Scene')
local dimensions = require('vgit.ui.dimensions')
local console = require('vgit.core.console')
local fs = require('vgit.core.fs')
local Diff = require('vgit.Diff')

local ProjectDiffScene = CodeDataScene:extend()

function ProjectDiffScene:new(...)
  return setmetatable(CodeDataScene:new(...), ProjectDiffScene)
end

function ProjectDiffScene:fetch(selected)
  selected = selected or 1
  local runtime_cache = self.runtime_cache
  local git = self.git
  local changed_files_err, changed_files = git:ls_changed()
  if changed_files_err then
    console.debug(changed_files_err, debug.traceback())
    runtime_cache.err = changed_files_err
    return self
  end
  if #changed_files == 0 then
    runtime_cache.data = {
      changed_files = changed_files,
      selected = selected,
    }
    return self
  end
  local file = changed_files[selected]
  if not file then
    selected = #changed_files
    file = changed_files[selected]
  end
  local filename = file.filename
  local status = file.status
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
    runtime_cache.err = lines_err
    return self
  end
  local hunks_err, hunks
  if status:has_both('??') then
    hunks = git:untracked_hunks(lines)
  elseif status:has_either('DD') then
    hunks = git:deleted_hunks(lines)
  else
    hunks_err, hunks = git:index_hunks(filename)
  end
  if hunks_err then
    console.debug(hunks_err, debug.traceback())
    runtime_cache.err = hunks_err
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
  runtime_cache.data = {
    filename = filename,
    filetype = fs.detect_filetype(filename),
    changed_files = changed_files,
    dto = dto,
    selected = selected,
  }
  return self
end

function ProjectDiffScene:get_unified_scene_options(options)
  local table_height = math.floor(dimensions.global_height() * 0.15)
  return {
    current = CodeComponent:new(utils.object_assign({
      config = {
        win_options = {
          cursorbind = true,
          scrollbind = true,
          cursorline = true,
        },
        window_props = {
          height = dimensions.global_height() - table_height,
          row = table_height,
        },
      },
    }, options)),
    table = TableComponent:new(utils.object_assign({
      header = { 'Filename', 'Status' },
      config = {
        window_props = {
          height = table_height,
          row = 0,
        },
      },
    }, options)),
  }
end

function ProjectDiffScene:get_split_scene_options(options)
  local table_height = math.floor(dimensions.global_height() * 0.15)
  return {
    previous = CodeComponent:new(utils.object_assign({
      config = {
        win_options = {
          cursorbind = true,
          scrollbind = true,
          cursorline = true,
        },
        window_props = {
          height = dimensions.global_height() - table_height,
          width = math.floor(dimensions.global_width() / 2),
          row = table_height,
        },
      },
    }, options)),
    current = CodeComponent:new(utils.object_assign({
      config = {
        win_options = {
          cursorbind = true,
          scrollbind = true,
          cursorline = true,
        },
        window_props = {
          height = dimensions.global_height() - table_height,
          width = math.floor(dimensions.global_width() / 2),
          col = math.floor(dimensions.global_width() / 2),
          row = table_height,
        },
      },
    }, options)),
    table = TableComponent:new(utils.object_assign({
      header = { 'Filename', 'Status' },
      config = {
        window_props = {
          height = table_height,
          row = 0,
        },
      },
    }, options)),
  }
end

function ProjectDiffScene:run_command(command)
  loop.await_fast_event()
  self:reset()
  local runtime_cache = self.runtime_cache
  local components = self.scene.components
  local table = components.table
  loop.await_fast_event()
  local selected = table:get_lnum()
  local filename = runtime_cache.data.changed_files[selected].filename
  if type(command) == 'function' then
    command(filename)
  end
  if runtime_cache.err then
    console.error(runtime_cache.err)
    return self
  end
  self:fetch(selected)
  loop.await_fast_event()
  if runtime_cache.err then
    console.error(runtime_cache.err)
    return self
  end
  if #runtime_cache.data.changed_files == 0 then
    return self:hide()
  end
  self
    :set_title(runtime_cache.title, {
      filename = runtime_cache.data.filename,
      filetype = runtime_cache.data.filetype,
      stat = runtime_cache.data.dto.stat,
    })
    :make_code()
    :paint_code()
    :make_table()
    :set_code_cursor_on_mark(1)
end

function ProjectDiffScene:refresh()
  self:run_command()
  return self
end

function ProjectDiffScene:git_reset()
  return self:run_command(function(filename)
    return self.git:reset(filename)
  end)
end

function ProjectDiffScene:git_stage()
  return self:run_command(function(filename)
    return self.git:stage_file(filename)
  end)
end

function ProjectDiffScene:git_unstage()
  return self:run_command(function(filename)
    return self.git:unstage_file(filename)
  end)
end

function ProjectDiffScene:open_file()
  local components = self.scene.components
  local table = components.table
  loop.await_fast_event()
  local selected = table:get_lnum()
  if self.runtime_cache.last_selected == selected then
    local focused_component_name = self.scene:get_focused_component_name()
    local runtime_cache = self.runtime_cache
    local data = runtime_cache.data
    local dto = data.dto
    local marks = dto.marks
    local filename = data.changed_files[selected].filename
    local mark = marks[runtime_cache.mark_index]
    local lnum
    if
      focused_component_name == 'current'
      or focused_component_name == 'previous'
    then
      local component = components[focused_component_name]
      loop.await_fast_event()
      local current_lnum = component:get_lnum()
      for i = 1, #marks do
        local current_mark = marks[i]
        if
          current_lnum >= current_mark.start
          and current_lnum <= current_mark.finish
        then
          mark = current_mark
          break
        end
      end
    end
    lnum = mark and mark.start_lnum
    self:hide()
    vim.cmd(string.format('e %s', filename))
    if lnum then
      Window:new(0):set_lnum(lnum):call(function()
        vim.cmd('norm! zz')
      end)
    end
    return self
  end
  self:update(selected)
end

function ProjectDiffScene:make_table()
  self.scene.components.table
    :unlock()
    :make_rows(self.runtime_cache.data.changed_files, function(file)
      local icon, icon_hl = icons.file_icon(file.filename, file.filetype)
      if icon then
        return {
          {
            icon_before = {
              icon = icon,
              hl = icon_hl,
            },
            text = file.filename,
          },
          file.status:to_string(),
        }
      end
      return {
        {
          text = file.filename,
        },
        file.status:to_string(),
      }
    end)
    :set_keymap('n', 'j', 'on_j')
    :set_keymap('n', 'J', 'on_j')
    :set_keymap('n', 'k', 'on_k')
    :set_keymap('n', 'K', 'on_k')
    :set_keymap('n', '<enter>', 'on_enter')
    :focus()
    :lock()
  return self
end

function ProjectDiffScene:set_code_keymap(mode, key, action)
  local components = self.scene.components
  components.current:set_keymap(mode, key, action)
  if self.layout_type == 'split' then
    components.previous:set_keymap(mode, key, action)
  end
  return self
end

function ProjectDiffScene:show(title, options)
  local is_inside_git_dir = self.git:is_inside_git_dir()
  if not is_inside_git_dir then
    console.log('Project has no git folder')
    console.debug(
      'project_diff_preview is disabled, we are not in git store anymore'
    )
    return false
  end
  self:hide()
  local runtime_cache = self.runtime_cache
  runtime_cache.title = title
  runtime_cache.options = options
  console.log('Processing project diff')
  self:fetch()
  loop.await_fast_event()
  if not runtime_cache.err and runtime_cache.data and #runtime_cache.data.changed_files == 0 then
    console.log('No changes found')
    return false
  end
  if runtime_cache.err then
    console.error(runtime_cache.err)
    return false
  end
  self.scene = Scene:new(self:get_scene_options(options)):mount()
  local data = runtime_cache.data
  local filename = data.filename
  local filetype = data.filetype
  self
    :set_title(title, {
      filename = filename,
      filetype = filetype,
      stat = data.dto.stat,
    })
    :make_code()
    :paint_code()
    :make_table()
    :set_code_cursor_on_mark(1)
    :set_code_keymap('n', '<enter>', 'on_enter')
  -- Must be after initial fetch
  runtime_cache.last_selected = 1
  console.clear()
  return true
end

return ProjectDiffScene
