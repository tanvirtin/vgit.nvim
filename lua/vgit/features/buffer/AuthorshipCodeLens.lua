local loop = require('vgit.core.loop')
local event = require('vgit.core.event')
local Object = require('vgit.core.Object')
local console = require('vgit.core.console')
local git_service = require('vgit.services.git')
local Namespace = require('vgit.core.Namespace')
local event_type = require('vgit.core.event_type')
local authorship_code_lens_setting = require('vgit.settings.authorship_code_lens')

local AuthorshipCodeLens = Object:extend()

function AuthorshipCodeLens:constructor()
  return {
    name = 'Authorship Code Lens',
    namespace = Namespace(),
  }
end

function AuthorshipCodeLens:register_events()
  event.custom_on(event_type.VGitBufAttached, function() self:sync() end)

  return self
end

function AuthorshipCodeLens:display(lnum, buffer, text)
  if not text then
    return self
  end

  if not buffer:is_valid() then
    return self
  end

  loop.await()
  self.namespace:insert_virtual_lines(buffer, {
    { {
      text,
      'GitComment',
    } },
  }, lnum)

  return self
end

function AuthorshipCodeLens:clear(buffer)
  if buffer then
    self.namespace:clear(buffer)
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
    loop.await()

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

  loop.await()
  local buffer = git_service.store.current()

  loop.await()
  if not buffer then
    return self
  end

  loop.await()
  if not buffer:is_valid() then
    return self
  end

  loop.await()
  if not buffer.git_blob:is_tracked() then
    return self
  end

  loop.await()
  if not buffer:is_valid() then
    return self
  end

  loop.await()
  local blames_err, blames = buffer.git_blob:blame_lines()

  loop.await()
  if not buffer:is_valid() then
    return self
  end

  loop.await()
  if blames_err then
    console.debug.error(blames_err)
    return self
  end

  loop.await()
  local config_err, config = buffer.git_blob:get_config()

  if config_err then
    console.debug.error(config_err)
    return self
  end

  if not buffer:is_valid() then
    return
  end

  self:clear(buffer):display(buffer:get_line_count(), buffer, self:generate_authorship(config, blames))

  return self
end

return AuthorshipCodeLens
