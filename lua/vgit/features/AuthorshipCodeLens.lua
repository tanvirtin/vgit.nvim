local Buffer = require('vgit.core.Buffer')
local authorship_code_lens_setting = require(
  'vgit.settings.authorship_code_lens'
)
local Feature = require('vgit.Feature')
local Namespace = require('vgit.core.Namespace')
local console = require('vgit.core.console')
local loop = require('vgit.core.loop')

local AuthorshipCodeLens = Feature:extend()

function AuthorshipCodeLens:new(git_store, versioning)
  return setmetatable({
    name = 'Authorship Code Lens',
    git_store = git_store,
    versioning = versioning,
    namespace = Namespace:new(),
    -- TODO: When some of the neovim versions become more stable in various linux distros we can remove this.
    requires_neovim_version = {
      major = 0,
      minor = 6,
      patch = 0,
    },
  }, AuthorshipCodeLens)
end

function AuthorshipCodeLens:display(lnum, buffer, display)
  if not display then
    return self
  end
  if not self:is_buffer_valid(buffer) then
    return self
  end
  loop.await_fast_event()
  self.namespace:insert_virtual_lines(buffer, {
    { {
      display,
      'GitComment',
    } },
  }, lnum)
  return self
end

function AuthorshipCodeLens:hide()
  local buffers = Buffer:list()
  for i = 1, #buffers do
    local buffer = buffers[i]
    if buffer then
      self.namespace:clear(buffer)
    end
  end
  return self
end

function AuthorshipCodeLens:get_blame_display(git_config, blame)
  local config_author = git_config['user.name']
  local author = blame.author
  if config_author == author then
    author = 'You'
  end
  return string.format('%s, %s', author, blame:age().display)
end

function AuthorshipCodeLens:get_authorship_display(git_config, data)
  local num_authors = data.num_authors
  local code_owner = data.code_owner
  local config_author = git_config['user.name']
  if config_author == code_owner then
    code_owner = 'You'
  end
  if num_authors == 1 then
    return string.format('%s author (%s)', num_authors, code_owner)
  end
  return string.format('%s authors (%s and others)', num_authors, code_owner)
end

function AuthorshipCodeLens:generate_blame_statistics(blames)
  if #blames == 0 then
    return nil
  end
  local code_owner = nil
  local latest_blame = nil
  local author_references = {}
  local max_ref = 0
  local max_time = 0
  local num_authors = 0
  for i = 1, #blames do
    local blame = blames[i]
    if blame.committed then
      local author_name = blame.author
      if author_references[author_name] then
        local ref_count = author_references[author_name]
        ref_count = ref_count + 1
        author_references[author_name] = ref_count
      else
        author_references[author_name] = 1
        num_authors = num_authors + 1
      end
      local ref_count = author_references[author_name]
      if ref_count > max_ref then
        code_owner = author_name
        max_ref = ref_count
      end
      local author_time = blame.author_time
      if max_time == 0 then
        max_time = author_time
        latest_blame = blame
      elseif author_time > max_time then
        max_time = author_time
        latest_blame = blame
      end
    end
  end
  if num_authors == 0 then
    return nil
  end
  return {
    num_authors = num_authors,
    code_owner = code_owner,
    latest_blame = latest_blame,
  }
end

function AuthorshipCodeLens:generate_authorship(config, blames)
  local data = self:generate_blame_statistics(blames)
  if not data then
    return nil
  end
  return string.format(
    '%s | %s',
    self:get_blame_display(config, data.latest_blame),
    self:get_authorship_display(config, data)
  )
end

function AuthorshipCodeLens:sync()
  if not authorship_code_lens_setting:get('enabled') then
    return self
  end
  if not self:guard() then
    return self
  end
  loop.await_fast_event()
  local buffer = self.git_store:current()
  if not buffer then
    return self
  end
  if not self:is_buffer_valid(buffer) then
    return self
  end
  if not self:is_buffer_tracked(buffer) then
    return self
  end
  loop.await_fast_event()
  local blames_err, blames = buffer.git_object:blames()
  if not self:is_buffer_valid(buffer) then
    return self
  end
  loop.await_fast_event()
  if blames_err then
    console.debug(blames_err, debug.traceback())
    return self
  end
  loop.await_fast_event()
  local config_err, config = buffer.git_object:config()
  if config_err then
    console.debug(config_err, debug.traceback())
    return self
  end
  self:display(
    buffer:get_line_count(),
    buffer,
    self:generate_authorship(config, blames)
  )
  return self
end

function AuthorshipCodeLens:resync()
  self:hide()
  self:sync()
end

return AuthorshipCodeLens
