local fs = require('vgit.core.fs')
local loop = require('vgit.core.loop')
local utils = require('vgit.core.utils')
local Layout = require('vgit.ui.Layout')
local Object = require('vgit.core.Object')
local console = require('vgit.core.console')
local repository = require('vgit.git.repository')
local LayoutSpec = require('vgit.ui.layout.LayoutSpec')
local diff_view_setting = require('vgit.settings.diff_view')
local ComponentManager = require('vgit.ui.ComponentManager')
local DiffComponent = require('vgit.ui.components.DiffComponent')
local LayoutComponent = require('vgit.ui.components.LayoutComponent')
local SplitDiffComponent = require('vgit.ui.components.SplitDiffComponent')
local StatusListComponent = require('vgit.ui.components.StatusListComponent')

local ProjectDiffView = Object:extend()

ProjectDiffView.DEBOUNCE_MS = 100
ProjectDiffView.STATUS_LIST_WIDTH = 50
ProjectDiffView.LAYOUT_SPLIT = 'split'
ProjectDiffView.LAYOUT_UNIFIED = 'unified'

function ProjectDiffView:constructor()
  return {
    opts = {
      layout_type = self.LAYOUT_UNIFIED,
    },
    data = nil,
    current_entry = nil,
    diff_component = nil,
    status_list_component = nil,
    component_manager = nil,
  }
end

function ProjectDiffView:_is_valid_entry(entry)
  if not entry then return false end
  if not entry.status then return false end
  if not entry.status.filename or type(entry.status.filename) ~= 'string' then return false end
  return true
end

function ProjectDiffView:_set_current_entry(entry)
  if self:_is_valid_entry(entry) then
    self.current_entry = entry
    return true
  end
  return false
end

function ProjectDiffView:hunk_up()
  self.diff_component:prev('top')
end

function ProjectDiffView:hunk_down()
  self.diff_component:next('top')
end

function ProjectDiffView:_handle_git_error(err, operation_name)
  if err then
    loop.free_textlock()
    console.debug.error(string.format('[ProjectDiffView] %s failed: %s', operation_name, err)).error(err)
    return false
  end
  return true
end

function ProjectDiffView:_build_entry_diff(entry, repo)
  if not self:_is_valid_entry(entry) then return nil, { 'entry is invalid' } end

  local entry_type = entry.type
  local status = entry.status
  local filename = status.filename

  local diff_spec
  if entry_type == 'staged' then
    diff_spec = {
      type = 'range',
      filename = filename,
      from = 'HEAD',
      to = 'index',
    }
  elseif entry_type == 'unmerged' then
    diff_spec = {
      type = 'conflict',
      filename = filename,
    }
  else
    diff_spec = {
      type = 'range',
      filename = filename,
      from = 'index',
      to = 'disk',
    }
  end

  local opts = {}
  if self.opts.layout_type then opts.layout_type = self.opts.layout_type end

  loop.free_textlock()
  return repo:diff(diff_spec, opts)
end

function ProjectDiffView:create(data)
  if not data then
    loop.free_textlock()
    console.error('[ProjectDiffView] No data provided to create()')
    return false
  end

  if type(data) ~= 'table' then
    loop.free_textlock()
    console.error('[ProjectDiffView] Expected table, got ' .. type(data))
    return false
  end

  if not data.entries then
    loop.free_textlock()
    console.error('[ProjectDiffView] Invalid data: missing entries')
    return false
  end
  if type(data.entries) ~= 'table' then
    loop.free_textlock()
    console.error('[ProjectDiffView] Invalid data: entries must be a table')
    return false
  end
  if utils.object.is_empty(data.entries) then
    loop.free_textlock()
    console.error('[ProjectDiffView] Invalid data: entries list is empty')
    return false
  end

  return self:_process_entries_data(data)
end

function ProjectDiffView:_process_entries_data(data)
  self.opts = utils.object.defaults({
    layout_type = data.layout_type,
  }, self.opts)

  self.data = data

  local entries_data = {
    entries = data.entries,
    layout_type = self.opts.layout_type,
  }

  return self:_create_entries_view(entries_data)
