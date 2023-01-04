local fs = require('vgit.core.fs')
local loop = require('vgit.core.loop')
local Scene = require('vgit.ui.Scene')
local utils = require('vgit.core.utils')
local Object = require('vgit.core.Object')
local Buffer = require('vgit.core.Buffer')
local Window = require('vgit.core.Window')
local console = require('vgit.core.console')
local DiffView = require('vgit.ui.views.DiffView')
local FSListGenerator = require('vgit.ui.FSListGenerator')
local FoldableListView = require('vgit.ui.views.FoldableListView')
local Store = require('vgit.features.screens.ProjectCommitsScreen.Store')

local ProjectCommitsScreen = Object:extend()

function ProjectCommitsScreen:constructor()
  local scene = Scene()
  local store = Store()

  return {
    name = 'Project Commits Screen',
    scene = scene,
    store = store,
    hydrate = false,
    layout_type = nil,
    diff_view = DiffView(scene, store, {
      col = '25vw',
      width = '75vw',
    }, {
      elements = {
        header = true,
        footer = false,
      },
    }),
    foldable_list_view = FoldableListView(scene, store, {
      width = '25vw',
    }, {
      elements = {
        header = true,
        footer = false,
      },
      get_list = function(commits)
        if utils.object.size(commits) == 1 then
          return FSListGenerator(utils.object.first(commits)):generate()
        end

        local foldable_list = {}

        for commit_hash, files in pairs(commits) do
          foldable_list[#foldable_list + 1] = {
            open = true,
            value = commit_hash:sub(1, 8),
            items = FSListGenerator(files):generate(),
          }
        end

        return foldable_list
      end,
    }),
  }
end

function ProjectCommitsScreen:get_list_title(commits)
  return utils.object.size(commits) == 1 and utils.object.first(commits):sub(1, 8) or 'Project commits'
end

function ProjectCommitsScreen:hunk_up() self.diff_view:prev() end

function ProjectCommitsScreen:hunk_down() self.diff_view:next() end

function ProjectCommitsScreen:handle_list_move_down()
  local list_item = self.foldable_list_view:move('down')

  if not list_item then
    return
  end

  self.store:set_id(list_item.id)
  self.diff_view:render_debounced(loop.async(function() self.diff_view:navigate_to_mark(1) end))
end

function ProjectCommitsScreen:handle_list_move_up()
  local list_item = self.foldable_list_view:move('up')

  if not list_item then
    return
  end

  self.store:set_id(list_item.id)
  self.diff_view:render_debounced(function() self.diff_view:navigate_to_mark(1) end)
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
    loop.await()

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

  Window(0):set_lnum(diff_dto.marks[1].top_relative):position_cursor('center')
end

function ProjectCommitsScreen:show(commits)
  loop.await()
  local err = self.store:fetch(self.layout_type, commits, { hydrate = self.hydrate })

  if err then
    console.debug.error(err).error(err)
    return false
  end

  loop.await()
  self.diff_view:show(self.layout_type)
  self.foldable_list_view:set_title(self:get_list_title(commits)):show()
  self.foldable_list_view:set_keymap({
    {
      mode = 'n',
      key = 'j',
      handler = loop.async(function() self:handle_list_move_down() end),
    },
    {
      mode = 'n',
      key = 'k',
      handler = loop.async(function() self:handle_list_move_up() end),
    },
    {
      mode = 'n',
      key = '<enter>',
      handler = loop.async(function() self:handle_on_enter() end),
    },
  })
  return true
end

function ProjectCommitsScreen:destroy()
  self.scene:destroy()

  return self
end

return ProjectCommitsScreen
