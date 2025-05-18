local loop = require('vgit.core.loop')
local utils = require('vgit.core.utils')
local keymap = require('vgit.core.keymap')
local Buffer = require('vgit.core.Buffer')
local Extmark = require('vgit.ui.Extmark')
local GitFile = require('vgit.git.GitFile')
local git_repo = require('vgit.git.git_repo')
local signs_setting = require('vgit.settings.signs')
local live_blame_setting = require('vgit.settings.live_blame')

local GitBuffer = Buffer:extend()

function GitBuffer:constructor(...)
  local buffer = Buffer.constructor(self, ...)
  local bufnr = buffer.bufnr

  buffer.state = {
    signs = {},
    blames = {},
    config = nil,
    conflicts = {},
  }
  buffer.blame_extmark = Extmark(bufnr, 'blame')
  buffer.gutter_extmark = Extmark(bufnr, 'gutter')
  buffer.conflict_extmark = Extmark(bufnr, 'conflict')

  return buffer
end

function GitBuffer:create(...)
  Buffer.create(self, ...)

  self.blame_extmark = Extmark(self.bufnr, 'blame')
  self.gutter_extmark = Extmark(self.bufnr, 'gutter')
  self.conflict_extmark = Extmark(self.bufnr, 'conflict')

  return self
end

function GitBuffer:sync()
  Buffer.sync(self)
  self.state = {
    signs = {},
    blames = {},
    config = nil,
    conflicts = {},
  }
  self.git_file = GitFile(self:get_name())

  return self
end

function GitBuffer:reset_signs()
  self.state.signs = {}
  return self
end

function Buffer:clear_conflicts(top, bot)
  top = top or 0
  bot = bot or -1

  self.conflict_extmark:clear(top, bot)
  return self
end

function Buffer:clear_blames(top, bot)
  top = top or 0
  bot = bot or -1

  self.blame_extmark:clear(top, bot)
  return self
end

function Buffer:clear_signs(top, bot)
  top = top or 0
  bot = bot or -1

  self.gutter_extmark:clear(top, bot)
  return self
end

function GitBuffer:clear_extmarks(top, bot)
  top = top or 0
  bot = bot or -1

  Buffer.clear_extmarks(self)
  self:clear_signs(top, bot)
  self:clear_blames(top, bot)
  self:clear_conflicts(top, bot)

  return self
end

function GitBuffer:config()
  if self.state.config then return self.state.config end
  local config, err = self.git_file:config()
  if config then self:set_state({ config = config }) end
  return config, err
end

function GitBuffer:is_ignored()
  return self.git_file:is_ignored()
end

function GitBuffer:is_tracked()
  return self.git_file:is_tracked()
end

function GitBuffer:is_inside_git_dir()
  return git_repo.exists(self:get_name())
end

function GitBuffer:generate_status()
  self:set_var('vgit_status', self.git_file:generate_status())
  return self
end

function GitBuffer:stage_hunk(hunk)
  local _, err = self.git_file:stage_hunk(hunk)
  if not err then
    loop.free_textlock()
    self:diff()
  end
  return _, err
end

function GitBuffer:unstage_hunk(hunk)
  local _, err = self.git_file:unstage_hunk(hunk)
  if not err then
    loop.free_textlock()
    self:diff()
  end
  return _, err
end

function GitBuffer:stage()
  local _, err = self.git_file:stage()
  if not err then
    loop.free_textlock()
    self:diff()
  end
  return _, err
end

function GitBuffer:unstage()
  local _, err = self.git_file:unstage()
  if not err then
    loop.free_textlock()
    self:diff()
  end
  return _, err
end

function GitBuffer:get_hunks()
  return self.git_file:get_hunks()
end

function GitBuffer:get_conflicts()
  return self.state.conflicts
end

function GitBuffer:get_conflict(lnum)
  local conflicts = self:get_conflicts()
  return utils.list.find(conflicts, function(conflict)
    local top = conflict.current.top
    local bot = conflict.incoming.bot
    return lnum >= top and lnum <= bot
  end)
end

function GitBuffer:get_conflict_marks()
  local conflicts = self:get_conflicts()
  return utils.list.map(conflicts, function(conflict)
    return {
      top = conflict.current.top,
      bot = conflict.incoming.bot
    }
  end)
end

function GitBuffer:blame(lnum)
  local blame, err = self.git_file:blame(lnum)
  if blame then self:set_state({ blames = { [lnum] = blame } }) end
  return blame, err
end

function GitBuffer:blames()
  return self.git_file:blames()
end

function GitBuffer:conflicts()
  local state = self.state
  if not self.git_file:has_conflict() then
    state.conflicts = {}
    return state.conflicts
  end
  loop.free_textlock()
  local lines = self:get_lines()
  local conflicts = self.git_file:conflicts(lines)
  self:set_state({ conflicts = conflicts })
  return conflicts
end

function GitBuffer:diff()
  local lines = self:get_lines()
  local hunks, err = self.git_file:live_hunks(lines)
  if err then return nil, err end
  if not hunks then return nil end

  local sign_types = signs_setting:get('usage').main

  local signs = {}
  for i = 1, #hunks do
    local hunk = hunks[i]
    for j = hunk.top, hunk.bot do
      local lnum = (hunk.type == 'remove' and j == 0) and 1 or j
      signs[#signs + 1] = {
        col = lnum - 1,
        name = sign_types[hunk.type],
      }
    end
  end

  self:set_state({ signs = signs })

  return hunks
