local utils = require('vgit.core.utils')
local keymap = require('vgit.core.keymap')
local Buffer = require('vgit.core.Buffer')
local git_repo = require('vgit.git.git_repo')
local GitObject = require('vgit.git.GitObject')
local signs_setting = require('vgit.settings.signs')

local GitBuffer = Buffer:extend()

function GitBuffer:sync()
  Buffer.sync(self)

  self.signs = {}
  self.conflicts = {}
  self.is_processing = false
  self.is_showing_lens = false
  self.git_object = GitObject(self:get_name())

  return self
end

function GitBuffer:config()
  return self.git_object:config()
end

function GitBuffer:is_ignored()
  return self.git_object:is_ignored()
end

function GitBuffer:is_tracked()
  return self.git_object:is_tracked()
end

function GitBuffer:is_inside_git_dir()
  return git_repo.exists(self:get_name())
end

function GitBuffer:has_conflict()
  return self.git_object:has_conflict()
end

function GitBuffer:parse_conflicts()
  self.conflicts = self.git_object:parse_conflicts(self:get_lines())
  return self.conflicts
end

function GitBuffer:render_conflict_help_text(conflict)
  local current = conflict.current

  local help_text = ''

  local accept_current_change_keymap = utils.list.find(keymap.find('conflict_accept_current_change'), function(binding)
    return binding.mode == 'n'
  end)
  local accept_incoming_change_keymap = utils.list.find(
    keymap.find('conflict_accept_incoming_change'),
    function(binding)
      return binding.mode == 'n'
    end
  )
  local accept_both_changes_keymap = utils.list.find(keymap.find('conflict_accept_both_changes'), function(binding)
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
    self:insert_virtual_line({
      text = help_text,
      hl = 'GitComment',
      row = current.top - 1,
      col = 0,
    })
  end

  return self
end

function GitBuffer:render_conflict(conflict)
  local middle = conflict.middle
  local current = conflict.current
  local ancestor = conflict.ancestor
  local incoming = conflict.incoming

  self:sign_place(current.top, 'GitConflictCurrentMark')
  self:transpose_virtual_text({
    text = '(Current Change)',
    hl = 'GitComment',
    row = current.top - 1,
    col = 0,
    pos = 'eol',
  })

  for lnum = current.top + 1, current.bot do
    self:sign_place(lnum, 'GitConflictCurrent')
  end

  for lnum = middle.top, middle.bot do
    self:sign_place(lnum, 'GitConflictMiddle')
  end

  for lnum = incoming.top, incoming.bot - 1 do
    self:sign_place(lnum, 'GitConflictIncoming')
  end

  self:sign_place(incoming.bot, 'GitConflictIncomingMark')
  self:transpose_virtual_text({
    text = '(Incoming Change)',
    hl = 'GitComment',
    row = incoming.bot - 1,
    col = 0,
    pos = 'eol',
  })

  if ancestor and not utils.list.is_empty(ancestor) then
    self:sign_place(ancestor.top, 'GitConflictAncestorMark')
    for lnum = ancestor.top + 1, ancestor.bot do
      self:sign_place(lnum, 'GitConflictAncestor')
    end
  end

  return self
end

function GitBuffer:render_conflicts()
  self:sign_unplace()
  self:clear_namespace()

  for i = 1, #self.conflicts do
    local conflict = self.conflicts[i]

    self:render_conflict_help_text(conflict)
    self:render_conflict(conflict)
  end

  return self
end

function GitBuffer:generate_status()
  self:set_var('vgit_status', self.git_object:generate_status())
  return self
end

function GitBuffer:stage_hunk(hunk)
  return self.git_object:stage_hunk(hunk)
end

function GitBuffer:unstage_hunk(hunk)
  return self.git_object:unstage_hunk(hunk)
end

function GitBuffer:stage()
  return self.git_object:stage()
end

function GitBuffer:unstage()
  return self.git_object:unstage()
end

function GitBuffer:get_hunks()
  return self.git_object.hunks
end

function GitBuffer:blame(lnum)
  return self.git_object:blame(lnum)
end

function GitBuffer:blames()
  return self.git_object:blames()
end

function GitBuffer:live_hunks()
  local lines = self:get_lines()
  local hunks, err = self.git_object:live_hunks(lines)

  if err then return nil, err end

  local sign_types = signs_setting:get('usage').main
  local sign_priority = signs_setting:get('priority')
  local sign_group = self.namespace:get_sign_ns_id(self)

  self.signs = {}
  for i = 1, #hunks do
    local hunk = hunks[i]
    for j = hunk.top, hunk.bot do
      local lnum = (hunk.type == 'remove' and j == 0) and 1 or j
      self.signs[lnum] = {
        id = lnum,
        lnum = lnum,
        buffer = self.bufnr,
        group = sign_group,
        name = sign_types[hunk.type],
        priority = sign_priority,
      }
    end
  end

  return hunks
end

function GitBuffer:get_conflict_under_hunk(cursor)
  local lnum = cursor[1]
  return utils.list.find(self.conflicts, function(conflict)
    local top = conflict.current.top
    local bot = conflict.incoming.bot
    return lnum >= top and lnum <= bot
  end)
end

return GitBuffer