end

function ProjectDiffView:move_to(query_fn)
  if not self.status_list_component then return false end
  return self.status_list_component:move_to(query_fn)
end

function ProjectDiffView:create_diff_component(opts)
  opts = opts or {}
  local layout_type = self.opts.layout_type or self.LAYOUT_UNIFIED

  local props = {
    diff = opts.diff,
    filename = opts.filename,
    filetype = opts.filetype or 'text',
  }

  if layout_type == self.LAYOUT_SPLIT then return SplitDiffComponent(props) end
  return DiffComponent(props)
end

function ProjectDiffView:_update_diff_component(hunk_index)
  loop.free_textlock()

  if not self:_is_valid_entry(self.current_entry) then return false end

  local repo, repo_err = repository.current()
  if not self:_handle_git_error(repo_err, 'repository.current') then return false end

  local diff_data, err = self:_build_entry_diff(self.current_entry, repo)
  if not self:_handle_git_error(err, '_build_entry_diff') then return false end

  self.diff_component:set_props({
    diff = diff_data,
    filename = self.current_entry.status.filename,
    filetype = self.current_entry.status.filetype,
  })

  if hunk_index then self.diff_component:move_to_hunk(hunk_index, 'top') end

  return true
end

function ProjectDiffView:stage_hunk()
  loop.free_textlock()

  if not self:_is_valid_entry(self.current_entry) then return end
  if self.current_entry.type ~= 'unstaged' then return end

  local filename = self.current_entry.status.filename

  local hunk, index = self.diff_component:get_hunk_under_cursor()
  if not hunk then return end

  local repo, err = repository.current()
  if err then return end
  repo:stage_hunk(filename, hunk)

  self:_update_diff_component(index)
end

function ProjectDiffView:unstage_hunk()
  loop.free_textlock()

  if not self:_is_valid_entry(self.current_entry) then return end
  if self.current_entry.type ~= 'staged' then return end

  local filename = self.current_entry.status.filename

  local hunk, index = self.diff_component:get_hunk_under_cursor()
  if not hunk then return end

  local repo, err = repository.current()
  if err then return end
  repo:unstage_hunk(filename, hunk)

  self:_update_diff_component(index)
end

function ProjectDiffView:stage_entry()
  if not self:_is_valid_entry(self.current_entry) then return end

  local filename = self.current_entry.status.filename

  local repo, err = repository.current()
  if err then return end
  repo:stage_file(filename)
  self:_update_diff_component()
end

function ProjectDiffView:unstage_entry()
  if not self:_is_valid_entry(self.current_entry) then return end

  local filename = self.current_entry.status.filename

  local repo, err = repository.current()
  if err then return end
  repo:unstage_file(filename)
  self:_update_diff_component()
end

function ProjectDiffView:reset_entry()
  if not self:_is_valid_entry(self.current_entry) then return end

  loop.free_textlock()
  local decision = console.input('Are you sure you want to discard changes? (y/N) '):lower()

  if decision ~= 'yes' and decision ~= 'y' then return end

  local filename = self.current_entry.status.filename

  local repo, err = repository.current()
  if err then return end
  repo:reset(filename)
  self:_update_diff_component()
end

function ProjectDiffView:commit()
  loop.free_textlock()
  local message = console.input('Commit message: ')

  if not message or message:match('^%s*$') then
    console.info('Commit cancelled: empty message')
    return
  end

  loop.free_textlock()
  local repo, repo_err = repository.current()
  if not self:_handle_git_error(repo_err, 'repository.current') then return end

  local _, err = repo:commit(message)
  if not self:_handle_git_error(err, 'commit') then return end

  console.info('Changes committed successfully')
  self:refresh_data()
end

function ProjectDiffView:open_file()
  if not self:_is_valid_entry(self.current_entry) then return end

  local filename = self.current_entry.status.filename

  self:destroy()
  loop.free_textlock()
  fs.open(filename)
