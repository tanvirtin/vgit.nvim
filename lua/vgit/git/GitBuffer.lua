local lazy = require('vgit.core.lazy')

local utils = lazy('vgit.core.utils')
local event = lazy('vgit.core.event')
local keymap = lazy('vgit.core.keymap')
local Buffer = lazy('vgit.core.Buffer')
local Extmark = lazy('vgit.ui.Extmark')
local GitFile = lazy('vgit.git.GitFile')
local git_repo = lazy('vgit.libgit2.git_repo')
local signs_setting = lazy('vgit.settings.signs')
local live_blame_setting = lazy('vgit.settings.live_blame')
local BlameAnnotator = lazy('vgit.ui.annotators.BlameAnnotator')
local ConflictAnnotator = lazy('vgit.ui.annotators.ConflictAnnotator')
local GutterSignAnnotator = lazy('vgit.ui.annotators.GutterSignAnnotator')

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
  buffer._signs_dirty = false
  buffer._op_lock = false
  buffer._blame_extmark = Extmark(bufnr, 'blame')
  buffer._gutter_extmark = Extmark(bufnr, 'gutter')
  buffer._conflict_extmark = Extmark(bufnr, 'conflict')
  buffer._gutter_sign_annotator = GutterSignAnnotator()
  buffer._conflict_annotator = ConflictAnnotator()
  buffer._blame_annotator = BlameAnnotator()

  return buffer
end

function GitBuffer:create(...)
  Buffer.create(self, ...)

  self._blame_extmark = Extmark(self.bufnr, 'blame')
  self._gutter_extmark = Extmark(self.bufnr, 'gutter')
  self._conflict_extmark = Extmark(self.bufnr, 'conflict')
  self._gutter_sign_annotator = GutterSignAnnotator()
  self._conflict_annotator = ConflictAnnotator()
  self._blame_annotator = BlameAnnotator()

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
  self._signs_dirty = false
  self._op_lock = false
  self._git_file = GitFile(self:get_name())

  return self
end

function GitBuffer:acquire()
  if self._op_lock then return false end
  self._op_lock = true
  return true
end

function GitBuffer:release()
  self._op_lock = false
end

function GitBuffer:reset_signs()
  self.state.signs = {}
  self._signs_dirty = true
  return self
end

function GitBuffer:clear_conflicts(top, bot)
  top = top or 0
  bot = bot or -1

  self._conflict_extmark:clear(top, bot)
  return self
end

function GitBuffer:clear_blames(top, bot)
  top = top or 0
  bot = bot or -1

  self._blame_extmark:clear(top, bot)
  return self
end

function GitBuffer:clear_signs(top, bot)
  top = top or 0
  bot = bot or -1

  self._gutter_extmark:clear(top, bot)
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
  local config, err = self._git_file:config()
  if config then self:set_state({ config = config }) end
  return config, err
end

function GitBuffer:is_ignored()
  return self._git_file:is_ignored()
end

function GitBuffer:is_tracked()
  return self._git_file:is_tracked()
end

function GitBuffer:is_inside_git_dir()
  return git_repo.exists(self:get_name())
end

function GitBuffer:generate_status()
  self:set_var('vgit_status', self._git_file:generate_status())
  return self
end

function GitBuffer:stage_hunk(hunk)
  local _, err = self._git_file:stage_hunk(hunk)
  if err then return _, err end

  return self:diff()
end

function GitBuffer:unstage_hunk(hunk)
  local _, err = self._git_file:unstage_hunk(hunk)
  if err then return _, err end

  return self:diff()
end

function GitBuffer:stage()
  local _, err = self._git_file:stage()
  if err then return _, err end

  return self:diff()
end

function GitBuffer:unstage()
  local _, err = self._git_file:unstage()
  if err then return _, err end

  return self:diff()
end

