local lazy = require('vgit.core.lazy')

local utils = lazy('vgit.core.utils')
local Element = lazy('vgit.ui.elements.Element')

local DEFAULT_BUF_OPTIONS = {
  modifiable = false,
  buflisted = false,
  bufhidden = 'wipe',
}

local function create_component_element(defaults, props)
  local buf_opts = utils.object.extend(DEFAULT_BUF_OPTIONS, defaults.buf_options or {})
  if props.buf_options then buf_opts = utils.object.extend(buf_opts, props.buf_options) end
  if props.filetype then buf_opts.filetype = props.filetype end

  local el_config = { buf_options = buf_opts }

  if defaults.win_options or props.win_options then
    el_config.win_options = utils.object.extend(defaults.win_options or {}, props.win_options or {})
  end

  if defaults.win_plot then el_config.win_plot = utils.object.clone(defaults.win_plot) end
  if props.win_plot then el_config.win_plot = utils.object.extend(el_config.win_plot or {}, props.win_plot) end
  if props.plot then el_config.plot = props.plot end

  return Element(el_config)
end

return create_component_element