end

function ProjectDiffView:_handle_file_selection_change(item)
  if not self.component_manager then return end

  if not item then
    console.warn('[ProjectDiffView] file selection changed called with nil item')
    return
  end

  local entry = item.entry or item

  if not self:_set_current_entry(entry) then
    console.warn('[ProjectDiffView] Invalid entry structure in file selection change')
    if self.diff_component then
      self.diff_component:clear_extmarks()
      self.diff_component:clear_lines()
      self.diff_component:clear_folds()
      self.diff_component:reset_cursor()
    end
    return
  end

  local repo, repo_err = repository.current()
  if not self:_handle_git_error(repo_err, 'repository.current') then return end

  local diff_data, err = self:_build_entry_diff(entry, repo)
  if not self:_handle_git_error(err, '_build_entry_diff') then return end

  if self.diff_component then
    local has_content = diff_data and diff_data.marks and #diff_data.marks > 0

    if has_content then
      loop.free_textlock()
      self.diff_component:set_props({
        diff = diff_data,
        filename = entry.status.filename,
        filetype = entry.status.filetype or 'text',
      })

      if self.diff_component.call then
        loop.free_textlock()
        self.diff_component:call(function()
          self.diff_component:move_to_hunk(1, 'top')
        end)
      end
    else
      loop.free_textlock()
      self.diff_component:set_props({
        diff = nil,
        filename = nil,
        filetype = nil,
      })
    end
  end
end

function ProjectDiffView:stage_all()
  local repo, err = repository.current()
  if err then return end
  repo:stage_all()
  self:refresh_data()
end

function ProjectDiffView:unstage_all()
  local repo, err = repository.current()
  if err then return end
  repo:unstage_all()
  self:refresh_data()
end

function ProjectDiffView:reset_all()
  loop.free_textlock()
  local decision = console.input('Are you sure you want to discard all changes? (y/N) '):lower()

  if decision ~= 'yes' and decision ~= 'y' then return end

  local repo, err = repository.current()
  if err then return end
  repo:reset()
  self:refresh_data()
end

function ProjectDiffView:refresh_data()
  local repo, err = repository.current()
  if err then return end

  loop.free_textlock()
  local data, status_err = repo:status(self.opts)
  if not self:_handle_git_error(status_err, 'status') then return end

  if not data or utils.object.is_empty(data.entries) then
    console.warn('[ProjectDiffView] No data returned from refresh_data()')
    return
  end

  local file_groups = {}
  for _, entry in ipairs(data.entries) do
    file_groups[#file_groups + 1] = {
      open = true,
      value = entry.title,
      metadata = {},
      items = entry.entries,
    }
  end

  if self.status_list_component then self.status_list_component:set_list(file_groups) end
end

function ProjectDiffView:get_key(keymap)
  if type(keymap) == 'string' then
    return keymap
  elseif type(keymap) == 'table' then
    return keymap.key
  end
  return nil
end

