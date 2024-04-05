local fs = require('vgit.core.fs')
local loop = require('vgit.core.loop')
local Scene = require('vgit.ui.Scene')
local Object = require('vgit.core.Object')
local Buffer = require('vgit.core.Buffer')
local Window = require('vgit.core.Window')
local console = require('vgit.core.console')
local DiffView = require('vgit.ui.views.DiffView')
local FSListGenerator = require('vgit.ui.FSListGenerator')
local FoldableListView = require('vgit.ui.views.FoldableListView')
local Store = require('vgit.features.screens.ProjectCommitsScreen.Store')

local ProjectCommitsScreen = Object:extend()

function ProjectCommitsScreen:constructor(opts)
  opts = opts or {}
  local scene = Scene()
  local store = Store()
  local layout_type = opts.layout_type or 'unified'

  return {
    name = 'Project Commits Screen',
    scene = scene,
    store = store,
    layout_type = layout_type,
    diff_view = DiffView(scene, store, {
      col = '25vw',
      width = '75vw',
    }, {
      elements = {
        header = true,
        footer = false,
      },
    }, layout_type),
    foldable_list_view = FoldableListView(scene, store, { width = '25vw' }, {
      elements = {
        header = true,
        footer = false,
      },
      get_list = function(commits)
        local foldable_list = {}

        for commit_hash, files in pairs(commits) do
          foldable_list[#foldable_list + 1] = {
            open = true,
            show_count = false,
            value = commit_hash,
            items = FSListGenerator(files):generate(),
          }
        end

        return foldable_list
      end,
    }),
  }
end

function ProjectCommitsScreen:hunk_up() self.diff_view:prev() end

function ProjectCommitsScreen:hunk_down() self.diff_view:next() end

function ProjectCommitsScreen:handle_list_move(direction)
  local list_item = self.foldable_list_view:move(direction)

  if not list_item then
    return
  end

  self.store:set_id(list_item.id)
  self.diff_view:render_debounced(loop.coroutine(function() self.diff_view:navigate_to_mark(1) end))
end

function ProjectCommitsScreen:handle_on_enter()
  local _, filename = self.store:get_filename()

  if not filename then
    self.foldable_list_view:toggle_current_list_item():render()

    return
  end

  if not fs.exists(filename) then
    local commit_err, commit_hash = self.store:get_parent_commit()

    if commit_err then
      console.debug.error(commit_err).error(commit_err)

      return
    end

    local lines_err, lines = self.store:get_remote_lines(filename, commit_hash)
    loop.free_textlock()

    if lines_err then
      console.debug.error(lines_err).error(lines_err)

      return
    end

    self:destroy()

    vim.cmd('enew')

    local buffer = Buffer(0)
    local filetype = fs.detect_filetype(filename)

    buffer:set_lines(lines)
    buffer:set_option('ft', filetype)

    return
  end

  self:destroy()

  fs.open(filename)

  local diff_dto_err, diff_dto = self.store:get_diff_dto()

  if diff_dto_err or not diff_dto then
    return
  end

  local window = Window(0)

  window:set_lnum(diff_dto.marks[1].top_relative):position_cursor('center')
end

function ProjectCommitsScreen:show(args)
  local commits = {}
  local buffer = Buffer(0)
  local target_filename = buffer.filename

  -- TODO: Need to add an arg parser in core that takes you can
  --       somehow define and then parse the input using definition.
  for i = 1, #args do
    local arg = args[i]

    if vim.startswith(arg, '--filename') then
      target_filename = arg:sub(#'--filename=' + 1, #arg)

      if target_filename == '' then
        target_filename = nil
      end
    else
      commits[#commits + 1] = arg
    end
  end

  loop.free_textlock()
  local err = self.store:fetch(self.layout_type, commits)

  if err then
    console.debug.error(err).error(err)
    return false
  end

  loop.free_textlock()
  self.diff_view:define()
  self.foldable_list_view:set_title('Project commits')
  self.foldable_list_view:define()

  self.diff_view:show()
  self.foldable_list_view:show()
  self.foldable_list_view:set_keymap({
    {
      mode = 'n',
      key = 'j',
      handler = loop.coroutine(function() self:handle_list_move('down') end),
    },
    {
      mode = 'n',
      key = 'k',
      handler = loop.coroutine(function() self:handle_list_move('up') end),
    },
    {
      mode = 'n',
      key = '<enter>',
      handler = loop.coroutine(function() self:handle_on_enter() end),
    },
  })

  self.foldable_list_view.scene:get('list').buffer:on('CursorMoved', loop.coroutine(function() self:handle_list_move() end))

  local list_item = self.foldable_list_view:move_to(function(node)
    local filename = node.path and node.path.file and node.path.file.filename or nil
    return filename == target_filename
  end)

  if not list_item then
    list_item = self.foldable_list_view:move_to(function(node)
      local filename = node.path and node.path.file and node.path.file.filename or nil
      return filename ~= nil
    end)
  end

  if list_item then
    self.store:set_id(list_item.id)
    self.diff_view:render_debounced(loop.coroutine(function() self.diff_view:navigate_to_mark(1) end))
  end

  return true
end

function ProjectCommitsScreen:destroy()
  self.scene:destroy()

  return self
end

return ProjectCommitsScreen
