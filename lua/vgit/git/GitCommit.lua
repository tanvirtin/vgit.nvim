local utils = require('vgit.core.utils')
local Object = require('vgit.core.Object')

local GitCommit = Object:extend()

GitCommit.EMPTY_HASH = '0000000000000000000000000000000000000000'

function GitCommit:constructor(data)
  if not data then error('GitCommit requires data') end

  local commit = {
    id = data.id or utils.math.uuid(),
    hash = data.hash or data.commit_hash,
    author = data.author or data.author_name,
    author_mail = data.author_mail or data.author_email,
    author_time = data.author_time or data.timestamp,
    author_tz = data.author_tz,
    committer = data.committer,
    committer_mail = data.committer_mail,
    committer_time = data.committer_time,
    committer_tz = data.committer_tz,
    message = data.message or data.commit_message or data.summary,

    -- Internal fields for lazy loading
    _parent_hash = data.parent_hash,
    _parent = nil, -- Cached parent GitCommit
    _repository = data.repository, -- For lazy loading

    -- Context metadata (how this commit was obtained)
    context = data.context or {},
  }

  -- If parent_hash is empty string, set to nil
  if commit._parent_hash == '' then commit._parent_hash = nil end

  -- Backward compatibility: expose fields with old names
  -- These are virtual fields that map to new structure
  commit.commit_hash = commit.hash
  commit.parent_hash = commit._parent_hash -- Direct access to parent hash (string)
  commit.commit_message = commit.message
  commit.author_name = commit.author
  commit.author_email = commit.author_mail
  commit.timestamp = commit.author_time
  -- Expose summary as both a field and a method for backward compatibility
  commit.summary = commit.message and commit.message:match('^([^\n]*)') or commit.message
  commit.lnum = commit.context.lnum
  commit.filename = commit.context.filename
  commit.revision = commit.context.revision
  commit.committed = commit.hash ~= GitCommit.EMPTY_HASH

  return commit
end

function GitCommit:is_empty()
  return self.hash == GitCommit.EMPTY_HASH
end

function GitCommit:is_uncommitted()
  return self:is_empty()
end

function GitCommit:is_committed()
  return not self:is_uncommitted()
end

function GitCommit:short_hash(length)
  length = length or 7
  if not self.hash then return nil end
  return self.hash:sub(1, length)
end

function GitCommit:age()
  if not self.author_time then return nil end
  return utils.date.age(self.author_time)
end

function GitCommit:author_signature()
  if not self.author then return nil end
  if self.author_mail then return string.format('%s <%s>', self.author, self.author_mail) end
  return self.author
end

function GitCommit:committer_signature()
  if not self.committer then return nil end
  if self.committer_mail then return string.format('%s <%s>', self.committer, self.committer_mail) end
  return self.committer
end

-- Note: summary is exposed as a field (commit.summary), not a method
-- This contains the first line of the commit message

-- Lazy-loaded parent commit (backward linked list)
-- Returns the parent as a full GitCommit object
function GitCommit:parent()
  if not self._parent_hash then return nil, nil end

  -- Return cached parent if already loaded
  if self._parent then return self._parent, nil end

  -- Lazy load parent commit if repository is available
  if self._repository then
    local git_log = require('vgit.git.git_log')
    local parent_commit, err = git_log.get(
      type(self._repository) == 'string' and self._repository or self._repository:get_path(),
      self._parent_hash
    )

    if err then return nil, err end

    if parent_commit then
      -- Cache the parent
      self._parent = parent_commit
      return parent_commit, nil
    end
  end

  -- If no repository or failed to load, return nil
  return nil, { 'parent commit not available' }
end

-- Check if this commit has a parent
function GitCommit:has_parent()
  return self._parent_hash ~= nil
end

-- Traverse parent chain with a callback
function GitCommit:traverse(callback, max_depth)
  if not callback then return nil, { 'callback is required' } end

  max_depth = max_depth or math.huge
  local current = self
  local depth = 0

  while current and depth < max_depth do
    local should_continue = callback(current, depth)
    if should_continue == false then break end

    local parent, err = current:parent()
    if err then return nil, err end
    current = parent
    depth = depth + 1
  end

  return true, nil
end

-- Get ancestor at specific depth (0 = self, 1 = parent, 2 = grandparent, etc)
function GitCommit:ancestor(depth)
  if depth == 0 then return self, nil end

  local current = self
  for _ = 1, depth do
    if not current then return nil, { 'ancestor not found' } end
    local parent, err = current:parent()
    if err then return nil, err end
    current = parent
  end

  return current, nil
end

function GitCommit:__tostring()
  return string.format('GitCommit(hash=%s, author=%s)', self:short_hash() or 'nil', self.author or 'nil')
end

function GitCommit:__eq(other)
  return self.hash == other.hash
end

return GitCommit
