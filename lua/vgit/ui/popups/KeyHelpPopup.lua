local Popup = require('vgit.ui.Popup')
local utils = require('vgit.core.utils')

local KeyHelpPopup = Popup:extend()

function KeyHelpPopup:constructor(props)
  return utils.object.assign(Popup.constructor(self), {
    config = {
      keymaps = {},
      position = 'bottom_right',
      border = {
        enabled = true,
        title = ' Key Mappings ',
        highlight = 'GitPopupBorder',
      },
      win_options = {
        winhl = 'Normal:GitHelpBackground',
        cursorline = false,
        cursorbind = false,
      },
      max_width = 60,
      min_width = 30,
      padding = 2,
    },
  }, props)
end

function KeyHelpPopup:calculate_content_dimensions()
  local max_key_length = 0
  local max_desc_length = 0
  local keymaps = self.config.keymaps

  for desc_key, key_info in pairs(keymaps) do
    local key
    local desc

    if type(key_info) == 'table' then
      key = key_info.key
      desc = key_info.desc
    else
      key = key_info
      desc = desc_key
    end

    max_key_length = math.max(max_key_length, #key)
    max_desc_length = math.max(max_desc_length, #desc)
  end

  local content_height = #utils.object.keys(keymaps) + self.config.padding * 2
  local total_width = max_key_length + max_desc_length + 5
  local content_width = math.min(
    math.max(total_width, self.config.min_width),
    self.config.max_width
  )

  return content_height, content_width
end

function KeyHelpPopup:center_key_lines(lines, content_width)
   local max_line_count = #lines[1]
  utils.list.each(lines, function(line)
    max_line_count = math.max(max_line_count, #line)
  end)

  local offset_width = math.floor((content_width - max_line_count) / 2)

  return utils.list.map(lines, function(line)
    local offset_padding = string.rep(' ', offset_width)
    return string.format('%s%s', offset_padding, line)
  end)
end

function KeyHelpPopup:generate_key_lines(content_width)
  local lines = {}
  local max_key_length = 0
  local keymaps = self.config.keymaps

  for _, key_info in pairs(keymaps) do
    local key

    if type(key_info) == 'table' then
      key = key_info.key
    else
      key = key_info
    end

    max_key_length = math.max(max_key_length, #key)
  end

  for desc_key, key_info in pairs(keymaps) do
    local key
    local desc

    if type(key_info) == 'table' then
      key = key_info.key
      desc = key_info.desc
    else
      key = key_info
      desc = desc_key
    end

    local padding = string.rep(' ', max_key_length - #key)
    local line = string.format('%s%s │ %s', key, padding, desc)

    table.insert(lines, line)
  end

  lines = self:center_key_lines(lines, content_width)

  for _ = 1, self.config.padding do
    table.insert(lines, 1, '')
    table.insert(lines, '')
  end

  return lines
end

function KeyHelpPopup:mount()
  local content_height, content_width = self:calculate_content_dimensions()

  self.config.height = content_height
  self.config.width = content_width

  Popup.mount(self)

  local lines = self:generate_key_lines(content_width)

  self.buffer:set_option('modifiable', true)
  self.buffer:set_lines(lines)
  self.buffer:set_option('modifiable', false)

  self:set_filetype('githelp')

  vim.cmd [[
    syntax match GitHelpKey /^\s*\zs\S\+/ contained
    syntax match GitHelpSeparator /│/ contained
    syntax match GitHelpDesc /│\s*\zs.*$/ contained
    syntax region GitHelpLine start=/^/ end=/$/ contains=GitHelpKey,GitHelpSeparator,GitHelpDesc
    highlight default link GitHelpKey Identifier
    highlight default link GitHelpSeparator Comment
    highlight default link GitHelpDesc Statement
  ]]

  self:set_keymap({
    mode = 'n',
    desc = 'Quit',
    key = '<enter>',
  }, function() self:unmount() end)

  return self
end

return KeyHelpPopup