function GitBuffer:get_hunks()
  return self._git_file:get_hunks()
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
  local marks = {}
  local marks_len = 0
  for _, conflict in ipairs(conflicts) do
    marks_len = marks_len + 1
    marks[marks_len] = {
      top = conflict.current.top,
      bot = conflict.incoming.bot,
    }
  end
  return marks
end

function GitBuffer:blame(lnum)
  local blame, err = self._git_file:blame(lnum)
  if blame then self:set_state({ blames = { [lnum] = blame } }) end
  return blame, err
end

function GitBuffer:blames()
  return self._git_file:blames()
end

function GitBuffer:conflicts()
  local state = self.state
  if not self._git_file:has_conflict() then
    state.conflicts = {}
    return state.conflicts
  end
  local lines = self:get_lines()
  local conflicts = self._git_file:conflicts(lines)
  self:set_state({ conflicts = conflicts })
  return conflicts
end

function GitBuffer:diff()
  local lines = self:get_lines()
  local hunks, err = self._git_file:live_hunks(lines)
  if err then return nil, err end
  if not hunks then return nil end

  local sign_types = signs_setting:get('usage').main
  local signs = self._gutter_sign_annotator:annotate(hunks, sign_types)

  self:set_state({ signs = signs })
  self._signs_dirty = true

  return hunks
end

function GitBuffer:exists()
  event.await()
  if not self:is_valid() then return false end

  if self:get_option('buftype') ~= '' then return false end

  if not self:is_inside_git_dir() then return false end

  if not self:is_in_disk() then return false end

  if self:is_ignored() then return false end

  return true
end

function GitBuffer:render_conflict_help_text(conflict)
  local current = conflict.current

  local help_text = ''

  local accept_current_change_keymap = utils.list.find(keymap.find('conflict_accept_current'), function(binding)
    return binding.mode == 'n'
  end)
  local accept_incoming_change_keymap = utils.list.find(keymap.find('conflict_accept_incoming'), function(binding)
    return binding.mode == 'n'
  end)
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
    self._conflict_extmark:text({
      text = help_text,
      hl = 'GitComment',
      row = current.top - 2,
      col = 0,
    })
  end

  return self
end

function GitBuffer:render_conflict(conflict)
  local annotation = self._conflict_annotator:annotate(conflict)
  for _, sign in ipairs(annotation.signs) do
    self._conflict_extmark:sign(sign)
  end
  for _, text in ipairs(annotation.texts) do
    self._conflict_extmark:text(text)
  end

  return self
end

function GitBuffer:render_conflicts(top, bot)
  top = top or 0
  bot = bot or -1

  event.await()
  self:clear_conflicts(top, bot)

  local conflicts = self:get_conflicts()
  for _, conflict in ipairs(conflicts) do
    self:render_conflict_help_text(conflict)
    self:render_conflict(conflict)
  end

  return self
end

function GitBuffer:render_signs(top, bot)
  top = top or 0
  bot = bot or -1

  -- When sign data has changed, do a full clear so stale signs outside
  -- the current viewport are removed, then reset the flag.
  if self._signs_dirty then
    self:clear_signs()
    self._signs_dirty = false
  else
    self:clear_signs(top, bot)
  end

  -- Only place extmarks for signs visible in the current viewport.
  local signs = self.state.signs or {}
  for _, sign in ipairs(signs) do
    local col = sign.col
    if col >= top and (bot == -1 or col <= bot) then self._gutter_extmark:sign(sign) end
  end

  return self
end

function GitBuffer:render_blames(top, bot)
  top = top or 0
  bot = bot or -1

  self:clear_blames(top, bot)

  local blames = self.state.blames or {}
  local format_fn = live_blame_setting:get('format')
  for lnum, blame in pairs(blames) do
    if blame and lnum >= top and (bot == -1 or lnum <= bot) then
      local annotation = self._blame_annotator:annotate(blame, lnum, self.state.config, format_fn)
      if annotation then self._blame_extmark:text(annotation) end
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
