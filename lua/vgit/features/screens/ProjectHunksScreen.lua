local icons = require('vgit.core.icons')
local Window = require('vgit.core.Window')
local loop = require('vgit.core.loop')
local CodeComponent = require('vgit.ui.components.CodeComponent')
local TableComponent = require('vgit.ui.components.TableComponent')
local CodeListScreen = require('vgit.ui.screens.CodeListScreen')
local Scene = require('vgit.ui.Scene')
local console = require('vgit.core.console')
local fs = require('vgit.core.fs')
local Diff = require('vgit.Diff')

local ProjectHunksScreen = CodeListScreen:extend()

function ProjectHunksScreen:new(...)
  return setmetatable(CodeListScreen:new(...), ProjectHunksScreen)
end

function ProjectHunksScreen:fetch(opts)
  opts = opts or {}
  local state = self.state
  if opts.cached then
    state.data = self.state.entries[self.list_control:i()]
    return self
  end
  local git = self.git
  state.entries = {}
  local entries = state.entries
  local status_files_err, status_files = git:status()
  if status_files_err then
    console.debug(status_files_err, debug.traceback())
    state.err = status_files_err
    return self
  end
  if #status_files == 0 then
    console.debug({ 'No changes found' }, debug.traceback())
    return self
  end
  for i = 1, #status_files do
    local file = status_files[i]
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
      state.err = lines_err
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
    if not hunks_err then
      for j = 1, #hunks do
        local hunk = hunks[j]
        entries[#entries + 1] = {
          hunk = hunk,
          hunks = hunks,
          filename = filename,
          filetype = fs.detect_filetype(filename),
          dto = dto,
          index = j,
        }
      end
    else
      console.debug(hunks_err, debug.traceback())
    end
  end
  state.entries = entries
  return self
end

function ProjectHunksScreen:get_unified_scene_definition()
  return {
    current = CodeComponent:new({
      elements = {
        header = true,
        footer = false,
      },
      config = {
        win_options = {
          cursorbind = true,
          scrollbind = true,
          cursorline = true,
        },
        win_plot = {
          height = '85vh',
          row = '15vh',
        },
      },
    }),
    list = TableComponent:new({
      elements = {
        header = true,
        footer = false,
      },
      config = {
        header = { 'Filename', 'Hunk' },
        win_plot = {
          height = '15vh',
        },
      },
    }),
  }
end

function ProjectHunksScreen:get_split_scene_definition()
  return {
    previous = CodeComponent:new({
      config = {
        elements = {
          header = true,
          footer = false,
        },
        win_options = {
          cursorbind = true,
          scrollbind = true,
          cursorline = true,
        },
        win_plot = {
          height = '85vh',
          width = '50vw',
          row = '15vh',
        },
      },
    }),
    current = CodeComponent:new({
      config = {
        elements = {
          header = true,
          footer = false,
        },
        win_options = {
          cursorbind = true,
          scrollbind = true,
          cursorline = true,
        },
        win_plot = {
          height = '85vh',
          width = '50vw',
          col = '50vw',
          row = '15vh',
        },
      },
    }),
    list = TableComponent:new({
      config = {
        elements = {
          header = true,
          footer = false,
        },
        header = { 'Filename', 'Hunk' },
        win_plot = {
          height = '15vh',
        },
      },
    }),
  }
end

function ProjectHunksScreen:resync_code()
  local state = self.state
  if state.err then
    console.error(state.err)
    return self
  end
  if not state.data and not state.data or not state.data.dto then
    return self
  end
  local data = state.data
  local index = data.index
  return CodeListScreen.resync_code(self):set_code_cursor_on_mark(index):notify(
    string.format('%s%s/%s Changes', string.rep(' ', 1), index, #data.dto.marks)
  )
end

function ProjectHunksScreen:open()
  local data = self.state.data
  self:hide()
  vim.cmd(string.format('e %s', data.filename))
  Window:new(0):set_lnum(data.hunks[data.index].top):call(function()
    vim.cmd('norm! zz')
  end)
  return self
end

function ProjectHunksScreen:resync_list()
  self.scene.components.list
    :unlock()
    :make_rows(self.state.entries, function(entry)
      local filename = entry.filename
      local filetype = entry.filetype
      local icon, icon_hl = icons.file_icon(filename, filetype)
      if icon then
        return {
          {
            icon_after = {
              icon = icon,
              hl = icon_hl,
            },
            text = filename,
          },
          string.format('%s/%s', entry.index, #entry.dto.marks),
        }
      end
      return {
        {
          text = filename,
        },
        string.format('%s/%s', entry.index, #entry.dto.marks),
      }
    end)
    :set_keymap('n', 'j', 'keys.j', function()
      self:list_move('down')
    end)
    :set_keymap('n', 'k', 'keys.k', function()
      self:list_move('up')
    end)
    :set_keymap('n', '<enter>', 'keys.enter', function()
      self:open()
    end)
    :focus()
    :lock()
  return self
end

function ProjectHunksScreen:show(title, props)
  self:clear_state()
  self.list_control:resync()
  local is_inside_git_dir = self.git:is_inside_git_dir()
  if not is_inside_git_dir then
    console.log('Project has no git folder')
    console.debug(
      'project_hunks_preview is disabled, we are not in git store anymore'
    )
    return false
  end
  local state = self.state
  state.title = title
  state.props = props
  console.log('Processing project hunks')
  self:fetch()
  loop.await_fast_event()
  if not state.err and state.entries and #state.entries == 0 then
    console.log('No hunks found')
    return false
  end
  if state.err then
    console.error(state.err)
    return false
  end
  self.scene = Scene:new(self:get_scene_definition(props)):mount()
  state.data = state.entries[1]
  self:resync_list():resync_code()
  console.clear()
  return true
end

return ProjectHunksScreen