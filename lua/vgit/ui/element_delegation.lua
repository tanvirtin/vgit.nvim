local function define_single_element_methods(Class, opts)
  local exclude = opts and opts.exclude or {}

  -- Chainable methods

  function Class:set_lines(lines)
    self:with_element(function(el)
      el:set_lines(lines)
    end)
    return self
  end

  function Class:clear_lines()
    self:with_element(function(el)
      el:clear_lines()
    end)
    return self
  end

  function Class:set_cursor(cursor)
    self:with_element(function(el)
      el:set_cursor(cursor)
    end)
    return self
  end

  function Class:set_lnum(lnum)
    self:with_element(function(el)
      el:set_lnum(lnum)
    end)
    return self
  end

  function Class:scroll_to(pos, offset)
    self:with_element(function(el)
      el:scroll_to(pos, offset)
    end)
    return self
  end

  function Class:reset_cursor()
    self:with_element(function(el)
      el:reset_cursor()
    end)
    return self
  end

  function Class:set_width(width)
    self:with_element(function(el)
      el:set_width(width)
    end)
    return self
  end

  function Class:set_height(height)
    self:with_element(function(el)
      el:set_height(height)
    end)
    return self
  end

  function Class:focus()
    self:with_element(function(el)
      el:focus()
    end)
    return self
  end

  function Class:start_insert()
    self:with_element(function(el)
      el:start_insert()
    end)
    return self
  end

  function Class:stop_insert()
    self:with_element(function(el)
      el:stop_insert()
    end)
    return self
  end

  function Class:set_filetype(filetype)
    self:with_element(function(el)
      el:set_filetype(filetype)
    end)
    return self
  end

  function Class:clear_extmarks()
    self:with_element(function(el)
      el:clear_extmarks()
    end)
    return self
  end

  function Class:clear_extmark_lnums()
    self:with_element(function(el)
      el:clear_extmark_lnums()
    end)
    return self
  end

  function Class:clear_extmark_texts()
    self:with_element(function(el)
      el:clear_extmark_texts()
    end)
    return self
  end

  function Class:clear_extmark_signs()
    self:with_element(function(el)
      el:clear_extmark_signs()
    end)
    return self
  end

  function Class:clear_extmark_highlights(...)
    local args = { ... }
    self:with_element(function(el)
      el:clear_extmark_highlights(unpack(args))
    end)
    return self
  end

  function Class:set_keymap(opts_or_mode, callback_or_key, handler, desc)
    self:with_element(function(el)
      el:set_keymap(opts_or_mode, callback_or_key, handler, desc)
    end)
    return self
  end

  function Class:on(event_name, callback)
    self:with_element(function(el)
      el:on(event_name, callback)
    end)
    return self
  end

  function Class:attach_to_changes(callback)
    self:with_element(function(el)
      el:attach_to_changes(callback)
    end)
    return self
  end

  function Class:call(callback)
    self:with_element(function(el)
      el:call(callback)
    end)
    return self
  end

  function Class:set_win_option(key, value)
    self:with_element(function(el)
      el:set_win_option(key, value)
    end)
    return self
  end

  function Class:enable_cursorline()
    self:with_element(function(el)
      el:enable_cursorline()
    end)
    return self
  end

  function Class:disable_cursorline()
    self:with_element(function(el)
      el:disable_cursorline()
    end)
    return self
  end

  function Class:attach_to_renderer(callback)
    self:with_element(function(el)
      el:attach_to_renderer(callback)
    end)
    return self
  end

  function Class:detach_from_renderer()
    self:with_element(function(el)
      el:detach_from_renderer()
    end)
    return self
  end

  -- Return-value methods

  if not exclude.get_lines then
    function Class:get_lines()
      return self:with_element(function(el)
        return el:get_lines()
      end)
    end
  end

  if not exclude.get_line_count then
    function Class:get_line_count()
      return self:with_element(function(el)
        return el:get_line_count()
      end)
    end
  end

  if not exclude.get_cursor then
    function Class:get_cursor()
      return self:with_element(function(el)
        return el:get_cursor()
      end)
    end
  end

  if not exclude.get_lnum then
    function Class:get_lnum()
      return self:with_element(function(el)
        return el:get_lnum()
      end)
    end
  end

  if not exclude.get_width then
    function Class:get_width()
      return self:with_element(function(el)
        return el:get_width()
      end)
    end
  end

  if not exclude.get_height then
    function Class:get_height()
      return self:with_element(function(el)
        return el:get_height()
      end)
    end
  end

  if not exclude.get_filetype then
    function Class:get_filetype()
      return self:with_element(function(el)
        return el:get_filetype()
      end)
    end
  end

  function Class:is_focused()
    return self:with_element(function(el)
      return el:is_focused()
    end) or false
  end

  function Class:is_valid()
    return self:with_element(function()
      return true
    end) or false
  end

  function Class:place_extmark_text(extmark_opts)
    return self:with_element(function(el)
      return el:place_extmark_text(extmark_opts)
    end)
  end

  function Class:place_extmark_lnum(extmark_opts)
    return self:with_element(function(el)
      return el:place_extmark_lnum(extmark_opts)
    end)
  end

  function Class:place_extmark_sign(extmark_opts)
    return self:with_element(function(el)
      return el:place_extmark_sign(extmark_opts)
    end)
  end

  function Class:place_extmark_highlight(extmark_opts)
    return self:with_element(function(el)
      return el:place_extmark_highlight(extmark_opts)
    end)
  end
end

local function define_getters_with_fallbacks(Class, fallbacks)
  for method_name, fallback in pairs(fallbacks) do
    Class[method_name] = function(self)
      return self:with_element(function(el)
        return el[method_name](el)
      end) or fallback
    end
  end
end

return {
  define_single_element_methods = define_single_element_methods,
  define_getters_with_fallbacks = define_getters_with_fallbacks,
}