end

function GitBuffer:exists()
  loop.free_textlock()
  if not self:is_valid() then return false end

  loop.free_textlock()
  if self:get_option('buftype') ~= '' then return false end

  loop.free_textlock()
  if not self:is_inside_git_dir() then return false end

  loop.free_textlock()
  if not self:is_in_disk() then return false end

  loop.free_textlock()
  if self:is_ignored() then return false end

  return true
end

function GitBuffer:render_conflict_help_text(conflict)
  local current = conflict.current

  local help_text = ''

  local accept_current_change_keymap = utils.list.find(keymap.find('conflict_accept_current'), function(binding)
    return binding.mode == 'n'
  end)
  local accept_incoming_change_keymap = utils.list.find(
    keymap.find('conflict_accept_incoming'),
    function(binding)
      return binding.mode == 'n'
    end
  )
  local accept_both_changes_keymap = utils.list.find(keymap.find('conflict_accept_both'), function(binding)
    return binding.mode == 'n'
  end)

  if accept_current_change_keymap then
    if help_text ~= '' then help_text = help_text .. ' | ' end
    help_text = help_text .. string.format('Accept Current Change (%s)', accept_current_change_keymap.lhs)
  end
  if accept_incoming_change_keymap then
    if help_text ~= '' then help_text = help_text .. ' | ' end
    help_text = help_text .. string.format('Accept Incoming Change (%s)', accept_incoming_change_keymap.lhs)
  end
  if accept_both_changes_keymap then
    if help_text ~= '' then help_text = help_text .. ' | ' end
    help_text = help_text .. string.format('Accept Both Changes (%s)', accept_both_changes_keymap.lhs)
  end

  if help_text ~= '' then
    self.conflict_extmark:text({
      text = help_text,
      hl = 'GitComment',
      row = current.top - 2,
      col = 0,
    })
  end

  return self
end

function GitBuffer:render_conflict(conflict)
  local current = conflict.current
  local ancestor = conflict.ancestor
  local middle = conflict.middle
  local incoming = conflict.incoming

  self.conflict_extmark:sign({
    col = current.top - 1,
    name = 'GitConflictCurrentMark',
  })
  self.conflict_extmark:text({
    text = '(Current Change)',
    hl = 'GitComment',
    row = current.top - 1,
    col = 0,
    pos = 'eol',
  })

  for lnum = current.top + 1, current.bot do
    self.conflict_extmark:sign({
      col = lnum - 1,
      name = 'GitConflictCurrent',
    })
  end

  if ancestor and not utils.list.is_empty(ancestor) then
    self.conflict_extmark:sign({
      col = ancestor.top - 1,
      name = 'GitConflictAncestorMark',
    })
    for lnum = ancestor.top + 1, ancestor.bot do
      self.conflict_extmark:sign({
        col = lnum - 1,
        name = 'GitConflictAncestor',
      })
    end
  end

  for lnum = middle.top, middle.bot do
    self.conflict_extmark:sign({
      col = lnum - 1,
      name = 'GitConflictMiddle',
    })
  end

  for lnum = incoming.top, incoming.bot - 1 do
    self.conflict_extmark:sign({
      col = lnum - 1,
      name = 'GitConflictIncoming',
    })
  end

  self.conflict_extmark:sign({
    col = incoming.bot - 1,
    name = 'GitConflictIncomingMark',
  })

  self.conflict_extmark:text({
    text = '(Incoming Change)',
    hl = 'GitComment',
    row = incoming.bot - 1,
    col = 0,
    pos = 'eol',
  })

  return self
end

function GitBuffer:render_conflicts(top, bot)
  top = top or 0
  bot = bot or -1

  self:clear_conflicts(top, bot)

  local conflicts = self:get_conflicts()
  utils.list.each(conflicts, function(conflict)
    self:render_conflict_help_text(conflict)
    self:render_conflict(conflict)
  end)

  return self
end

function Buffer:render_signs(top, bot)
  top = top or 0
  bot = bot or -1
  self:clear_signs(top, bot)

  local signs = self.state.signs or {}
  for _, sign in ipairs(signs) do
    local col = sign.col
    if col >= top and (bot == -1 or col <= bot) then self.gutter_extmark:sign(sign) end
  end

  return self
end

function Buffer:render_blames(top, bot)
  top = top or 0
  bot = bot or -1

  self:clear_blames(top, bot)

  local blames = self.state.blames or {}
  for lnum, blame in pairs(blames) do
    if blame and lnum >= top and (bot == -1 or lnum <= bot) then
      local text = live_blame_setting:get('format')(blame, self.state.config)
      if type(text) == 'string' then
        self.blame_extmark:text({
          text = text,
          hl = 'GitComment',
          row = lnum - 1,
          col = 0,
          pos = 'eol',
        })
      end
    end
  end

  return self
end

function GitBuffer:render(top, bot)
  Buffer.render(self, top, bot)
  self:render_signs(top, bot)

  return self
end

return GitBuffer
