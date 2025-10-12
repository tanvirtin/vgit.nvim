local Layout = {}

function Layout.screen(component, opts)
  opts = opts or {}

  return {
    mode = 'screen',
    component = component,
    width = opts.width,
    height = opts.height,
  }
end

function Layout.lens(component, opts)
  opts = opts or {}

  return {
    mode = 'lens',
    component = component,
    position = opts.position or 'cursor',
    width = opts.width,
    height = opts.height or '40vh',
    zindex = opts.zindex or 2,
  }
end

function Layout.popup(component, opts)
  opts = opts or {}

  return {
    mode = 'popup',
    component = component,
    position = opts.position or 'center',
    width = opts.width or 80,
    height = opts.height or 20,
    border = opts.border or 'rounded',
    title = opts.title,
    zindex = opts.zindex or 10,
  }
end

return Layout
