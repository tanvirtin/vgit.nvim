local loop = require('vgit.core.loop')
local Object = require('vgit.core.Object')
local console = require('vgit.core.console')
local GitBuffer = require('vgit.git.GitBuffer')
local Namespace = require('vgit.core.Namespace')
local git_buffer_store = require('vgit.git.git_buffer_store')
local authorship_code_lens_setting = require('vgit.settings.authorship_code_lens')

local AuthorshipCodeLens = Object:extend()

function AuthorshipCodeLens:constructor()
  return {
    name = 'Authorship Code Lens',
    namespace = Namespace(),
  }
end

function AuthorshipCodeLens:display(lnum, buffer, text)
  if not text then
    return self
  end

  if not buffer:is_valid() then
    return self
  end

  loop.free_textlock()
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

function AuthorshipCodeLens:reset()
  local buffers = GitBuffer:list()

  for i = 1, #buffers do
    self:clear(buffers[i])
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
    loop.free_textlock()

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

function AuthorshipCodeLens:render(git_buffer, bot)
  if not authorship_code_lens_setting:get('enabled') then
    return self
  end

  if git_buffer.state.is_showing_lens then
    git_buffer.state.is_processing = false

    return
  end

  if git_buffer.state.is_processing then
    return
  end

  local line_count = git_buffer:get_line_count()

  if line_count > bot then
    git_buffer.state.is_processing = false

    return
  end

  git_buffer.state.is_processing = true

  loop.free_textlock()
  local blames_err, blames = git_buffer.git_object:blames()

  loop.free_textlock()
  if blames_err then
    git_buffer.state.is_processing = false

    console.debug.error(blames_err)
    return self
  end

  loop.free_textlock()
  local config_err, config = git_buffer.git_object:config()

  if config_err then
    git_buffer.state.is_processing = false

    console.debug.error(config_err)
    return self
  end

  local authorship = self:generate_authorship(config, blames)

  self:clear(git_buffer)
  self:display(line_count, git_buffer, authorship)

  git_buffer.state.is_processing = false
  git_buffer.state.is_showing_lens = true
end

function AuthorshipCodeLens:register_events()
  git_buffer_store.attach('render', function(git_buffer, _, bot) self:render(git_buffer, bot) end)

  return self
end

return AuthorshipCodeLens
