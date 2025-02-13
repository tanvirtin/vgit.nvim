local fs = require('vgit.core.fs')
local loop = require('vgit.core.loop')
local Scene = require('vgit.ui.Scene')
local Object = require('vgit.core.Object')
local Buffer = require('vgit.core.Buffer')
local Window = require('vgit.core.Window')
local console = require('vgit.core.console')
local git_show = require('vgit.git.git_show')
local git_repo = require('vgit.libgit2.git_repo')
local DiffView = require('vgit.ui.views.DiffView')
local StatusListView = require('vgit.ui.views.StatusListView')
local Model = require('vgit.features.screens.ProjectCommitsScreen.Model')

local ProjectCommitsScreen = Object:extend()

function ProjectCommitsScreen:constructor(opts)
  opts = opts or {}

  local scene = Scene()
  local model = Model(opts)

  return {
    name = 'Project Commits Screen',
    scene = scene,
    model = model,
    status_list_view = StatusListView(scene, {
      entries = function()
        return model:get_entries()
      end,
    }, { height = '25vh' }, {
      open_folds = false,
      elements = {
        header = true,
        footer = false,
      },
    }),
    diff_view = DiffView(scene, {
      layout_type = function()
        return model:get_layout_type()
      end,
      filename = function()
        return model:get_filename()
      end,
      filetype = function()
        return model:get_filetype()
      end,
      diff = function()
        return model:get_diff()
      end,
    }, {
      row = '25vh',
      height = '100vh',
    }, {
      elements = {
        header = true,
        footer = false,
      },
    }),
  }
end

function ProjectCommitsScreen:hunk_up()
  self.diff_view:prev()
end

function ProjectCommitsScreen:hunk_down()
  self.diff_view:next()
end

ProjectCommitsScreen.render_diff_view_debounced = loop.debounce_coroutine(function(self)
  self.diff_view:render()
  self.diff_view:move_to_hunk()
end, 200)

function ProjectCommitsScreen:handle_list_move(direction)
  local list_item = self.status_list_view:move(direction)
  if not list_item then return end

  self.model:set_entry_id(list_item.id)
  self:render_diff_view_debounced()
end

function ProjectCommitsScreen:open_file()
  local filename = self.model:get_filename()
  if not filename then return end

  if not fs.exists(filename) then
    local commit_hash, commit_err = self.model:get_parent_commit()
    loop.free_textlock()

    if commit_err then
      console.debug.error(commit_err).error(commit_err)
      return
    end

    local reponame = git_repo.discover()
    local lines, lines_err = git_show.lines(reponame, filename, commit_hash)
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

  local diff, diff_err = self.model:get_diff()
  if diff_err or not diff then return end

  local window = Window(0)

  window:set_lnum(diff.marks[1].top_relative):position_cursor('center')
end

function ProjectCommitsScreen:create(args)
  local commits = {}
  local buffer = Buffer(0)
  local filename = buffer:get_name()

  for i = 1, #args do
    local arg = args[i]

    if vim.startswith(arg, '--filename') then
      filename = arg:sub(#'--filename=' + 1, #arg)

      if filename == '' then filename = nil end
    else
      commits[#commits + 1] = arg
    end
  end

  loop.free_textlock()
  local _, err = self.model:fetch(commits)
  loop.free_textlock()

  if err then
    console.debug.error(err).error(err)
    return false
  end

  loop.free_textlock()
  self.diff_view:define()
  self.diff_view:mount()

  self.status_list_view:define()
  self.status_list_view:mount({
    event_handlers = {
      on_enter = function()
        self:open_file()
      end,
      on_move = function()
        self:handle_list_move()
      end,
    },
  })
  self.status_list_view:render()

  return true
end

function ProjectCommitsScreen:destroy()
  self.scene:destroy()
end

return ProjectCommitsScreen