function ProjectDiffView:setup_keymaps()
  local scene_setting = require('vgit.settings.scene')
  local scene_keymaps = scene_setting:get('keymaps')
  local diff_keymaps = diff_view_setting:get('keymaps')

  if scene_keymaps and scene_keymaps.quit then
    local quit_key = self:get_key(scene_keymaps.quit)
    if quit_key then
      loop.free_textlock()
      if self.status_list_component:is_valid() then
        self.status_list_component:set_keymap('n', quit_key, function()
          self.component_manager:destroy()
        end, 'Quit')
      end

      self.diff_component:set_keymap({
        mode = 'n',
        key = quit_key,
      }, function()
        self.component_manager:destroy()
      end)
    end
  end

  local hunk_up_key = self:get_key(diff_keymaps.hunk_up)
  if hunk_up_key then
    self.diff_component:set_keymap(
      {
        mode = 'n',
        key = hunk_up_key,
      },
      loop.debounce_coroutine(function()
        self:hunk_up()
      end, self.DEBOUNCE_MS)
    )
  end

  local hunk_down_key = self:get_key(diff_keymaps.hunk_down)
  if hunk_down_key then
    self.diff_component:set_keymap(
      {
        mode = 'n',
        key = hunk_down_key,
      },
      loop.debounce_coroutine(function()
        self:hunk_down()
      end, self.DEBOUNCE_MS)
    )
  end

  local stage_hunk_key = self:get_key(diff_keymaps.stage_hunk)
  if stage_hunk_key then
    self.diff_component:set_keymap(
      {
        mode = 'n',
        key = stage_hunk_key,
      },
      loop.debounce_coroutine(function()
        self:stage_hunk()
      end, self.DEBOUNCE_MS)
    )
  end

  local unstage_hunk_key = self:get_key(diff_keymaps.unstage_hunk)
  if unstage_hunk_key then
    self.diff_component:set_keymap(
      {
        mode = 'n',
        key = unstage_hunk_key,
      },
      loop.debounce_coroutine(function()
        self:unstage_hunk()
      end, self.DEBOUNCE_MS)
    )
  end

  self.diff_component:set_keymap(
    {
      mode = 'n',
      key = '<enter>',
    },
    loop.debounce_coroutine(function()
      self:open_file()
    end, self.DEBOUNCE_MS)
  )
end

function ProjectDiffView:_create_entries_view(data)
  local repo, err = repository.current()
  if err then return false end

  if repo:conflict_status() then
    loop.free_textlock()
    console.info('All conflicts fixed but you are still merging')
    return false
  end

  local file_groups = {}
  for _, entry in ipairs(data.entries) do
    file_groups[#file_groups + 1] = {
      open = true,
      value = entry.title,
      metadata = {},
      items = entry.entries,
    }
  end

  local initial_entry = nil
  for _, group in ipairs(file_groups) do
    if group.items and #group.items > 0 then
      initial_entry = group.items[1]
      break
    end
  end

  if initial_entry then
    if not self:_set_current_entry(initial_entry) then
      console.warn('[ProjectDiffView] Initial entry failed validation')
    end
  end

  self.status_list_component = StatusListComponent({
    list = file_groups,
    title = '',
    width = 50,
    focus = true,
    keymaps = diff_view_setting:get('keymaps'),
    keymap_handlers = {
      commit = function()
        self:commit()
      end,
      reset = function()
        self:reset_entry()
      end,
      stage = function()
        self:stage_entry()
      end,
      unstage = function()
        self:unstage_entry()
      end,
      stage_all = function()
        self:stage_all()
      end,
      unstage_all = function()
        self:unstage_all()
      end,
      reset_all = function()
        self:reset_all()
      end,
    },
  })

  self.status_list_component:set_on_enter(function()
    self:open_file()
  end)

  self.status_list_component:set_on_move(loop.debounce_coroutine(function(item)
    self:_handle_file_selection_change(item)
  end, self.DEBOUNCE_MS))

  self.diff_component = self:create_diff_component({
    diff = nil,
    filename = nil,
    filetype = nil,
  })

  local wrapper = LayoutComponent({
    spec = LayoutSpec.horizontal({
      LayoutSpec.view(self.status_list_component, {
        width = '30%',
      }),
      LayoutSpec.view(self.diff_component, {
        expand = true,
      }),
    }),
  })

  self.component_manager = ComponentManager()
  loop.free_textlock()
  self.component_manager:render(Layout.screen(wrapper, {
    width = '100vw',
    height = '100vh',
  }))

  self:setup_keymaps()

  if self.status_list_component and self.status_list_component:is_valid() then self.status_list_component:focus() end

  return true
end

function ProjectDiffView:emit_cleanup_events()
  self.diff_component:component_will_unmount()
  self.status_list_component:component_will_unmount()
end

function ProjectDiffView:destroy()
  self:emit_cleanup_events()
  self.component_manager:destroy()
end

return ProjectDiffView
