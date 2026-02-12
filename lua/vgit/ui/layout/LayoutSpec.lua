local lazy = require('vgit.core.lazy')
local Object = lazy('vgit.core.Object')

local LayoutSpec = Object:extend()

LayoutSpec.Type = {
  CONTAINER = 'container',
  FLEX = 'flex',
  ABSOLUTE = 'absolute',
  VIEW = 'view',
}

LayoutSpec.Direction = {
  HORIZONTAL = 'horizontal',
  VERTICAL = 'vertical',
}

LayoutSpec.Align = {
  START = 'start',
  CENTER = 'center',
  END = 'end',
  STRETCH = 'stretch',
}

LayoutSpec.Justify = {
  START = 'start',
  CENTER = 'center',
  END = 'end',
  SPACE_BETWEEN = 'space-between',
  SPACE_AROUND = 'space-around',
  SPACE_EVENLY = 'space-evenly',
}

LayoutSpec.Anchor = {
  TOP_LEFT = 'top-left',
  TOP_CENTER = 'top-center',
  TOP_RIGHT = 'top-right',
  CENTER_LEFT = 'center-left',
  CENTER = 'center',
  CENTER_RIGHT = 'center-right',
  BOTTOM_LEFT = 'bottom-left',
  BOTTOM_CENTER = 'bottom-center',
  BOTTOM_RIGHT = 'bottom-right',
}

function LayoutSpec.container(child)
  return {
    type = LayoutSpec.Type.CONTAINER,
    child = child,
  }
end

function LayoutSpec.horizontal(children, opts)
  opts = opts or {}
  return LayoutSpec.flex({
    direction = LayoutSpec.Direction.HORIZONTAL,
    children = children or {},
    gap = opts.gap,
    align = opts.align,
    justify = opts.justify,
  })
end

function LayoutSpec.vertical(children, opts)
  opts = opts or {}
  return LayoutSpec.flex({
    direction = LayoutSpec.Direction.VERTICAL,
    children = children or {},
    gap = opts.gap,
    align = opts.align,
    justify = opts.justify,
  })
end

function LayoutSpec.row(children, opts)
  opts = opts or {}
  return LayoutSpec.horizontal(children, {
    gap = opts.gap or 0,
    align = opts.align or LayoutSpec.Align.CENTER,
    justify = opts.justify or LayoutSpec.Justify.START,
  })
end

function LayoutSpec.flex(opts)
  opts = opts or {}
  return {
    type = LayoutSpec.Type.FLEX,
    direction = opts.direction or LayoutSpec.Direction.HORIZONTAL,
    children = opts.children or {},
    gap = opts.gap,
    align = opts.align,
    justify = opts.justify,
    flex = opts.flex,
    width = opts.width,
    height = opts.height,
    min_width = opts.min_width,
    max_width = opts.max_width,
    min_height = opts.min_height,
    max_height = opts.max_height,
  }
end

function LayoutSpec.absolute(child, opts)
  opts = opts or {}
  return {
    type = LayoutSpec.Type.ABSOLUTE,
    child = child,
    anchor = opts.anchor or LayoutSpec.Anchor.CENTER,
    offset = opts.offset,
    row = opts.row,
    col = opts.col,
    width = opts.width,
    height = opts.height,
    min_width = opts.min_width,
    max_width = opts.max_width,
    min_height = opts.min_height,
    max_height = opts.max_height,
    zindex = opts.zindex,
  }
end

function LayoutSpec.view(view_instance, opts)
  opts = opts or {}
  return {
    type = LayoutSpec.Type.VIEW,
    view = view_instance,
    id = opts.id,
    flex = opts.flex or 1,
    min_width = opts.min_width,
    max_width = opts.max_width,
    min_height = opts.min_height,
    max_height = opts.max_height,
    width = opts.width,
    height = opts.height,
    anchor = opts.anchor,
    offset = opts.offset,
    focus = opts.focus,
  }
end

function LayoutSpec.screen(children, opts)
  opts = opts or {}
  return LayoutSpec.absolute(LayoutSpec.vertical(children, opts), {
    anchor = LayoutSpec.Anchor.CENTER,
    width = '100vw',
    height = '100vh',
    zindex = opts.zindex or 1,
  })
end

function LayoutSpec.popup(child, opts)
  opts = opts or {}
  return LayoutSpec.absolute(child, {
    anchor = LayoutSpec.Anchor.CENTER,
    width = opts.width or '80vw',
    height = opts.height or '60vh',
    zindex = opts.zindex or 2,
  })
end

function LayoutSpec.lens(child, opts)
  opts = opts or {}
  return LayoutSpec.absolute(child, {
    anchor = LayoutSpec.Anchor.CENTER,
    width = opts.width or '100vw',
    height = opts.height or '35vh',
    zindex = opts.zindex or 2,
  })
end

function LayoutSpec.center(child, opts)
  opts = opts or {}
  return LayoutSpec.absolute(child, {
    anchor = LayoutSpec.Anchor.CENTER,
    width = opts.width,
    height = opts.height,
    zindex = opts.zindex,
  })
end

function LayoutSpec.full_width(child, opts)
  opts = opts or {}
  return LayoutSpec.absolute(child, {
    anchor = opts.anchor or LayoutSpec.Anchor.TOP_LEFT,
    width = '100vw',
    height = opts.height,
    zindex = opts.zindex,
  })
end

function LayoutSpec.full_height(child, opts)
  opts = opts or {}
  return LayoutSpec.absolute(child, {
    anchor = opts.anchor or LayoutSpec.Anchor.TOP_LEFT,
    width = opts.width,
    height = '100vh',
    zindex = opts.zindex,
  })
end

return LayoutSpec
