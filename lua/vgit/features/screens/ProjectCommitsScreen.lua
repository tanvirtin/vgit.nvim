local utils = require('vgit.core.utils')
local loop = require('vgit.core.loop')
local CodeComponent = require('vgit.ui.components.CodeComponent')
local HeaderComponent = require('vgit.ui.components.HeaderComponent')
local FoldableListComponent = require('vgit.ui.components.FoldedListComponent')
local CodeListScreen = require('vgit.ui.screens.CodeListScreen')
local Scene = require('vgit.ui.Scene')
local console = require('vgit.core.console')
local fs = require('vgit.core.fs')
local File = require('vgit.cli.models.File')
local CommitEntry = require('vgit.ui.CommitEntry')
local Diff = require('vgit.Diff')
local ProjectCommitsScreen = CodeListScreen:extend()

function ProjectCommitsScreen:new(...)
  return setmetatable(CodeListScreen:new(...), ProjectCommitsScreen)
end

function ProjectCommitsScreen:generate_dto(file)
  local git = self.git
  local state = self.state
  local log = file.log
  local filename = file.filename
  local parent_hash = log.parent_hash
  local commit_hash = log.commit_hash
  local lines_err, lines
  local is_deleted = false
  if not git:is_in_remote(filename, commit_hash) then
    is_deleted = true
    lines_err, lines = git:show(filename, parent_hash)
  else
    lines_err, lines = git:show(filename, commit_hash)
  end
  if lines_err then
    console.debug(lines_err, debug.traceback())
    state.err = lines_err
    return self
  end
  local hunks_err, hunks
  if is_deleted then
    hunks = git:deleted_hunks(lines)
  else
    hunks_err, hunks = git:remote_hunks(filename, parent_hash, commit_hash)
  end
  if hunks_err then
    console.debug(hunks_err, debug.traceback())
    state.err = hunks_err
    return self
  end
  return Diff:new(hunks):call(lines)
end

function ProjectCommitsScreen:get_entry_from_list()
  local scene = self.scene
  if scene then
    local list = scene.components.list
    loop.await_fast_event()
    local item = list:get_list_item(self.list_control:i())
    if item then
      return item.entry
    end
  end
end

function ProjectCommitsScreen:resync_code_data()
  local state = self.state
  local entry = self:get_entry_from_list()
  if entry and entry:is(File) then
    state.data = utils.object.assign(state.data, {
      filename = entry.filename,
      filetype = entry.filetype,
      dto = self:generate_dto(entry),
    })
  end
  return self
end

function ProjectCommitsScreen:fetch(opts)
  opts = opts or {}
  local props = self.state.props or {}
  local commits = props.commits or {}
  local state = self.state
  local git = self.git
  if not opts.cached then
    local entries = {}
    local first_entry = nil
    local logs = {}
    for i = 1, #commits do
      local err, log = git:log(commits[i])
      if err then
        console.debug(err, debug.traceback())
        state.err = err
        return self
      end
      logs[#logs + 1] = log
    end
    for i = 1, #logs do
      local log = logs[i]
      local err, files = git:ls_log(log)
      if err then
        console.debug(err, debug.traceback())
        state.err = err
        return self
      else
        local commit_entry = CommitEntry:new(log, files)
        entries[#entries + 1] = commit_entry
        if not first_entry then
          first_entry = commit_entry
        end
      end
    end
    state.data = {
      entries = entries,
    }
    if first_entry then
      local file = first_entry.files[1]
      if file then
        state.data = utils.object.assign(state.data, {
          filename = file.filename,
          filetype = file.filetype,
          dto = self:generate_dto(file),
        })
      end
    end
  end
  return self
end

function ProjectCommitsScreen:get_unified_scene_definition()
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

function ProjectCommitsScreen:get_split_scene_definition(props)
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

function ProjectCommitsScreen:has_data()
  local data = self.state.data
  return data and #data.entries > 0
end

function ProjectCommitsScreen:hide_when_no_data()
  if not self:has_data() then
    self:hide()
    return true
  end
  return false
end

function ProjectCommitsScreen:sync_list()
  loop.await_fast_event()
  self.scene.components.list:define(self:define_foldable_list()):sync()
  return self
end

ProjectCommitsScreen.sync = loop.debounce(
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

function ProjectCommitsScreen:resync()
  self:fetch()
  if self:hide_when_no_data() then
    return self
  end
  loop.await_fast_event()
  return self:sync_list():resync_code_data():resync_code()
end

function ProjectCommitsScreen:open()
  local components = self.scene.components
  local list = components.list
  local lnum = self.list_control:i()
  loop.await_fast_event()
  local focused_component_name = self.scene:get_focused_component_name()
  local is_in_code_window = focused_component_name == 'current'
    or focused_component_name == 'previous'
  local item = list:get_list_item(lnum)
  if not is_in_code_window then
    list:toggle_list_item(item):sync()
  end
end

function ProjectCommitsScreen:define_foldable_list()
  local foldable_list = {}
  local data = self.state.data
  local entries = data.entries
  for i = 1, #entries do
    local commit_entry = entries[i]
    local commit_hash = commit_entry.log.commit_hash
    foldable_list[#foldable_list + 1] = {
      open = true,
      value = commit_hash:sub(1, 7),
      items = utils.list.map(commit_entry.files, function(file)
        return {
          value = fs.short_filename(file.filename),
          entry = file,
        }
      end),
    }
  end
  return foldable_list
end

function ProjectCommitsScreen:resync_list()
  local list = self.scene.components.list
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
  return self
end

function ProjectCommitsScreen:show(title, props)
  self:clear_state()
  props = props or {}
  self.list_control:resync()
  local is_inside_git_dir = self.git:is_inside_git_dir()
  if not is_inside_git_dir then
    console.log('Project has no git folder')
    console.debug(
      'commits_preview is disabled, we are not in git store anymore'
    )
    return false
  end
  local state = self.state
  state.title = title
  state.props = props
  console.log('Processing commits')
  self:fetch()
  if not state.err and not self:has_data() then
    console.log('No commits provided')
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

return ProjectCommitsScreen
