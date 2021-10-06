local utils = require('vgit.utils')
local CodeComponent = require('vgit.components.CodeComponent')
local Preview = require('vgit.Preview')
local render_store = require('vgit.stores.render_store')

local config = render_store.get('layout').gutter_blame_preview

local function get_blame_line(blame)
  local time = os.difftime(os.time(), blame.author_time) / (24 * 60 * 60)
  local time_format = string.format('%s days ago', utils.round(time))
  local time_divisions = {
    { 24, 'hours' },
    { 60, 'minutes' },
    { 60, 'seconds' },
  }
  local division_counter = 1
  while time < 1 and division_counter ~= #time_divisions do
    local division = time_divisions[division_counter]
    time = time * division[1]
    time_format = string.format('%s %s ago', utils.round(time), division[2])
    division_counter = division_counter + 1
  end
  if blame.committed then
    return string.format(
      '%s (%s) • %s',
      blame.author,
      time_format,
      blame.committed and blame.commit_message or 'Uncommitted changes'
    )
  end
  return 'Uncommitted changes'
end

local function get_blame_lines(blames)
  local blame_lines = {}
  local last_blame = nil
  for i = 1, #blames do
    local blame = blames[i]
    if last_blame then
      if blame.commit_hash == last_blame.commit_hash then
        blame_lines[#blame_lines + 1] = ''
      else
        blame_lines[#blame_lines + 1] = get_blame_line(blame)
      end
    else
      blame_lines[#blame_lines + 1] = get_blame_line(blame)
    end
    last_blame = blame
  end
  return blame_lines
end

local GutterBlamePreview = Preview:extend()

function GutterBlamePreview:new(opts)
  local this = Preview:new({
    blame = CodeComponent:new({
      header = {
        enabled = false,
      },
      border = utils.retrieve(config.blame.border),
      win_options = {
        ['winhl'] = string.format(
          'Normal:%s',
          utils.retrieve(config.blame.background_hl) or ''
        ),
        ['cursorbind'] = true,
        ['scrollbind'] = true,
        ['cursorline'] = true,
      },
      window_props = {
        focusable = false,
        style = 'minimal',
        height = utils.retrieve(config.blame.height),
        width = utils.retrieve(config.blame.width),
        row = utils.retrieve(config.blame.row),
        col = utils.retrieve(config.blame.col),
      },
    }),
    preview = CodeComponent:new({
      header = {
        enabled = false,
      },
      border = utils.retrieve(config.blame.preview),
      win_options = {
        ['winhl'] = string.format(
          'Normal:%s',
          utils.retrieve(config.preview.background_hl) or ''
        ),
        ['cursorbind'] = true,
        ['scrollbind'] = true,
        ['cursorline'] = true,
        ['number'] = true,
      },
      window_props = {
        style = 'minimal',
        height = utils.retrieve(config.preview.height),
        width = utils.retrieve(config.preview.width),
        row = utils.retrieve(config.preview.row),
        col = utils.retrieve(config.preview.col),
      },
      filetype = opts.filetype,
    }),
  }, {
    temporary = true,
  })
  return setmetatable(this, GutterBlamePreview)
end

function GutterBlamePreview:get_preview_buf()
  return { self:get_components().preview:get_buf() }
end

function GutterBlamePreview:set_cursor(row, col)
  self:get_components().preview:set_cursor(row, col)
  return self
end

function GutterBlamePreview:render()
  if not self:is_mounted() then
    return
  end
  local err, data = self.err, self.data
  self:clear()
  local components = self:get_components()
  if err then
    self:set_error(true)
    return self
  end
  if data then
    components.preview:set_lines(data.lines)
    components.blame:set_lines(get_blame_lines(data.blames))
  end
  components.preview:focus()
  return self
end

return GutterBlamePreview
